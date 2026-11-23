//! §11.1 `srs/queue.rs`。

mod common;

use chrono::Duration;
use common::*;
use jp_srs::queue::{
    available_new_cards, next_card, queue_summary, NextCard, QueueLimits, QueueStep,
};
use jp_store::{ActivityDelta, ActivityRepo, QueueFilter, SqliteRepository, SrsRepo};

const LIMITS: QueueLimits = QueueLimits {
    review_cap: 10,
    new_words_per_day: 5,
    tail_new_cards_per_day: 100,
};
const AUDIO: QueueFilter = QueueFilter {
    audio_available: true,
};
const SILENT: QueueFilter = QueueFilter {
    audio_available: false,
};

fn next(repo: &SqliteRepository) -> NextCard {
    next_card(repo, &ctx(), LIMITS, AUDIO).unwrap()
}

fn next_id(repo: &SqliteRepository, limits: QueueLimits, queue: QueueFilter) -> Option<String> {
    match next_card(repo, &ctx(), limits, queue).unwrap() {
        NextCard::Card { card, .. } => Some(card.card_id),
        NextCard::Done { .. } => None,
    }
}

fn expect_step(repo: &SqliteRepository, card_id: &str, step: QueueStep) {
    match next(repo) {
        NextCard::Card { card, step: actual } => {
            assert_eq!(card.card_id, card_id);
            assert_eq!(actual, step);
        }
        NextCard::Done { .. } => panic!("期待 {card_id}，實際 Done"),
    }
}

fn due_review(repo: &SqliteRepository, card_id: &str) {
    add_old_card(repo, card_id, 0);
    place(repo, card_id, 2, ts(LONG_AGO));
}

#[test]
fn walks_the_six_steps_in_order() {
    let repo = repo();
    let now = ts(NOW);
    add_old_card(&repo, "vo.a:recog", 0);
    place(&repo, "vo.a:recog", 1, now - Duration::minutes(1));
    due_review(&repo, "vo.b:recog");
    add_old_card(&repo, "vo.c:recog", 0);
    add_old_card(&repo, "vo.d:listen", 1);
    add_old_card(&repo, "vo.e:recog", 0);
    place(&repo, "vo.e:recog", 3, now + Duration::minutes(10));

    expect_step(&repo, "vo.a:recog", QueueStep::Learning);
    clear_from_queue(&repo, "vo.a:recog");
    expect_step(&repo, "vo.b:recog", QueueStep::DueReview);
    clear_from_queue(&repo, "vo.b:recog");
    expect_step(&repo, "vo.c:recog", QueueStep::NewPriority0);
    clear_from_queue(&repo, "vo.c:recog");
    expect_step(&repo, "vo.d:listen", QueueStep::NewPriority1);
    clear_from_queue(&repo, "vo.d:listen");
    expect_step(&repo, "vo.e:recog", QueueStep::EarlyLearning);
    clear_from_queue(&repo, "vo.e:recog");
    assert_eq!(next(&repo), NextCard::Done { next_due_at: None });
}

mod learning {
    use super::*;

    #[test]
    fn only_cards_due_by_now_are_served_at_step_one() {
        let repo = repo();
        add_old_card(&repo, "vo.a:recog", 0);
        add_old_card(&repo, "vo.b:recog", 0);
        place(&repo, "vo.a:recog", 1, ts(NOW) + Duration::minutes(1));
        place(&repo, "vo.b:recog", 3, ts(NOW));

        expect_step(&repo, "vo.b:recog", QueueStep::Learning);
    }

    #[test]
    fn early_window_includes_exactly_twenty_minutes() {
        let repo = repo();
        add_old_card(&repo, "vo.a:recog", 0);
        place(&repo, "vo.a:recog", 1, ts(NOW) + Duration::minutes(20));

        expect_step(&repo, "vo.a:recog", QueueStep::EarlyLearning);
    }

    #[test]
    fn beyond_the_early_window_is_done_with_its_due_time() {
        let repo = repo();
        let due = ts(NOW) + Duration::minutes(20) + Duration::milliseconds(1);
        add_old_card(&repo, "vo.a:recog", 0);
        place(&repo, "vo.a:recog", 1, due);

        assert_eq!(
            next(&repo),
            NextCard::Done {
                next_due_at: Some(due)
            }
        );
    }
}

mod due_reviews {
    use super::*;

    #[test]
    fn due_is_compared_with_the_end_of_the_logical_day() {
        let repo = repo();
        add_old_card(&repo, "vo.in:recog", 0);
        add_old_card(&repo, "vo.out:recog", 0);
        place(
            &repo,
            "vo.in:recog",
            2,
            ts(END_OF_TODAY) - Duration::milliseconds(1),
        );
        place(&repo, "vo.out:recog", 2, ts(END_OF_TODAY));

        expect_step(&repo, "vo.in:recog", QueueStep::DueReview);
        clear_from_queue(&repo, "vo.in:recog");
        assert_eq!(next(&repo), NextCard::Done { next_due_at: None });
    }

    /// §6.4：21:00 排程 4 天的卡，第 4 天早上 08:00 就到期。
    #[test]
    fn a_card_scheduled_at_night_is_due_that_morning() {
        let repo = repo();
        let due_at_9pm = ts("2026-03-08T13:00:00Z"); // 台北 21:00
        let morning = ctx_at(ts("2026-03-08T00:00:00Z")); // 台北 08:00
        add_old_card(&repo, "vo.a:recog", 0);
        place(&repo, "vo.a:recog", 2, due_at_9pm);

        let found = next_card(&repo, &morning, LIMITS, AUDIO).unwrap();

        assert!(matches!(
            found,
            NextCard::Card {
                step: QueueStep::DueReview,
                ..
            }
        ));
    }

    #[test]
    fn oldest_due_comes_first() {
        let repo = repo();
        add_old_card(&repo, "vo.newer:recog", 0);
        add_old_card(&repo, "vo.older:recog", 0);
        place(&repo, "vo.newer:recog", 2, ts(NOW));
        place(&repo, "vo.older:recog", 2, ts(NOW) - Duration::hours(3));

        expect_step(&repo, "vo.older:recog", QueueStep::DueReview);
    }

    #[test]
    fn the_cap_is_measured_by_todays_reviews_done() {
        let repo = repo();
        due_review(&repo, "vo.a:recog");
        add_old_card(&repo, "vo.b:recog", 0);
        repo.add_activity(
            d(TODAY),
            ActivityDelta {
                reviews_done: 2,
                new_done: 50,
                relearn_done: 50,
                ..ActivityDelta::default()
            },
        )
        .unwrap();

        let open = QueueLimits {
            review_cap: 3,
            ..LIMITS
        };
        let reached = QueueLimits {
            review_cap: 2,
            ..LIMITS
        };

        assert_eq!(next_id(&repo, open, AUDIO).as_deref(), Some("vo.a:recog"));
        assert_eq!(
            next_id(&repo, reached, AUDIO).as_deref(),
            Some("vo.b:recog")
        );
    }

    #[test]
    fn yesterdays_reviews_do_not_count_against_the_cap() {
        let repo = repo();
        due_review(&repo, "vo.a:recog");
        repo.add_activity(
            d("2026-03-03"),
            ActivityDelta {
                reviews_done: 99,
                ..ActivityDelta::default()
            },
        )
        .unwrap();

        expect_step(&repo, "vo.a:recog", QueueStep::DueReview);
    }

    #[test]
    fn a_sibling_done_today_holds_the_other_facet_back() {
        let repo = repo();
        due_review(&repo, "vo.a:listen");
        due_review(&repo, "vo.b:recog");
        add_old_card(&repo, "vo.a:recog", 0);
        place_on(
            &repo,
            "vo.a:recog",
            2,
            ts(NOW) + Duration::days(30),
            d(TODAY),
        );

        expect_step(&repo, "vo.b:recog", QueueStep::DueReview);
    }

    #[test]
    fn suspended_cards_are_skipped() {
        let repo = repo();
        due_review(&repo, "vo.a:recog");
        due_review(&repo, "vo.b:recog");
        repo.set_content_suspended("vo.a", true).unwrap();

        expect_step(&repo, "vo.b:recog", QueueStep::DueReview);
    }
}

mod new_cards {
    use super::*;

    #[test]
    fn cards_created_today_wait_for_tomorrow() {
        let repo = repo();
        let start = ts(START_OF_TODAY);
        repo.insert_cards(&[new_card_at("vo.today:recog", 0, start)])
            .unwrap();
        repo.insert_cards(&[new_card_at("vo.today:listen", 1, start)])
            .unwrap();

        assert_eq!(next(&repo), NextCard::Done { next_due_at: None });
    }

    #[test]
    fn cards_created_before_the_day_started_are_served() {
        let repo = repo();
        let just_before = ts(START_OF_TODAY) - Duration::milliseconds(1);
        add_taught_card(&repo, "vo.y:recog", 0, just_before);

        expect_step(&repo, "vo.y:recog", QueueStep::NewPriority0);
    }

    #[test]
    fn introduction_order_decides_among_new_cards() {
        let repo = repo();
        add_old_card(&repo, "vo.z:recog", 0);
        add_old_card(&repo, "vo.a:recog", 0);

        expect_step(&repo, "vo.z:recog", QueueStep::NewPriority0);
    }

    #[test]
    fn priority_zero_ignores_siblings_done_today() {
        let repo = repo();
        add_old_card(&repo, "vo.a:listen", 0);
        add_old_card(&repo, "vo.a:recog", 0);
        place_on(
            &repo,
            "vo.a:recog",
            1,
            ts(NOW) + Duration::days(30),
            d(TODAY),
        );

        expect_step(&repo, "vo.a:listen", QueueStep::NewPriority0);
    }

    #[test]
    fn priority_one_excludes_siblings_done_today() {
        let repo = repo();
        add_old_card(&repo, "vo.a:listen", 1);
        add_old_card(&repo, "vo.b:listen", 1);
        add_old_card(&repo, "vo.a:recog", 0);
        place_on(
            &repo,
            "vo.a:recog",
            1,
            ts(NOW) + Duration::days(30),
            d(TODAY),
        );

        expect_step(&repo, "vo.b:listen", QueueStep::NewPriority1);
    }

    #[test]
    fn priority_one_stops_at_the_daily_limit() {
        let repo = repo();
        add_old_card(&repo, "vo.a:listen", 1);
        add_old_card(&repo, "vo.b:listen", 1);
        place_on(
            &repo,
            "vo.a:listen",
            1,
            ts(NOW) + Duration::days(30),
            d(TODAY),
        );
        let one_per_day = QueueLimits {
            new_words_per_day: 1,
            ..LIMITS
        };
        let two_per_day = QueueLimits {
            new_words_per_day: 2,
            ..LIMITS
        };

        assert_eq!(next_id(&repo, one_per_day, AUDIO), None);
        assert_eq!(
            next_id(&repo, two_per_day, AUDIO).as_deref(),
            Some("vo.b:listen")
        );
    }

    /// §6.4 收尾上限：第 3、4 步合計，今天以前建立、今天第一次接觸的卡不超過上限。
    #[test]
    fn steps_three_and_four_stop_at_the_daily_tail_limit() {
        let repo = repo();
        add_old_card(&repo, "vo.a:recog", 0);
        add_old_card(&repo, "vo.b:recog", 0);
        add_old_card(&repo, "vo.c:listen", 1);
        place_on(
            &repo,
            "vo.a:recog",
            1,
            ts(NOW) + Duration::days(30),
            d(TODAY),
        );
        let two_per_day = QueueLimits {
            tail_new_cards_per_day: 2,
            ..LIMITS
        };
        let one_per_day = QueueLimits {
            tail_new_cards_per_day: 1,
            ..LIMITS
        };

        assert_eq!(
            next_id(&repo, two_per_day, AUDIO).as_deref(),
            Some("vo.b:recog")
        );
        assert_eq!(next_id(&repo, one_per_day, AUDIO), None);
    }

    #[test]
    fn priority_zero_has_no_daily_limit() {
        let repo = repo();
        add_old_card(&repo, "vo.a:recog", 0);
        add_old_card(&repo, "vo.b:recog", 0);
        place_on(
            &repo,
            "vo.a:recog",
            1,
            ts(NOW) + Duration::days(30),
            d(TODAY),
        );
        let none_per_day = QueueLimits {
            new_words_per_day: 0,
            ..LIMITS
        };

        assert_eq!(
            next_id(&repo, none_per_day, AUDIO).as_deref(),
            Some("vo.b:recog")
        );
    }
}

mod silent_mode {
    use super::*;

    #[test]
    fn listen_cards_are_excluded_from_every_step() {
        let now = ts(NOW);
        let due_times = [
            (1, now - Duration::minutes(1)),
            (2, ts(LONG_AGO)),
            (3, now + Duration::minutes(10)),
        ];
        for (state, due) in due_times {
            let repo = repo();
            add_old_card(&repo, "vo.a:listen", 0);
            place(&repo, "vo.a:listen", state, due);

            assert_eq!(next_id(&repo, LIMITS, SILENT), None, "state {state}");
            assert_eq!(
                next_id(&repo, LIMITS, AUDIO).as_deref(),
                Some("vo.a:listen")
            );
        }
    }

    #[test]
    fn new_listen_cards_of_both_priorities_are_excluded() {
        let repo = repo();
        add_old_card(&repo, "vo.a:listen", 0);
        add_old_card(&repo, "vo.b:listen", 1);

        assert_eq!(next_id(&repo, LIMITS, SILENT), None);
    }

    #[test]
    fn next_due_time_ignores_listen_cards() {
        let repo = repo();
        let soon = ts(NOW) + Duration::hours(1);
        add_old_card(&repo, "vo.a:listen", 0);
        place(&repo, "vo.a:listen", 1, soon);

        assert_eq!(
            next_card(&repo, &ctx(), LIMITS, SILENT).unwrap(),
            NextCard::Done { next_due_at: None }
        );
        assert_eq!(
            next_card(&repo, &ctx(), LIMITS, AUDIO).unwrap(),
            NextCard::Done {
                next_due_at: Some(soon)
            }
        );
    }
}

mod summary {
    use super::*;

    #[test]
    fn counts_every_queue_and_echoes_the_cap() {
        let repo = repo();
        due_review(&repo, "vo.r1:recog");
        due_review(&repo, "vo.r2:recog");
        add_old_card(&repo, "vo.l:recog", 0);
        place(&repo, "vo.l:recog", 1, ts(NOW) + Duration::minutes(5));
        add_old_card(&repo, "vo.n:recog", 0);
        add_old_card(&repo, "vo.p:listen", 1);
        repo.add_activity(
            d(TODAY),
            ActivityDelta {
                reviews_done: 1,
                ..ActivityDelta::default()
            },
        )
        .unwrap();

        let summary = queue_summary(&repo, &ctx(), LIMITS, AUDIO).unwrap();

        assert_eq!(summary.due_reviews, 2);
        assert_eq!(summary.learning, 1);
        assert_eq!(summary.new_cards, 2);
        assert_eq!(summary.reviews_done_today, 1);
        assert_eq!(summary.review_cap, 10);
        assert_eq!(summary.remaining_estimate(), 5);
    }

    #[test]
    fn remaining_estimate_counts_reviews_only_up_to_the_cap() {
        let repo = repo();
        for index in 0..5 {
            due_review(&repo, &format!("vo.r{index}:recog"));
        }
        repo.add_activity(
            d(TODAY),
            ActivityDelta {
                reviews_done: 2,
                ..ActivityDelta::default()
            },
        )
        .unwrap();
        let limits = QueueLimits {
            review_cap: 3,
            ..LIMITS
        };

        let summary = queue_summary(&repo, &ctx(), limits, AUDIO).unwrap();

        assert_eq!(summary.due_reviews, 5);
        assert_eq!(summary.remaining_estimate(), 1);
    }

    /// §7.4：第 3 步全部計入，第 4 步不超過當日剩餘額度。
    #[test]
    fn new_cards_cap_priority_one_by_the_remaining_daily_limit() {
        let repo = repo();
        add_old_card(&repo, "vo.a:recog", 0);
        add_old_card(&repo, "vo.b:recog", 0);
        for name in ["c", "d", "e", "f"] {
            add_old_card(&repo, &format!("vo.{name}:listen"), 1);
        }
        place_on(
            &repo,
            "vo.c:listen",
            1,
            ts(NOW) + Duration::days(30),
            d(TODAY),
        );
        let limits = QueueLimits {
            new_words_per_day: 2,
            ..LIMITS
        };

        let available = available_new_cards(&repo, &ctx(), limits, AUDIO).unwrap();

        assert_eq!(available, 3);
    }

    #[test]
    fn new_cards_saturate_when_the_daily_limit_is_exhausted() {
        let repo = repo();
        add_old_card(&repo, "vo.c:listen", 1);
        add_old_card(&repo, "vo.d:listen", 1);
        place_on(
            &repo,
            "vo.c:listen",
            1,
            ts(NOW) + Duration::days(30),
            d(TODAY),
        );
        let limits = QueueLimits {
            new_words_per_day: 1,
            ..LIMITS
        };

        assert_eq!(
            available_new_cards(&repo, &ctx(), limits, AUDIO).unwrap(),
            0
        );
    }

    /// 長期無聲後打開聲音，累積的 `:listen` 新卡分散到之後幾天，`new_cards` 不超過剩餘的收尾上限。
    #[test]
    fn new_cards_are_capped_by_the_remaining_tail_limit() {
        let repo = repo();
        for name in ["a", "b", "c", "d", "e"] {
            add_old_card(&repo, &format!("vo.{name}:listen"), 0);
        }
        place_on(
            &repo,
            "vo.a:listen",
            1,
            ts(NOW) + Duration::days(30),
            d(TODAY),
        );
        let limits = QueueLimits {
            tail_new_cards_per_day: 3,
            ..LIMITS
        };

        assert_eq!(
            available_new_cards(&repo, &ctx(), limits, AUDIO).unwrap(),
            2
        );
        assert_eq!(
            available_new_cards(&repo, &ctx(), LIMITS, AUDIO).unwrap(),
            4
        );
    }

    #[test]
    fn new_cards_exclude_listen_in_silent_mode() {
        let repo = repo();
        add_old_card(&repo, "vo.a:recog", 0);
        add_old_card(&repo, "vo.a:listen", 0);
        add_old_card(&repo, "vo.b:listen", 1);

        assert_eq!(
            available_new_cards(&repo, &ctx(), LIMITS, AUDIO).unwrap(),
            3
        );
        assert_eq!(
            available_new_cards(&repo, &ctx(), LIMITS, SILENT).unwrap(),
            1
        );
    }
}

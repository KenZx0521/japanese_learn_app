//! §9.6 作答流程。對錯判定由 jp_quiz 負責，這裡從評分開始。

mod common;

use std::sync::Arc;

use chrono::Duration;
use common::*;
use jp_lang::clock::DayContext;
use jp_srs::review::{submit_review, Grade, ReviewRequest};
use jp_srs::{CardState, FsrsScheduler, Outcome, Rating, SrsError, SrsScheduler, SrsState};
use jp_store::{ActivityRepo, DailyActivityRow, SqliteRepository, SrsRepo, StoreError};

const CARD: &str = "vo.gakusei:recog";

const GOOD: Grade = Grade::SelfRated(Rating::Good);

fn scheduler() -> FsrsScheduler {
    FsrsScheduler::new(0.9).unwrap()
}

fn request(expected_reps: i32) -> ReviewRequest<'static> {
    ReviewRequest {
        card_id: CARD,
        expected_reps,
        grade: GOOD,
        question_type: "recog",
        duration_ms: 1500,
    }
}

fn seeded() -> SqliteRepository {
    let repo = repo();
    add_old_card(&repo, CARD, 0);
    repo
}

fn activity_on(repo: &SqliteRepository, date: &str) -> DailyActivityRow {
    repo.activity_range(d(date), d(date)).unwrap().remove(0)
}

/// 回傳固定 `scheduled_days` 的排程器，用來驗證解鎖與錯誤路徑。
struct FixedInterval {
    scheduled_days: i64,
    fail: bool,
}

impl SrsScheduler for FixedInterval {
    fn preview(&self, _: &CardState, _: &DayContext) -> Result<[Outcome; 4], SrsError> {
        panic!("作答流程不該呼叫 preview");
    }

    fn review(
        &self,
        card: &CardState,
        rating: Rating,
        ctx: &DayContext,
    ) -> Result<Outcome, SrsError> {
        if self.fail {
            return Err(SrsError::Internal {
                message: "invalid FSRS output".to_string(),
            });
        }
        Ok(Outcome {
            rating,
            card: CardState {
                state: SrsState::Review,
                due: ctx.now + Duration::days(self.scheduled_days),
                last_review: ctx.now,
                stability: 8.0,
                difficulty: 5.0,
                elapsed_days: 0,
                scheduled_days: self.scheduled_days,
                reps: card.reps + 1,
                lapses: card.lapses,
            },
            state_before: card.state,
            elapsed_days: 0,
            scheduled_days_before: card.scheduled_days,
            reviewed_at: ctx.now,
            clock_skewed: false,
        })
    }
}

mod rating_mapping {
    use super::*;

    fn auto(is_correct: bool, hint_used: bool, attempts: u32) -> Rating {
        Grade::Auto {
            is_correct,
            hint_used,
            attempts,
        }
        .rating()
    }

    #[test]
    fn self_rating_passes_through() {
        for rating in Rating::ALL {
            assert_eq!(Grade::SelfRated(rating).rating(), rating);
        }
    }

    /// §6.2 全表。
    #[test]
    fn auto_grading_follows_the_table() {
        assert_eq!(auto(false, false, 1), Rating::Again);
        assert_eq!(auto(false, true, 3), Rating::Again);
        assert_eq!(auto(true, true, 1), Rating::Hard);
        assert_eq!(auto(true, false, 2), Rating::Hard);
        assert_eq!(auto(true, false, 1), Rating::Good);
        assert_eq!(auto(true, false, 0), Rating::Good);
    }

    #[test]
    fn auto_grading_never_gives_easy() {
        for attempts in 0..4 {
            for (correct, hint) in [(true, true), (true, false), (false, true), (false, false)] {
                assert_ne!(auto(correct, hint, attempts), Rating::Easy);
            }
        }
    }
}

mod happy_path {
    use super::*;

    #[test]
    fn first_answer_moves_the_card_out_of_new_and_logs_it() {
        let repo = seeded();

        let result = submit_review(&repo, &content(), &scheduler(), &ctx(), &request(0)).unwrap();

        let card = repo.card(CARD).unwrap().unwrap();
        assert_eq!(card.state, 1);
        assert_eq!(card.reps, 1);
        assert_eq!(card.due_at, ts(NOW) + Duration::minutes(10));
        assert_eq!(card.last_review_at, ts(NOW));
        assert_eq!(card.last_logical_date, Some(d(TODAY)));
        assert_eq!(result.outcome.interval_minutes(), 10);
        assert_eq!(result.outcome.rating, Rating::Good);
        assert_eq!(result.unlocked_cards, 0);
    }

    #[test]
    fn log_records_the_answer_in_detail() {
        let repo = seeded();

        submit_review(&repo, &content(), &scheduler(), &ctx(), &request(0)).unwrap();

        let logs = repo.reviews_for_card(CARD).unwrap();
        assert_eq!(logs.len(), 1);
        let entry = &logs[0].entry;
        assert_eq!(entry.rating, 3);
        assert_eq!(entry.state_before, 0);
        assert_eq!(entry.state_after, 1);
        assert_eq!(entry.logical_date, d(TODAY));
        assert_eq!(entry.reviewed_at, ts(NOW));
        assert_eq!(entry.utc_offset_minutes, 480);
        assert_eq!(entry.duration_ms, 1500);
        assert_eq!(entry.question_type, "recog");
        assert!(!entry.clock_skewed);
    }

    /// `review_log.scheduled_days` 是作答前的值，與卡片新的間隔不同。
    #[test]
    fn log_keeps_the_interval_from_before_the_answer() {
        let repo = seeded();
        place(&repo, CARD, 2, ts(NOW));
        let again = ReviewRequest {
            grade: Grade::SelfRated(Rating::Again),
            ..request(1)
        };

        submit_review(&repo, &content(), &scheduler(), &ctx(), &again).unwrap();

        let log = repo.reviews_for_card(CARD).unwrap().remove(1).entry;
        assert_eq!(log.scheduled_days, 4);
        assert_eq!(repo.card(CARD).unwrap().unwrap().scheduled_days, 0);
    }

    #[test]
    fn the_stage_before_the_answer_decides_which_counter_grows() {
        let repo = seeded();
        let store = content();
        let scheduler = scheduler();

        let first = submit_review(&repo, &store, &scheduler, &ctx(), &request(0)).unwrap();
        let second_at = first.outcome.card.due;
        let second =
            submit_review(&repo, &store, &scheduler, &ctx_at(second_at), &request(1)).unwrap();
        assert_eq!(second.outcome.state_before, SrsState::Learning);
        let third_at = second.outcome.card.due;
        submit_review(&repo, &store, &scheduler, &ctx_at(third_at), &request(2)).unwrap();

        let today = activity_on(&repo, TODAY);
        assert_eq!(
            (today.new_done, today.relearn_done, today.reviews_done),
            (1, 1, 0)
        );
        assert_eq!(today.study_ms, 3000);
        let later_day = third_at.format("%Y-%m-%d").to_string();
        assert_eq!(activity_on(&repo, &later_day).reviews_done, 1);
    }

    #[test]
    fn again_on_a_learning_card_counts_as_relearn() {
        let repo = seeded();
        let store = content();
        let scheduler = scheduler();
        place(&repo, CARD, 3, ts(NOW));
        let again = ReviewRequest {
            grade: Grade::SelfRated(Rating::Again),
            ..request(1)
        };

        submit_review(&repo, &store, &scheduler, &ctx(), &again).unwrap();

        assert_eq!(activity_on(&repo, TODAY).relearn_done, 1);
    }

    /// F1 穿過整個流程：21:00 複習，隔天 08:00 再答，存進去的經過天數是 1。
    #[test]
    fn logical_day_gap_reaches_the_database() {
        let repo = seeded();
        let night = ts("2026-03-04T13:00:00Z");
        let morning = ts("2026-03-05T00:00:00Z");
        let store = content();
        let scheduler = scheduler();
        let easy = ReviewRequest {
            grade: Grade::SelfRated(Rating::Easy),
            ..request(0)
        };

        submit_review(&repo, &store, &scheduler, &ctx_at(night), &easy).unwrap();
        submit_review(&repo, &store, &scheduler, &ctx_at(morning), &request(1)).unwrap();

        let logs = repo.reviews_for_card(CARD).unwrap();
        assert_eq!(logs[1].entry.elapsed_days, 1);
        assert_eq!(repo.card(CARD).unwrap().unwrap().elapsed_days, 1);
    }

    #[test]
    fn a_rolled_back_clock_is_flagged_and_stays_finite() {
        let repo = seeded();
        let store = content();
        let scheduler = scheduler();
        let start = ts(NOW);
        let first = submit_review(&repo, &store, &scheduler, &ctx_at(start), &request(0)).unwrap();
        let rolled_back = ctx_at(first.outcome.card.due - Duration::days(100));

        let second = submit_review(&repo, &store, &scheduler, &rolled_back, &request(1)).unwrap();

        let card = repo.card(CARD).unwrap().unwrap();
        assert!(card.stability.is_finite() && card.stability > 0.0);
        assert!(second.outcome.clock_skewed);
        assert_eq!(card.last_review_at, start, "卡片時間不得倒退");
        let log = &repo.reviews_for_card(CARD).unwrap()[1].entry;
        assert!(log.clock_skewed);
        assert_eq!(log.reviewed_at, rolled_back.now, "log 留下裝置當時的時刻");
        assert_eq!(log.logical_date, rolled_back.today());
    }
}

mod rejected_answers {
    use super::*;

    fn is_stale(result: Result<impl std::fmt::Debug, SrsError>) -> bool {
        matches!(result, Err(SrsError::Store(StoreError::StaleCard { .. })))
    }

    #[test]
    fn unknown_card_is_not_found() {
        let repo = repo();

        let result = submit_review(&repo, &content(), &scheduler(), &ctx(), &request(0));

        assert!(
            matches!(result, Err(SrsError::NotFound { ref entity, ref id }) if entity == "card" && id == CARD)
        );
    }

    #[test]
    fn malformed_card_id_is_invalid_input() {
        let repo = repo();
        let bad = ReviewRequest {
            card_id: "not a card",
            ..request(0)
        };

        let result = submit_review(&repo, &content(), &scheduler(), &ctx(), &bad);

        assert!(matches!(result, Err(SrsError::InvalidInput { .. })));
    }

    #[test]
    fn a_mismatched_rep_count_is_stale_and_writes_nothing() {
        let repo = seeded();

        let result = submit_review(&repo, &content(), &scheduler(), &ctx(), &request(7));

        assert!(is_stale(result));
        assert_eq!(repo.reviews_for_card(CARD).unwrap().len(), 0);
    }

    /// 排程之前就要擋下，排程器不該看到過期的卡。
    #[test]
    fn a_stale_card_never_reaches_the_scheduler() {
        let repo = seeded();
        let failing = FixedInterval {
            scheduled_days: 0,
            fail: true,
        };

        let result = submit_review(&repo, &content(), &failing, &ctx(), &request(7));

        assert!(is_stale(result));
    }

    #[test]
    fn a_double_tap_applies_once() {
        let repo = seeded();
        let store = content();

        submit_review(&repo, &store, &scheduler(), &ctx(), &request(0)).unwrap();
        let second = submit_review(&repo, &store, &scheduler(), &ctx(), &request(0));

        assert!(is_stale(second));
        assert_eq!(repo.reviews_for_card(CARD).unwrap().len(), 1);
        assert_eq!(activity_on(&repo, TODAY).new_done, 1);
    }

    #[test]
    fn a_scheduler_failure_writes_nothing() {
        let repo = seeded();
        let failing = FixedInterval {
            scheduled_days: 0,
            fail: true,
        };

        let result = submit_review(&repo, &content(), &failing, &ctx(), &request(0));

        assert!(matches!(result, Err(SrsError::Internal { .. })));
        assert_eq!(repo.reviews_for_card(CARD).unwrap().len(), 0);
        assert_eq!(repo.card(CARD).unwrap().unwrap().reps, 0);
    }

    /// F3 的 store 邊界：排程器漏掉 Infinity 時，寫入也要被擋下。
    #[test]
    fn a_non_finite_outcome_is_stopped_at_the_store() {
        struct InfiniteStability;
        impl SrsScheduler for InfiniteStability {
            fn preview(&self, _: &CardState, _: &DayContext) -> Result<[Outcome; 4], SrsError> {
                unreachable!()
            }
            fn review(
                &self,
                card: &CardState,
                rating: Rating,
                ctx: &DayContext,
            ) -> Result<Outcome, SrsError> {
                let healthy = FixedInterval {
                    scheduled_days: 3,
                    fail: false,
                }
                .review(card, rating, ctx)?;
                Ok(Outcome {
                    card: CardState {
                        stability: f64::INFINITY,
                        ..healthy.card.clone()
                    },
                    ..healthy
                })
            }
        }
        let repo = seeded();

        let result = submit_review(&repo, &content(), &InfiniteStability, &ctx(), &request(0));

        assert!(matches!(
            result,
            Err(SrsError::Store(StoreError::Internal { .. }))
        ));
        assert_eq!(repo.card(CARD).unwrap().unwrap().reps, 0);
    }

    #[test]
    fn concurrent_submissions_apply_exactly_once() {
        let repo = Arc::new(seeded());
        let store = Arc::new(content());

        let handles: Vec<_> = (0..8)
            .map(|_| {
                let repo = Arc::clone(&repo);
                let store = Arc::clone(&store);
                std::thread::spawn(move || {
                    submit_review(repo.as_ref(), &store, &scheduler(), &ctx(), &request(0))
                })
            })
            .collect();
        let results: Vec<_> = handles.into_iter().map(|h| h.join().unwrap()).collect();

        assert_eq!(results.iter().filter(|r| r.is_ok()).count(), 1);
        assert!(results
            .into_iter()
            .filter_map(Result::err)
            .all(|err| matches!(err, SrsError::Store(StoreError::StaleCard { .. }))));
        assert_eq!(repo.reviews_for_card(CARD).unwrap().len(), 1);
    }
}

mod unlocks {
    use super::*;

    fn fixed(days: i64) -> FixedInterval {
        FixedInterval {
            scheduled_days: days,
            fail: false,
        }
    }

    fn exists(repo: &SqliteRepository, id: &str) -> bool {
        repo.card(id).unwrap().is_some()
    }

    #[test]
    fn crossing_a_threshold_creates_the_next_facet() {
        let repo = seeded();

        let result = submit_review(&repo, &content(), &fixed(4), &ctx(), &request(0)).unwrap();

        assert_eq!(result.unlocked_cards, 1);
        let listen = repo.card("vo.gakusei:listen").unwrap().unwrap();
        assert_eq!(listen.priority, 1);
        assert_eq!(listen.state, 0);
        assert_eq!(listen.created_at, ts(NOW));
        assert!(!exists(&repo, "vo.gakusei:produce"));
    }

    #[test]
    fn already_unlocked_facets_are_not_counted_again() {
        let repo = seeded();
        let store = content();

        submit_review(&repo, &store, &fixed(4), &ctx(), &request(0)).unwrap();
        let second = submit_review(&repo, &store, &fixed(7), &ctx(), &request(1)).unwrap();

        assert_eq!(second.unlocked_cards, 1);
        assert!(exists(&repo, "vo.gakusei:produce"));
    }

    #[test]
    fn below_the_threshold_nothing_is_created() {
        let repo = seeded();

        let result = submit_review(&repo, &content(), &fixed(3), &ctx(), &request(0)).unwrap();

        assert_eq!(result.unlocked_cards, 0);
        assert!(!exists(&repo, "vo.gakusei:listen"));
    }

    #[test]
    fn a_full_real_schedule_eventually_unlocks_listen_and_produce() {
        let repo = seeded();
        let store = content();
        let scheduler = scheduler();
        let mut now = ts(NOW);

        for reps in 0..4 {
            let result =
                submit_review(&repo, &store, &scheduler, &ctx_at(now), &request(reps)).unwrap();
            now = result.outcome.card.due;
        }

        assert!(exists(&repo, "vo.gakusei:listen"));
        assert!(exists(&repo, "vo.gakusei:produce"));
    }
}

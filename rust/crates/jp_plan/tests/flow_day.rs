//! §7.4 今日任務流程，用真實 SQLite（單日流程與換日界線）。

mod common;

use chrono::Duration;
use common::flow::*;
use common::*;
use jp_content::ContentStore;
use jp_lang::clock::DayContext;
use jp_plan::complete::complete_task;
use jp_plan::input::PlanInput;
use jp_plan::slice::Slice;
use jp_plan::tasks::DailyTask;
use jp_plan::today::{ensure_snapshot, learn_more, session_limits, today_view};
use jp_plan::PlanError;
use jp_srs::queue::{next_card, NextCard, QueueLimits, QueueStep};
use jp_store::{ActivityRepo, PlanRepo, QueueFilter, SqliteRepository, SrsRepo};

mod first_day {
    use super::*;

    #[test]
    fn lists_review_done_and_first_batch() {
        let (repo, store) = setup(20);

        let got = view(&repo, &store, monday());

        assert_eq!(got.logical_date, monday());
        assert!(got.is_study_day);
        assert_eq!(keys(&got), vec!["review", "new:ka.hira.a"]);
        let review = task(&got, "review");
        assert!(review.done, "due 0、learning 0 時 Review 為 done");
        assert_eq!(review.review.unwrap().due, 0);
        assert_eq!(got.estimated_minutes, 12.0);
        assert_eq!(got.learning_tail, 0);
    }

    #[test]
    fn no_plan_is_not_found() {
        let (repo, store) = (repo(), content());

        let err = today_view(&repo, &store, &ctx_on(monday()), AUDIO).unwrap_err();

        assert!(matches!(err, PlanError::NotFound { .. }));
    }
}

mod snapshot {
    use super::*;

    #[test]
    fn frozen_for_the_whole_day() {
        let (repo, store) = setup(20);
        let before = view(&repo, &store, monday());

        // 當天新增一張到期卡：快照預算不變，Review 的到期數即時更新。
        seed_due_review(&repo, "vo.watashi", "recog", ts("2026-03-02T10:00:00Z"));
        let after = view(&repo, &store, monday());

        assert_eq!(before.budget, after.budget);
        assert_eq!(keys(&before), keys(&after));
        assert_eq!(task(&after, "review").review.unwrap().due, 1);
        assert!(!task(&after, "review").done);
    }

    #[test]
    fn corrupt_payload_is_rebuilt() {
        let (repo, store) = setup(20);
        let row = {
            ensure_snapshot(&repo, &store, &ctx_on(monday()), AUDIO).unwrap();
            let mut row = repo.snapshot(monday()).unwrap().unwrap();
            row.payload_json = "{bad".to_owned();
            row
        };
        repo.put_snapshot(&row).unwrap();

        let got = view(&repo, &store, monday());

        assert_eq!(keys(&got), vec!["review", "new:ka.hira.a"]);
    }

    #[test]
    fn session_limits_come_from_the_snapshot() {
        let (repo, store) = setup(20);

        let limits = session_limits(&repo, &store, &ctx_on(monday()), AUDIO).unwrap();

        assert_eq!(
            limits,
            QueueLimits {
                review_cap: 60,
                new_words_per_day: 5,
                // S0 的 review 8 分＝480 秒，一半給收尾新卡：240 / 8 = 30 張。
                tail_new_cards_per_day: 30,
            }
        );
        assert!(
            repo.snapshot(monday()).unwrap().is_some(),
            "必要時先建立快照"
        );
    }
}

mod complete {
    use super::*;

    #[test]
    fn new_content_intros_and_creates_read_cards() {
        let (repo, store) = setup(20);
        let today = monday();
        let key = new_key(&view(&repo, &store, today));

        let got = done(&repo, &store, today, &key);

        assert!(task(&got, &key).done);
        let intro = repo.introduced_items().unwrap();
        assert!(intro.contains("ka.hira.a") && intro.contains("ka.hira.u"));
        assert!(repo.card("ka.hira.a:read").unwrap().is_some());
        assert_eq!(repo.task_done(today).unwrap().len(), 1);
    }

    /// 題數來自 `kana_submit` 的實際作答，結案本身不補題數（§7.6）。
    #[test]
    fn kana_slice_completion_adds_no_answers_by_itself() {
        let (repo, store) = setup(20);
        let key = new_key(&view(&repo, &store, monday()));

        done(&repo, &store, monday(), &key);

        let rows = repo.activity_range(monday(), monday()).unwrap();
        assert_eq!(rows[0].new_done, 0);
    }

    #[test]
    fn duration_goes_into_study_ms() {
        let (repo, store) = setup(20);
        let key = new_key(&view(&repo, &store, monday()));

        done(&repo, &store, monday(), &key);

        let rows = repo.activity_range(monday(), monday()).unwrap();
        assert_eq!(rows[0].study_ms, 60_000);
    }

    #[test]
    fn repeated_call_is_a_no_op() {
        let (repo, store) = setup(20);
        let key = new_key(&view(&repo, &store, monday()));

        done(&repo, &store, monday(), &key);
        done(&repo, &store, monday(), &key);

        let rows = repo.activity_range(monday(), monday()).unwrap();
        assert_eq!(rows[0].study_ms, 60_000);
    }

    #[test]
    fn unknown_key_is_not_found() {
        let (repo, store) = setup(20);
        view(&repo, &store, monday());

        let err = complete_task(&repo, &store, &ctx_on(monday()), "bogus", 1, AUDIO).unwrap_err();

        assert!(matches!(err, PlanError::NotFound { .. }));
    }

    #[test]
    fn review_key_is_recorded() {
        let (repo, store) = setup(20);
        seed_due_review(&repo, "vo.watashi", "recog", ts("2026-03-02T10:00:00Z"));
        view(&repo, &store, monday());

        let got = done(&repo, &store, monday(), "review");

        assert!(task(&got, "review").done);
    }

    #[test]
    fn completing_last_chars_finishes_lesson_and_adds_lessons_done() {
        let (repo, store) = setup(45);

        // 45 分方案：第一批 3 字；第二批 10 字補完 K01 與 K02，再取 K03 前 3 字。
        for offset in 0..2 {
            let key = new_key(&view(&repo, &store, day(offset)));
            done(&repo, &store, day(offset), &key);
        }

        let progress = repo.lesson_progress().unwrap();
        assert_eq!(progress["le.k01"].completed_date, Some(day(1)));
        let lessons = repo.activity_range(day(1), day(1)).unwrap()[0].lessons_done;
        assert_eq!(lessons, 2);
    }
}

mod learning_counts {
    use super::*;

    #[test]
    fn card_created_today_goes_to_the_tail_and_keeps_review_done() {
        let (repo, store) = setup(20);
        let ctx = ctx_on(monday());
        repo.insert_cards(&[new_card("vo.watashi", "recog", 0, ctx.now)])
            .unwrap();
        first_contact_due(&repo, "vo.watashi:recog", ctx.now, ctx.now);

        let got = view(&repo, &store, monday());

        let review = task(&got, "review");
        assert_eq!(review.review.unwrap().learning, 0);
        assert!(review.done);
        assert_eq!(got.learning_tail, 1);
    }

    #[test]
    fn learning_card_created_earlier_keeps_review_open() {
        let (repo, store) = setup(20);
        let ctx = ctx_on(monday());
        let yesterday = ctx.now - Duration::days(1);
        repo.insert_cards(&[new_card("vo.watashi", "recog", 0, yesterday)])
            .unwrap();
        first_contact_due(&repo, "vo.watashi:recog", yesterday, ctx.now);

        let got = view(&repo, &store, monday());

        let review = task(&got, "review");
        assert_eq!(review.review.unwrap().learning, 1);
        assert!(!review.done);
    }
}

mod next_day {
    use super::*;

    fn after_first_day() -> (SqliteRepository, ContentStore) {
        let (repo, store) = setup(20);
        let key = new_key(&view(&repo, &store, monday()));
        done(&repo, &store, monday(), &key);
        (repo, store)
    }

    #[test]
    fn untouched_read_cards_show_as_new_cards_and_review_is_done() {
        let (repo, store) = after_first_day();

        let got = view(&repo, &store, day(1));

        let review = task(&got, "review");
        assert!(review.done, "只剩 state=0 卡時 Review 為 done");
        assert_eq!(review.review.unwrap().new_cards, 3);
        assert_eq!(review.review.unwrap().due, 0);
        assert_eq!(got.learning_tail, 3);
    }

    #[test]
    fn estimated_minutes_counts_new_cards_even_when_review_is_done() {
        let (repo, store) = after_first_day();

        let got = view(&repo, &store, day(1));

        // 新內容 12 分 + 新卡 3×8 秒 ≈ 0.5 分。
        assert_eq!(got.estimated_minutes, 12.5);
    }

    #[test]
    fn session_next_returns_the_cards_without_first_card() {
        let (repo, store) = after_first_day();
        let ctx = ctx_on(day(1));
        let limits = session_limits(&repo, &store, &ctx, AUDIO).unwrap();

        let next = next_card(
            &repo,
            &ctx,
            limits,
            QueueFilter {
                audio_available: AUDIO,
            },
        )
        .unwrap();

        let NextCard::Card { card, step } = next else {
            panic!("{next:?}")
        };
        assert_eq!(step, QueueStep::NewPriority0);
        assert_eq!(card.card_id, "ka.hira.a:read");
    }

    #[test]
    fn second_slice_uses_daily_quota() {
        let (repo, store) = after_first_day();

        let got = view(&repo, &store, day(1));

        let DailyTask::NewContent {
            slice: Slice::Kana { kana, .. },
            ..
        } = &task(&got, &new_key(&got)).task
        else {
            panic!()
        };
        assert_eq!(kana.len(), 5);
    }
}

mod day_boundary {
    use super::*;

    fn ctx_utc(text: &str) -> DayContext {
        DayContext {
            now: ts(text),
            utc_offset_minutes: 480,
            rollover_hour: 4,
        }
    }

    #[test]
    fn before_rollover_is_still_the_previous_logical_day() {
        let (repo, store) = setup(20);

        // +08:00、換日 4 點：03-02T19:59:59Z 是 03-03 03:59:59 → 邏輯日 03-02。
        let before = today_view(&repo, &store, &ctx_utc("2026-03-02T19:59:59Z"), AUDIO).unwrap();
        let after = today_view(&repo, &store, &ctx_utc("2026-03-02T20:00:00Z"), AUDIO).unwrap();

        assert_eq!(before.logical_date, monday());
        assert_eq!(after.logical_date, day(1));
    }

    #[test]
    fn task_done_stays_with_the_logical_day_across_midnight() {
        let (repo, store) = setup(20);
        let late = ctx_utc("2026-03-02T17:00:00Z"); // 當地 01:00，邏輯日仍是 03-02
        let key = new_key(&today_view(&repo, &store, &late, AUDIO).unwrap());

        complete_task(&repo, &store, &late, &key, 1, AUDIO).unwrap();

        assert_eq!(repo.task_done(monday()).unwrap().len(), 1);
    }

    #[test]
    fn utc_offset_change_moves_the_logical_day() {
        let (repo, store) = setup(20);
        let taipei = DayContext {
            now: ts("2026-03-02T21:00:00Z"),
            utc_offset_minutes: 480,
            rollover_hour: 4,
        };
        let new_york = DayContext {
            utc_offset_minutes: -300,
            ..taipei
        };

        // 台北 05:00 已是 03-03，紐約 16:00 仍是 03-02。
        assert_eq!(
            today_view(&repo, &store, &taipei, AUDIO)
                .unwrap()
                .logical_date,
            day(1)
        );
        assert_eq!(
            today_view(&repo, &store, &new_york, AUDIO)
                .unwrap()
                .logical_date,
            monday()
        );
    }

    #[test]
    fn rollover_hour_change_only_affects_later_days() {
        let (repo, store) = setup(20);
        let ctx0 = DayContext {
            now: ts("2026-03-02T19:00:00Z"),
            utc_offset_minutes: 480,
            rollover_hour: 0,
        };
        let ctx4 = DayContext {
            rollover_hour: 4,
            ..ctx0
        };

        // 當地 03-03 03:00：換日 0 點已是隔天，換日 4 點仍是今天。
        assert_eq!(
            today_view(&repo, &store, &ctx0, AUDIO)
                .unwrap()
                .logical_date,
            day(1)
        );
        assert_eq!(
            today_view(&repo, &store, &ctx4, AUDIO)
                .unwrap()
                .logical_date,
            monday()
        );
    }
}

/// curriculum §11.3-2：收尾新卡的時間先從 review 額度扣掉，T1 的預估不超過方案分鐘。
mod t1_estimate {
    use super::*;

    const TAIL_KANA: [&str; 10] = ["a", "i", "u", "e", "o", "ka", "ki", "ku", "ke", "ko"];

    fn with_tail_and_due(due: usize) -> (SqliteRepository, ContentStore) {
        let (repo, store) = setup(20);
        let yesterday = ctx_on(monday()).now - Duration::days(1);
        let tail: Vec<_> = TAIL_KANA
            .iter()
            .map(|kana| new_card(&format!("ka.hira.{kana}"), "read", 0, yesterday))
            .collect();
        repo.insert_cards(&tail).unwrap();
        for i in 0..due {
            seed_due_review(
                &repo,
                &format!("vo.x{i}"),
                "recog",
                ts("2026-03-01T10:00:00Z"),
            );
        }
        (repo, store)
    }

    #[test]
    fn review_cap_leaves_room_for_the_new_card_tail() {
        let (repo, store) = with_tail_and_due(70);

        let got = view(&repo, &store, monday());

        assert_eq!(task(&got, "review").review.unwrap().new_cards, 10);
        // S0 的 review 8 分＝480 秒，扣 10 × 8 = 80 秒，餘 400 秒 / 8 = 50 張；
        // 50 × 8 + 80 = 480 秒＝8 分，加新內容 12 分剛好 20 分。
        assert_eq!(got.budget.review_cap, 50);
        assert_eq!(task(&got, "review").minutes, 8.0);
        assert_eq!(got.estimated_minutes, 20.0);
    }

    /// 長期無聲後打開聲音：前些天建的 `:listen` 新卡一次可取上百張（review_rust R2-H1）。
    /// 收尾一天至多用 review 秒數的一半，`review_cap` 不塌成 1，T1 不超過方案分鐘。
    fn with_huge_tail() -> (SqliteRepository, ContentStore) {
        let (repo, store) = setup(20);
        let yesterday = ctx_on(monday()).now - Duration::days(1);
        let tail: Vec<_> = (0..160)
            .map(|i| new_card(&format!("ka.t{i}"), "read", 0, yesterday))
            .collect();
        repo.insert_cards(&tail).unwrap();
        for i in 0..30 {
            seed_due_review(
                &repo,
                &format!("vo.x{i}"),
                "use",
                ts("2026-03-01T10:00:00Z"),
            );
        }
        (repo, store)
    }

    #[test]
    fn a_huge_tail_keeps_the_review_cap_and_the_estimate_within_the_plan() {
        let (repo, store) = with_huge_tail();

        let got = view(&repo, &store, monday());

        // 480 秒的一半：收尾 30 張（240 秒），餘 240 秒放得下 9 張 use 卡（225 秒）。
        assert_eq!(task(&got, "review").review.unwrap().new_cards, 30);
        assert_eq!(got.budget.review_cap, 9);
        // 225 + 240 = 465 秒 ≈ 8 分，加新內容 12 分。
        assert_eq!(got.estimated_minutes, 20.0);
    }

    #[test]
    fn the_tail_stops_at_the_daily_limit_and_resumes_the_next_day() {
        let (repo, store) = with_huge_tail();
        let now = ctx_on(monday()).now;
        view(&repo, &store, monday());
        for i in 0..30 {
            first_contact(&repo, &format!("ka.t{i}:read"), now);
        }

        let today = view(&repo, &store, monday());
        let tomorrow = view(&repo, &store, day(1));

        assert_eq!(task(&today, "review").review.unwrap().new_cards, 0);
        assert_eq!(task(&tomorrow, "review").review.unwrap().new_cards, 30);
    }
}

mod non_study_day {
    use super::*;

    fn mwf() -> (SqliteRepository, ContentStore) {
        let (repo, store) = (repo(), content());
        let plan = PlanInput {
            weekday_mask: MWF_MASK,
            ..input(20)
        };
        create_plan(&repo, &store, &ctx_on(monday()), &plan);
        (repo, store)
    }

    #[test]
    fn shows_next_study_date_and_no_tasks_when_nothing_due() {
        let (repo, store) = mwf();

        let got = view(&repo, &store, day(1));

        assert!(!got.is_study_day);
        assert_eq!(got.next_study_date, Some(day(2)));
        assert!(got.tasks.is_empty());
    }

    #[test]
    fn lists_review_when_due() {
        let (repo, store) = mwf();
        seed_due_review(&repo, "vo.watashi", "recog", ts("2026-03-03T01:00:00Z"));

        let got = view(&repo, &store, day(1));

        assert_eq!(keys(&got), vec!["review"]);
    }

    #[test]
    fn cannot_learn_more() {
        let (repo, store) = mwf();

        let err = learn_more(&repo, &store, &ctx_on(day(1)), AUDIO).unwrap_err();

        assert!(matches!(err, PlanError::InvalidInput { .. }));
    }
}

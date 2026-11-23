//! §7.4 今日任務流程，用真實 SQLite（受限、回鍋與再學一批）。

mod common;

use chrono::NaiveDate;
use common::flow::*;
use common::*;
use jp_content::ContentStore;
use jp_plan::budget::{NewContentMode, RecoveryReason};
use jp_plan::input::PlanInput;
use jp_plan::slice::Slice;
use jp_plan::tasks::DailyTask;
use jp_plan::today::{learn_more, today_view, TodayView};
use jp_plan::PlanError;
use jp_store::{ActivityDelta, ActivityRepo, ItemIntroRow, PlanRepo, SqliteRepository, SrsRepo};

mod recovery {
    use super::*;

    fn seed_unseen(repo: &SqliteRepository, count: usize) {
        let created = ts("2026-02-20T00:00:00Z");
        let cards: Vec<_> = (0..count)
            .map(|i| new_card(&format!("vo.x{i}"), "recog", 0, created))
            .collect();
        repo.insert_cards(&cards).unwrap();
        let intros: Vec<_> = (0..count)
            .map(|i| ItemIntroRow {
                item_id: format!("vo.x{i}"),
                lesson_id: "le.l01".to_owned(),
                logical_date: d("2026-02-20"),
                introduced_at: created,
            })
            .collect();
        repo.insert_item_intros(&intros).unwrap();
    }

    fn mark_active(repo: &SqliteRepository, on: NaiveDate) {
        repo.add_activity(
            on,
            ActivityDelta {
                reviews_done: 1,
                ..Default::default()
            },
        )
        .unwrap();
    }

    /// 回鍋要有卡可碰（§7.2）：放一張早就到期的卡。
    fn seed_one_due(repo: &SqliteRepository) {
        seed_due_review(repo, "vo.due", "recog", ts("2026-02-25T00:00:00Z"));
    }

    #[test]
    fn unseen_cards_restrict_two_days_then_minimal_from_day_three() {
        let (repo, store) = setup(20);
        seed_unseen(&repo, 6);

        let mut modes = Vec::new();
        for offset in 0..4 {
            let got = view(&repo, &store, day(offset));
            modes.push((got.budget.recovery_days, got.budget.new_content));
            mark_active(&repo, day(offset));
        }

        assert_eq!(
            modes,
            vec![
                (1, NewContentMode::None),
                (2, NewContentMode::None),
                (3, NewContentMode::Minimal),
                (4, NewContentMode::Minimal),
            ]
        );
    }

    #[test]
    fn minimal_day_lists_a_small_slice() {
        let (repo, store) = setup(20);
        seed_unseen(&repo, 6);
        for offset in 0..2 {
            view(&repo, &store, day(offset));
            mark_active(&repo, day(offset));
        }

        let got = view(&repo, &store, day(2));

        assert!(got
            .tasks
            .iter()
            .any(|t| matches!(t.task, DailyTask::NewContent { .. })));
    }

    #[test]
    fn recovery_resets_once_no_longer_restricted() {
        let (repo, store) = setup(20);
        let got = view(&repo, &store, monday());
        assert_eq!(got.budget.recovery_days, 0);
        seed_unseen(&repo, 6);
        mark_active(&repo, monday());

        assert_eq!(view(&repo, &store, day(1)).budget.recovery_days, 1);
    }

    #[test]
    fn return_after_three_missed_study_days_is_new_content_zero_with_half_cap() {
        let (repo, store) = setup(20);
        seed_one_due(&repo);
        mark_active(&repo, monday());

        // 3 個學習日未學（day 1–3），day 4 回鍋。
        let got = view(&repo, &store, day(4));

        assert_eq!(
            got.budget.recovery_reason,
            Some(RecoveryReason::ReturnAfterBreak)
        );
        assert_eq!(got.budget.recovery_days, 1);
        assert_eq!(got.budget.review_cap, 30);
        assert!(!got
            .tasks
            .iter()
            .any(|t| matches!(t.task, DailyTask::NewContent { .. })));
    }

    /// 只跟讀過、沒有任何卡的人缺席後打開：今天沒事可做，不能天天判回鍋（review_rc RC1）。
    #[test]
    fn nothing_to_review_after_a_break_still_offers_new_content() {
        let (repo, store) = setup(20);
        repo.add_activity(
            monday(),
            ActivityDelta {
                shadow_kept: 1,
                ..Default::default()
            },
        )
        .unwrap();

        let got = view(&repo, &store, day(4));

        assert_eq!(got.budget.recovery_reason, None);
        assert_eq!(got.budget.new_content, NewContentMode::Full);
        assert!(got
            .tasks
            .iter()
            .any(|t| matches!(t.task, DailyTask::NewContent { .. })));
    }

    /// 週六回來（休息日）與週一回來，下個學習日的處置要一樣：都從第 1 天起算（review_rc RC4）。
    #[test]
    fn return_on_a_rest_day_does_not_skip_the_first_two_days() {
        let (repo, store) = (repo(), content());
        let plan = PlanInput {
            weekday_mask: MWF_MASK,
            ..input(20)
        };
        create_plan(&repo, &store, &ctx_on(monday()), &plan);
        seed_unseen(&repo, 6);
        // 週一、三、五受限，積到第 3 天。
        for offset in [0, 2, 4] {
            view(&repo, &store, day(offset));
            mark_active(&repo, day(offset));
        }
        seed_one_due(&repo);

        // 下週一、三、五缺席，再下週六回來並作答。
        let saturday = view(&repo, &store, day(19));
        mark_active(&repo, day(19));
        let monday_after = view(&repo, &store, day(21));

        assert!(!saturday.is_study_day);
        assert_eq!(
            saturday.budget.recovery_reason,
            Some(RecoveryReason::ReturnAfterBreak)
        );
        assert_eq!(saturday.budget.recovery_days, 0);
        assert_eq!(monday_after.budget.recovery_days, 1);
        assert_eq!(monday_after.budget.new_content, NewContentMode::None);
    }

    #[test]
    fn two_missed_study_days_is_not_a_break() {
        let (repo, store) = setup(20);
        mark_active(&repo, monday());

        assert_eq!(view(&repo, &store, day(3)).budget.recovery_reason, None);
    }

    #[test]
    fn rest_days_do_not_count_as_missed() {
        let (repo, store) = (repo(), content());
        let plan = PlanInput {
            weekday_mask: MWF_MASK,
            ..input(20)
        };
        create_plan(&repo, &store, &ctx_on(monday()), &plan);
        mark_active(&repo, monday());

        // 一三五：隔週一之間只排了週三、週五 2 天。
        assert_eq!(view(&repo, &store, day(7)).budget.recovery_reason, None);
    }

    #[test]
    fn long_absence_does_not_pile_up_tasks() {
        let (repo, store) = setup(20);
        let first = view(&repo, &store, monday());
        seed_one_due(&repo);
        mark_active(&repo, monday());
        let after_month_review = view(&repo, &store, day(30));
        mark_active(&repo, day(30));

        let back = view(&repo, &store, day(31));

        assert_eq!(
            after_month_review.budget.recovery_reason,
            Some(RecoveryReason::ReturnAfterBreak)
        );
        assert!(!after_month_review
            .tasks
            .iter()
            .any(|t| matches!(t.task, DailyTask::NewContent { .. })));
        // 隔天恢復，額度與第一天相同，沒有債務。
        assert_eq!(back.budget.new_content, NewContentMode::Full);
        assert_eq!(back.budget.review_cap, first.budget.review_cap);
        assert_eq!(back.estimated_minutes, first.estimated_minutes);
    }

    /// 一三五的計畫，週一起未看完的新卡受限；週二是休息日。
    fn mwf_with_unseen(open_on_tuesday: bool) -> TodayView {
        let (repo, store) = (repo(), content());
        let plan = PlanInput {
            weekday_mask: MWF_MASK,
            ..input(20)
        };
        create_plan(&repo, &store, &ctx_on(monday()), &plan);
        seed_unseen(&repo, 6);
        view(&repo, &store, monday());
        mark_active(&repo, monday());
        if open_on_tuesday {
            let rest = view(&repo, &store, day(1));
            assert!(!rest.is_study_day);
            assert_eq!(rest.budget.recovery_days, 1, "休息日維持前一筆的值");
        }
        view(&repo, &store, day(2))
    }

    /// RULINGS O12：休息日不遞增 `recovery_days`，「第 3 天起給最小切片」不取決於休息日有沒有打開 App。
    #[test]
    fn opening_the_app_on_a_rest_day_does_not_advance_recovery() {
        let opened = mwf_with_unseen(true);
        let skipped = mwf_with_unseen(false);

        assert_eq!(opened.budget.recovery_days, 2);
        assert_eq!(opened.budget.new_content, NewContentMode::None);
        assert_eq!(
            (opened.budget.recovery_days, opened.budget.new_content),
            (skipped.budget.recovery_days, skipped.budget.new_content)
        );
    }

    #[test]
    fn same_day_activity_does_not_flip_a_rebuilt_snapshot() {
        let (repo, store) = setup(20);
        seed_one_due(&repo);
        mark_active(&repo, monday());
        let got = view(&repo, &store, day(4));
        assert_eq!(
            got.budget.recovery_reason,
            Some(RecoveryReason::ReturnAfterBreak)
        );
        mark_active(&repo, day(4));
        repo.delete_snapshot(day(4)).unwrap();

        // 同一天改計畫會刪快照重算；今天已活躍不應把回鍋判定翻掉。
        let again = view(&repo, &store, day(4));

        assert_eq!(
            again.budget.recovery_reason,
            Some(RecoveryReason::ReturnAfterBreak)
        );
    }
}

mod learn_more_flow {
    use super::*;

    #[test]
    fn locked_until_todays_tasks_are_done() {
        let (repo, store) = setup(20);

        let got = view(&repo, &store, monday());
        assert!(!got.can_learn_more);

        let err = learn_more(&repo, &store, &ctx_on(monday()), AUDIO).unwrap_err();
        assert!(matches!(err, PlanError::InvalidInput { .. }));
    }

    #[test]
    fn appends_the_next_slice_and_keeps_tomorrow_unchanged() {
        let (repo, store) = setup(20);
        let first = new_key(&view(&repo, &store, monday()));
        let after = done(&repo, &store, monday(), &first);
        assert!(after.can_learn_more);

        let more = learn_more(&repo, &store, &ctx_on(monday()), AUDIO).unwrap();

        assert_eq!(more.tasks.len(), after.tasks.len() + 1);
        let extra = &more.tasks.last().unwrap().task;
        assert_eq!(extra.key(), "new:ka.hira.e");
        assert!(!more.can_learn_more);

        done(&repo, &store, monday(), extra.key());
        // 隔天快照照進度重新計算，額度不因多學而變動。
        let tomorrow = view(&repo, &store, day(1));
        assert_eq!(tomorrow.budget.kana_chars_limit, 5);
    }

    #[test]
    fn restricted_day_cannot_learn_more() {
        let (repo, store) = setup(20);
        let cards: Vec<_> = (0..6)
            .map(|i| new_card(&format!("vo.x{i}"), "recog", 0, ts("2026-02-20T00:00:00Z")))
            .collect();
        repo.insert_cards(&cards).unwrap();

        let got = view(&repo, &store, monday());

        assert!(!got.can_learn_more);
    }
}

/// 依序完成當天全部任務；`NewContent` 的單字、文法當場第一次接觸。
fn play_full_day(repo: &SqliteRepository, store: &ContentStore, on: NaiveDate) -> TodayView {
    let today = view(repo, store, on);
    for task in &today.tasks {
        let key = task.task.key().to_owned();
        if let DailyTask::NewContent {
            slice: Slice::Vocab { words, grammar, .. },
            ..
        } = &task.task
        {
            done(repo, store, on, &key);
            let cards = words
                .iter()
                .map(|w| format!("{w}:recog"))
                .chain(grammar.iter().map(|g| format!("{g}:use")));
            for card in cards {
                first_contact(repo, &card, ctx_on(on).now);
            }
        } else {
            done(repo, store, on, &key);
        }
    }
    today
}

#[test]
fn thirty_days_of_normal_use_is_never_restricted() {
    let (repo, store) = setup(20);

    for offset in 0..30 {
        let today = play_full_day(&repo, &store, day(offset));

        assert_eq!(
            today.budget.new_content,
            NewContentMode::Full,
            "day {offset}"
        );
        assert_eq!(today.budget.recovery_reason, None, "day {offset}");
    }
    assert!(repo
        .lesson_progress()
        .unwrap()
        .get("le.k19")
        .and_then(|p| p.completed_date)
        .is_some());
}

#[test]
fn k01_to_k19_finish_on_the_forecast_date() {
    let (repo, store) = setup(20);

    for offset in 0..21 {
        play_full_day(&repo, &store, day(offset));
    }

    assert_eq!(
        repo.lesson_progress().unwrap()["le.k19"].completed_date,
        Some(day(20))
    );
}

#[test]
fn a_missed_day_delays_everything_by_one_day_and_adds_no_debt() {
    let (repo, store) = setup(20);
    play_full_day(&repo, &store, monday());

    // 跳過 day 1，day 2 的切片與 day 1 應有的切片相同，任務量不累加。
    let late = view(&repo, &store, day(2));

    let expected_first = "ka.hira.e";
    assert_eq!(new_key(&late), format!("new:{expected_first}"));
    assert_eq!(late.budget.kana_chars_limit, 5);
}

#[test]
fn streak_is_reported_in_view() {
    let (repo, store) = setup(20);
    repo.add_activity(
        monday(),
        ActivityDelta {
            reviews_done: 1,
            ..Default::default()
        },
    )
    .unwrap();
    repo.add_activity(
        day(1),
        ActivityDelta {
            reviews_done: 1,
            ..Default::default()
        },
    )
    .unwrap();

    assert_eq!(view(&repo, &store, day(1)).streak, 2);
}

#[test]
fn audio_false_excludes_listen_cards_from_counts() {
    let (repo, store) = setup(20);
    seed_due_review(&repo, "vo.watashi", "listen", ts("2026-03-02T10:00:00Z"));

    let silent = today_view(&repo, &store, &ctx_on(monday()), false).unwrap();

    assert_eq!(task(&silent, "review").review.unwrap().due, 0);
}

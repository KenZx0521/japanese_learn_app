//! §7.2 積壓時的今日任務（RULINGS O11）：`ReviewBacklog` 只排複習、`review_cap` 先扣收尾新卡。

mod common;

use chrono::NaiveDate;
use common::*;
use jp_content::ContentStore;
use jp_plan::budget::{stage_split, NewContentMode, RecoveryReason, Split};
use jp_plan::compose::compose_day;
use jp_plan::tasks::{DailyTask, DaySnapshot};

fn today() -> NaiveDate {
    d(MONDAY)
}

fn compose(fixture: &FactsFixture, store: &ContentStore) -> DaySnapshot {
    compose_day(&fixture.facts(), store)
}

fn has(snapshot: &DaySnapshot, wanted: fn(&DailyTask) -> bool) -> bool {
    snapshot.tasks.iter().any(wanted)
}

fn listen_minutes(snapshot: &DaySnapshot) -> Option<f64> {
    snapshot.tasks.iter().find_map(|task| match task {
        DailyTask::Listen { minutes, .. } => Some(*minutes),
        _ => None,
    })
}

/// L21 之後：游標在 L31。
fn after_l21(store: &ContentStore) -> FactsFixture {
    FactsFixture::new(store, today(), 20, state_at("le.l31", store))
}

mod pause_line {
    use super::*;

    #[test]
    fn minimal_backlog_day_lists_listen_with_its_full_minutes() {
        let store = content();
        let mut fixture = after_l21(&store);
        fixture.due_facets = due_facets(150, "recog"); // cap 67，2 倍 134、5 倍 335
        fixture.previous_recovery_days = 2;

        let got = compose(&fixture, &store);

        assert_eq!(
            got.budget.recovery_reason,
            Some(RecoveryReason::ReviewBacklog)
        );
        assert_eq!(got.budget.new_content, NewContentMode::Minimal);
        assert_eq!(listen_minutes(&got), Some(got.budget.split.listen));
    }

    #[test]
    fn backlog_over_the_pause_line_lists_no_new_content_on_day_five() {
        let store = content();
        let mut fixture = FactsFixture::new(&store, today(), 20, state_at("le.l01", &store));
        fixture.due_facets = due_facets(301, "recog"); // S1 cap 60，5 倍 300
        fixture.previous_recovery_days = 4;

        let got = compose(&fixture, &store);

        assert_eq!(got.budget.new_content, NewContentMode::None);
        assert_eq!(got.budget.recovery_days, 5);
        assert!(!has(&got, |t| matches!(t, DailyTask::NewContent { .. })));
    }
}

mod tail_reserve {
    use super::*;

    #[test]
    fn review_cap_reserves_time_for_the_new_card_tail() {
        let store = content();
        let mut fixture = FactsFixture::new(&store, today(), 20, state_at("le.k02", &store));
        fixture.tail_new_cards = 5;

        // S0 的 review 8 分＝480 秒，扣 5 × 8 = 40 秒，餘 440 秒 / 8 = 55 張。
        assert_eq!(compose(&fixture, &store).budget.review_cap, 55);
    }

    /// 收尾新卡只扣 T1 的時間，不讓積壓判定變嚴（RULINGS O11）：容量 60 張，2 倍 120。
    #[test]
    fn backlog_line_uses_the_capacity_before_the_reserve() {
        let store = content();
        let reason = |due| {
            let mut fixture = FactsFixture::new(&store, today(), 20, state_at("le.k02", &store));
            fixture.tail_new_cards = 5;
            fixture.due_facets = due_facets(due, "recog");
            let got = compose(&fixture, &store);
            (got.budget.recovery_reason, got.budget.review_cap)
        };

        assert_eq!(reason(120), (None, 55));
        // 積壓第 1 天只排複習：20 分＝1,200 秒，扣 40 秒後 145 張。
        assert_eq!(reason(121), (Some(RecoveryReason::ReviewBacklog), 145));
    }
}

/// 積壓判定用的 `capacity` 也寫進預算，模擬與報表才能對暫停線斷言（review_rust R2-M2）。
mod capacity {
    use super::*;

    fn budget_at(due: usize) -> jp_plan::budget::DayBudget {
        let store = content();
        let mut fixture = FactsFixture::new(&store, today(), 20, state_at("le.k02", &store));
        fixture.tail_new_cards = 5;
        fixture.due_facets = due_facets(due, "recog");
        compose(&fixture, &store).budget
    }

    #[test]
    fn budget_keeps_the_capacity_before_the_tail_reserve() {
        let got = budget_at(120);

        assert_eq!((got.capacity, got.review_cap), (60, 55));
    }

    #[test]
    fn review_only_day_keeps_the_stage_capacity_and_raises_the_cap() {
        let got = budget_at(121);

        assert_eq!(got.split.review, 20.0);
        assert_eq!((got.capacity, got.review_cap), (60, 145));
    }
}

/// `ReviewBacklog` 且不給新內容的日子，當天分鐘全部給複習（RULINGS O11）。
mod review_only_day {
    use super::*;

    fn backlog_after_l21(store: &ContentStore, due: usize) -> FactsFixture {
        let mut fixture = after_l21(store);
        fixture.due_facets = due_facets(due, "recog");
        fixture
    }

    fn stage_split_at_l31(fixture: &FactsFixture, store: &ContentStore) -> Split {
        let stage = store.lesson("le.l31").map(|lesson| lesson.stage.as_str());
        stage_split(&fixture.preset, stage)
    }

    fn is_practice(task: &DailyTask) -> bool {
        matches!(
            task,
            DailyTask::NewContent { .. }
                | DailyTask::Integration { .. }
                | DailyTask::Drill { .. }
                | DailyTask::Listen { .. }
        )
    }

    #[test]
    fn every_minute_goes_to_review() {
        let store = content();
        let fixture = backlog_after_l21(&store, 200);

        let got = compose(&fixture, &store);

        assert_eq!(got.budget.new_content, NewContentMode::None);
        let all = Split {
            new: 0.0,
            review: 20.0,
            drill: 0.0,
            listen: 0.0,
        };
        assert_eq!(got.budget.split, all);
        // 20 分＝1,200 秒，150 張自動卡。
        assert_eq!(got.budget.review_cap, 150);
        assert!(!has(&got, is_practice));
    }

    #[test]
    fn review_cap_still_reserves_the_new_card_tail() {
        let store = content();
        let mut fixture = backlog_after_l21(&store, 200);
        fixture.tail_new_cards = 10;

        // (1,200 − 80) / 8 = 140。
        assert_eq!(compose(&fixture, &store).budget.review_cap, 140);
    }

    #[test]
    fn backlog_is_judged_on_the_stage_split() {
        let store = content();
        // 階段 review 9 分的容量 67，2 倍 134；全給複習時 150 張不算積壓，但判定不看它。
        let got = compose(&backlog_after_l21(&store, 135), &store);

        assert_eq!(
            got.budget.recovery_reason,
            Some(RecoveryReason::ReviewBacklog)
        );
        assert_eq!(got.budget.review_cap, 150);
    }

    #[test]
    fn minimal_backlog_day_keeps_the_stage_split() {
        let store = content();
        let mut fixture = backlog_after_l21(&store, 150);
        fixture.previous_recovery_days = 2;

        let got = compose(&fixture, &store);

        assert_eq!(got.budget.new_content, NewContentMode::Minimal);
        assert_eq!(got.budget.split, stage_split_at_l31(&fixture, &store));
        assert!(has(&got, |t| matches!(t, DailyTask::Drill { .. })));
    }

    #[test]
    fn other_restrictions_keep_the_stage_split() {
        let store = content();
        let mut fixture = after_l21(&store);
        fixture.unseen_new = 99;

        let got = compose(&fixture, &store);

        assert_eq!(got.budget.new_content, NewContentMode::None);
        assert_eq!(got.budget.split, stage_split_at_l31(&fixture, &store));
    }
}

/// 回鍋日與休息日的積壓（RULINGS O12）：只排複習看到期數，不看原因標籤；
/// 休息日不遞增 `recovery_days`，複習上限用階段配比。
mod return_and_rest_days {
    use super::*;
    use jp_plan::calendar::{PlanHistory, ALL_DAYS_MASK};

    const TUESDAY: &str = "2026-03-03";

    fn back_after_break(store: &ContentStore, due: usize) -> FactsFixture {
        let mut fixture = after_l21(store);
        fixture.history = PlanHistory::from_rows(std::slice::from_ref(&plan_row(
            d("2026-01-01"),
            20,
            ALL_DAYS_MASK,
        )));
        fixture.last_active = Some(today() - chrono::Duration::days(4));
        fixture.due_facets = due_facets(due, "recog");
        fixture
    }

    /// 一三五的計畫，今天週二（休息日）。
    fn rest_day(store: &ContentStore, due: usize) -> FactsFixture {
        let mut fixture = after_l21(store);
        fixture.today = d(TUESDAY);
        fixture.plan = plan_row(today(), 20, MWF_MASK);
        fixture.history = PlanHistory::from_rows(std::slice::from_ref(&fixture.plan));
        fixture.due_facets = due_facets(due, "recog");
        fixture
    }

    fn stage_split_at_l31(fixture: &FactsFixture, store: &ContentStore) -> Split {
        let stage = store.lesson("le.l31").map(|lesson| lesson.stage.as_str());
        stage_split(&fixture.preset, stage)
    }

    fn is_practice(task: &DailyTask) -> bool {
        matches!(
            task,
            DailyTask::NewContent { .. }
                | DailyTask::Integration { .. }
                | DailyTask::Drill { .. }
                | DailyTask::Listen { .. }
        )
    }

    /// 20 分、到期 300（階段容量 67，4.5 倍）：修正前照發演練、聽力，cap 33。
    #[test]
    fn return_day_with_backlog_only_reviews_with_half_the_merged_cap() {
        let store = content();

        let got = compose(&back_after_break(&store, 300), &store);

        assert_eq!(
            got.budget.recovery_reason,
            Some(RecoveryReason::ReturnAfterBreak)
        );
        assert_eq!(got.budget.split.review, 20.0);
        assert_eq!(got.budget.split.new + got.budget.split.drill, 0.0);
        assert_eq!(got.budget.split.listen, 0.0);
        // 20 分＝1,200 秒，150 張自動卡，回鍋減半 75。
        assert_eq!(got.budget.review_cap, 75);
        assert_eq!(got.budget.capacity, 67);
        assert!(!has(&got, is_practice));
    }

    #[test]
    fn return_day_half_cap_still_reserves_the_new_card_tail() {
        let store = content();
        let mut fixture = back_after_break(&store, 300);
        fixture.tail_new_cards = 10;

        // (1,200 − 80) / 8 = 140，減半 70。
        assert_eq!(compose(&fixture, &store).budget.review_cap, 70);
    }

    #[test]
    fn return_day_under_the_backlog_line_keeps_the_stage_split() {
        let store = content();
        let fixture = back_after_break(&store, 134);

        let got = compose(&fixture, &store);

        assert_eq!(
            got.budget.recovery_reason,
            Some(RecoveryReason::ReturnAfterBreak)
        );
        assert_eq!(got.budget.split, stage_split_at_l31(&fixture, &store));
        assert_eq!(got.budget.review_cap, 33);
        assert!(has(&got, is_practice));
    }

    #[test]
    fn rest_day_backlog_keeps_the_stage_split_and_cap() {
        let store = content();
        let fixture = rest_day(&store, 300);

        let got = compose(&fixture, &store);

        assert_eq!(
            got.budget.recovery_reason,
            Some(RecoveryReason::ReviewBacklog)
        );
        assert_eq!(got.budget.split, stage_split_at_l31(&fixture, &store));
        assert_eq!(got.budget.review_cap, 67);
        assert_eq!(got.tasks.len(), 1, "休息日只列 Review：{:?}", got.tasks);
    }

    #[test]
    fn rest_day_does_not_advance_the_recovery_days() {
        let store = content();
        let mut fixture = rest_day(&store, 300);
        fixture.previous_recovery_days = 2;

        assert_eq!(compose(&fixture, &store).budget.recovery_days, 2);
    }
}

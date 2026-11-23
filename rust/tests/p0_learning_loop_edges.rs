//! p0 學習迴路模擬的受限路徑（review_rust R2-M3）：主模擬（`p0_learning_loop.rs`）的學習者一直有聲、
//! 每天都是學習日、從不連缺三個學習日，所以沒走過下面三條路：
//!
//! - 長期無聲後打開聲音：累積的 `:listen` 新卡一次可取（R2-H1）。
//! - 週一到週五的計畫，週末也打開 App：非學習日只排複習（§7.4），複習上限用階段配比、
//!   `recovery_days` 不遞增（RULINGS O12）。
//! - 每 6 週消失 8 天：`ReturnAfterBreak`（§7.2），回鍋日積壓時只排複習（RULINGS O12）。
//! - 週一到週五、每 40 天消失 8 天：回鍋日輪流落在一週的每一天，含休息日（RULINGS O12）。
//!
//! 只斷言這些路徑上有意義的條文。
//! 四位學習者平行模擬，release 約一分鐘：
//! `cargo test --release --test p0_learning_loop_edges -- --ignored --nocapture`。

mod common;

use std::sync::OnceLock;

use common::loop_invariants::Rule;
use common::loop_run::{assert_none, print_report, run, Breaks, RunReport, Scenario, EVERY_DAY};
use jp_core::api::dto_plan::RecoveryReason;

/// 無聲期間累積的 `:listen` 新卡，打開聲音當天至少要有這麼多分鐘的收尾（23 張以上），
/// 檢查才不是空轉。正常有聲的學習者收尾最多約 20 張。
const SILENT_TAIL_MINUTES: f64 = 3.0;
const SILENT_DAYS: u32 = 300;
/// rust-core §7.2 `BACKLOG_FACTOR`：到期數 > 2 × `capacity` 是積壓。
const BACKLOG_FACTOR: u32 = 2;
const WEEKDAYS: [u32; 5] = [1, 2, 3, 4, 5];

const SCENARIOS: [Scenario; 4] = [
    Scenario {
        name: "20 分・前 300 天無聲・之後有聲",
        audio_from_day: SILENT_DAYS + 1,
        ..Scenario::diligent("", 20, SILENT_DAYS + 30)
    },
    Scenario {
        name: "20 分・週一到週五・週末也打開・答錯 30%",
        study_weekdays: &WEEKDAYS,
        wrong_per_ten: 3,
        ..Scenario::diligent("", 20, 300)
    },
    Scenario {
        name: "20 分・每 6 週消失 8 天・答錯 20%",
        study_weekdays: &EVERY_DAY,
        breaks: Some(Breaks {
            every_days: 42,
            length: 8,
        }),
        wrong_per_ten: 2,
        ..Scenario::diligent("", 20, 400)
    },
    Scenario {
        name: "20 分・週一到週五・每 40 天消失 8 天・答錯 20%",
        study_weekdays: &WEEKDAYS,
        breaks: Some(Breaks {
            every_days: 40,
            length: 8,
        }),
        wrong_per_ten: 2,
        ..Scenario::diligent("", 20, 300)
    },
];
const SILENT: usize = 0;
const WEEKDAY_PLAN: usize = 1;
const BREAKS: usize = 2;
const WEEKDAY_BREAKS: usize = 3;

/// 每條路徑都要守的條文。
const RULES: [Rule; 8] = [
    Rule::MinutesWithNewCards,
    Rule::ReviewCapFloor,
    Rule::RestDayReviewOnly,
    Rule::BacklogPauseLine,
    Rule::ReviewOnlyDay,
    Rule::MainSliceAtCursor,
    Rule::NewItemOnce,
    Rule::NoCoreError,
];

fn report(index: usize) -> &'static RunReport {
    static REPORTS: [OnceLock<RunReport>; SCENARIOS.len()] =
        [const { OnceLock::new() }; SCENARIOS.len()];
    REPORTS[index].get_or_init(|| run(SCENARIOS[index]))
}

fn all_reports() -> Vec<&'static RunReport> {
    std::thread::scope(|scope| {
        for index in 0..SCENARIOS.len() {
            scope.spawn(move || report(index));
        }
    });
    (0..SCENARIOS.len()).map(report).collect()
}

#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop_edges -- --ignored --nocapture"]
fn report_edge_learners() {
    for r in all_reports() {
        print_report(r);
    }
}

#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop_edges -- --ignored"]
fn edge_learners_keep_the_daily_invariants() {
    let found: Vec<String> = all_reports()
        .into_iter()
        .flat_map(|r| r.breaches_of(&RULES))
        .collect();
    assert_none(&found);
}

/// R2-H1：打開聲音後的收尾新卡分散到幾天，T1 不超過方案、`review_cap` 不塌（由 `RULES` 判定）；
/// 這裡確認那幾天真的有大量收尾新卡。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop_edges -- --ignored"]
fn turning_audio_on_brings_a_large_tail_that_is_spread_out() {
    let r = report(SILENT);
    let switch = r.days.get(SILENT_DAYS as usize).map(|d| d.date);
    let tails: Vec<f64> = r
        .days
        .iter()
        .filter(|d| Some(d.date) >= switch)
        .map(|d| d.new_card_minutes)
        .collect();
    let largest = tails.iter().copied().fold(0.0, f64::max);
    assert!(
        largest >= SILENT_TAIL_MINUTES,
        "打開聲音後收尾新卡最多 {largest:.1} 分，檢查空轉"
    );
    let busy_days = tails.iter().filter(|m| **m >= SILENT_TAIL_MINUTES).count();
    assert!(busy_days > 1, "收尾新卡只用了 {busy_days} 天，應分散到幾天");
}

#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop_edges -- --ignored"]
fn weekday_plan_visits_rest_days_with_backlog() {
    let r = report(WEEKDAY_PLAN);
    let rest = r.days.iter().filter(|d| !d.is_study_day).count();
    let rest_backlog = r
        .days
        .iter()
        .filter(|d| !d.is_study_day && d.recovery == Some(RecoveryReason::ReviewBacklog))
        .count();
    assert!(rest > 0, "沒有走到休息日");
    assert!(rest_backlog > 0, "休息日沒有遇到積壓，檢查空轉");
}

#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop_edges -- --ignored"]
fn coming_back_after_a_break_triggers_return_after_break() {
    let r = report(BREAKS);
    let returns = r
        .days
        .iter()
        .filter(|d| d.recovery == Some(RecoveryReason::ReturnAfterBreak))
        .count();
    assert!(
        returns > 0,
        "{}：沒有出現 ReturnAfterBreak",
        r.scenario.name
    );
}

/// 回鍋落在休息日時，下個學習日要從第 1 天起算（由 `Rule::BacklogPauseLine` 判定）；
/// 這裡確認真的有這種回鍋日，檢查不是空轉。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop_edges -- --ignored"]
fn coming_back_on_a_rest_day_is_reached() {
    let r = report(WEEKDAY_BREAKS);
    let rest_returns = r
        .days
        .iter()
        .filter(|d| !d.is_study_day && d.recovery == Some(RecoveryReason::ReturnAfterBreak))
        .count();
    assert!(
        rest_returns > 0,
        "{}：回鍋日沒有落在休息日",
        r.scenario.name
    );
}

/// RULINGS O12：回鍋日到期數 > 2 × `capacity` 時只排複習（由 `Rule::ReviewOnlyDay` 判定）；
/// 這裡確認真的有這種回鍋日，檢查不是空轉。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop_edges -- --ignored"]
fn return_days_with_backlog_only_review() {
    let r = report(BREAKS);
    let backlog_returns: Vec<_> = r
        .days
        .iter()
        .filter(|d| d.recovery == Some(RecoveryReason::ReturnAfterBreak))
        .filter(|d| d.due_start > BACKLOG_FACTOR * d.capacity)
        .collect();
    assert!(
        !backlog_returns.is_empty(),
        "{}：沒有積壓的回鍋日，檢查空轉",
        r.scenario.name
    );
    assert!(backlog_returns.iter().all(|d| d.review_only));
}

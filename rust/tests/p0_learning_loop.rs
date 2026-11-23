//! p0 學習迴路模擬（rust-core.md §7）：真實 `p0` 內容，零基礎的學習者每天打開 App、做完今日任務，
//! 直到主線 L30 完成再多走 60 天。逐日檢查 §7 的不變量（條文見 `common::loop_invariants::Rule`）。
//!
//! 完整模擬很長，標 `#[ignore]`，以 release 執行（五位學習者平行，約兩到三分鐘；答錯 30% 的學習者
//! 最慢）：`cargo test --release --test p0_learning_loop -- --ignored --nocapture`。
//! 無聲、休息日與回鍋這些受限路徑在 `p0_learning_loop_edges.rs`。模擬的執行與報表在
//! `common::loop_run`。

mod common;

use std::collections::BTreeSet;
use std::sync::OnceLock;

use chrono::Weekday;
use common::loop_facts::ContentFacts;
use common::loop_invariants::Rule;
use common::loop_report::{backlog_bound_breaches, day_no, forecast_error, longest_stall};
use common::loop_run::{
    assert_none, describe, print_report, run, simulate, RunReport, Scenario, C1_FACTOR, EVERY_DAY,
};
use common::real::p0_content;
use jp_core::api::dto_plan::RecoveryReason;

const MAX_DAYS: u32 = 1_000;
/// 答錯 30% 的學習者幾乎天天積壓（實測第 1,110 天學完 L30），另給較長的上限。
const STRUGGLER_MAX_DAYS: u32 = 1_800;
/// C4：主線完成前，連續沒有主線切片的日曆天數上限。
const MAX_STALL_DAYS: i64 = 14;
/// 建立計畫時預估的主線完成日，與實際天數的相對誤差上限。
const FORECAST_TOLERANCE: f64 = 0.05;
/// §11.3-1：到期量 > 2 × `review_cap` 就是積壓。做完當天全部任務後留到隔天的量不該達到這條線。
const BACKLOG_FACTOR: u32 = 2;
/// 不標 `ignore` 的短模擬：45 分方案前六週（假名、L01–L05），debug 約數秒。
const SHORT_RUN_DAYS: u32 = 42;
/// RULINGS O7：p0 只有到 L30 的里程碑，不得出現 N4。
const P0_MILESTONES: [&str; 6] = [
    "ms.hira",
    "ms.kata",
    "ms.survive",
    "ms.a1_half",
    "ms.casual",
    "ms.n5",
];

const SCENARIOS: [Scenario; 5] = [
    Scenario::diligent("10 分・每天全做", 10, MAX_DAYS),
    Scenario::diligent("20 分・每天全做", 20, MAX_DAYS),
    Scenario::diligent("30 分・每天全做", 30, MAX_DAYS),
    Scenario::diligent("45 分・每天全做", 45, MAX_DAYS),
    Scenario {
        name: "20 分・每週缺六日・答錯 30%",
        minutes: 20,
        study_weekdays: &EVERY_DAY,
        skipped: &[Weekday::Sat, Weekday::Sun],
        breaks: None,
        audio_from_day: 0,
        wrong_per_ten: 3,
        max_days: STRUGGLER_MAX_DAYS,
    },
];
const DILIGENT: [usize; 4] = [0, 1, 2, 3];
const STRUGGLING: usize = 4;
const FORTY_FIVE: usize = 3;

fn report(index: usize) -> &'static RunReport {
    static REPORTS: [OnceLock<RunReport>; SCENARIOS.len()] =
        [const { OnceLock::new() }; SCENARIOS.len()];
    REPORTS[index].get_or_init(|| run(SCENARIOS[index]))
}

/// 五位學習者平行模擬，結果在同一個測試執行檔內共用。
fn all_reports() -> Vec<&'static RunReport> {
    std::thread::scope(|scope| {
        for index in 0..SCENARIOS.len() {
            scope.spawn(move || report(index));
        }
    });
    (0..SCENARIOS.len()).map(report).collect()
}

/// 五位學習者都不違反 `rules`。
fn assert_rules_hold(rules: &[Rule]) {
    let found: Vec<String> = all_reports()
        .into_iter()
        .flat_map(|r| r.breaches_of(rules))
        .collect();
    assert_none(&found);
}

#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored --nocapture"]
fn report_every_learner() {
    for r in all_reports() {
        print_report(r);
    }
}

/// 不標 `ignore`：45 分方案前六週，涵蓋假名、片假名與 L01 起的單字切片。
#[test]
fn first_six_weeks_of_the_45_minute_plan_keep_the_daily_invariants() {
    let facts = ContentFacts::new(&p0_content());

    let (trace, checker, _) = simulate(SCENARIOS[FORTY_FIVE], &facts, SHORT_RUN_DAYS);

    assert_eq!(trace.days.len(), SHORT_RUN_DAYS as usize);
    assert!(
        checker.completed_on("le.l03").is_some(),
        "六週內應走過 L03，游標 {:?}",
        trace.last_cursor
    );
    assert!(checker.sentences_checked > 0, "應檢查過題目露出的句子");
    assert_none(&describe("45 分前六週", checker.violations.iter()));
}

#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn learners_finish_the_main_line() {
    for r in all_reports() {
        let (name, limit) = (r.scenario.name, r.scenario.max_days);
        assert!(r.main_end.is_some(), "{name}：{limit} 天內沒學完 L30");
        assert!(
            day_no(r.last_date) < i64::from(limit),
            "{name}：撞到模擬上限"
        );
    }
}

/// §7.2–§7.4：扣掉收尾新卡，只容許四捨五入。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn daily_minutes_stay_within_budget_apart_from_the_new_card_tail() {
    assert_rules_hold(&[Rule::MinutesBudget]);
}

/// §7.4：`NewContent`、`Listen` 任務的分鐘等於預算的 new、listen 額度。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn new_content_and_listen_minutes_match_the_budget() {
    assert_rules_hold(&[Rule::TaskMinutes]);
}

/// C3、curriculum §11.3-2：T1 顯示的預估分鐘（含收尾新卡）不超過方案（RULINGS O11），
/// 收尾新卡也不會把 `review_cap` 擠到 1。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn t1_estimate_stays_within_the_plan_minutes() {
    assert_rules_hold(&[Rule::MinutesWithNewCards, Rule::ReviewCapFloor]);
}

#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn new_content_comes_only_from_unlocked_lessons() {
    assert_rules_hold(&[
        Rule::MainSliceAtCursor,
        Rule::NewItemLesson,
        Rule::NewItemOnce,
        Rule::MainCardLesson,
        Rule::SentenceUsable,
    ]);
}

/// RULINGS O11：不給新內容的積壓日只排複習；到期數 > 5 × `capacity` 的積壓日不給主線切片，
/// 積壓第 3 天起未過暫停線時給最小切片（釘住 `BACKLOG_PAUSE_FACTOR`）。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn review_backlog_days_only_review_and_respect_the_pause_line() {
    assert_rules_hold(&[Rule::ReviewOnlyDay, Rule::BacklogPauseLine]);
    let backlog_days = all_reports()
        .iter()
        .flat_map(|r| &r.days)
        .filter(|d| d.recovery == Some(RecoveryReason::ReviewBacklog))
        .count();
    assert!(backlog_days > 0, "檢查不是空轉：應有 ReviewBacklog 日");
}

/// §7.4 檢定與 RULINGS O7：p0 只有到 L30 的六個里程碑，每個恰好列出一次。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn checkpoints_cover_exactly_the_p0_milestones() {
    assert_rules_hold(&[Rule::Checkpoint]);
    let expected: BTreeSet<&str> = P0_MILESTONES.into_iter().collect();
    for r in all_reports() {
        let offered: BTreeSet<&str> = r.checkpoints.iter().map(|(_, id)| id.as_str()).collect();
        let shown: BTreeSet<&str> = r.milestones_shown.iter().map(String::as_str).collect();
        assert_eq!(offered, expected, "{}：列出的檢定", r.scenario.name);
        assert_eq!(shown, expected, "{}：plan_view 的里程碑", r.scenario.name);
        assert_eq!(
            r.checkpoints.len(),
            expected.len(),
            "{}：重複列出",
            r.scenario.name
        );
    }
}

#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn no_api_call_returns_a_core_error() {
    assert_rules_hold(&[Rule::NoCoreError]);
}

/// 收尾後留到隔天的到期卡 ≤ 2 × `review_cap`，`today` 的 `review_cap` 為準。
fn backlog_breaches(r: &RunReport) -> Vec<String> {
    r.days
        .iter()
        .filter(|d| d.due_left > BACKLOG_FACTOR * d.review_cap)
        .map(|d| {
            format!(
                "{}｜第 {} 天 留 {} 張 > 2 × cap {}",
                r.scenario.name,
                day_no(d.date),
                d.due_left,
                d.review_cap
            )
        })
        .collect()
}

#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn review_carry_over_stays_below_the_backlog_line_for_diligent_learners() {
    let found: Vec<String> = DILIGENT
        .into_iter()
        .flat_map(|index| backlog_breaches(report(index)))
        .collect();
    assert_none(&found);
}

/// C1（RULINGS O11）：留到隔天的到期卡 ≤ 3 × 當天 `review_cap` ＋ 兩次收尾之間新增的到期量，
/// 而且仍學完 L30。只排複習的日子 `review_cap` 是合併後的上限（約階段容量的兩倍），這條上界
/// 鬆，不釘住暫停線；暫停線由 `review_backlog_days_only_review_and_respect_the_pause_line` 檢查。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn review_backlog_stays_bounded_for_a_struggling_learner() {
    let r = report(STRUGGLING);
    let found: Vec<String> = backlog_bound_breaches(&r.days, C1_FACTOR)
        .into_iter()
        .map(|(d, inflow)| {
            format!(
                "第 {} 天 留 {} 張 > 3 × cap {} ＋ 新增 {inflow}",
                day_no(d.date),
                d.due_left,
                d.review_cap
            )
        })
        .collect();
    assert_none(&found);
    let end = r.main_end.map(day_no);
    assert!(end.is_some(), "{}：沒學完 L30", r.scenario.name);
    println!("{}：L30 第 {end:?} 天完成", r.scenario.name);
}

/// C4：主線完成前，任何學習者都不會連續超過 14 個日曆天沒有主線切片（含缺席日）。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn no_learner_goes_more_than_two_weeks_without_new_content() {
    let found: Vec<String> = all_reports()
        .into_iter()
        .filter_map(|r| {
            let (calendar, study) = longest_stall(&r.days, r.main_end);
            (calendar > MAX_STALL_DAYS).then(|| {
                format!(
                    "{}：最長 {calendar} 日曆天（{study} 學習日）",
                    r.scenario.name
                )
            })
        })
        .collect();
    assert_none(&found);
}

/// 預估只會往後順延（§7.5），不會早於實際；完成後停在實際完成日。
fn main_forecast_breaches(r: &RunReport) -> Vec<String> {
    let Some(actual) = r.main_end else {
        return vec![format!("{}：主線沒完成", r.scenario.name)];
    };
    let mut previous = None;
    let mut found = Vec::new();
    for f in &r.forecasts {
        let ok = match f.main_end {
            Some(end) if f.date > actual => end == actual,
            Some(end) => end <= actual && previous.is_none_or(|p| end >= p),
            None => false,
        };
        if !ok {
            found.push(format!(
                "{}｜第 {} 天預估 {:?}，實際 {actual}",
                r.scenario.name,
                day_no(f.date),
                f.main_end
            ));
        }
        previous = f.main_end;
    }
    found
}

#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn main_forecast_only_slips_later_and_settles_on_the_actual_end() {
    let found: Vec<String> = all_reports()
        .into_iter()
        .flat_map(main_forecast_breaches)
        .collect();
    assert_none(&found);
}

/// §7.5 不模擬受限狀態：認真學習者的主線誤差只來自受限天數。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn forecast_gap_is_explained_by_throttled_days() {
    for index in DILIGENT {
        let r = report(index);
        let first = r.initial();
        let throttled = r.throttled_days();
        let gap = (r.main_end.expect("已完成") - first.main_end.expect("有預估")).num_days();
        assert!(
            (0..=throttled).contains(&gap),
            "{}：主線差 {gap} 天，受限 {throttled} 天",
            r.scenario.name
        );
    }
}

/// C2：四種方案的認真學習者，建立計畫時的主線完成日預估誤差 ≤ 5%（RULINGS O11）。
#[test]
#[ignore = "長模擬：cargo test --release --test p0_learning_loop -- --ignored"]
fn initial_forecast_is_within_five_percent_for_diligent_learners() {
    for index in DILIGENT {
        let r = report(index);
        let (forecast, actual) = (r.initial().main_end, r.main_end);
        let error = forecast_error(forecast, actual).expect("已完成且有預估");
        assert!(
            error.abs() <= FORECAST_TOLERANCE,
            "{}：主線預估 {forecast:?}，實際 {actual:?}（{:+.1}%）",
            r.scenario.name,
            error * 100.0
        );
    }
}

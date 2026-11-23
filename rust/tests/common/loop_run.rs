//! 學習迴路模擬的執行與報表（p0_learning_loop.rs、p0_learning_loop_edges.rs 共用）：
//! 依 `Scenario` 逐日學習、記錄量測值與違反，最後印出摘要。

use std::collections::BTreeMap;
use std::time::{Duration as Elapsed, Instant};

use chrono::{Datelike, Duration, NaiveDate, Weekday};
use jp_core::api::dto_plan::{PlanInputDto, StartLevel};

use super::learner::{AnswerPolicy, DayLog, Learner};
use super::loop_facts::ContentFacts;
use super::loop_invariants::{Checker, Rule, Violation};
use super::loop_report::{
    backlog_series, backlog_summary, day_no, metrics_line, minutes_summary, restricted_sample,
    return_days, start_date, DayStat, ForecastSample, Outcome,
};
use super::plan_input;
use super::real::p0_content;

const DAYS_AFTER_MAIN: i64 = 60;
const FORECAST_EVERY_DAYS: u32 = 7;
/// C1 上界的倍數（RULINGS O11 的驗收條件，與暫停線倍數無關）。上界以當天 `review_cap` 計，
/// 只排複習的日子是合併後的上限，所以它不釘住暫停線；暫停線由 `Rule::BacklogPauseLine` 對
/// `capacity` 檢查。
pub const C1_FACTOR: u32 = 3;
pub const MAX_SHOWN: usize = 12;
const SERIES_EVERY: usize = 60;
/// 每天都是學習日（`PlanInputDto.weekdays`，1 = 週一）。
pub const EVERY_DAY: [u32; 7] = [1, 2, 3, 4, 5, 6, 7];

/// 週期性缺席：每 `every_days` 天中，最後 `length` 天不打開 App。
#[derive(Debug, Clone, Copy)]
pub struct Breaks {
    pub every_days: u32,
    pub length: u32,
}

#[derive(Debug, Clone, Copy)]
pub struct Scenario {
    pub name: &'static str,
    pub minutes: u32,
    /// 計畫的學習日（`PlanInputDto.weekdays`）。
    pub study_weekdays: &'static [u32],
    /// 不打開 App 的星期。其他日子（含計畫的休息日）都會打開 App、做完清單。
    pub skipped: &'static [Weekday],
    pub breaks: Option<Breaks>,
    /// 第 1 天到這一天之前都在無聲模式（`audio_available = false`），0 表示一直有聲。
    pub audio_from_day: u32,
    pub wrong_per_ten: u64,
    pub max_days: u32,
}

impl Scenario {
    pub const fn diligent(name: &'static str, minutes: u32, max_days: u32) -> Self {
        Self {
            name,
            minutes,
            study_weekdays: &EVERY_DAY,
            skipped: &[],
            breaks: None,
            audio_from_day: 0,
            wrong_per_ten: 0,
            max_days,
        }
    }

    fn plan_input(&self) -> PlanInputDto {
        PlanInputDto {
            weekdays: self.study_weekdays.to_vec(),
            ..plan_input(self.minutes, StartLevel::Zero)
        }
    }

    fn absent_on(&self, day: u32, date: NaiveDate) -> bool {
        let on_break = self
            .breaks
            .is_some_and(|b| (day - 1) % b.every_days >= b.every_days - b.length);
        on_break || self.skipped.contains(&date.weekday())
    }

    fn audio_on(&self, day: u32) -> bool {
        day >= self.audio_from_day
    }
}

pub struct RunReport {
    pub scenario: Scenario,
    pub elapsed: Elapsed,
    pub last_date: NaiveDate,
    pub days: Vec<DayStat>,
    pub missed: usize,
    pub violations: Vec<Violation>,
    pub main_end: Option<NaiveDate>,
    pub key_lessons: Vec<(NaiveDate, String)>,
    pub checkpoints: Vec<(NaiveDate, String)>,
    pub sentences_checked: usize,
    pub milestones_shown: Vec<String>,
    pub forecasts: Vec<ForecastSample>,
}

/// curriculum §11.4「各時點」表的課。
const KEY_LESSONS: [&str; 6] = ["le.k19", "le.kk08", "le.l07", "le.l14", "le.l21", "le.l30"];

/// 模擬進行中的累積資料。
pub struct Trace {
    pub days: Vec<DayStat>,
    pub missed: Vec<NaiveDate>,
    pub main_end: Option<NaiveDate>,
    pub last_cursor: Option<String>,
    pub forecasts: Vec<ForecastSample>,
}

impl Trace {
    fn record(&mut self, log: &DayLog) {
        self.days.push(DayStat::of(log));
        self.last_cursor.clone_from(&log.cursor_after);
        if self.main_end.is_none() && log.cursor_after.is_none() {
            self.main_end = Some(log.date);
        }
    }

    /// 主線完成滿 60 天。
    fn finished(&self, date: NaiveDate) -> bool {
        self.main_end
            .is_some_and(|end| date >= end + Duration::days(DAYS_AFTER_MAIN))
    }
}

/// 從零開始，逐日學習到 `limit` 天或 `Trace::finished`。缺席日不打開 App。
pub fn simulate(
    scenario: Scenario,
    facts: &ContentFacts,
    limit: u32,
) -> (Trace, Checker<'_>, Learner) {
    let mut checker = Checker::new(facts, scenario.minutes);
    let policy = AnswerPolicy::wrong_per_ten(scenario.wrong_per_ten);
    let mut learner = Learner::start(p0_content(), &scenario.plan_input(), policy);
    let mut trace = Trace {
        days: Vec::new(),
        missed: Vec::new(),
        main_end: None,
        last_cursor: None,
        forecasts: vec![ForecastSample::of(&learner.created, start_date())],
    };
    for day in 1..=limit {
        let date = start_date() + Duration::days(i64::from(day) - 1);
        if scenario.absent_on(day, date) {
            trace.missed.push(date);
        } else {
            if day % FORECAST_EVERY_DAYS == 1 {
                let view = learner.app.core.plan_view().expect("plan_view");
                trace.forecasts.push(ForecastSample::of(&view, date));
            }
            learner.set_audio(scenario.audio_on(day));
            let log = learner.study_day(day);
            checker.check_day(&log);
            trace.record(&log);
        }
        if trace.finished(date) {
            break;
        }
        learner.next_day();
    }
    (trace, checker, learner)
}

pub fn run(scenario: Scenario) -> RunReport {
    let started = Instant::now();
    let facts = ContentFacts::new(&p0_content());
    let (trace, checker, learner) = simulate(scenario, &facts, scenario.max_days);
    let last_studied = trace.days.last().map_or(start_date(), |d| d.date);
    RunReport {
        scenario,
        elapsed: started.elapsed(),
        last_date: last_studied.max(trace.missed.last().copied().unwrap_or(last_studied)),
        days: trace.days,
        missed: trace.missed.len(),
        violations: checker.violations.clone(),
        main_end: trace.main_end,
        key_lessons: KEY_LESSONS
            .iter()
            .filter_map(|id| Some((checker.completed_on(id)?, (*id).to_owned())))
            .collect(),
        checkpoints: checker.checkpoints().to_vec(),
        sentences_checked: checker.sentences_checked,
        milestones_shown: learner
            .created
            .milestones
            .iter()
            .map(|m| m.id.clone())
            .collect(),
        forecasts: trace.forecasts,
    }
}

impl RunReport {
    pub fn throttled_days(&self) -> i64 {
        let count = self.days.iter().filter(|d| d.recovery.is_some()).count();
        i64::try_from(count).expect("天數不可能超過 i64")
    }

    pub fn initial(&self) -> ForecastSample {
        self.forecasts[0]
    }

    pub fn outcome(&self) -> Outcome<'_> {
        Outcome {
            days: &self.days,
            plan_minutes: self.scenario.minutes,
            main_end: self.main_end,
            initial: self.initial(),
        }
    }

    /// 違反 `rules` 的條目，一筆一行。
    pub fn breaches_of(&self, rules: &[Rule]) -> Vec<String> {
        let matching = self.violations.iter().filter(|v| rules.contains(&v.rule));
        describe(self.scenario.name, matching)
    }
}

pub fn describe<'a>(name: &str, violations: impl Iterator<Item = &'a Violation>) -> Vec<String> {
    violations
        .map(|v| {
            format!(
                "{name}｜{} 第 {} 天 {:?}：{}",
                v.date,
                day_no(v.date),
                v.rule,
                v.detail
            )
        })
        .collect()
}

pub fn assert_none(found: &[String]) {
    let shown: Vec<&str> = found.iter().take(MAX_SHOWN).map(String::as_str).collect();
    assert!(
        found.is_empty(),
        "{} 筆違反，前 {} 筆：\n{}",
        found.len(),
        shown.len(),
        shown.join("\n")
    );
}

fn rule_counts(r: &RunReport) -> BTreeMap<String, usize> {
    r.violations.iter().fold(BTreeMap::new(), |mut acc, v| {
        *acc.entry(format!("{:?}", v.rule)).or_default() += 1;
        acc
    })
}

fn dated(items: &[(NaiveDate, String)]) -> Vec<String> {
    items
        .iter()
        .map(|(date, id)| format!("{id}@{}", day_no(*date)))
        .collect()
}

fn print_milestones(r: &RunReport) {
    let first = r.initial();
    println!(
        "== {}（{:.1?}，模擬到第 {} 天，學習 {} 天，缺席 {} 天）",
        r.scenario.name,
        r.elapsed,
        day_no(r.last_date),
        r.days.len(),
        r.missed
    );
    println!(
        "  L30 完成：第 {:?} 天（{:?}）｜建立計畫時預估第 {:?} 天｜受限 {} 天",
        r.main_end.map(day_no),
        r.main_end,
        first.main_end.map(day_no),
        r.throttled_days()
    );
    println!("  課完成日：{:?}", dated(&r.key_lessons));
    println!("  檢定：{:?}", dated(&r.checkpoints));
}

pub fn print_report(r: &RunReport) {
    print_milestones(r);
    println!("  {}", metrics_line(&r.outcome(), C1_FACTOR));
    println!(
        "  受限日（第幾天:到期/capacity/cap）：{:?}",
        restricted_sample(&r.days, MAX_SHOWN)
    );
    let returns = return_days(&r.days);
    if !returns.is_empty() {
        println!("  回鍋日（第幾天:到期/capacity/cap，* 只排複習）：{returns:?}");
    }
    println!("  {}", minutes_summary(&r.days, r.scenario.minutes));
    println!("  {}", backlog_summary(&r.days));
    println!(
        "  違反：{:?}｜檢查句子露出 {} 次",
        rule_counts(r),
        r.sentences_checked
    );
    for line in backlog_series(&r.days, SERIES_EVERY) {
        println!("    {line}");
    }
}

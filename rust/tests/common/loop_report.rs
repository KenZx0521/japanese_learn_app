//! 學習迴路模擬的量測值與摘要文字（p0_learning_loop.rs）：每日分鐘、複習積壓、預估完成日。

use std::collections::BTreeMap;

use chrono::NaiveDate;
use jp_core::api::dto_plan::{PlanViewDto, RecoveryReason, TaskDto};

use super::learner::{DayLog, Source};
use super::loop_invariants::new_cards_minutes;
use super::start_time;

const OVER_BUDGET_EDGES: [f64; 3] = [0.8, 1.0, 1.1];
/// `Review` 的估算四捨五入到 0.5 分（§7.4）。
const ROUNDING_MINUTES: f64 = 0.5;

pub fn start_date() -> NaiveDate {
    start_time().date_naive()
}

/// 從零開始的第幾天（第一天為 1）。
pub fn day_no(date: NaiveDate) -> i64 {
    (date - start_date()).num_days() + 1
}

/// 學習日的量測值。
#[derive(Debug, Clone)]
pub struct DayStat {
    pub date: NaiveDate,
    /// 當天第一次 `today_view` 的 `estimated_minutes`（T1 顯示的數字）。
    pub planned: f64,
    pub new_card_minutes: f64,
    /// 開始時的到期複習數（`Review.due`）。
    pub due_start: u32,
    pub review_cap: u32,
    /// 積壓判定用的複習容量（§7.2）。
    pub capacity: u32,
    pub is_study_day: bool,
    /// 收尾後仍到期、留到隔天的張數。
    pub due_left: u32,
    pub answered: usize,
    pub recovery: Option<RecoveryReason>,
    /// 當天有主線切片（`NewContent` 或 `Integration`）。
    pub main_slice: bool,
    /// 學習日只排複習：new、drill、listen 額度都併入 review（RULINGS O11、O12）。
    pub review_only: bool,
}

fn has_main_slice(tasks: &[TaskDto]) -> bool {
    tasks
        .iter()
        .any(|t| matches!(t, TaskDto::NewContent { .. } | TaskDto::Integration { .. }))
}

impl DayStat {
    pub fn of(log: &DayLog) -> Self {
        let view = &log.first_view;
        let due_start = view
            .tasks
            .iter()
            .find_map(|task| match task {
                TaskDto::Review { due, .. } => Some(*due),
                _ => None,
            })
            .unwrap_or(0);
        Self {
            main_slice: has_main_slice(&view.tasks),
            date: log.date,
            planned: view.estimated_minutes,
            new_card_minutes: new_cards_minutes(view),
            due_start,
            review_cap: view.budget.review_cap,
            capacity: view.budget.capacity,
            is_study_day: view.is_study_day,
            due_left: log.due_left,
            answered: log
                .questions
                .iter()
                .filter(|q| q.source == Source::Review)
                .count(),
            recovery: view.recovery_reason,
            review_only: view.is_study_day
                && view.budget.new_minutes + view.budget.drill_minutes + view.budget.listen_minutes
                    == 0.0,
        }
    }
}

/// `plan_view` 在某天給的主線完成日。
#[derive(Debug, Clone, Copy)]
pub struct ForecastSample {
    pub date: NaiveDate,
    pub main_end: Option<NaiveDate>,
}

fn parse(date: Option<&String>) -> Option<NaiveDate> {
    date.map(|text| NaiveDate::parse_from_str(text, "%Y-%m-%d").expect("YYYY-MM-DD"))
}

impl ForecastSample {
    pub fn of(view: &PlanViewDto, date: NaiveDate) -> Self {
        Self {
            date,
            main_end: parse(view.main_forecast_end.as_ref()),
        }
    }
}

fn percentile(sorted: &[f64], p: f64) -> f64 {
    let index = ((sorted.len() as f64 - 1.0) * p).round() as usize;
    sorted.get(index).copied().unwrap_or(0.0)
}

/// 每日預估分鐘的最大值、百分位與相對方案分鐘的分布。
pub fn minutes_summary(days: &[DayStat], plan_minutes: u32) -> String {
    let mut planned: Vec<f64> = days.iter().map(|d| d.planned).collect();
    planned.sort_by(f64::total_cmp);
    let budget = f64::from(plan_minutes);
    let [low, full, over] = OVER_BUDGET_EDGES.map(|edge| edge * budget);
    let count = |lo: f64, hi: f64| planned.iter().filter(|m| **m > lo && **m <= hi).count();
    let tail_max = days.iter().map(|d| d.new_card_minutes).fold(0.0, f64::max);
    format!(
        "每日預估分鐘 max {} p50 {} p90 {} p99 {}｜≤80% {}、80–100% {}、100–110% {}、>110% {} 天｜收尾新卡最多 {tail_max:.1} 分",
        planned.last().copied().unwrap_or(0.0),
        percentile(&planned, 0.5),
        percentile(&planned, 0.9),
        percentile(&planned, 0.99),
        count(f64::MIN, low),
        count(low, full),
        count(full, over),
        count(over, f64::MAX)
    )
}

/// 複習積壓：開始時到期最多、收尾後留到隔天最多、受限天數。
pub fn backlog_summary(days: &[DayStat]) -> String {
    let max_start = days.iter().max_by_key(|d| d.due_start);
    let max_left = days.iter().max_by_key(|d| d.due_left);
    let recovery: BTreeMap<String, usize> = days
        .iter()
        .filter_map(|d| d.recovery.map(|reason| format!("{reason:?}")))
        .fold(BTreeMap::new(), |mut acc, key| {
            *acc.entry(key).or_default() += 1;
            acc
        });
    format!(
        "開始時到期最多 {:?}（當天 cap {:?}）｜收尾後留到隔天最多 {:?}（第 {:?} 天）｜單日複習作答最多 {}｜受限 {recovery:?}",
        max_start.map(|d| d.due_start),
        max_start.map(|d| d.review_cap),
        max_left.map(|d| d.due_left),
        max_left.map(|d| day_no(d.date)),
        days.iter().map(|d| d.answered).max().unwrap_or(0)
    )
}

/// 當天開始時的到期數減去上一個學習日收尾後留下的數，即兩次收尾之間新增的到期量。
pub fn inflows(days: &[DayStat]) -> Vec<u32> {
    let previous = std::iter::once(0).chain(days.iter().map(|d| d.due_left));
    days.iter()
        .zip(previous)
        .map(|(d, left)| d.due_start.saturating_sub(left))
        .collect()
}

/// 留到隔天的到期卡超過 `factor × review_cap ＋ 當天新增到期量` 的學習日（C1 的上界）。
pub fn backlog_bound_breaches(days: &[DayStat], factor: u32) -> Vec<(&DayStat, u32)> {
    days.iter()
        .zip(inflows(days))
        .filter(|(d, inflow)| d.due_left > factor * d.review_cap + inflow)
        .collect()
}

/// T1 的容許上限：方案分鐘＋四捨五入（§7.4）。
pub fn allowed_minutes(plan_minutes: u32) -> f64 {
    f64::from(plan_minutes) + ROUNDING_MINUTES
}

/// 主線完成前，最長連續沒有主線切片的日曆天數（含缺席日）與學習日數。
pub fn longest_stall(days: &[DayStat], main_end: Option<NaiveDate>) -> (i64, usize) {
    let in_main = |d: &&DayStat| main_end.is_none_or(|end| d.date <= end);
    let slice_dates: Vec<NaiveDate> = std::iter::once(start_date() - chrono::Duration::days(1))
        .chain(
            days.iter()
                .filter(in_main)
                .filter(|d| d.main_slice)
                .map(|d| d.date),
        )
        .chain(
            main_end
                .is_none()
                .then(|| days.last().map(|d| d.date))
                .flatten(),
        )
        .collect();
    let calendar = slice_dates
        .windows(2)
        .map(|pair| (pair[1] - pair[0]).num_days() - 1)
        .max()
        .unwrap_or(0);
    let study = days
        .iter()
        .filter(in_main)
        .fold((0, 0), |(run, best), d| {
            let run = if d.main_slice { 0 } else { run + 1 };
            (run, best.max(run))
        })
        .1;
    (calendar, study)
}

/// 量測表一列需要的每日統計（報告用）。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DayMetrics {
    pub max_left: u32,
    pub max_left_ratio: f64,
    pub backlog_days: usize,
    pub restricted_days: usize,
    pub bound_breaches: usize,
    pub t1_max: f64,
    pub t1_excess: f64,
    pub stall_calendar: i64,
    pub stall_study: usize,
    pub review_only_days: usize,
}

impl DayMetrics {
    pub fn of(days: &[DayStat], plan_minutes: u32, factor: u32, end: Option<NaiveDate>) -> Self {
        let (stall_calendar, stall_study) = longest_stall(days, end);
        let fmax = |f: &dyn Fn(&DayStat) -> f64| days.iter().map(f).fold(f64::MIN, f64::max);
        Self {
            max_left: days.iter().map(|d| d.due_left).max().unwrap_or(0),
            max_left_ratio: fmax(&|d| f64::from(d.due_left) / f64::from(d.review_cap.max(1))),
            backlog_days: days
                .iter()
                .filter(|d| d.recovery == Some(RecoveryReason::ReviewBacklog))
                .count(),
            restricted_days: days.iter().filter(|d| d.recovery.is_some()).count(),
            bound_breaches: backlog_bound_breaches(days, factor).len(),
            t1_max: fmax(&|d| d.planned),
            t1_excess: fmax(&|d| d.planned - allowed_minutes(plan_minutes)),
            stall_calendar,
            stall_study,
            review_only_days: days.iter().filter(|d| d.review_only).count(),
        }
    }
}

/// 前半與後半學習日各自留到隔天的最多張數，看積壓有沒有隨時間增長。
pub fn left_by_half(days: &[DayStat]) -> (u32, u32) {
    let (first, second) = days.split_at(days.len() / 2);
    let max = |part: &[DayStat]| part.iter().map(|d| d.due_left).max().unwrap_or(0);
    (max(first), max(second))
}

/// 預估與實際完成日的相對誤差（實際減預估，除以實際天數）。
pub fn forecast_error(forecast: Option<NaiveDate>, actual: Option<NaiveDate>) -> Option<f64> {
    let (forecast, actual) = (day_no(forecast?), day_no(actual?));
    Some((actual - forecast) as f64 / actual as f64)
}

/// 一位學習者的模擬結果中，量測表用到的部分。
pub struct Outcome<'a> {
    pub days: &'a [DayStat],
    pub plan_minutes: u32,
    pub main_end: Option<NaiveDate>,
    pub initial: ForecastSample,
}

fn percent(error: Option<f64>) -> String {
    error.map_or("—".to_owned(), |e| format!("{:+.1}%", e * 100.0))
}

/// 量測表一列：積壓、受限、完成日、預估誤差、T1 最大分鐘、最長停滯。
pub fn metrics_line(o: &Outcome<'_>, factor: u32) -> String {
    let m = DayMetrics::of(o.days, o.plan_minutes, factor, o.main_end);
    let (early, late) = left_by_half(o.days);
    format!(
        "量測｜留到隔天最多 {}（{:.2}×cap；前半 {}、後半 {}）超出 C1 上界 {} 天｜受限 {} 天（積壓 {}，只排複習 {}）｜主線第 {:?} 天 誤差 {}｜T1 最大 {} 分（超出容許 {:+.2}）｜最長停滯 {} 日曆天／{} 學習日",
        m.max_left,
        m.max_left_ratio,
        early,
        late,
        m.bound_breaches,
        m.restricted_days,
        m.backlog_days,
        m.review_only_days,
        o.main_end.map(day_no),
        percent(forecast_error(o.initial.main_end, o.main_end)),
        m.t1_max,
        m.t1_excess,
        m.stall_calendar,
        m.stall_study
    )
}

/// 受限日的前 `limit` 筆：`第幾天:到期/capacity/cap`。積壓用 `capacity` 判定，`cap` 是當天上限。
pub fn restricted_sample(days: &[DayStat], limit: usize) -> Vec<String> {
    days.iter()
        .filter(|d| d.recovery.is_some())
        .take(limit)
        .map(|d| {
            format!(
                "{}:{}/{}/{}",
                day_no(d.date),
                d.due_start,
                d.capacity,
                d.review_cap
            )
        })
        .collect()
}

/// 回鍋日（`ReturnAfterBreak`）：`第幾天:到期/capacity/cap`，只排複習的日子加 `*`。
pub fn return_days(days: &[DayStat]) -> Vec<String> {
    days.iter()
        .filter(|d| d.recovery == Some(RecoveryReason::ReturnAfterBreak))
        .map(|d| {
            let mark = if d.review_only { "*" } else { "" };
            format!(
                "{}:{}/{}/{}{mark}",
                day_no(d.date),
                d.due_start,
                d.capacity,
                d.review_cap
            )
        })
        .collect()
}

/// 每 `every` 個學習日一行的積壓序列。
pub fn backlog_series(days: &[DayStat], every: usize) -> Vec<String> {
    days.iter()
        .step_by(every)
        .map(|d| {
            format!(
                "第 {} 天：到期 {} capacity {} cap {} 留 {} 作答 {} 預估 {} 分 {:?}",
                day_no(d.date),
                d.due_start,
                d.capacity,
                d.review_cap,
                d.due_left,
                d.answered,
                d.planned,
                d.recovery
            )
        })
        .collect()
}

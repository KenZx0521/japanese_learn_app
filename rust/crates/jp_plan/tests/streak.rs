//! §7.6 連續天數全表。

mod common;

use std::collections::BTreeSet;

use common::*;
use jp_plan::calendar::{is_study_day, PlanHistory, ALL_DAYS_MASK};
use jp_plan::streak::{best_streak, current_streak};
use jp_store::PlanVersionRow;

fn active(dates: &[&str]) -> BTreeSet<chrono::NaiveDate> {
    dates.iter().map(|date| d(date)).collect()
}

fn daily(date: chrono::NaiveDate) -> bool {
    is_study_day(ALL_DAYS_MASK, date)
}

fn mwf(date: chrono::NaiveDate) -> bool {
    is_study_day(MWF_MASK, date)
}

#[test]
fn no_active_days_is_zero() {
    assert_eq!(current_streak(&active(&[]), d("2026-03-05"), daily), 0);
}

#[test]
fn active_today_is_one() {
    assert_eq!(
        current_streak(&active(&["2026-03-05"]), d("2026-03-05"), daily),
        1
    );
}

#[test]
fn not_yet_studied_today_does_not_break() {
    assert_eq!(
        current_streak(&active(&["2026-03-04"]), d("2026-03-05"), daily),
        1
    );
}

#[test]
fn yesterday_missed_breaks_to_zero() {
    assert_eq!(
        current_streak(&active(&["2026-03-03"]), d("2026-03-05"), daily),
        0
    );
}

#[test]
fn three_days_in_a_row() {
    let days = active(&["2026-03-03", "2026-03-04", "2026-03-05"]);
    assert_eq!(current_streak(&days, d("2026-03-05"), daily), 3);
}

#[test]
fn rest_days_are_transparent() {
    let days = active(&["2026-03-02", "2026-03-04"]);
    assert_eq!(current_streak(&days, d("2026-03-05"), mwf), 2);
}

#[test]
fn missing_wednesday_breaks_mwf() {
    assert_eq!(
        current_streak(&active(&["2026-03-02"]), d("2026-03-05"), mwf),
        0
    );
}

#[test]
fn studying_on_rest_day_counts() {
    let days = active(&["2026-03-02", "2026-03-03", "2026-03-04"]);
    assert_eq!(current_streak(&days, d("2026-03-04"), mwf), 3);
}

#[test]
fn today_being_rest_day_does_not_break() {
    assert_eq!(
        current_streak(&active(&["2026-03-02"]), d("2026-03-03"), mwf),
        1
    );
}

fn history(rows: &[(i64, &str, u8)]) -> PlanHistory {
    let versions: Vec<PlanVersionRow> = rows
        .iter()
        .map(|&(id, from, mask)| PlanVersionRow {
            id,
            ..plan_row(d(from), 20, mask)
        })
        .collect();
    PlanHistory::from_rows(&versions)
}

#[test]
fn changing_plan_later_cannot_rescue_a_broken_streak() {
    // 週三（03-04）當時是學習日且缺席；03-05 才把週三改成休息日，也救不回來。
    let plans = history(&[(1, "2026-03-02", ALL_DAYS_MASK), (2, "2026-03-05", 0b1)]);
    let days = active(&["2026-03-02"]);

    assert_eq!(
        current_streak(&days, d("2026-03-05"), |date| plans.is_study_day(date)),
        0
    );
}

#[test]
fn plan_change_applies_from_its_effective_date() {
    let plans = history(&[(1, "2026-03-02", 0b1), (2, "2026-03-04", ALL_DAYS_MASK)]);
    let days = active(&["2026-03-02", "2026-03-04"]);

    assert_eq!(
        current_streak(&days, d("2026-03-04"), |date| plans.is_study_day(date)),
        2
    );
}

#[test]
fn dates_before_first_plan_are_not_study_days() {
    let plans = history(&[(1, "2026-03-04", ALL_DAYS_MASK)]);
    let days = active(&["2026-03-01", "2026-03-04"]);

    assert_eq!(
        current_streak(&days, d("2026-03-04"), |date| plans.is_study_day(date)),
        2
    );
}

#[test]
fn best_streak_of_nothing_is_zero() {
    assert_eq!(best_streak(&active(&[]), daily), 0);
}

#[test]
fn best_streak_finds_longest_run() {
    let days = active(&[
        "2026-03-01",
        "2026-03-02",
        "2026-03-04",
        "2026-03-05",
        "2026-03-06",
    ]);
    assert_eq!(best_streak(&days, daily), 3);
}

#[test]
fn best_streak_treats_rest_days_as_transparent() {
    let days = active(&["2026-03-02", "2026-03-04", "2026-03-06"]);
    assert_eq!(best_streak(&days, mwf), 3);
}

#[test]
fn best_streak_breaks_on_missed_study_day() {
    let days = active(&["2026-03-02", "2026-03-06"]);
    assert_eq!(best_streak(&days, mwf), 1);
}

/// 時區往西讓邏輯日倒退時，比今天晚的活躍日不能被忽略（§2、§7.6）。
#[test]
fn a_logical_day_moved_backwards_keeps_later_active_days() {
    assert_eq!(
        current_streak(&active(&["2026-03-02"]), d("2026-03-01"), daily),
        1
    );
    assert_eq!(
        current_streak(
            &active(&["2026-02-28", "2026-03-02"]),
            d("2026-03-01"),
            daily
        ),
        2,
        "倒退到的那天還沒學，不算斷"
    );
}

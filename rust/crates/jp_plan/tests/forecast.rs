//! §7.5 里程碑預測與順延。

mod common;

use chrono::{Datelike, Duration, NaiveDate, Weekday};
use common::*;
use jp_content::schema::ContentStage;
use jp_content::ContentStore;
use jp_plan::forecast::{
    forecast, plan_status, suggested_minutes, Forecast, ForecastRequest, PlanStatus,
};
use jp_plan::input::{PlanInput, StartLevel};
use jp_plan::milestone::milestone_outlook;
use jp_plan::state::CursorState;

fn monday() -> NaiveDate {
    d(MONDAY)
}

fn day(n: i64) -> NaiveDate {
    monday() + Duration::days(n - 1)
}

fn run(state: &CursorState, plan: &PlanInput, today: NaiveDate, store: &ContentStore) -> Forecast {
    let request = ForecastRequest {
        today,
        today_slice_done: false,
        plan,
    };
    forecast(state, &request, store).unwrap()
}

fn milestone(forecast: &Forecast, id: &str) -> NaiveDate {
    forecast.milestones.iter().find(|(m, _)| m == id).unwrap().1
}

#[test]
fn every_day_twenty_minute_plan_matches_hand_simulation() {
    let store = content();

    let got = run(&CursorState::default(), &input(20), monday(), &store);

    assert_eq!(milestone(&got, "ms.hira"), day(21));
    assert_eq!(milestone(&got, "ms.survive"), day(30));
    assert_eq!(milestone(&got, "ms.kata"), day(31));
    assert_eq!(milestone(&got, "ms.casual"), day(35));
    assert_eq!(milestone(&got, "ms.n4"), day(37));
    assert_eq!(got.main_end, Some(day(37)));
}

#[test]
fn p0a_forecast_reaches_the_main_end() {
    let store = content_at(ContentStage::P0a);

    let got = run(&CursorState::default(), &input(20), monday(), &store);

    assert!(!got.milestones.is_empty());
    assert!(got.main_end.is_some());
}

#[test]
fn starting_three_days_later_shifts_everything_by_exactly_three_days() {
    let store = content();
    let state = CursorState::default();

    let base = run(&state, &input(20), monday(), &store);
    let later = run(&state, &input(20), monday() + Duration::days(3), &store);

    for ((id_a, date_a), (id_b, date_b)) in base.milestones.iter().zip(&later.milestones) {
        assert_eq!(id_a, id_b);
        assert_eq!(*date_b - *date_a, Duration::days(3));
    }
    assert_eq!(
        later.main_end.unwrap() - base.main_end.unwrap(),
        Duration::days(3)
    );
}

#[test]
fn mwf_plan_only_lands_on_study_days() {
    let store = content();
    let plan = PlanInput {
        weekday_mask: MWF_MASK,
        ..input(20)
    };

    let got = run(&CursorState::default(), &plan, monday(), &store);

    for (_, date) in &got.milestones {
        assert!(
            matches!(date.weekday(), Weekday::Mon | Weekday::Wed | Weekday::Fri),
            "{date}"
        );
    }
    assert!(matches!(
        got.main_end.unwrap().weekday(),
        Weekday::Mon | Weekday::Wed | Weekday::Fri
    ));
}

#[test]
fn schedule_only_contains_study_days_with_their_lessons() {
    let store = content();
    let plan = PlanInput {
        weekday_mask: MWF_MASK,
        ..input(20)
    };

    let got = run(&CursorState::default(), &plan, monday(), &store);

    assert_eq!(got.schedule[0].date, monday());
    assert_eq!(got.schedule[0].lesson_ids, ids(&["le.k01"]));
    assert!(got.schedule.iter().all(|day| matches!(
        day.date.weekday(),
        Weekday::Mon | Weekday::Wed | Weekday::Fri
    )));
}

#[test]
fn large_lesson_still_terminates_and_is_scheduled() {
    let store = content();

    // 10 分方案每字每課都更慢，仍要走得完。
    let got = run(&CursorState::default(), &input(10), monday(), &store);

    assert!(got.main_end.is_some());
    assert_eq!(got.milestones.len(), store.milestones().len());
}

#[test]
fn slower_plans_finish_later() {
    let store = content();
    let end = |minutes| {
        run(&CursorState::default(), &input(minutes), monday(), &store)
            .main_end
            .unwrap()
    };

    assert!(end(10) > end(20));
    assert!(end(20) >= end(45));
}

#[test]
fn ten_minute_plan_needs_two_integration_days_per_lesson() {
    let store = content();
    let state = state_at("le.l08", &store);

    // L08：1 字 + 2 整合 = 3 天；20 分方案 2 天（L21、L31 更多）。
    let ten = run(&state, &input(10), monday(), &store);
    let twenty = run(&state, &input(20), monday(), &store);

    assert_eq!(
        milestone(&ten, "ms.casual") - milestone(&twenty, "ms.casual"),
        Duration::days(2)
    );
}

#[test]
fn already_completed_milestone_keeps_its_completed_date() {
    let store = content();
    let state = state_at("le.l01", &store);

    let got = run(&state, &input(20), monday(), &store);

    assert_eq!(milestone(&got, "ms.hira"), d("2026-01-01"));
}

#[test]
fn today_slice_done_starts_from_the_next_study_day() {
    let store = content();
    let state = CursorState::default();
    let plan = input(20);
    let mut request = ForecastRequest {
        today: monday(),
        today_slice_done: false,
        plan: &plan,
    };

    let today = forecast(&state, &request, &store).unwrap();
    request.today_slice_done = true;
    let tomorrow = forecast(&state, &request, &store).unwrap();

    assert_eq!(
        tomorrow.main_end.unwrap() - today.main_end.unwrap(),
        Duration::days(1)
    );
}

#[test]
fn forecast_does_not_change_the_given_state() {
    let store = content();
    let state = state_at("le.k02", &store);
    let before = state.clone();

    run(&state, &input(20), monday(), &store);

    assert_eq!(state, before);
}

#[test]
fn start_level_skips_are_applied_in_memory() {
    let store = content();
    let plan = PlanInput {
        start_level: StartLevel::Hiragana,
        ..input(20)
    };

    let got = run(&CursorState::default(), &plan, monday(), &store);

    // 跳過全部平假名：L01 第一天。
    assert_eq!(got.schedule[0].lesson_ids, ids(&["le.l01"]));
    assert_eq!(milestone(&got, "ms.hira"), monday());
}

#[test]
fn known_lessons_shorten_the_plan_by_those_days() {
    let store = content();
    let plan = PlanInput {
        known_kana_lessons: ids(&["le.k02", "le.k03"]),
        ..input(20)
    };

    let shorter = run(&CursorState::default(), &plan, monday(), &store);
    let full = run(&CursorState::default(), &input(20), monday(), &store);

    assert!(shorter.main_end.unwrap() < full.main_end.unwrap());
}

#[test]
fn everything_done_reports_last_completed_date() {
    let store = content();

    let got = run(&state_all_done(&store), &input(20), monday(), &store);

    assert_eq!(got.main_end, Some(d("2026-01-01")));
}

#[test]
fn plan_status_compares_main_end_with_target() {
    assert_eq!(plan_status(None, Some(monday())), PlanStatus::NoTarget);
    assert_eq!(
        plan_status(Some(monday()), Some(monday())),
        PlanStatus::OnTrack
    );
    assert_eq!(
        plan_status(Some(monday()), Some(monday() + Duration::days(1))),
        PlanStatus::Behind
    );
    assert_eq!(plan_status(Some(monday()), None), PlanStatus::Behind);
}

#[test]
fn suggested_minutes_is_the_smallest_preset_that_meets_target() {
    let store = content();
    let state = CursorState::default();
    let mut plan = input(10);

    plan.target_date = Some(monday() + Duration::days(365));
    let request = ForecastRequest {
        today: monday(),
        today_slice_done: false,
        plan: &plan,
    };
    assert_eq!(
        suggested_minutes(&state, &request, &store).unwrap(),
        Some(10)
    );

    plan.target_date = Some(day(37));
    let request = ForecastRequest {
        today: monday(),
        today_slice_done: false,
        plan: &plan,
    };
    assert_eq!(
        suggested_minutes(&state, &request, &store).unwrap(),
        Some(20)
    );

    plan.target_date = Some(day(5));
    let request = ForecastRequest {
        today: monday(),
        today_slice_done: false,
        plan: &plan,
    };
    assert_eq!(suggested_minutes(&state, &request, &store).unwrap(), None);
}

#[test]
fn milestone_outlook_merges_forecast_and_baseline() {
    let store = content();
    let got = run(&CursorState::default(), &input(20), monday(), &store);
    let baseline = vec![("ms.hira".to_owned(), day(19))];

    let outlook = milestone_outlook(&got, &baseline, &store);

    assert_eq!(outlook.len(), store.milestones().len());
    let hira = outlook.iter().find(|m| m.id == "ms.hira").unwrap();
    assert_eq!(hira.forecast_date, Some(day(21)));
    assert_eq!(hira.planned_date, Some(day(19)));
    assert_eq!(hira.delay_days, 2);
    let n4 = outlook.iter().find(|m| m.id == "ms.n4").unwrap();
    assert_eq!(n4.planned_date, None);
    assert_eq!(n4.delay_days, 0);
}

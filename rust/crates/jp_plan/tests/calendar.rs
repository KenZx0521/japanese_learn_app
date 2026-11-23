//! §7 學習日與 weekday mask。

mod common;

use common::*;
use jp_plan::calendar::{
    is_study_day, mask_from_weekdays, next_study_date, weekdays_from_mask, PlanHistory,
    ALL_DAYS_MASK,
};
use jp_plan::PlanError;
use jp_store::PlanVersionRow;

#[test]
fn mask_bit_zero_is_monday() {
    assert!(is_study_day(0b1, d("2026-03-02")));
    assert!(!is_study_day(0b1, d("2026-03-03")));
    assert!(is_study_day(0b100_0000, d("2026-03-08")));
}

#[test]
fn monday_wednesday_friday_mask() {
    assert!(is_study_day(MWF_MASK, d("2026-03-02")));
    assert!(!is_study_day(MWF_MASK, d("2026-03-03")));
    assert!(is_study_day(MWF_MASK, d("2026-03-04")));
    assert!(is_study_day(MWF_MASK, d("2026-03-06")));
    assert!(!is_study_day(MWF_MASK, d("2026-03-07")));
    assert!(!is_study_day(MWF_MASK, d("2026-03-08")));
}

#[test]
fn next_study_date_excludes_the_day_itself() {
    assert_eq!(
        next_study_date(MWF_MASK, d("2026-03-02")),
        Some(d("2026-03-04"))
    );
    assert_eq!(
        next_study_date(MWF_MASK, d("2026-03-06")),
        Some(d("2026-03-09"))
    );
    assert_eq!(
        next_study_date(ALL_DAYS_MASK, d("2026-03-02")),
        Some(d("2026-03-03"))
    );
}

#[test]
fn next_study_date_with_empty_mask_is_none() {
    assert_eq!(next_study_date(0, d("2026-03-02")), None);
}

#[test]
fn next_study_date_crosses_month_and_leap_day() {
    assert_eq!(
        next_study_date(ALL_DAYS_MASK, d("2028-02-28")),
        Some(d("2028-02-29"))
    );
    assert_eq!(
        next_study_date(ALL_DAYS_MASK, d("2026-12-31")),
        Some(d("2027-01-01"))
    );
}

#[test]
fn weekdays_round_trip_mask() {
    assert_eq!(mask_from_weekdays(&[1, 3, 5]).unwrap(), MWF_MASK);
    assert_eq!(weekdays_from_mask(MWF_MASK), vec![1, 3, 5]);
    assert_eq!(mask_from_weekdays(&[7, 1, 1]).unwrap(), 0b100_0001);
    assert_eq!(weekdays_from_mask(ALL_DAYS_MASK), vec![1, 2, 3, 4, 5, 6, 7]);
}

#[test]
fn weekdays_out_of_range_or_empty_are_rejected() {
    for bad in [vec![], vec![0], vec![8], vec![1, 9]] {
        let err = mask_from_weekdays(&bad).unwrap_err();
        assert!(matches!(err, PlanError::InvalidInput { .. }), "{bad:?}");
    }
}

fn version(id: i64, from: &str, mask: u8) -> PlanVersionRow {
    PlanVersionRow {
        id,
        weekday_mask: mask,
        ..plan_row(d(from), 20, mask)
    }
}

#[test]
fn history_uses_the_plan_effective_on_each_date() {
    let history = PlanHistory::from_rows(&[
        version(1, "2026-03-02", MWF_MASK),
        version(2, "2026-03-09", ALL_DAYS_MASK),
    ]);

    assert!(!history.is_study_day(d("2026-03-03")));
    assert!(history.is_study_day(d("2026-03-10")));
    assert_eq!(history.mask_on(d("2026-03-08")), Some(MWF_MASK));
}

#[test]
fn history_same_day_versions_take_the_largest_id() {
    let history = PlanHistory::from_rows(&[
        version(3, "2026-03-02", 0b1),
        version(2, "2026-03-02", MWF_MASK),
    ]);

    assert_eq!(history.mask_on(d("2026-03-02")), Some(0b1));
}

#[test]
fn history_before_first_plan_has_no_study_days() {
    let history = PlanHistory::from_rows(&[version(1, "2026-03-02", ALL_DAYS_MASK)]);

    assert_eq!(history.mask_on(d("2026-03-01")), None);
    assert!(!history.is_study_day(d("2026-03-01")));
}

#[test]
fn empty_history_is_never_a_study_day() {
    assert!(!PlanHistory::from_rows(&[]).is_study_day(d("2026-03-02")));
}

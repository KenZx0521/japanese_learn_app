//! rust-core.md §2 的邊界表與換日性質測試。

use std::sync::Arc;

use chrono::{DateTime, Duration, NaiveDate, TimeZone, Utc};
use jp_lang::clock::{
    validate_rollover_hour, validate_utc_offset, Clock, ClockError, DayContext, FixedClock,
    SystemClock, DEFAULT_ROLLOVER_HOUR,
};

fn utc(y: i32, mo: u32, d: u32, h: u32, mi: u32, s: u32) -> DateTime<Utc> {
    Utc.with_ymd_and_hms(y, mo, d, h, mi, s)
        .single()
        .expect("測試用的時刻合法")
}

fn date(y: i32, mo: u32, d: u32) -> NaiveDate {
    NaiveDate::from_ymd_opt(y, mo, d).expect("測試用的日期合法")
}

fn ctx(now: DateTime<Utc>, offset: i32, rollover: u32) -> DayContext {
    DayContext {
        now,
        utc_offset_minutes: offset,
        rollover_hour: rollover,
    }
}

#[test]
fn logical_date_matches_boundary_table() {
    let cases = [
        (utc(2026, 3, 4, 19, 59, 59), 480, 4, date(2026, 3, 4)),
        (utc(2026, 3, 4, 20, 0, 0), 480, 4, date(2026, 3, 5)),
        (utc(2026, 3, 4, 15, 59, 59), 480, 0, date(2026, 3, 4)),
        (utc(2026, 3, 4, 16, 0, 0), 480, 0, date(2026, 3, 5)),
        (utc(2026, 1, 1, 3, 59, 59), 0, 4, date(2025, 12, 31)),
        (utc(2026, 3, 1, 3, 0, 0), 0, 4, date(2026, 2, 28)),
        (utc(2028, 3, 1, 3, 0, 0), 0, 4, date(2028, 2, 29)),
        (utc(2026, 3, 4, 11, 0, 0), -480, 4, date(2026, 3, 3)),
        (utc(2026, 3, 4, 12, 0, 0), -480, 4, date(2026, 3, 4)),
        (utc(2026, 3, 4, 13, 59, 59), 840, 4, date(2026, 3, 4)),
        (utc(2026, 3, 4, 14, 0, 0), 840, 4, date(2026, 3, 5)),
    ];
    for (at, offset, rollover, want) in cases {
        let context = ctx(at, offset, rollover);
        assert_eq!(
            context.logical_date_of(at),
            want,
            "{at} {offset} {rollover}"
        );
        assert_eq!(context.today(), want, "{at} {offset} {rollover}");
    }
}

#[test]
fn end_of_today_is_next_rollover_instant() {
    let context = ctx(utc(2026, 3, 4, 19, 59, 59), 480, 4);
    assert_eq!(context.end_of_today_utc(), utc(2026, 3, 4, 20, 0, 0));
    assert_eq!(
        context.end_of_day_utc(date(2026, 3, 4)),
        utc(2026, 3, 4, 20, 0, 0)
    );
}

#[test]
fn days_partition_time_without_overlap_or_gap() {
    let combos = [
        (480, 4),
        (480, 0),
        (0, 4),
        (-480, 4),
        (840, 4),
        (-720, 12),
        (345, 3),
        (540, 6),
    ];
    let step = Duration::minutes(10);
    let steps_per_probe = 6 * 24 * 40;
    for (offset, rollover) in combos {
        let start = utc(2026, 2, 20, 0, 0, 0);
        for n in 0..steps_per_probe {
            let at = start + step * n;
            let context = ctx(at, offset, rollover);
            let today = context.today();
            let end = context.end_of_today_utc();
            let label = format!("{at} {offset} {rollover}");
            assert!(end > at, "{label}");
            assert!(end - at <= Duration::hours(24), "{label}");
            assert_eq!(
                context.logical_date_of(end - Duration::seconds(1)),
                today,
                "{label}"
            );
            let tomorrow = today.succ_opt().expect("測試範圍內有下一天");
            assert_eq!(context.logical_date_of(end), tomorrow, "{label}");
        }
    }
}

#[test]
fn from_clock_reads_time_and_offset() {
    let clock = FixedClock::new(utc(2026, 3, 4, 20, 0, 0), 480);
    let context = DayContext::from_clock(&clock, DEFAULT_ROLLOVER_HOUR);
    assert_eq!(context.now, utc(2026, 3, 4, 20, 0, 0));
    assert_eq!(context.utc_offset_minutes, 480);
    assert_eq!(context.rollover_hour, 4);
    assert_eq!(context.today(), date(2026, 3, 5));
}

#[test]
fn fixed_clock_advances_forward_and_backward() {
    let clock = FixedClock::new(utc(2026, 3, 4, 0, 0, 0), 0);
    clock.advance(Duration::days(2));
    assert_eq!(clock.now_utc(), utc(2026, 3, 6, 0, 0, 0));
    clock.advance(Duration::days(-10));
    assert_eq!(clock.now_utc(), utc(2026, 2, 24, 0, 0, 0));
}

#[test]
fn clock_is_usable_as_shared_trait_object_across_threads() {
    let clock: Arc<dyn Clock> = Arc::new(FixedClock::new(utc(2026, 3, 4, 0, 0, 0), 60));
    let shared = Arc::clone(&clock);
    let offset = std::thread::spawn(move || shared.utc_offset_minutes())
        .join()
        .expect("執行緒不會 panic");
    assert_eq!(offset, 60);
    assert_eq!(
        DayContext::from_clock(clock.as_ref(), 0).utc_offset_minutes,
        60
    );
}

#[test]
fn system_clock_validates_and_updates_offset() {
    let clock = SystemClock::new(480).expect("480 在範圍內");
    assert_eq!(clock.utc_offset_minutes(), 480);
    assert_eq!(clock.set_utc_offset(-720), Ok(()));
    assert_eq!(clock.utc_offset_minutes(), -720);
    assert_eq!(
        clock.set_utc_offset(841),
        Err(ClockError::OffsetOutOfRange { minutes: 841 })
    );
    assert_eq!(clock.utc_offset_minutes(), -720);
    assert_eq!(
        SystemClock::new(-721).map(|_| ()),
        Err(ClockError::OffsetOutOfRange { minutes: -721 })
    );
    assert!(clock.now_utc() > utc(2020, 1, 1, 0, 0, 0));
}

#[test]
fn offset_and_rollover_ranges_match_spec() {
    assert_eq!(validate_utc_offset(-720), Ok(()));
    assert_eq!(validate_utc_offset(840), Ok(()));
    assert_eq!(
        validate_utc_offset(841),
        Err(ClockError::OffsetOutOfRange { minutes: 841 })
    );
    assert_eq!(validate_rollover_hour(0), Ok(()));
    assert_eq!(validate_rollover_hour(12), Ok(()));
    assert_eq!(
        validate_rollover_hour(13),
        Err(ClockError::RolloverOutOfRange { hour: 13 })
    );
}

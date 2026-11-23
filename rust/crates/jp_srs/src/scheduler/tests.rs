//! §11.1 `srs/scheduler.rs`：§0.3 排程表、F1、F2、F3、Fuzz 確定性與 rs-fsrs 的陷阱。

use chrono::{Duration, TimeZone};
use proptest::prelude::*;
use rs_fsrs::{Seed, State as FsrsState};

use super::*;

const TAIPEI_MINUTES: i32 = 480;
const ROLLOVER: u32 = 4;
const TOLERANCE: f64 = 0.001;
/// rs-fsrs 為維持 Hard < Good < Easy，在上限處各加 1 天，所以最多超過 2 天。
const CAP_OVERSHOOT_DAYS: i64 = 2;

fn ts(text: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(text).unwrap().to_utc()
}

fn ctx_at(now: DateTime<Utc>) -> DayContext {
    DayContext {
        now,
        utc_offset_minutes: TAIPEI_MINUTES,
        rollover_hour: ROLLOVER,
    }
}

fn plain_scheduler() -> FsrsScheduler {
    FsrsScheduler {
        retention_bits: AtomicU64::new(DEFAULT_REQUEST_RETENTION.to_bits()),
        enable_fuzz: false,
    }
}

fn fuzzed_scheduler() -> FsrsScheduler {
    FsrsScheduler::new(DEFAULT_REQUEST_RETENTION).unwrap()
}

fn review_card(last_review: DateTime<Utc>, stability: f64, difficulty: f64) -> CardState {
    CardState {
        state: SrsState::Review,
        due: last_review + Duration::days(4),
        last_review,
        stability,
        difficulty,
        elapsed_days: 0,
        scheduled_days: 4,
        reps: 2,
        lapses: 0,
    }
}

fn assert_close(actual: f64, expected: f64, label: &str) {
    assert!(
        (actual - expected).abs() < TOLERANCE,
        "{label}: {actual} != {expected}"
    );
}

enum Interval {
    Minutes(i64),
    Days(i64),
}

/// §0.3 實測排程，Fuzz 關閉，每次都在到期時作答。
#[test]
fn matches_the_measured_schedule_table() {
    use Interval::{Days, Minutes};
    let table = [
        (Rating::Good, SrsState::Learning, Minutes(10), 3.126, 5.315),
        (Rating::Good, SrsState::Review, Days(4), 4.351, 5.267),
        (Rating::Good, SrsState::Review, Days(15), 14.949, 5.221),
        (Rating::Good, SrsState::Review, Days(48), 47.788, 5.175),
        (
            Rating::Again,
            SrsState::Relearning,
            Minutes(5),
            4.605,
            7.211,
        ),
        (Rating::Good, SrsState::Review, Days(6), 6.409, 7.119),
        (Rating::Good, SrsState::Review, Days(17), 16.528, 7.030),
        (Rating::Hard, SrsState::Review, Days(23), 22.573, 7.982),
        (Rating::Easy, SrsState::Review, Days(95), 95.162, 6.832),
    ];
    let scheduler = plain_scheduler();
    let mut now = ts("2026-03-04T12:00:00Z");
    let mut card = CardState::new_at(now);

    for (step, (rating, state, interval, stability, difficulty)) in table.into_iter().enumerate() {
        let outcome = scheduler.review(&card, rating, &ctx_at(now)).unwrap();

        let label = format!("#{step}");
        assert_eq!(outcome.card.state, state, "{label}");
        let expected_due = match interval {
            Minutes(minutes) => now + Duration::minutes(minutes),
            Days(days) => now + Duration::days(days),
        };
        assert_eq!(outcome.card.due, expected_due, "{label}");
        assert_close(outcome.card.stability, stability, &label);
        assert_close(outcome.card.difficulty, difficulty, &label);
        now = outcome.card.due;
        card = outcome.card;
    }
}

mod logical_day_correction {
    use super::*;

    const LAST_REVIEW: &str = "2026-03-04T13:00:00Z"; // 台北 21:00

    /// F1：21:00 複習、隔天 08:00 再複習，真實經過 11 小時，邏輯上是隔天。
    #[test]
    fn next_morning_counts_as_one_elapsed_day() {
        let card = review_card(ts(LAST_REVIEW), 4.351, 5.267);
        let morning = ts("2026-03-05T00:00:00Z");

        let outcome = plain_scheduler()
            .review(&card, Rating::Good, &ctx_at(morning))
            .unwrap();

        assert_close(outcome.card.stability, 7.197, "stability");
        assert_eq!(outcome.elapsed_days, 1);
        assert_eq!(outcome.card.elapsed_days, 1);
        assert!(!outcome.clock_skewed);
    }

    #[test]
    fn same_logical_day_elapses_zero_days() {
        let card = review_card(ts(LAST_REVIEW), 4.351, 5.267);
        let later = ts("2026-03-04T15:00:00Z"); // 台北 23:00

        let outcome = plain_scheduler()
            .review(&card, Rating::Good, &ctx_at(later))
            .unwrap();

        assert_close(outcome.card.stability, 4.351, "stability");
        assert_eq!(outcome.elapsed_days, 0);
    }

    /// 邏輯日以換日時間為界，03:00 仍算前一天。
    #[test]
    fn crossing_the_rollover_hour_elapses_one_day() {
        let before_rollover = ts("2026-03-04T19:00:00Z"); // 台北 03:00
        let after_rollover = ts("2026-03-04T21:00:00Z"); // 台北 05:00
        let card = review_card(before_rollover, 4.351, 5.267);

        let outcome = plain_scheduler()
            .review(&card, Rating::Good, &ctx_at(after_rollover))
            .unwrap();

        assert_eq!(outcome.elapsed_days, 1);
    }

    #[test]
    fn output_last_review_is_the_real_now_not_the_corrected_one() {
        let card = review_card(ts(LAST_REVIEW), 4.351, 5.267);
        let morning = ts("2026-03-05T00:00:00Z");

        let outcome = plain_scheduler()
            .review(&card, Rating::Good, &ctx_at(morning))
            .unwrap();

        assert_eq!(outcome.card.last_review, morning);
        assert_eq!(outcome.reviewed_at, morning);
    }

    #[test]
    fn prepare_shifts_last_review_by_the_logical_gap() {
        let card = review_card(ts(LAST_REVIEW), 4.351, 5.267);
        let morning = ts("2026-03-05T00:00:00Z");

        let (prepared, now, skewed) = prepare(&card, &ctx_at(morning));

        assert_eq!(now, morning);
        assert_eq!(prepared.last_review, morning - Duration::days(1));
        assert!(!skewed);
    }

    #[test]
    fn prepare_leaves_new_cards_uncorrected() {
        let created = ts("2026-03-01T00:00:00Z");
        let now = ts("2026-03-04T12:00:00Z");

        let (prepared, _, skewed) = prepare(&CardState::new_at(created), &ctx_at(now));

        assert_eq!(prepared.last_review, created);
        assert_eq!(prepared.state, FsrsState::New);
        assert!(!skewed);
    }
}

mod clock_rollback {
    use super::*;

    const LAST_REVIEW: &str = "2026-03-04T12:00:00Z";

    fn assert_healthy(outcome: &Outcome, last_review: DateTime<Utc>) {
        let card = &outcome.card;
        assert!(
            card.stability.is_finite() && card.stability > 0.0,
            "{card:?}"
        );
        assert!(card.difficulty.is_finite(), "{card:?}");
        assert!((1.0..=10.0).contains(&card.difficulty), "{card:?}");
        assert!(outcome.clock_skewed);
        assert_eq!(outcome.reviewed_at, last_review);
        assert_eq!(card.last_review, last_review);
        assert!(card.due >= last_review, "{card:?}");
    }

    /// F2：倒退 10 天 stability 曾為負，倒退 100 天曾為 NaN。
    #[test]
    fn rollback_of_1_10_100_days_never_poisons_the_card() {
        let last_review = ts(LAST_REVIEW);
        let card = review_card(last_review, 4.351, 5.267);

        for days in [1, 10, 100] {
            let earlier = last_review - Duration::days(days);
            for outcome in fuzzed_scheduler().preview(&card, &ctx_at(earlier)).unwrap() {
                assert_healthy(&outcome, last_review);
            }
        }
    }

    #[test]
    fn prepare_clamps_now_and_reports_skew() {
        let last_review = ts(LAST_REVIEW);
        let card = review_card(last_review, 4.351, 5.267);

        let (prepared, now, skewed) = prepare(&card, &ctx_at(last_review - Duration::days(10)));

        assert_eq!(now, last_review);
        assert_eq!(prepared.last_review, last_review);
        assert!(skewed);
    }

    #[test]
    fn exact_same_instant_is_not_skew() {
        let last_review = ts(LAST_REVIEW);
        let card = review_card(last_review, 4.351, 5.267);

        let (_, _, skewed) = prepare(&card, &ctx_at(last_review));

        assert!(!skewed);
    }

    #[test]
    fn a_new_card_created_after_the_clock_reads_is_still_answerable() {
        let created = ts(LAST_REVIEW);
        let card = CardState::new_at(created);

        let outcome = fuzzed_scheduler()
            .review(&card, Rating::Good, &ctx_at(created - Duration::days(3)))
            .unwrap();

        assert!(outcome.clock_skewed);
        assert_eq!(outcome.card.due, created + Duration::minutes(10));
    }

    proptest! {
        #[test]
        fn any_rollback_keeps_output_finite_and_positive(
            days in 0i64..40_000,
            minutes in 0i64..1440,
            rating in 0usize..4,
            stability in 0.1f64..5000.0,
            difficulty in 1.0f64..=10.0,
        ) {
            let last_review = ts(LAST_REVIEW);
            let card = review_card(last_review, stability, difficulty);
            let earlier = last_review - Duration::days(days) - Duration::minutes(minutes);

            let outcome = fuzzed_scheduler()
                .review(&card, Rating::ALL[rating], &ctx_at(earlier))
                .unwrap();

            prop_assert!(outcome.card.stability.is_finite() && outcome.card.stability > 0.0);
            prop_assert!(outcome.card.difficulty.is_finite());
            prop_assert!((1.0..=10.0).contains(&outcome.card.difficulty));
            prop_assert!(outcome.card.due >= last_review);
        }

        #[test]
        fn any_forward_gap_keeps_output_finite_and_positive(
            days in 0i64..4000,
            rating in 0usize..4,
            stability in 0.1f64..5000.0,
            difficulty in 1.0f64..=10.0,
        ) {
            let last_review = ts(LAST_REVIEW);
            let card = review_card(last_review, stability, difficulty);
            let later = last_review + Duration::days(days);

            let outcome = fuzzed_scheduler()
                .review(&card, Rating::ALL[rating], &ctx_at(later))
                .unwrap();

            prop_assert!(outcome.card.stability.is_finite() && outcome.card.stability > 0.0);
            let cap = i64::from(MAXIMUM_INTERVAL_DAYS) + CAP_OVERSHOOT_DAYS;
            prop_assert!(outcome.card.scheduled_days <= cap);
            prop_assert!(!outcome.clock_skewed);
        }
    }
}

mod guards {
    use super::*;

    fn card_with(stability: f64, difficulty: f64) -> Card {
        Card {
            stability,
            difficulty,
            ..Card::default()
        }
    }

    fn is_internal(result: Result<(), SrsError>) -> bool {
        matches!(result, Err(SrsError::Internal { .. }))
    }

    /// F3：SQLite 接受 Infinity，只能在寫入前擋下。
    #[test]
    fn rejects_non_finite_or_out_of_range_values() {
        let bad = [
            (f64::INFINITY, 5.0),
            (f64::NEG_INFINITY, 5.0),
            (f64::NAN, 5.0),
            (0.0, 5.0),
            (-1.0, 5.0),
            (3.0, f64::INFINITY),
            (3.0, f64::NAN),
            (3.0, 0.99),
            (3.0, 10.01),
        ];

        for (stability, difficulty) in bad {
            assert!(
                is_internal(guard(&card_with(stability, difficulty))),
                "{stability} {difficulty}"
            );
        }
    }

    #[test]
    fn accepts_boundary_values() {
        for (stability, difficulty) in [(0.0001, 1.0), (36500.0, 10.0), (3.0, 5.0)] {
            assert!(guard(&card_with(stability, difficulty)).is_ok());
        }
    }

    #[test]
    fn infinite_stability_on_the_input_card_is_rejected_by_review() {
        let now = ts("2026-03-04T12:00:00Z");
        let card = review_card(now - Duration::days(1), f64::INFINITY, 5.0);

        let result = plain_scheduler().review(&card, Rating::Good, &ctx_at(now));

        assert!(matches!(result, Err(SrsError::Internal { .. })));
    }
}

mod fuzz {
    use super::*;

    const NOW: &str = "2026-03-20T12:00:00Z";

    fn due_card() -> CardState {
        review_card(ts("2026-03-04T12:00:00Z"), 14.949, 5.221)
    }

    /// 種子由 now、reps、D×S 推導，同輸入同輸出，可搭配 FixedClock 測試。
    #[test]
    fn same_input_gives_same_result_across_instances() {
        let ctx = ctx_at(ts(NOW));

        let first = fuzzed_scheduler()
            .review(&due_card(), Rating::Good, &ctx)
            .unwrap();
        let second = fuzzed_scheduler()
            .review(&due_card(), Rating::Good, &ctx)
            .unwrap();

        assert_eq!(first, second);
    }

    #[test]
    fn fuzz_actually_varies_with_the_answer_time() {
        let scheduler = fuzzed_scheduler();
        let start = ts(NOW);

        let intervals: std::collections::HashSet<i64> = (0..40)
            .map(|second| {
                let ctx = ctx_at(start + Duration::seconds(second));
                scheduler
                    .review(&due_card(), Rating::Good, &ctx)
                    .unwrap()
                    .card
                    .scheduled_days
            })
            .collect();

        assert!(intervals.len() > 1, "{intervals:?}");
    }

    /// `Seed::Empty`、`Seed::Default` 的 `inner_str` 會無窮遞迴（§0.3）。
    #[test]
    fn parameters_carry_a_string_seed() {
        assert!(matches!(
            fuzzed_scheduler().parameters().seed,
            Seed::String(_)
        ));
    }
}

mod parameters {
    use super::*;

    #[test]
    fn matches_the_documented_configuration() {
        let parameters = fuzzed_scheduler().parameters();

        assert_eq!(parameters.request_retention, DEFAULT_REQUEST_RETENTION);
        assert_eq!(parameters.maximum_interval, MAXIMUM_INTERVAL_DAYS);
        assert!(parameters.enable_short_term);
        assert!(parameters.enable_fuzz);
    }

    #[test]
    fn retention_outside_the_range_is_invalid_input() {
        for retention in [0.79, 0.96, 0.0, 1.0, f64::NAN, f64::INFINITY] {
            let result = FsrsScheduler::new(retention);

            assert!(
                matches!(result, Err(SrsError::InvalidInput { ref field, .. }) if field == "desired_retention"),
                "{retention}"
            );
        }
    }

    #[test]
    fn range_boundaries_are_accepted() {
        assert!(FsrsScheduler::new(MIN_REQUEST_RETENTION).is_ok());
        assert!(FsrsScheduler::new(MAX_REQUEST_RETENTION).is_ok());
    }

    #[test]
    fn higher_retention_schedules_sooner() {
        let now = ts("2026-03-20T12:00:00Z");
        let card = review_card(ts("2026-03-04T12:00:00Z"), 14.949, 5.221);
        let scheduler = plain_scheduler();

        let relaxed = {
            scheduler.set_request_retention(0.80).unwrap();
            scheduler.review(&card, Rating::Good, &ctx_at(now)).unwrap()
        };
        let strict = {
            scheduler.set_request_retention(0.95).unwrap();
            scheduler.review(&card, Rating::Good, &ctx_at(now)).unwrap()
        };

        assert!(strict.card.scheduled_days < relaxed.card.scheduled_days);
        assert_eq!(scheduler.request_retention(), 0.95);
    }

    #[test]
    fn set_retention_rejects_bad_values_and_keeps_the_old_one() {
        let scheduler = plain_scheduler();

        let result = scheduler.set_request_retention(0.5);

        assert!(matches!(result, Err(SrsError::InvalidInput { .. })));
        assert_eq!(scheduler.request_retention(), DEFAULT_REQUEST_RETENTION);
    }

    #[test]
    fn intervals_are_capped_at_ten_years() {
        let now = ts("2036-03-04T12:00:00Z");
        let card = review_card(ts("2026-03-04T12:00:00Z"), 30_000.0, 2.0);
        let scheduler = plain_scheduler();
        let days = |rating| {
            scheduler
                .review(&card, rating, &ctx_at(now))
                .unwrap()
                .card
                .scheduled_days
        };
        let cap = i64::from(MAXIMUM_INTERVAL_DAYS);

        assert_eq!(days(Rating::Hard), cap);
        assert_eq!(days(Rating::Good), cap + 1);
        assert_eq!(days(Rating::Easy), cap + CAP_OVERSHOOT_DAYS);
    }
}

mod states {
    use super::*;

    /// `Card::new()` 內部呼叫 `Utc::now()`，建立新卡必須只看注入的時間（§0.3）。
    #[test]
    fn new_card_uses_only_the_injected_time() {
        let now = Utc.with_ymd_and_hms(2001, 2, 3, 4, 5, 6).unwrap();

        let card = CardState::new_at(now);

        assert_eq!(card.state, SrsState::New);
        assert_eq!(card.due, now);
        assert_eq!(card.last_review, now);
        assert_eq!(card.stability, 0.0);
        assert_eq!(card.difficulty, 0.0);
        assert_eq!((card.reps, card.lapses), (0, 0));
        assert_eq!((card.elapsed_days, card.scheduled_days), (0, 0));
    }

    #[test]
    fn state_values_match_the_schema() {
        for state in [
            SrsState::New,
            SrsState::Learning,
            SrsState::Review,
            SrsState::Relearning,
        ] {
            assert_eq!(SrsState::from_u8(state.as_u8()), Some(state));
        }
        assert_eq!(SrsState::New.as_u8(), 0);
        assert_eq!(SrsState::Relearning.as_u8(), 3);
        assert_eq!(SrsState::from_u8(4), None);
    }

    #[test]
    fn an_impossible_state_value_on_a_row_is_internal() {
        let now = ts("2026-03-04T12:00:00Z");
        let row = CardRow {
            card_id: "vo.a:recog".to_string(),
            content_id: "vo.a".to_string(),
            facet: "recog".to_string(),
            priority: 0,
            state: 9,
            due_at: now,
            last_review_at: now,
            stability: 0.0,
            difficulty: 0.0,
            elapsed_days: 0,
            scheduled_days: 0,
            reps: 0,
            lapses: 0,
            last_logical_date: None,
            suspended: false,
            introduced_seq: 1,
            created_at: now,
        };

        assert!(matches!(
            CardState::from_row(&row),
            Err(SrsError::Internal { .. })
        ));
    }

    #[test]
    fn rating_values_match_the_schema() {
        assert_eq!(Rating::ALL.map(Rating::as_u8), [1, 2, 3, 4]);
    }

    #[test]
    fn preview_returns_all_four_ratings_in_order_matching_review() {
        let now = ts("2026-03-04T12:00:00Z");
        let card = CardState::new_at(now);
        let ctx = ctx_at(now);
        let scheduler = fuzzed_scheduler();

        let previews = scheduler.preview(&card, &ctx).unwrap();

        assert_eq!(previews.each_ref().map(|o| o.rating), Rating::ALL);
        for outcome in &previews {
            assert_eq!(
                *outcome,
                scheduler.review(&card, outcome.rating, &ctx).unwrap()
            );
        }
        assert_eq!(previews[0].interval_minutes(), 1);
        assert_eq!(previews[1].interval_minutes(), 5);
        assert_eq!(previews[2].interval_minutes(), 10);
        assert!(previews[3].interval_minutes() >= 24 * 60);
    }

    #[test]
    fn outcome_records_the_state_and_interval_before_the_review() {
        let now = ts("2026-03-20T12:00:00Z");
        let card = review_card(ts("2026-03-04T12:00:00Z"), 14.949, 5.221);

        let outcome = plain_scheduler()
            .review(&card, Rating::Again, &ctx_at(now))
            .unwrap();

        assert_eq!(outcome.state_before, SrsState::Review);
        assert_eq!(outcome.scheduled_days_before, 4);
        assert_eq!(outcome.card.state, SrsState::Relearning);
        assert_eq!(outcome.card.lapses, 1);
        assert_eq!(outcome.card.reps, 3);
    }
}

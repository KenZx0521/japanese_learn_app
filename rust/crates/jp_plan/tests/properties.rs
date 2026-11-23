//! 計畫引擎的性質測試。

mod common;

use std::collections::{BTreeSet, HashMap, HashSet};

use chrono::{Duration, NaiveDate};
use common::*;
use jp_content::schema::KanaKind;
use jp_content::ContentStore;
use jp_plan::budget::{review_cap, stage_split, NewContentMode};
use jp_plan::calendar::is_study_day;
use jp_plan::completion::{apply_effects, integration_completes, slice_effects};
use jp_plan::forecast::{forecast, ForecastRequest};
use jp_plan::input::PlanInput;
use jp_plan::slice::{next_slice, Slice, SliceQuota};
use jp_plan::state::{cursor, CursorState};
use jp_plan::streak::{best_streak, current_streak};
use proptest::prelude::*;

/// 走到課程結束，回傳每個切片。假名與單字都應只介紹一次。
fn run_course(quota: SliceQuota, store: &ContentStore) -> Vec<Slice> {
    let mut state = CursorState::default();
    let mut slices = Vec::new();
    for _ in 0..2000 {
        let Some(slice) = next_slice(&state, &quota, store) else {
            break;
        };
        match &slice {
            Slice::Integration {
                lesson_id,
                dialogue_id,
                ..
            } => {
                let after = state.integration_days.get(lesson_id).copied().unwrap_or(0) + 1;
                state.integration_days.insert(lesson_id.clone(), after);
                if let Some(dialogue) = dialogue_id {
                    state
                        .integration_dialogues
                        .insert(lesson_id.clone(), dialogue.clone());
                }
                if integration_completes(
                    lesson_id,
                    after,
                    quota.integration_days_needed,
                    &state,
                    store,
                ) {
                    state.completed.insert(lesson_id.clone(), d(MONDAY));
                }
            }
            other => {
                let effects = slice_effects(other, &state, store);
                apply_effects(&mut state, &effects, d(MONDAY));
            }
        }
        slices.push(slice);
    }
    assert_eq!(cursor(&state, store), None, "切片必須走完全部課程");
    slices
}

fn introduced_counts(slices: &[Slice]) -> HashMap<String, usize> {
    let mut counts = HashMap::new();
    for slice in slices {
        let items: Vec<&String> = match slice {
            Slice::Kana { kana, rules, .. } => kana.iter().chain(rules).collect(),
            Slice::KanaRule {
                rules, confusables, ..
            } => rules.iter().chain(confusables).collect(),
            Slice::Vocab { words, grammar, .. } => words.iter().chain(grammar).collect(),
            Slice::Integration { .. } => Vec::new(),
        };
        for item in items {
            *counts.entry(item.clone()).or_insert(0) += 1;
        }
    }
    counts
}

fn all_slices_nonempty(slices: &[Slice]) -> bool {
    slices.iter().all(|slice| match slice {
        Slice::Kana { kana, .. } => !kana.is_empty(),
        Slice::Vocab { words, grammar, .. } => !words.is_empty() || !grammar.is_empty(),
        Slice::KanaRule { .. } | Slice::Integration { .. } => true,
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(32))]

    #[test]
    fn every_quota_walks_the_whole_course_introducing_each_item_once(
        words in 1u32..15,
        kana in 1u32..15,
        days in 1u32..3,
    ) {
        let store = content();
        let quota = SliceQuota { mode: NewContentMode::Full, words, kana, integration_days_needed: days };

        let slices = run_course(quota, &store);
        let counts = introduced_counts(&slices);

        prop_assert!(all_slices_nonempty(&slices));
        prop_assert!(counts.values().all(|count| *count == 1), "{counts:?}");
        for entry in store.kana().iter().filter(|k| k.def.kind != KanaKind::Mark && !k.def.retired) {
            prop_assert_eq!(counts.get(&entry.def.id).copied(), Some(1), "{}", entry.def.id);
        }
    }

    #[test]
    fn minimal_slices_also_finish_the_course(days in 1u32..3) {
        let store = content();
        let quota = SliceQuota { mode: NewContentMode::Minimal, words: 5, kana: 5, integration_days_needed: days };

        let slices = run_course(quota, &store);

        prop_assert!(introduced_counts(&slices).values().all(|count| *count == 1));
    }

    #[test]
    fn starting_later_shifts_daily_forecast_exactly(offset in 0i64..60, minutes in prop::sample::select(vec![10u32, 20, 30, 45])) {
        let store = content();
        let plan = input(minutes);
        let start = d(MONDAY);
        let later = start + Duration::days(offset);
        let run = |today: NaiveDate| {
            let request = ForecastRequest { today, today_slice_done: false, plan: &plan };
            forecast(&CursorState::default(), &request, &store).unwrap()
        };

        let (a, b) = (run(start), run(later));

        for ((_, x), (_, y)) in a.milestones.iter().zip(&b.milestones) {
            prop_assert_eq!(*y - *x, Duration::days(offset));
        }
        prop_assert_eq!(b.main_end.unwrap() - a.main_end.unwrap(), Duration::days(offset));
    }

    #[test]
    fn forecast_lands_only_on_study_days(mask in 1u8..128) {
        let store = content();
        let plan = PlanInput { weekday_mask: mask, ..input(20) };
        let request = ForecastRequest { today: d(MONDAY), today_slice_done: false, plan: &plan };

        let got = forecast(&CursorState::default(), &request, &store).unwrap();

        prop_assert!(got.milestones.iter().all(|(_, date)| is_study_day(mask, *date)));
        prop_assert!(got.schedule.iter().all(|day| is_study_day(mask, day.date)));
    }

    #[test]
    fn review_cap_never_exceeds_affordable_cards(minutes in 0u32..30, use_count in 0usize..100, auto_count in 0usize..100) {
        let mut facets = due_facets(use_count, "use");
        facets.extend(due_facets(auto_count, "recog"));

        let cap = review_cap(f64::from(minutes), &facets);

        prop_assert!(cap >= 1);
        prop_assert!(cap <= (minutes * 60 / 8).max(1));
    }

    #[test]
    fn split_is_consistent_for_every_stage(stage in prop::sample::select(vec!["st.s0", "st.s1", "st.s2", "st.s3"]), minutes in prop::sample::select(vec![10u32, 20, 30, 45])) {
        let store = content();

        let s = stage_split(&preset(&store, minutes), Some(stage));

        prop_assert_eq!(s.new + s.review + s.drill + s.listen, f64::from(minutes));
        prop_assert!(s.review > 0.0);
    }

    #[test]
    fn streak_never_exceeds_active_days(days in prop::collection::btree_set(0i64..30, 0..15), mask in 1u8..128, today_offset in 0i64..30) {
        let base = d(MONDAY);
        let active: BTreeSet<NaiveDate> = days.iter().map(|o| base + Duration::days(*o)).collect();
        let today = base + Duration::days(today_offset);

        let streak = current_streak(&active, today, |date| is_study_day(mask, date));
        let best = best_streak(&active, |date| is_study_day(mask, date));

        prop_assert!(streak <= active.len() as u32);
        prop_assert!(best <= active.len() as u32);
        if active.is_empty() {
            prop_assert_eq!(streak, 0);
        }
    }
}

#[test]
fn hiragana_introduces_every_non_mark_char_exactly_once_in_file_order() {
    let store = content();
    let quota = SliceQuota {
        mode: NewContentMode::Full,
        words: 5,
        kana: 5,
        integration_days_needed: 1,
    };
    let expected: Vec<&str> = store
        .kana()
        .iter()
        .filter(|k| k.def.kind != KanaKind::Mark && k.def.id.starts_with("ka.hira."))
        .map(|k| k.def.id.as_str())
        .collect();

    let order: Vec<String> = run_course(quota, &store)
        .into_iter()
        .flat_map(|slice| match slice {
            Slice::Kana { kana, .. } => kana,
            _ => Vec::new(),
        })
        .filter(|id| id.starts_with("ka.hira."))
        .collect();

    assert_eq!(order, expected);
}

#[test]
fn hiragana_fixture_set_has_no_duplicates() {
    let store = content();
    let quota = SliceQuota {
        mode: NewContentMode::Full,
        words: 5,
        kana: 5,
        integration_days_needed: 1,
    };

    let ids: Vec<String> = run_course(quota, &store)
        .into_iter()
        .flat_map(|slice| match slice {
            Slice::Kana { kana, .. } => kana,
            _ => Vec::new(),
        })
        .collect();

    assert_eq!(ids.len(), ids.iter().collect::<HashSet<_>>().len());
}

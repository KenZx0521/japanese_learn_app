//! §7.3 課的完成條件（`complete_task` 與 `forecast` 共用的純函式）。

mod common;

use chrono::NaiveDate;
use common::*;
use jp_plan::completion::{apply_effects, integration_completes, slice_effects, IntroItem};
use jp_plan::slice::Slice;
use jp_plan::state::CursorState;

fn on() -> NaiveDate {
    d("2026-03-05")
}

fn intros(items: &[IntroItem]) -> Vec<&str> {
    items.iter().map(|item| item.item_id.as_str()).collect()
}

#[test]
fn partial_kana_slice_does_not_complete_the_lesson() {
    let store = content();
    let slice = Slice::Kana {
        lesson_ids: ids(&["le.k01"]),
        kana: ids(&["ka.hira.a", "ka.hira.i", "ka.hira.u"]),
        rules: vec![],
    };

    let effects = slice_effects(&slice, &CursorState::default(), &store);

    assert_eq!(
        intros(&effects.intros),
        vec!["ka.hira.a", "ka.hira.i", "ka.hira.u"]
    );
    assert!(effects.completed_lessons.is_empty());
}

#[test]
fn last_kana_slice_completes_lesson_and_adds_marks() {
    let store = content();
    let mut state = state_at("le.k14", &store);
    intro(
        &mut state,
        &[
            "ka.hira.kya",
            "ka.hira.kyu",
            "ka.hira.kyo",
            "ka.hira.sha",
            "ka.hira.shu",
            "ka.hira.sho",
        ],
    );
    let slice = Slice::Kana {
        lesson_ids: ids(&["le.k14"]),
        kana: ids(&["ka.hira.cha", "ka.hira.chu", "ka.hira.cho"]),
        rules: vec![],
    };

    let effects = slice_effects(&slice, &state, &store);

    assert_eq!(effects.completed_lessons, ids(&["le.k14"]));
    let written = intros(&effects.intros);
    for mark in ["ka.hira.small_ya", "ka.hira.small_yu", "ka.hira.small_yo"] {
        assert!(written.contains(&mark), "{mark}");
    }
    assert_eq!(
        effects
            .intros
            .iter()
            .filter(|i| i.lesson_id == "le.k14")
            .count(),
        6
    );
}

#[test]
fn kana_slice_across_two_lessons_completes_the_first_only_when_done() {
    let store = content();
    let mut state = CursorState::default();
    intro(&mut state, &["ka.hira.a", "ka.hira.i", "ka.hira.u"]);
    let slice = Slice::Kana {
        lesson_ids: ids(&["le.k01", "le.k02"]),
        kana: ids(&[
            "ka.hira.e",
            "ka.hira.o",
            "ka.hira.ka",
            "ka.hira.ki",
            "ka.hira.ku",
        ]),
        rules: vec![],
    };

    let effects = slice_effects(&slice, &state, &store);

    assert_eq!(effects.completed_lessons, ids(&["le.k01"]));
}

#[test]
fn kana_lesson_with_rule_card_needs_the_rule_introduced() {
    let store = content();
    let mut state = state_at("le.kk07", &store);
    let slice = Slice::Kana {
        lesson_ids: ids(&["le.kk07"]),
        kana: ids(&["ka.kata.kya", "ka.kata.kyu", "ka.kata.kyo"]),
        rules: ids(&[]),
    };

    assert!(slice_effects(&slice, &state, &store)
        .completed_lessons
        .is_empty());

    intro(&mut state, &["ka.rule.chouon_kata"]);
    assert_eq!(
        slice_effects(&slice, &state, &store).completed_lessons,
        ids(&["le.kk07"])
    );
}

#[test]
fn rule_slice_completes_lesson_and_writes_mark_and_confusable_intros() {
    let store = content();
    let slice = Slice::KanaRule {
        lesson_id: "le.k16".to_owned(),
        rules: ids(&["ka.rule.sokuon"]),
        confusables: vec![],
    };

    let effects = slice_effects(&slice, &state_at("le.k16", &store), &store);

    assert_eq!(effects.completed_lessons, ids(&["le.k16"]));
    assert_eq!(
        intros(&effects.intros),
        vec!["ka.rule.sokuon", "ka.hira.sokuon"]
    );
}

#[test]
fn k10_rule_slice_writes_confusable_intro() {
    let store = content();
    let slice = Slice::KanaRule {
        lesson_id: "le.k10".to_owned(),
        rules: vec![],
        confusables: ids(&["ka.cf.nu_me"]),
    };

    let effects = slice_effects(&slice, &state_at("le.k10", &store), &store);

    assert_eq!(effects.completed_lessons, ids(&["le.k10"]));
    assert_eq!(intros(&effects.intros), vec!["ka.cf.nu_me"]);
}

#[test]
fn kana_completion_writes_all_lesson_confusables() {
    let store = content();
    let slice = Slice::Kana {
        lesson_ids: ids(&["le.kk01"]),
        kana: ids(&[
            "ka.kata.a",
            "ka.kata.i",
            "ka.kata.u",
            "ka.kata.e",
            "ka.kata.o",
            "ka.kata.ka",
            "ka.kata.ki",
            "ka.kata.ku",
            "ka.kata.ke",
            "ka.kata.ko",
        ]),
        rules: vec![],
    };

    let effects = slice_effects(&slice, &state_at("le.kk01", &store), &store);

    let written = intros(&effects.intros);
    assert!(written.contains(&"ka.cf.ka_kata"));
    assert!(written.contains(&"ka.cf.ka_chikara"));
}

#[test]
fn vocab_slice_only_introduces() {
    let store = content();
    let slice = Slice::Vocab {
        lesson_id: "le.l02".to_owned(),
        words: ids(&["vo.taberu", "vo.nomu"]),
        grammar: ids(&["gr.wo_obj", "gr.masu"]),
    };

    let effects = slice_effects(&slice, &state_at("le.l02", &store), &store);

    assert_eq!(effects.intros.len(), 4);
    assert!(effects.intros.iter().all(|i| i.lesson_id == "le.l02"));
    assert!(effects.completed_lessons.is_empty());
}

#[test]
fn integration_slice_has_no_effects() {
    let store = content();
    let slice = Slice::Integration {
        lesson_id: "le.l01".to_owned(),
        dialogue_id: None,
        phases: vec![1, 2, 3, 4],
        day_no: 1,
    };

    let effects = slice_effects(&slice, &state_at("le.l01", &store), &store);

    assert!(effects.intros.is_empty());
    assert!(effects.completed_lessons.is_empty());
}

#[test]
fn integration_completes_requires_items_and_days() {
    let store = content();
    let mut state = state_at("le.l02", &store);

    assert!(!integration_completes("le.l02", 1, 1, &state, &store));

    state.introduced.extend(lesson_item_ids("le.l02", &store));
    assert!(integration_completes("le.l02", 1, 1, &state, &store));
    assert!(!integration_completes("le.l02", 1, 2, &state, &store));
    assert!(integration_completes("le.l02", 2, 2, &state, &store));
}

#[test]
fn apply_effects_updates_state() {
    let store = content();
    let mut state = CursorState::default();
    let slice = Slice::KanaRule {
        lesson_id: "le.k10".to_owned(),
        rules: vec![],
        confusables: ids(&["ka.cf.nu_me"]),
    };

    let effects = slice_effects(&slice, &state, &store);
    apply_effects(&mut state, &effects, on());

    assert!(state.introduced.contains("ka.cf.nu_me"));
    assert_eq!(state.completed.get("le.k10"), Some(&on()));
}

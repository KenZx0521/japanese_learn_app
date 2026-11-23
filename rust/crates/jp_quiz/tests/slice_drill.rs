//! §9.4 K11–K15 切片後接的 `minimal_pair`、`kana_word`（夾具）。真實內容見
//! `rust/tests/kana_slice_drills_real_content.rs`。

mod common;

use std::collections::HashSet;

use common::*;
use jp_content::ContentStore;
use jp_quiz::slice_drill::{slice_drill_quiz, slice_drills};
use jp_quiz::QuestionType;

const K11_KANA: [&str; 10] = [
    "ka.hira.ga",
    "ka.hira.gi",
    "ka.hira.gu",
    "ka.hira.ge",
    "ka.hira.go",
    "ka.hira.za",
    "ka.hira.ji",
    "ka.hira.zu",
    "ka.hira.ze",
    "ka.hira.zo",
];

/// 夾具的 K11 只有一題 `minimal_pair`，測選題要多幾題。`(序號, 清音, 濁音)`。
fn with_k11_pairs(extra: &[(u32, &str, &str)]) -> ContentStore {
    let lines: String = extra
        .iter()
        .map(|(number, plain, voiced)| {
            format!(
                r#"{{"id": "dr.k11.mpr.{number:03}", "type": "minimal_pair", "lesson": "le.k11", "targets": ["ka.hira.{plain}", "ka.hira.{voiced}"], "a": "か", "a_zh": "清音", "b": "が", "b_zh": "濁音"}},
    "#
            )
        })
        .collect();
    let replacement = format!(r#"{lines}{{"id": "dr.k16.mpr.001""#);
    content_with(&[(r#"{"id": "dr.k16.mpr.001""#, &replacement)])
}

fn slice_of(kana: &[&str]) -> Vec<String> {
    kana.iter().map(|id| (*id).to_owned()).collect()
}

/// 清音都會了，K11 還沒開始。
fn known_before_k11(store: &ContentStore) -> HashSet<String> {
    all_known(store)
        .into_iter()
        .filter(|id| !K11_KANA.contains(&id.as_str()))
        .collect()
}

fn picked_ids(store: &ContentStore, known: &HashSet<String>, slice: &[&str]) -> Vec<String> {
    slice_drills(&ctx(store, known), "le.k11", &slice_of(slice))
        .into_iter()
        .map(|drill| drill.id().to_owned())
        .collect()
}

fn pair_ids(ids: &[String]) -> Vec<&str> {
    ids.iter()
        .map(String::as_str)
        .filter(|id| id.contains(".mpr."))
        .collect()
}

#[test]
fn lessons_outside_k11_to_k15_get_nothing() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    for lesson in ["le.k05", "le.k10", "le.k16", "le.k17", "le.l01"] {
        assert!(
            slice_drills(&context, lesson, &slice_of(&["ka.hira.ga"])).is_empty(),
            "{lesson}"
        );
    }
}

#[test]
fn pair_waits_until_both_targets_are_taught() {
    let store = content();
    let known = known_before_k11(&store);
    let without_ka: HashSet<String> = known
        .iter()
        .filter(|id| id.as_str() != "ka.hira.ka")
        .cloned()
        .collect();

    assert_eq!(
        pair_ids(&picked_ids(&store, &known, &["ka.hira.ga"])),
        ["dr.k11.mpr.001"]
    );
    assert!(pair_ids(&picked_ids(&store, &without_ka, &["ka.hira.ga"])).is_empty());
    assert!(
        pair_ids(&picked_ids(&store, &known, &["ka.hira.gu"])).is_empty(),
        "が 不在本切片也還沒教"
    );
}

#[test]
fn takes_at_most_three_pairs_owned_by_the_slice() {
    let store = with_k11_pairs(&[
        (10, "ki", "gi"),
        (11, "ku", "gu"),
        (12, "ke", "ge"),
        (13, "ko", "go"),
    ]);
    let known = known_before_k11(&store);

    let picked = picked_ids(&store, &known, &K11_KANA[..5]);

    assert_eq!(pair_ids(&picked).len(), 3, "{picked:?}");
}

#[test]
fn each_char_first_gets_the_pair_that_tests_it() {
    let store = with_k11_pairs(&[(10, "ki", "gi"), (11, "ki", "gi"), (12, "ku", "gu")]);
    let known = known_before_k11(&store);

    let picked = picked_ids(
        &store,
        &known,
        &["ka.hira.ga", "ka.hira.gi", "ka.hira.gu", "ka.hira.ge"],
    );

    assert_eq!(
        pair_ids(&picked),
        ["dr.k11.mpr.001", "dr.k11.mpr.010", "dr.k11.mpr.012"],
        "か／が、き／ぎ、く／ぐ 各一題，第二題 き／ぎ 排到沒有自己題目的字"
    );
}

#[test]
fn a_later_slice_prefers_the_pairs_its_own_kana_owns() {
    let store = with_k11_pairs(&[(10, "ki", "gi"), (11, "sa", "za"), (12, "shi", "ji")]);
    let mut known = known_before_k11(&store);
    known.extend(["ka.hira.ga".to_owned(), "ka.hira.gi".to_owned()]);

    let picked = picked_ids(&store, &known, &["ka.hira.za", "ka.hira.ji"]);

    assert_eq!(pair_ids(&picked), ["dr.k11.mpr.011", "dr.k11.mpr.012"]);
}

#[test]
fn a_slice_short_of_pairs_fills_to_two_with_never_assigned_pairs_first() {
    // 第二題 き／ぎ 排不到字，比已經派給字（考過）的題優先
    let store = with_k11_pairs(&[(10, "ki", "gi"), (11, "ki", "gi"), (13, "sa", "za")]);
    let mut known = known_before_k11(&store);
    known.extend(["ka.hira.ga".to_owned(), "ka.hira.gi".to_owned()]);

    let picked = picked_ids(&store, &known, &["ka.hira.za"]);

    assert_eq!(pair_ids(&picked), ["dr.k11.mpr.013", "dr.k11.mpr.011"]);
}

#[test]
fn a_slice_short_of_pairs_reuses_an_assigned_pair_when_nothing_else_is_left() {
    let store = with_k11_pairs(&[(10, "ki", "gi"), (11, "sa", "za")]);
    let mut known = known_before_k11(&store);
    known.extend(["ka.hira.ga".to_owned(), "ka.hira.gi".to_owned()]);

    let picked = picked_ids(&store, &known, &["ka.hira.za"]);
    let pairs = pair_ids(&picked);

    assert_eq!(pairs.len(), 2, "{pairs:?}");
    assert_eq!(pairs[0], "dr.k11.mpr.011");
    assert!(["dr.k11.mpr.001", "dr.k11.mpr.010"].contains(&pairs[1]));
}

#[test]
fn assignments_do_not_depend_on_how_the_lesson_is_sliced() {
    let store = with_k11_pairs(&[
        (10, "ki", "gi"),
        (11, "ku", "gu"),
        (12, "ke", "ge"),
        (13, "ko", "go"),
    ]);
    let known = known_before_k11(&store);
    let mut after_two = known.clone();
    after_two.extend(K11_KANA[..2].iter().map(|id| (*id).to_owned()));

    let early = picked_ids(&store, &known, &K11_KANA[..2]);
    let late = picked_ids(&store, &after_two, &K11_KANA[2..4]);

    let early = pair_ids(&early);
    let late = pair_ids(&late);
    assert!(
        early.iter().all(|id| !late.contains(id)),
        "{early:?} {late:?}"
    );
}

#[test]
fn a_slice_with_nothing_taught_yet_gets_no_pairs() {
    let store = content();
    let known = HashSet::new();

    assert!(pair_ids(&picked_ids(&store, &known, &["ka.hira.gu"])).is_empty());
}

#[test]
fn kana_word_comes_after_pairs_only_on_the_last_slice_of_the_lesson() {
    let store = content();
    let mut known = known_before_k11(&store);

    assert!(
        !picked_ids(&store, &known, &K11_KANA[..3]).contains(&"dr.k11.kwd.002".to_owned()),
        "還有字沒教"
    );

    known.extend(K11_KANA[..9].iter().map(|id| (*id).to_owned()));
    let picked = picked_ids(&store, &known, &K11_KANA[9..]);

    assert_eq!(picked.last().map(String::as_str), Some("dr.k11.kwd.002"));
}

#[test]
fn silent_mode_drops_pairs_but_keeps_a_typing_kana_word() {
    let store = content();
    let mut known = known_before_k11(&store);
    known.extend(K11_KANA[..9].iter().map(|id| (*id).to_owned()));
    let audio = ctx(&store, &known);
    let context = silent(&audio);

    let questions = slice_drill_quiz(&context, "le.k11", &slice_of(&K11_KANA[9..])).unwrap();

    assert_eq!(questions.len(), 1, "{questions:?}");
    assert_eq!(questions[0].question_type, QuestionType::KanaWord);
    assert_eq!(
        questions[0].reference.drill_id.as_deref(),
        Some("dr.k11.kwd.002")
    );
}

#[test]
fn listen_disabled_and_retired_pairs_are_never_picked() {
    let disabled = content_with(&[(
        r#""id": "dr.k11.mpr.001", "type": "minimal_pair""#,
        r#""id": "dr.k11.mpr.001", "listen_disabled": true, "type": "minimal_pair""#,
    )]);
    let retired = content_with(&[(
        r#""id": "dr.k11.mpr.001", "type": "minimal_pair""#,
        r#""id": "dr.k11.mpr.001", "retired": true, "type": "minimal_pair""#,
    )]);

    for store in [&disabled, &retired] {
        let known = known_before_k11(store);
        assert!(pair_ids(&picked_ids(store, &known, &["ka.hira.ga"])).is_empty());
    }
}

#[test]
fn the_picked_set_does_not_depend_on_the_session_seed() {
    let store = with_k11_pairs(&[
        (10, "ki", "gi"),
        (11, "ku", "gu"),
        (12, "ke", "ge"),
        (13, "ko", "go"),
    ]);
    let known = known_before_k11(&store);
    let context = ctx(&store, &known);
    let slice = slice_of(&K11_KANA[..5]);

    let picked = |seed| -> Vec<String> {
        slice_drills(&with_seed(&context, seed), "le.k11", &slice)
            .into_iter()
            .map(|drill| drill.id().to_owned())
            .collect()
    };

    assert_eq!(picked(1), picked(99));
}

#[test]
fn quiz_questions_carry_the_drill_reference_and_only_pairs_or_kana_word() {
    let store = content();
    let mut known = known_before_k11(&store);
    known.extend(K11_KANA[..4].iter().map(|id| (*id).to_owned()));
    known.remove("ka.hira.ga");
    let context = ctx(&store, &known);

    let questions = slice_drill_quiz(&context, "le.k11", &slice_of(&["ka.hira.ga"])).unwrap();

    assert_eq!(questions.len(), 1);
    assert_eq!(questions[0].question_type, QuestionType::MinimalPair);
    assert_eq!(
        questions[0].reference.drill_id.as_deref(),
        Some("dr.k11.mpr.001")
    );
}

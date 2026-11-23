//! `drill_session` 的選題規則（§7.4、§8.4）。

mod common;

use common::*;
use jp_content::ContentStore;
use jp_quiz::drill::{drill_session, quizzable_drill_ids, DrillSelection};
use jp_quiz::{Question, QuestionType};

const NONE: &[String] = &[];

fn strings(ids: &[&str]) -> Vec<String> {
    ids.iter().map(|id| (*id).to_string()).collect()
}

fn session(store: &ContentStore, selection: &DrillSelection<'_>) -> Vec<Question> {
    let known = all_known(store);
    drill_session(&ctx(store, &known), selection).unwrap()
}

fn ids(questions: &[Question]) -> Vec<String> {
    questions
        .iter()
        .map(|q| q.reference.drill_id.clone().unwrap())
        .collect()
}

fn selection<'a>(lessons: &'a [String], count: u32) -> DrillSelection<'a> {
    DrillSelection {
        lesson_ids: lessons,
        target: None,
        drill_ids: NONE,
        count,
    }
}

#[test]
fn takes_drills_of_lessons_up_to_count_deterministically() {
    let store = content();
    let lessons = strings(&["le.l01", "le.l02"]);

    let first = session(&store, &selection(&lessons, 5));

    assert_eq!(first.len(), 5);
    assert_eq!(first, session(&store, &selection(&lessons, 5)));
    let all = session(&store, &selection(&lessons, 0));
    assert_eq!(all.len(), 13);
}

#[test]
fn rotates_question_types() {
    let store = content();
    let lessons = strings(&["le.l01", "le.l02"]);

    let picked = session(&store, &selection(&lessons, 7));

    let mut kinds: Vec<_> = picked.iter().map(|q| q.question_type).collect();
    kinds.sort_by_key(|k| k.as_str());
    kinds.dedup();
    assert_eq!(kinds.len(), 7, "前 7 題應各是不同題型：{kinds:?}");
}

#[test]
fn unintroduced_drills_are_skipped_for_lessons_but_not_for_explicit_ids() {
    let store = content();
    let known = set(&["gr.desu"]);
    let context = ctx(&store, &known);
    let lessons = strings(&["le.l01"]);

    let gated = drill_session(&context, &selection(&lessons, 0)).unwrap();
    assert!(gated.is_empty(), "{:?}", ids(&gated));

    let explicit = strings(&["dr.l01.par.001"]);
    let by_id = drill_session(
        &context,
        &DrillSelection {
            lesson_ids: NONE,
            target: None,
            drill_ids: &explicit,
            count: 0,
        },
    )
    .unwrap();
    assert_eq!(ids(&by_id), vec!["dr.l01.par.001"]);
}

#[test]
fn target_filter_can_combine_with_lessons() {
    let store = content();
    let lessons = strings(&["le.l02"]);
    let by_target = |lesson_ids| DrillSelection {
        lesson_ids,
        target: Some("gr.masu"),
        drill_ids: NONE,
        count: 0,
    };

    let only_target = session(&store, &by_target(NONE));
    let both = session(&store, &by_target(&lessons));

    assert!(!only_target.is_empty());
    assert_eq!(both.len(), only_target.len(), "gr.masu 的題全在 L02");
    assert!(only_target
        .iter()
        .all(|q| q.focus_ids.contains(&"gr.masu".to_string())));
}

#[test]
fn listen_disabled_pairs_and_retired_drills_are_excluded() {
    let store = content_with(&[(
        r#""id": "dr.k16.mpr.001", "type": "minimal_pair""#,
        r#""id": "dr.k16.mpr.001", "retired": true, "type": "minimal_pair""#,
    )]);
    let explicit = strings(&["dr.k19.mpr.001", "dr.k16.mpr.001", "dr.k11.mpr.001"]);

    let picked = session(
        &store,
        &DrillSelection {
            lesson_ids: NONE,
            target: None,
            drill_ids: &explicit,
            count: 0,
        },
    );

    assert_eq!(ids(&picked), vec!["dr.k11.mpr.001"]);
}

#[test]
fn audio_questions_are_dropped_when_silent() {
    let store = content();
    let known = all_known(&store);
    let context = silent(&ctx(&store, &known));
    let lessons = strings(&["le.l01", "le.l02"]);

    let picked = drill_session(&context, &selection(&lessons, 0)).unwrap();

    assert!(!picked.is_empty());
    assert!(picked
        .iter()
        .all(|q| { !q.question_type.needs_audio() && !q.prompt.hide_text_until_answered }));
}

#[test]
fn missing_explicit_ids_are_not_found() {
    let store = content();
    let known = all_known(&store);
    let explicit = strings(&["dr.nope"]);

    let result = drill_session(
        &ctx(&store, &known),
        &DrillSelection {
            lesson_ids: NONE,
            target: None,
            drill_ids: &explicit,
            count: 0,
        },
    );

    assert!(matches!(result, Err(jp_quiz::QuizError::NotFound { .. })));
}

#[test]
fn quizzable_ids_filter_disabled_pairs() {
    let store = content();
    let input = strings(&["dr.k16.mpr.001", "dr.k19.mpr.001", "dr.nope"]);

    assert_eq!(quizzable_drill_ids(&store, &input), vec!["dr.k16.mpr.001"]);
}

#[test]
fn drill_ids_of_a_rule_card_are_filtered() {
    let store = content();
    let rule = store.rule_card_by_id("ka.rule.accent_intro").unwrap();

    assert!(quizzable_drill_ids(&store, &rule.drills).is_empty());
    let group = store.sound_group_by_id("ka.sg.accent_ame").unwrap();
    assert!(quizzable_drill_ids(&store, &group.test_drills).is_empty());
}

#[test]
fn listen_session_question_types_are_not_mistaken_for_others() {
    let store = content();
    let lessons = strings(&["le.l02"]);

    let picked = session(&store, &selection(&lessons, 0));

    assert!(picked
        .iter()
        .all(|q| q.question_type != QuestionType::KanaRead));
}

//! §8.4 `substitution`：選列、slot、去重、退回 Reorder。

mod common;

use common::*;
use jp_content::ContentStore;
use jp_quiz::drill::drill_question;
use jp_quiz::grade::grade_answer;
use jp_quiz::model::{AnswerPayload, Question, QuestionRef};
use jp_quiz::{QuestionKey, QuestionType, QuizError};

const ID: &str = "dr.l02.sub.001";
const THIRD_ROW: &str =
    r#"{"a": "ご飯|ごはん|vo.gohan", "b": "飲み|のみ|vo.nomu+ます|gr.masu", "zh": "我喝飯。"}"#;

fn build(store: &ContentStore, seed: u32) -> Question {
    let known = all_known(store);
    let context = with_seed(&ctx(store, &known), seed);
    drill_question(&context, drill(store, ID), QuestionKey::plain(ID), None).unwrap()
}

fn reference(variant: Option<u32>) -> QuestionRef {
    QuestionRef {
        question_type: QuestionType::Substitution,
        card_id: None,
        drill_id: Some(ID.to_string()),
        content_id: "gr.wo_obj".to_string(),
        variant,
    }
}

fn choose(id: &str) -> AnswerPayload {
    AnswerPayload::Choice {
        option_id: id.to_string(),
    }
}

#[test]
fn tied_slots_pick_the_last_key_and_blank_points_at_it() {
    let store = content();

    let question = build(&store, SEED);

    assert_eq!(question.question_type, QuestionType::Substitution);
    assert_eq!(blank_index(&question), Some(4));
    assert_eq!(sorted(option_ids(&question)), vec!["r0", "r1"]);
    assert!(sorted(option_texts(&question)).contains(&"食べます"));
}

#[test]
fn slot_with_most_distinct_values_wins() {
    let store = content_with(&[(
        THIRD_ROW,
        r#"{"a": "先生|せんせい|vo.sensei", "b": "飲み|のみ|vo.nomu+ます|gr.masu", "zh": "我喝老師。"}"#,
    )]);

    let question = build(&store, SEED);

    assert_eq!(blank_index(&question), Some(2));
    assert_eq!(sorted(option_ids(&question)), vec!["r0", "r1", "r2"]);
}

#[test]
fn prompt_shows_row_chinese_and_expanded_frame() {
    let store = content();

    for seed in 0..30 {
        let question = build(&store, seed);
        let variant = question.reference.variant.unwrap() as usize;
        let row = [
            ("我吃飯。", "私はご飯を食べます。"),
            ("我喝茶。", "私はお茶を飲みます。"),
            ("我喝飯。", "私はご飯を飲みます。"),
        ][variant];
        assert_eq!(question.prompt.plain_text.as_deref(), Some(row.0));
        assert_eq!(question.prompt.text.as_ref().unwrap().parsed.display, row.1);
    }
}

#[test]
fn duplicate_slot_values_keep_the_first_row_as_option() {
    let store = content();

    for seed in 0..30 {
        let question = build(&store, seed);
        let expected = match question.reference.variant.unwrap() {
            0 => "r0",
            _ => "r1",
        };
        assert_eq!(correct_id(&question), expected);
    }
}

#[test]
fn all_rows_are_reachable_as_variant() {
    let store = content();

    let variants: std::collections::HashSet<_> = (0..60)
        .map(|seed| build(&store, seed).reference.variant)
        .collect();

    assert_eq!(variants.len(), 3);
}

#[test]
fn row_tts_applies_to_expanded_sentence() {
    let store = content_with(&[(
        r#""zh": "我喝茶。"}"#,
        r#""zh": "我喝茶。", "tts": "kana"}"#,
    )]);

    for seed in 0..60 {
        let question = build(&store, seed);
        if question.reference.variant == Some(1) {
            let speech = question.prompt.text.as_ref().unwrap().parsed.speech.clone();
            assert_eq!(speech.text, speech.kana);
            return;
        }
    }
    panic!("應能選到第 2 列");
}

#[test]
fn fewer_than_two_distinct_values_becomes_reorder_with_same_type() {
    let store = content_with(&[
        (
            r#"{"a": "お茶|おちゃ|vo.ocha", "b": "飲み|のみ|vo.nomu+ます|gr.masu", "zh": "我喝茶。"}"#,
            r#"{"a": "ご飯|ごはん|vo.gohan", "b": "食べ|たべ|vo.taberu+ます|gr.masu", "zh": "我喝茶。"}"#,
        ),
        (
            THIRD_ROW,
            r#"{"a": "ご飯|ごはん|vo.gohan", "b": "食べ|たべ|vo.taberu+ます|gr.masu", "zh": "我喝飯。"}"#,
        ),
    ]);

    let question = build(&store, SEED);

    assert_eq!(question.question_type, QuestionType::Substitution);
    let identity = vec![vec![0, 1, 2]];
    assert_eq!(accept_orders(&question), identity.as_slice());
    assert_ne!(chunk_order(&question), identity[0]);

    let reference = reference(question.reference.variant);
    let right = grade_answer(
        &store,
        &reference,
        &AnswerPayload::Reorder {
            order: vec![0, 1, 2],
        },
    )
    .unwrap();
    assert!(right.is_correct);
}

#[test]
fn grading_compares_slot_values_of_the_chosen_row() {
    let store = content();

    let drink = grade_answer(&store, &reference(Some(2)), &choose("r1")).unwrap();
    assert!(drink.is_correct);
    assert_eq!(
        drink.correct_display,
        "{ja:私はご飯を飲みます。|わたしはごはんをのみます。}"
    );
    assert_eq!(drink.reveal.unwrap().zh, "我喝飯。");

    let eat = grade_answer(&store, &reference(Some(2)), &choose("r0")).unwrap();
    assert!(!eat.is_correct);
}

#[test]
fn invalid_variant_or_option_is_rejected() {
    let store = content();

    for variant in [None, Some(3)] {
        let result = grade_answer(&store, &reference(variant), &choose("r0"));
        assert!(matches!(result, Err(QuizError::InvalidInput { .. })));
    }
    for bad in ["r9", "x0", "r"] {
        let result = grade_answer(&store, &reference(Some(0)), &choose(bad));
        assert!(!result.unwrap().is_correct, "{bad} 視為答錯");
    }
}

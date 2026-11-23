//! 自動補的 `listen_meaning` 與聽力 session（§8.4、§9.4）。

mod common;

use common::*;
use jp_content::ContentStore;
use jp_quiz::listen_quiz::{auto_listen_meaning, listen_session};
use jp_quiz::model::QuestionBody;
use jp_quiz::{Question, QuestionKey, QuestionType, QuizContext};

const KEY: QuestionKey<'static> = QuestionKey {
    seed_key: "gr.desu:use",
    card_id: Some("gr.desu:use"),
};

fn index(store: &ContentStore, id: &str) -> u32 {
    store.sentence_index(id).unwrap()
}

fn auto(context: &QuizContext<'_>, id: &str) -> Option<Question> {
    auto_listen_meaning(context, index(context.content, id), KEY).unwrap()
}

#[test]
fn auto_listen_meaning_references_the_sentence() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    let question = auto(&context, "se.l01.003").unwrap();

    assert_eq!(question.question_type, QuestionType::ListenMeaning);
    assert_eq!(question.reference.drill_id, None);
    assert_eq!(question.reference.content_id, "se.l01.003");
    assert_eq!(question.reference.card_id.as_deref(), Some("gr.desu:use"));
    assert_eq!(correct_id(&question), "s:se.l01.003");
    assert_eq!(options(&question).len(), 4);
    assert!(option_ids(&question).iter().all(|id| id.starts_with("s:")));
    assert!(question.prompt.autoplay && question.prompt.hide_text_until_answered);
}

#[test]
fn focus_ids_are_grammar_refs_in_order_without_duplicates() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    let several = auto(&context, "se.l02.001").unwrap();
    assert_eq!(
        several.focus_ids,
        vec!["gr.wa_topic", "gr.wo_obj", "gr.masu"]
    );

    let plain = auto(&context, "se.l01.003").unwrap();
    assert_eq!(plain.focus_ids, vec!["gr.desu"]);
}

#[test]
fn same_lesson_distractors_come_first() {
    let store = content();
    let known = all_known(&store);

    for seed in 0..30 {
        let context = with_seed(&ctx(&store, &known), seed);
        let question = auto(&context, "se.l01.003").unwrap();
        for id in option_ids(&question) {
            assert!(id.starts_with("s:se.l01."), "seed {seed}: {id}");
        }
    }
}

#[test]
fn distractors_exclude_same_chinese_and_are_distinct() {
    let store = content_with(&[(
        r#""t": "はい|vo.hai 、 お茶|おちゃ|vo.ocha 。", "zh": "好，茶。""#,
        r#""t": "はい|vo.hai 、 お茶|おちゃ|vo.ocha 。", "zh": "是的，是學生。""#,
    )]);
    let known = all_known(&store);

    for seed in 0..30 {
        let context = with_seed(&ctx(&store, &known), seed);
        let question = auto(&context, "se.l01.003").unwrap();
        assert!(
            !option_ids(&question).contains(&"s:se.l01.011"),
            "seed {seed}"
        );
        let mut texts = option_texts(&question);
        texts.sort_unstable();
        texts.dedup();
        assert_eq!(texts.len(), 4);
    }
}

#[test]
fn unavailable_sentences_are_not_distractors() {
    let store = content();
    let known = set(&["vo.hai", "vo.gakusei", "gr.desu", "vo.hajimemashite"]);
    let context = ctx(&store, &known);

    let question = auto(&context, "se.l01.003").unwrap();

    let mut ids = sorted(option_ids(&question));
    ids.sort_unstable();
    assert_eq!(ids, vec!["s:se.l01.003", "s:se.l01.009", "s:se.l01.010"]);
}

#[test]
fn cursor_limits_distractors_to_reached_lessons() {
    let store = content();
    let known = all_known(&store);
    let cursor = store.lesson_pos("le.l01").unwrap();
    let context = QuizContext {
        cursor_pos: Some(cursor),
        ..ctx(&store, &known)
    };

    for seed in 0..20 {
        let question = auto(&with_seed(&context, seed), "se.l01.003").unwrap();
        assert!(option_ids(&question)
            .iter()
            .all(|id| id.starts_with("s:se.l01.")));
    }
}

#[test]
fn no_question_without_a_distractor() {
    let store = content();
    let known = set(&["vo.hajimemashite"]);
    let context = ctx(&store, &known);

    assert_eq!(auto(&context, "se.l01.009"), None);
}

fn session_ids() -> Vec<String> {
    [
        "se.l01.003",
        "se.l01.004",
        "se.l01.005",
        "se.l01.006",
        "se.l01.009",
        "se.l02.001",
        "se.l02.002",
    ]
    .iter()
    .map(|id| (*id).to_string())
    .collect()
}

#[test]
fn every_third_question_is_shadowing() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    let questions = listen_session(&context, &session_ids()).unwrap();

    assert_eq!(questions.len(), 7);
    for (position, question) in questions.iter().enumerate() {
        let expected = if position % 3 == 2 {
            QuestionType::Shadowing
        } else {
            QuestionType::ListenMeaning
        };
        assert_eq!(question.question_type, expected, "第 {position} 題");
        assert_eq!(question.reference.drill_id, None);
    }
    let QuestionBody::Shadow { reveal } = &questions[2].body else {
        panic!("預期 Shadow");
    };
    assert_eq!(reveal.id, questions[2].reference.content_id);
}

#[test]
fn order_follows_seed() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let order = |context: &QuizContext<'_>| -> Vec<String> {
        listen_session(context, &session_ids())
            .unwrap()
            .into_iter()
            .map(|q| q.reference.content_id)
            .collect()
    };

    assert_eq!(order(&context), order(&context));
    assert!((0..30u32).any(|seed| order(&with_seed(&context, seed)) != order(&context)));
}

#[test]
fn silent_listen_session_is_empty() {
    let store = content();
    let known = all_known(&store);
    let context = silent(&ctx(&store, &known));

    assert_eq!(listen_session(&context, &session_ids()).unwrap(), vec![]);
}

#[test]
fn stale_or_unusable_sentence_ids_are_skipped() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let ids = vec!["se.gone".to_string(), "se.l01.003".to_string()];

    let questions = listen_session(&context, &ids).unwrap();

    assert_eq!(questions.len(), 1);
    assert_eq!(questions[0].reference.content_id, "se.l01.003");
}

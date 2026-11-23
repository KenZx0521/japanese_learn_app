//! §8.3 單字題。

mod common;

use std::collections::HashSet;

use common::*;
use jp_content::schema::Style;
use jp_content::ContentStore;
use jp_quiz::model::{QuestionBody, SentenceView};
use jp_quiz::vocab_quiz::{produce_question, recog_question, vocab_listen_question};
use jp_quiz::{Question, QuestionKey, QuestionType};

const KEY: QuestionKey<'static> = QuestionKey {
    seed_key: "vo.test:recog",
    card_id: None,
};

fn recog(store: &ContentStore, known: &HashSet<String>, id: &str, seed: u32) -> Question {
    let context = with_seed(&ctx(store, known), seed);
    recog_question(&context, id, KEY).unwrap()
}

fn reveal(question: &Question) -> &SentenceView {
    match &question.body {
        QuestionBody::SelfGrade { reveal } => reveal,
        other => panic!("預期 SelfGrade，得到 {other:?}"),
    }
}

#[test]
fn recog_shows_word_and_four_chinese_options() {
    let store = content();
    let known = all_known(&store);

    let question = recog(&store, &known, "vo.gohan", SEED);

    assert_eq!(question.question_type, QuestionType::Recog);
    assert_eq!(
        question.prompt.plain_text.as_deref(),
        Some("{ja:ご飯|ごはん}")
    );
    assert_eq!(options(&question).len(), 4);
    assert_eq!(correct_id(&question), "vo.gohan");
    assert!(option_texts(&question).contains(&"飯"));
    assert_eq!(question.focus_ids, vec!["vo.gohan"]);
    assert_eq!(question.reference.content_id, "vo.gohan");
}

#[test]
fn zh_list_is_joined_for_option_text() {
    let store = content_with(&[(
        r#""kana": "ごはん", "zh": ["飯"]"#,
        r#""kana": "ごはん", "zh": ["飯", "米飯"]"#,
    )]);
    let known = all_known(&store);

    let question = recog(&store, &known, "vo.gohan", SEED);

    assert!(
        option_texts(&question).contains(&"飯、米飯"),
        "{:?}",
        option_texts(&question)
    );
}

#[test]
fn candidates_are_limited_to_introduced_words() {
    let store = content();
    let known = set(&["vo.gohan", "vo.ocha", "vo.sensei", "vo.gakusei"]);

    for seed in 0..30 {
        let question = recog(&store, &known, "vo.gohan", seed);
        assert_eq!(
            sorted(option_ids(&question)),
            vec!["vo.gakusei", "vo.gohan", "vo.ocha", "vo.sensei"]
        );
    }
}

#[test]
fn same_pos_and_topic_come_first() {
    let store = content();
    let known = all_known(&store);

    for seed in 0..40 {
        let question = recog(&store, &known, "vo.gohan", seed);
        assert!(option_ids(&question).contains(&"vo.ocha"), "seed {seed}");
    }
}

#[test]
fn only_same_pos_words_are_candidates() {
    let store = content();
    let known = all_known(&store);

    for seed in 0..30 {
        let question = recog(&store, &known, "vo.taberu", seed);
        // v1 只有 食べる、見る；不足 2 個干擾項
        assert!(
            matches!(question.body, QuestionBody::SelfGrade { .. }),
            "seed {seed}"
        );
    }
}

#[test]
fn excludes_retired_same_kana_and_shared_zh() {
    let store = content_with(&[
        (
            r#""kana": "おちゃ", "zh": ["茶"]"#,
            r#""kana": "おちゃ", "zh": ["茶"], "retired": true"#,
        ),
        (
            r#""surface": "先生", "kana": "せんせい", "zh": ["老師"]"#,
            r#""surface": "先生", "kana": "ごはん", "zh": ["老師"]"#,
        ),
        (
            r#""surface": "学生", "kana": "がくせい", "zh": ["學生"]"#,
            r#""surface": "学生", "kana": "がくせい", "zh": ["學生", "飯"]"#,
        ),
    ]);
    let known = all_known(&store);

    for seed in 0..30 {
        let question = recog(&store, &known, "vo.gohan", seed);
        let ids = option_ids(&question);
        for excluded in ["vo.ocha", "vo.sensei", "vo.gakusei"] {
            assert!(!ids.contains(&excluded), "{ids:?}");
        }
    }
}

#[test]
fn distractors_do_not_duplicate_each_other() {
    let store = content_with(&[(
        r#""surface": "手紙", "kana": "てがみ", "zh": ["信"]"#,
        r#""surface": "手紙", "kana": "てがみ", "zh": ["每天早上"]"#,
    )]);
    let known = all_known(&store);

    for seed in 0..40 {
        let question = recog(&store, &known, "vo.gohan", seed);
        let mut texts = option_texts(&question);
        texts.sort_unstable();
        let total = texts.len();
        texts.dedup();
        assert_eq!(texts.len(), total, "seed {seed}");
    }
}

#[test]
fn fewer_than_two_distractors_falls_back_to_self_grade() {
    let store = content();
    let known = set(&["vo.gohan", "vo.ocha"]);

    let question = recog(&store, &known, "vo.gohan", SEED);

    assert_eq!(question.question_type, QuestionType::Recog);
    let sentence = reveal(&question);
    assert_eq!(sentence.id, "vo.gohan");
    assert_eq!(sentence.parsed.display, "ご飯");
    assert_eq!(sentence.parsed.romaji, "gohan");
    assert_eq!(sentence.zh, "飯");
    assert_eq!(sentence.style, Style::Neutral);
    let [word] = sentence.parsed.words.as_slice() else {
        panic!("預期單一詞");
    };
    assert_eq!(word.surface, "ご飯");
    assert_eq!(word.kana, "ごはん");
    assert_eq!(word.speech_kana, "ごはん");
    assert_eq!(word.refs, vec!["vo.gohan"]);
    assert_eq!(word.ref_id.as_deref(), Some("vo.gohan"));
    assert_eq!(word.gloss_zh, None);
    assert!(!word.is_punct);
    assert_eq!(word.ruby[0].base, "ご");
    assert_eq!(word.ruby[1].ruby.as_deref(), Some("はん"));
}

#[test]
fn self_grade_reveal_strips_spaces_for_ruby_and_keeps_word_speech() {
    let store = content();
    let known = set(&["vo.konnichiwa"]);

    let question = recog(&store, &known, "vo.konnichiwa", SEED);

    let sentence = reveal(&question);
    assert_eq!(sentence.parsed.display, "こんにちは");
    assert_eq!(sentence.parsed.romaji, "konnichi wa");
    assert_eq!(sentence.parsed.speech.text, "こんにち わ");
    assert_eq!(sentence.parsed.words[0].speech_kana, "こんにち わ");
    assert_eq!(sentence.parsed.words[0].ruby[0].base, "こんにちは");
    assert_eq!(sentence.parsed.words[0].ruby[0].ruby, None);
}

#[test]
fn same_form_word_plays_audio_and_hides_text_when_audio_is_available() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    let question = recog_question(&context, "vo.sensei", KEY).unwrap();

    assert!(question.prompt.autoplay);
    assert!(question.prompt.hide_text_until_answered);
    assert_eq!(question.prompt.speech.as_ref().unwrap().text, "せんせい");
    assert_eq!(
        question.prompt.plain_text.as_deref(),
        Some("{ja:先生|せんせい}")
    );
}

#[test]
fn same_form_word_shows_only_kana_without_audio() {
    let store = content();
    let known = all_known(&store);
    let context = silent(&ctx(&store, &known));

    let question = recog_question(&context, "vo.sensei", KEY).unwrap();

    assert!(!question.prompt.autoplay);
    assert!(!question.prompt.hide_text_until_answered);
    assert_eq!(question.prompt.speech, None);
    assert_eq!(question.prompt.plain_text.as_deref(), Some("{ja:せんせい}"));
}

#[test]
fn vocab_listen_autoplays_and_keeps_type_on_fallback() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    let question = vocab_listen_question(&context, "vo.gohan", KEY).unwrap();
    assert_eq!(question.question_type, QuestionType::VocabListen);
    assert!(question.prompt.autoplay);
    assert!(question.prompt.hide_text_until_answered);
    assert_eq!(options(&question).len(), 4);

    let few = set(&["vo.gohan"]);
    let context = ctx(&store, &few);
    let fallback = vocab_listen_question(&context, "vo.gohan", KEY).unwrap();
    assert_eq!(fallback.question_type, QuestionType::VocabListen);
    assert_eq!(reveal(&fallback).id, "vo.gohan");
}

#[test]
fn produce_is_self_grade_from_chinese() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    let question = produce_question(&context, "vo.hai", KEY).unwrap();

    assert_eq!(question.question_type, QuestionType::Produce);
    assert_eq!(question.prompt.plain_text.as_deref(), Some("是、好"));
    assert_eq!(reveal(&question).id, "vo.hai");
}

#[test]
fn unknown_word_is_not_found() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    for result in [
        recog_question(&context, "vo.nope", KEY),
        vocab_listen_question(&context, "vo.nope", KEY),
        produce_question(&context, "vo.nope", KEY),
    ] {
        assert!(matches!(result, Err(jp_quiz::QuizError::NotFound { .. })));
    }
}

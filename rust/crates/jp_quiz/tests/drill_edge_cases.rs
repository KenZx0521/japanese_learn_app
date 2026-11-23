//! 內容組合與錯誤路徑：夾具沒有的型態用程式組出 `DrillDef`。

mod common;

use std::collections::BTreeMap;

use common::*;
use jp_content::schema::{ConjForm, DrillDef, KanaWordMode, SubRowDef};
use jp_content::ContentStore;
use jp_quiz::card::question_for_card;
use jp_quiz::distractor::KanaPool;
use jp_quiz::drill::drill_question;
use jp_quiz::grade::grade_answer;
use jp_quiz::kana_quiz::{confuse_quiz, kana_listen_question};
use jp_quiz::model::{AnswerPayload, QuestionBody, QuestionRef, ShadowLevel};
use jp_quiz::{Question, QuestionKey, QuestionType, QuizError};
use jp_srs::{CardId, Rating};

const KEY: QuestionKey<'static> = QuestionKey {
    seed_key: "edge",
    card_id: None,
};

fn build(store: &ContentStore, drill_def: &DrillDef) -> Result<Question, QuizError> {
    let known = all_known(store);
    drill_question(&ctx(store, &known), drill_def, KEY, None)
}

fn conjugate(form: ConjForm, lemmas: &[&str]) -> DrillDef {
    DrillDef::Conjugate {
        id: "dr.test.cnj".into(),
        lesson: "le.l02".into(),
        targets: vec!["gr.masu".into()],
        form,
        lemmas: lemmas.iter().map(|l| (*l).to_string()).collect(),
        retired: false,
        replaced_by: None,
    }
}

fn prompt_text(question: &Question) -> &str {
    question.prompt.plain_text.as_deref().unwrap()
}

#[test]
fn every_conjugation_form_has_a_label() {
    let store = content();
    let table = [
        (ConjForm::Masu, "{ja:ます}形"),
        (ConjForm::Te, "{ja:て}形"),
        (ConjForm::Ta, "{ja:た}形"),
        (ConjForm::Nai, "{ja:ない}形"),
        (ConjForm::Potential, "可能形"),
        (ConjForm::Volitional, "意向形"),
        (ConjForm::Ba, "{ja:ば}形"),
        (ConjForm::Imperative, "命令形"),
        (ConjForm::Passive, "被動形"),
        (ConjForm::Causative, "使役形"),
    ];
    for (form, label) in table {
        let question = build(&store, &conjugate(form, &["vo.taberu"])).unwrap();
        assert_eq!(
            prompt_text(&question),
            format!("{{ja:食べる|たべる}} → {label}")
        );
    }
}

#[test]
fn suru_verbs_show_the_dictionary_form() {
    let store = content_with(&[(
        r#""kana": "おちゃ", "zh": ["茶"], "pos": "n""#,
        r#""kana": "おちゃ", "zh": ["茶"], "pos": "vs""#,
    )]);

    let stem = build(&store, &conjugate(ConjForm::Te, &["vo.ocha"])).unwrap();
    assert!(prompt_text(&stem).starts_with("{ja:お茶する|おちゃする}"));
    let QuestionBody::Typing {
        expected_reading, ..
    } = &stem.body
    else {
        panic!("預期 Typing");
    };
    assert_eq!(expected_reading, "おちゃして");

    let suru = build(&store, &conjugate(ConjForm::Te, &["vo.suru"])).unwrap();
    assert!(prompt_text(&suru).starts_with("{ja:する}"));
}

#[test]
fn unconjugatable_or_empty_lemmas_are_internal_errors() {
    let store = content();

    for lemmas in [vec!["vo.gohan"], vec![]] {
        let result = build(&store, &conjugate(ConjForm::Te, &lemmas));
        assert!(
            matches!(result, Err(QuizError::Internal { .. })),
            "{lemmas:?}"
        );
    }
    assert!(matches!(
        build(&store, &conjugate(ConjForm::Te, &["vo.nope"])),
        Err(QuizError::NotFound { .. })
    ));
}

fn substitution(frame: &str, rows: Vec<(&str, &str)>) -> DrillDef {
    DrillDef::Substitution {
        id: "dr.test.sub".into(),
        lesson: "le.l02".into(),
        targets: vec!["gr.masu".into()],
        frame: frame.into(),
        rows: rows
            .into_iter()
            .map(|(value, zh)| SubRowDef {
                zh: zh.into(),
                tts: None,
                slots: BTreeMap::from([("b".to_string(), value.to_string())]),
            })
            .collect(),
        retired: false,
        replaced_by: None,
    }
}

#[test]
fn blank_points_at_the_word_containing_a_glued_slot() {
    let store = content();
    let drill_def = substitution(
        "私|わたし|vo.watashi は|gr.wa_topic 食べ|たべ|vo.taberu+{b} 。",
        vec![
            ("ます|gr.masu", "我吃。"),
            ("ない|gr.plain_style", "我不吃。"),
        ],
    );

    let question = build(&store, &drill_def).unwrap();

    assert_eq!(blank_index(&question), Some(2));
    assert_eq!(sorted(option_texts(&question)), vec!["ない", "ます"]);
}

#[test]
fn blank_counts_every_word_of_earlier_multi_word_slots() {
    let store = content();
    let drill_def = DrillDef::Substitution {
        id: "dr.test.sub".into(),
        lesson: "le.l02".into(),
        targets: vec!["gr.masu".into()],
        frame: "{a} {b} 。".into(),
        rows: [
            ("はい|vo.hai 、", "ご飯|ごはん|vo.gohan", "好，飯。"),
            ("はい|vo.hai 、", "お茶|おちゃ|vo.ocha", "好，茶。"),
            ("はい|vo.hai 、", "先生|せんせい|vo.sensei", "好，老師。"),
        ]
        .into_iter()
        .map(|(a, b, zh)| SubRowDef {
            zh: zh.into(),
            tts: None,
            slots: BTreeMap::from([
                ("a".to_string(), a.to_string()),
                ("b".to_string(), b.to_string()),
            ]),
        })
        .collect(),
        retired: false,
        replaced_by: None,
    };

    let question = build(&store, &drill_def).unwrap();

    assert_eq!(blank_index(&question), Some(2), "はい、 佔兩個詞");
}

#[test]
fn empty_rows_or_bad_frame_are_internal_errors() {
    let store = content();

    assert!(matches!(
        build(&store, &substitution("{b} 。", vec![])),
        Err(QuizError::Internal { .. })
    ));
    assert!(matches!(
        build(
            &store,
            &substitution("{c} 。", vec![("ます|gr.masu", "x"), ("ない|gr.masu", "y")])
        ),
        Err(QuizError::Internal { .. })
    ));
}

#[test]
fn particle_answer_follows_the_word_in_the_sentence_not_the_choice_order() {
    let store = content_with(&[(
        r#""choices": ["は|gr.wa_topic", "です|gr.desu"]"#,
        r#""choices": ["です|gr.desu", "は|gr.wa_topic"]"#,
    )]);
    let id = "dr.l01.par.001";

    let question = build(&store, drill(&store, id)).unwrap();
    assert_eq!(correct_id(&question), "c1");

    let choose = |option: &str| AnswerPayload::Choice {
        option_id: option.to_owned(),
    };
    let reference = question.reference.clone();
    assert!(
        grade_answer(&store, &reference, &choose("c1"))
            .unwrap()
            .is_correct
    );
    assert!(
        !grade_answer(&store, &reference, &choose("c0"))
            .unwrap()
            .is_correct
    );
}

#[test]
fn particle_choices_without_the_sentence_word_are_internal_errors() {
    let store = content_with(&[(
        r#""choices": ["は|gr.wa_topic", "です|gr.desu"]"#,
        r#""choices": ["を|gr.wo_obj", "です|gr.desu"]"#,
    )]);

    let result = build(&store, drill(&store, "dr.l01.par.001"));

    assert!(matches!(result, Err(QuizError::Internal { .. })));
}

#[test]
fn false_friend_with_missing_note_is_internal_error() {
    let store = content();
    let drill_def = DrillDef::FalseFriend {
        id: "dr.test.ffr".into(),
        lesson: "le.l08".into(),
        targets: vec!["vo.tegami".into()],
        note: "no.ff.nope".into(),
        prompt_zh: "x".into(),
        choices_zh: vec!["信".into(), "紙".into()],
        answer_index: 0,
        retired: false,
        replaced_by: None,
    };

    assert!(matches!(
        build(&store, &drill_def),
        Err(QuizError::Internal { .. })
    ));
}

#[test]
fn kana_word_choice_without_answer_index_is_internal_error() {
    let store = content();
    let drill_def = DrillDef::KanaWord {
        id: "dr.test.kwd".into(),
        lesson: "le.k05".into(),
        targets: vec!["ka.hira.i".into()],
        word: "いぬ".into(),
        zh: "狗".into(),
        mode: KanaWordMode::Choice,
        choices_zh: vec!["狗".into()],
        answer_index: None,
        retired: false,
        replaced_by: None,
    };

    assert!(matches!(
        build(&store, &drill_def),
        Err(QuizError::Internal { .. })
    ));
}

#[test]
fn register_convert_labels_follow_target_style() {
    let polite = content_with(&[(
        r#""from": "se.l02.001", "to": "se.l21.001""#,
        r#""from": "se.l21.001", "to": "se.l02.001""#,
    )]);
    let neutral = content_with(&[(
        r#""from": "se.l02.001", "to": "se.l21.001""#,
        r#""from": "se.l02.001", "to": "se.l01.007""#,
    )]);

    let to_polite = build(&polite, drill(&polite, "dr.l21.reg.001")).unwrap();
    let to_other = build(&neutral, drill(&neutral, "dr.l21.reg.001")).unwrap();

    assert_eq!(prompt_text(&to_polite), "改成敬體");
    assert_eq!(prompt_text(&to_other), "改成另一種語體");
}

fn reference(question_type: QuestionType, drill_id: Option<&str>, content_id: &str) -> QuestionRef {
    QuestionRef {
        question_type,
        card_id: None,
        drill_id: drill_id.map(str::to_owned),
        content_id: content_id.to_owned(),
        variant: Some(0),
    }
}

#[test]
fn wrong_payload_kinds_are_rejected_for_every_body() {
    let store = content();
    let choice = || AnswerPayload::Choice {
        option_id: "x".into(),
    };
    let typing = || AnswerPayload::Typing { input: "x".into() };
    let cases = [
        (
            reference(QuestionType::Substitution, Some("dr.l02.sub.001"), "gr"),
            typing(),
        ),
        (
            reference(QuestionType::Reorder, Some("dr.l01.ord.001"), "gr"),
            choice(),
        ),
        (
            reference(QuestionType::RegisterConvert, Some("dr.l21.reg.001"), "gr"),
            choice(),
        ),
        (
            reference(QuestionType::Conjugate, Some("dr.l02.cnj.001"), "gr"),
            choice(),
        ),
        (
            reference(QuestionType::KanaWord, Some("dr.k11.kwd.002"), "ka"),
            choice(),
        ),
        (
            reference(QuestionType::Shadowing, Some("dr.l01.shd.001"), "gr"),
            choice(),
        ),
        (
            reference(QuestionType::Shadowing, None, "se.l01.003"),
            choice(),
        ),
        (reference(QuestionType::Recog, None, "gr.desu"), choice()),
        (
            reference(QuestionType::ParticleFill, None, "gr.desu"),
            choice(),
        ),
    ];
    for (reference, response) in cases {
        assert!(
            matches!(
                grade_answer(&store, &reference, &response),
                Err(QuizError::InvalidInput { .. })
            ),
            "{reference:?}"
        );
    }
}

#[test]
fn self_rating_and_shadow_results_do_not_need_variants() {
    let store = content();
    let hard = AnswerPayload::SelfGrade {
        rating: Rating::Hard,
    };
    let lost = AnswerPayload::Shadow {
        level: ShadowLevel::Lost,
    };
    let word = QuestionRef {
        variant: None,
        ..reference(QuestionType::VocabListen, None, "vo.gohan")
    };
    let sentence = reference(QuestionType::Shadowing, None, "se.l01.003");

    assert!(grade_answer(&store, &word, &hard).unwrap().is_correct);
    let followed = grade_answer(&store, &sentence, &lost).unwrap();
    assert!(followed.is_correct);
    assert_eq!(followed.reveal.unwrap().id, "se.l01.003");
}

#[test]
fn use_card_without_examples_or_candidates_shows_the_title() {
    let store = content_with(&[(
        r#""requires": [], "examples": ["se.l01.002", "se.l01.003"]"#,
        r#""requires": [], "examples": []"#,
    )]);
    let known = set(&[]);
    let context = ctx(&store, &known);
    let card = CardId::parse("gr.desu:use").unwrap();

    let question = question_for_card(&context, &card, 0).unwrap();

    let QuestionBody::SelfGrade { reveal } = &question.body else {
        panic!("預期 SelfGrade");
    };
    assert_eq!(
        reveal.parsed.display, "{ja:です}：是",
        "保留標記，Dart 才能用 MixedText 分段"
    );
    assert!(reveal.parsed.words.is_empty());
}

#[test]
fn listen_question_without_distractors_is_none() {
    let store = content();
    let known = set(&["ka.hira.ka"]);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    assert_eq!(
        kana_listen_question(&context, "ka.hira.ka", &pool, KEY).unwrap(),
        None
    );
}

#[test]
fn confuse_quiz_skips_members_not_yet_taught() {
    let store = content();
    let known = set(&["ka.hira.nu"]);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    assert!(confuse_quiz(&context, "ka.cf.nu_me", &pool)
        .unwrap()
        .is_empty());
}

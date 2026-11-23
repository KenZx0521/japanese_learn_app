//! §8.2 假名題與干擾項。

mod common;

use std::collections::HashSet;

use common::*;
use jp_quiz::distractor::KanaPool;
use jp_quiz::kana_quiz::{
    confuse_quiz, kana_batch_quiz, kana_confuse_question, kana_listen_question,
    kana_match_question, kana_session, rule_quiz,
};
use jp_quiz::model::QuestionBody;
use jp_quiz::{QuestionKey, QuestionType};

const KEY: QuestionKey<'static> = QuestionKey {
    seed_key: "test",
    card_id: None,
};

#[test]
fn kana_listen_plays_sound_and_hides_text() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let question = kana_listen_question(&context, "ka.hira.ka", &pool, KEY)
        .unwrap()
        .unwrap();

    assert_eq!(question.question_type, QuestionType::KanaListen);
    assert_eq!(question.prompt.plain_text, None);
    assert_eq!(question.prompt.speech.as_ref().unwrap().text, "か");
    assert!(question.prompt.autoplay);
    assert!(option_texts(&question).contains(&"か"));
}

#[test]
fn kana_listen_falls_back_to_read_when_disabled_or_silent() {
    let store = content_with(&[(
        r#""example_words": [{"surface": "あい", "zh": "愛"}]"#,
        r#""example_words": [{"surface": "あい", "zh": "愛"}], "listen_disabled": true"#,
    )]);
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let disabled = kana_listen_question(&context, "ka.hira.a", &pool, KEY)
        .unwrap()
        .unwrap();
    let no_audio = kana_listen_question(&silent(&context), "ka.hira.ka", &pool, KEY)
        .unwrap()
        .unwrap();

    assert_eq!(disabled.question_type, QuestionType::KanaRead);
    assert_eq!(no_audio.question_type, QuestionType::KanaRead);
}

#[test]
fn kana_confuse_shape_prompts_reading_and_offers_group_shapes() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let question = kana_confuse_question(&context, "ka.hira.nu", &pool, KEY)
        .unwrap()
        .unwrap();

    assert_eq!(question.question_type, QuestionType::KanaConfuse);
    assert_eq!(question.prompt.plain_text.as_deref(), Some("nu"));
    assert_eq!(question.prompt.speech.as_ref().unwrap().text, "ぬ");
    assert!(!question.prompt.autoplay);
    assert_eq!(
        sorted(option_ids(&question)),
        vec!["ka.hira.me", "ka.hira.nu"]
    );
    assert_eq!(sorted(option_texts(&question)), vec!["ぬ", "め"]);
    assert_eq!(correct_id(&question), "ka.hira.nu");
    assert!(question.explain_zh.as_deref().unwrap().contains("收尾"));
}

#[test]
fn kana_confuse_shape_has_no_speech_when_listening_is_disabled() {
    let store = content_with(&[(
        r#""id": "ka.hira.nu","#,
        r#""id": "ka.hira.nu", "listen_disabled": true,"#,
    )]);
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let question = kana_confuse_question(&context, "ka.hira.nu", &pool, KEY)
        .unwrap()
        .unwrap();

    assert_eq!(question.prompt.plain_text.as_deref(), Some("nu"));
    assert_eq!(question.prompt.speech, None);
}

#[test]
fn kana_confuse_shape_never_offers_a_member_with_the_same_reading() {
    let store = content_with(&[(
        r#""members": ["ka.hira.nu", "ka.hira.me"]"#,
        r#""members": ["ka.hira.o", "ka.hira.wo", "ka.hira.a"]"#,
    )]);
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let question = kana_confuse_question(&context, "ka.hira.o", &pool, KEY)
        .unwrap()
        .unwrap();

    assert_eq!(
        sorted(option_ids(&question)),
        vec!["ka.hira.a", "ka.hira.o"]
    );
}

#[test]
fn kana_confuse_cross_script_prompts_counterpart_and_offers_target_script() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let katakana = kana_confuse_question(&context, "ka.kata.ka", &pool, KEY)
        .unwrap()
        .unwrap();
    let hiragana = kana_confuse_question(&context, "ka.hira.ka", &pool, KEY)
        .unwrap()
        .unwrap();

    assert_eq!(katakana.question_type, QuestionType::KanaConfuse);
    assert_eq!(katakana.prompt.plain_text.as_deref(), Some("{ja:か}"));
    assert_eq!(correct_id(&katakana), "ka.kata.ka");
    assert!(option_ids(&katakana).len() >= 2);
    assert!(option_ids(&katakana)
        .iter()
        .all(|id| id.starts_with("ka.kata.")));
    assert!(katakana.prompt.instruction_zh.contains("片假名"));

    assert_eq!(hiragana.prompt.plain_text.as_deref(), Some("{ja:カ}"));
    assert_eq!(correct_id(&hiragana), "ka.hira.ka");
    assert!(option_ids(&hiragana)
        .iter()
        .all(|id| id.starts_with("ka.hira.")));
    assert!(hiragana.prompt.instruction_zh.contains("平假名"));
}

#[test]
fn kana_confuse_cross_script_answer_counts_for_the_prompted_kana() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let question = kana_confuse_question(&context, "ka.kata.ka", &pool, KEY)
        .unwrap()
        .unwrap();

    assert_eq!(question.reference.content_id, "ka.kata.ka");
    assert_eq!(correct_id(&question), question.reference.content_id);
}

#[test]
fn kana_confuse_cross_script_needs_a_taught_counterpart_and_another_same_script_kana() {
    let store = content();

    let no_counterpart = set(&["ka.kata.ka", "ka.kata.ki"]);
    let context = ctx(&store, &no_counterpart);
    let pool = KanaPool::taught(&store, &no_counterpart, &[]);
    assert_eq!(
        kana_confuse_question(&context, "ka.kata.ka", &pool, KEY).unwrap(),
        None
    );

    let only_the_pair = set(&["ka.kata.ka", "ka.hira.ka"]);
    let context = ctx(&store, &only_the_pair);
    let pool = KanaPool::taught(&store, &only_the_pair, &[]);
    assert_eq!(
        kana_confuse_question(&context, "ka.kata.ka", &pool, KEY).unwrap(),
        None
    );
}

#[test]
fn kana_confuse_needs_two_taught_members_of_a_shape_or_cross_script_group() {
    let store = content();
    let one_member = set(&["ka.hira.nu", "ka.hira.a"]);
    let context = ctx(&store, &one_member);
    let pool = KanaPool::taught(&store, &one_member, &[]);
    assert_eq!(
        kana_confuse_question(&context, "ka.hira.nu", &pool, KEY).unwrap(),
        None
    );

    // ka.kata.ka 的另一組是 kana_kanji（カ／力），不能當 kana_confuse
    let known = set(&["ka.kata.ka", "ka.hira.a"]);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);
    assert_eq!(
        kana_confuse_question(&context, "ka.kata.ka", &pool, KEY).unwrap(),
        None
    );
}

#[test]
fn kana_match_is_five_pairs_with_ids_on_both_sides() {
    let store = content();
    let known = HashSet::new();
    let context = ctx(&store, &known);
    let ids = [
        "ka.hira.a",
        "ka.hira.i",
        "ka.hira.u",
        "ka.hira.e",
        "ka.hira.o",
        "ka.hira.ka",
    ];

    let question = kana_match_question(&context, &ids, KEY).unwrap().unwrap();

    assert_eq!(question.question_type, QuestionType::KanaMatch);
    let QuestionBody::Match { pairs } = &question.body else {
        panic!("預期 Match");
    };
    assert_eq!(pairs.len(), 5);
    assert!(pairs.iter().all(|p| p.left_id == p.right_id));
    let mut rights: Vec<_> = pairs.iter().map(|p| p.right.as_str()).collect();
    rights.sort_unstable();
    rights.dedup();
    assert_eq!(rights.len(), 5);
    assert_eq!(kana_match_question(&context, &ids[..1], KEY).unwrap(), None);
}

#[test]
fn kana_match_does_not_pair_chars_with_same_reading() {
    let store = content();
    let known = HashSet::new();
    let context = ctx(&store, &known);
    let ids = ["ka.hira.ji", "ka.hira.di", "ka.hira.a"];

    let question = kana_match_question(&context, &ids, KEY).unwrap().unwrap();

    let QuestionBody::Match { pairs } = &question.body else {
        panic!("預期 Match");
    };
    assert_eq!(pairs.len(), 2);
}

#[test]
fn batch_quiz_gives_two_questions_per_char() {
    let store = content();
    let known = HashSet::new();
    let context = ctx(&store, &known);
    let batch = ["ka.hira.a", "ka.hira.i", "ka.hira.u"];
    let pool = KanaPool::taught(&store, &known, &batch);

    let questions = kana_batch_quiz(&context, &batch, &pool).unwrap();
    assert_eq!(questions.len(), 6);
    for id in batch {
        let (mut read, mut listen) = (0, 0);
        for q in questions.iter().filter(|q| q.reference.content_id == id) {
            match q.question_type {
                QuestionType::KanaRead => read += 1,
                QuestionType::KanaListen => listen += 1,
                other => panic!("非預期題型 {other:?}"),
            }
        }
        assert_eq!((read, listen), (1, 1), "{id}");
    }

    let silent_context = silent(&context);
    let questions = kana_batch_quiz(&silent_context, &batch, &pool).unwrap();
    assert_eq!(questions.len(), 6);
    assert!(questions
        .iter()
        .all(|q| q.question_type == QuestionType::KanaRead));
}

#[test]
fn confuse_quiz_asks_each_member_and_skips_non_confusable_groups() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let questions = confuse_quiz(&context, "ka.cf.nu_me", &pool).unwrap();
    assert_eq!(questions.len(), 2);
    assert!(questions
        .iter()
        .all(|q| q.question_type == QuestionType::KanaConfuse));

    let none = confuse_quiz(&context, "ka.cf.ka_chikara", &pool).unwrap();
    assert!(none.is_empty());
    assert!(matches!(
        confuse_quiz(&context, "ka.cf.nope", &pool),
        Err(jp_quiz::QuizError::NotFound { .. })
    ));
}

#[test]
fn groups_of_other_kinds_are_not_used_for_kana_confuse() {
    let store = content_with(&[(
        r#""id": "ka.cf.nu_me", "lesson": "le.k10", "kind": "shape""#,
        r#""id": "ka.cf.nu_me", "lesson": "le.k10", "kind": "listen""#,
    )]);
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    assert!(confuse_quiz(&context, "ka.cf.nu_me", &pool)
        .unwrap()
        .is_empty());
    assert_eq!(
        kana_confuse_question(&context, "ka.hira.nu", &pool, KEY).unwrap(),
        None
    );
}

#[test]
fn rule_quiz_is_minimal_pairs_and_empty_when_all_disabled() {
    let store = content();
    let known = HashSet::new();
    let context = ctx(&store, &known);

    let sokuon = rule_quiz(&context, "ka.rule.sokuon").unwrap();
    assert_eq!(sokuon.len(), 1);
    assert_eq!(sokuon[0].question_type, QuestionType::MinimalPair);

    assert!(rule_quiz(&context, "ka.rule.accent_intro")
        .unwrap()
        .is_empty());
    assert!(rule_quiz(&silent(&context), "ka.rule.sokuon")
        .unwrap()
        .is_empty());
    assert!(matches!(
        rule_quiz(&context, "ka.rule.nope"),
        Err(jp_quiz::QuizError::NotFound { .. })
    ));
}

#[test]
fn kana_session_covers_lesson_chars_with_its_own_batch_as_taught() {
    let store = content();
    let known = HashSet::new();
    let context = ctx(&store, &known);

    let questions = kana_session(&context, "le.k01").unwrap();

    assert_eq!(
        questions
            .iter()
            .filter(|q| q.question_type == QuestionType::KanaMatch)
            .count(),
        1
    );
    let reads = questions
        .iter()
        .filter(|q| q.question_type == QuestionType::KanaRead);
    assert_eq!(reads.count(), 5);
    assert_eq!(questions, kana_session(&context, "le.k01").unwrap());
    assert!(matches!(
        kana_session(&context, "le.nope"),
        Err(jp_quiz::QuizError::NotFound { .. })
    ));
}

#[test]
fn kana_session_includes_word_and_pair_drills_but_not_disabled_pairs() {
    let store = content();
    let known = HashSet::new();
    let context = ctx(&store, &known);

    let k05 = kana_session(&context, "le.k05").unwrap();
    assert!(k05
        .iter()
        .any(|q| q.question_type == QuestionType::KanaWord));

    let k19 = kana_session(&context, "le.k19").unwrap();
    assert!(
        k19.is_empty(),
        "K19 的 minimal_pair 全被 listen_disabled 排除"
    );

    let k16 = kana_session(&silent(&context), "le.k16").unwrap();
    assert!(k16
        .iter()
        .all(|q| q.question_type != QuestionType::MinimalPair));
}

#[test]
fn kana_session_confuse_questions_come_from_lesson_groups() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    let questions = kana_session(&context, "le.k10").unwrap();

    let confuse: Vec<_> = questions
        .iter()
        .filter(|q| q.question_type == QuestionType::KanaConfuse)
        .collect();
    assert_eq!(confuse.len(), 2);
}

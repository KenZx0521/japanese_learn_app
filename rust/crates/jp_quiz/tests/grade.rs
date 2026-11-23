//! §8.4、§9.6 作答判定。

mod common;

use common::*;
use jp_content::ContentStore;
use jp_quiz::drill::drill_question;
use jp_quiz::grade::{grade_answer, review_grade};
use jp_quiz::model::{AnswerPayload, QuestionRef, ShadowLevel};
use jp_quiz::{GradeResult, QuestionKey, QuestionType, QuizError};
use jp_srs::review::Grade;
use jp_srs::Rating;

fn drill_ref(question_type: QuestionType, drill_id: &str, variant: Option<u32>) -> QuestionRef {
    QuestionRef {
        question_type,
        card_id: None,
        drill_id: Some(drill_id.to_string()),
        content_id: "gr.desu".to_string(),
        variant,
    }
}

fn content_ref(question_type: QuestionType, content_id: &str) -> QuestionRef {
    QuestionRef {
        question_type,
        card_id: None,
        drill_id: None,
        content_id: content_id.to_string(),
        variant: None,
    }
}

fn choose(id: &str) -> AnswerPayload {
    AnswerPayload::Choice {
        option_id: id.to_string(),
    }
}

fn typed(input: &str) -> AnswerPayload {
    AnswerPayload::Typing {
        input: input.to_string(),
    }
}

fn grade(store: &ContentStore, reference: &QuestionRef, response: &AnswerPayload) -> GradeResult {
    grade_answer(store, reference, response).unwrap()
}

#[test]
fn particle_fill_grading_and_explanation() {
    let store = content();
    let reference = drill_ref(QuestionType::ParticleFill, "dr.l01.par.001", None);

    let right = grade(&store, &reference, &choose("c0"));
    assert!(right.is_correct);
    assert_eq!(right.correct_display, "{ja:は}");
    assert_eq!(right.explain_zh.as_deref(), Some("主題用 {ja:は}。"));
    assert_eq!(right.reveal.unwrap().id, "se.l01.001");
    assert!(!grade(&store, &reference, &choose("c1")).is_correct);
}

#[test]
fn zh_to_ja_reports_why_for_the_chosen_distractor() {
    let store = content();
    let reference = drill_ref(QuestionType::ZhToJaChoice, "dr.l01.z2j.001", None);

    let wrong = grade(&store, &reference, &choose("d0"));
    assert!(!wrong.is_correct);
    assert_eq!(wrong.why_zh.as_deref(), Some("這是說自己是學生。"));
    assert_eq!(wrong.correct_display, "{ja:私は先生。|わたしはせんせい。}");

    let right = grade(&store, &reference, &choose("a"));
    assert!(right.is_correct);
    assert_eq!(right.why_zh, None);
}

#[test]
fn situation_response_with_inline_answer_grades() {
    let store = content();
    let reference = drill_ref(QuestionType::SituationResponse, "dr.l01.sit.001", None);

    let right = grade(&store, &reference, &choose("a"));
    assert!(right.is_correct);
    assert_eq!(right.correct_display, "{ja:はじめまして。}");
}

#[test]
fn listen_meaning_and_false_friend_use_answer_index() {
    let store = content();
    let listen = drill_ref(QuestionType::ListenMeaning, "dr.l01.lsn.001", None);
    let friend = drill_ref(QuestionType::FalseFriend, "dr.l08.ffr.001", None);

    let heard = grade(&store, &listen, &choose("c0"));
    assert!(heard.is_correct);
    assert_eq!(heard.correct_display, "是的，是學生。");
    assert_eq!(heard.reveal.unwrap().id, "se.l01.003");
    assert!(!grade(&store, &listen, &choose("c2")).is_correct);

    let note = grade(&store, &friend, &choose("c0"));
    assert!(note.is_correct);
    assert!(note.explain_zh.unwrap().contains("信（書信）"));
}

#[test]
fn reorder_accepts_any_listed_order() {
    let store = content();
    let reference = drill_ref(QuestionType::Reorder, "dr.l02.ord.001", None);
    let order = |order: Vec<u32>| AnswerPayload::Reorder { order };

    assert!(grade(&store, &reference, &order(vec![0, 1, 2])).is_correct);
    assert!(grade(&store, &reference, &order(vec![1, 0, 2])).is_correct);
    assert!(!grade(&store, &reference, &order(vec![2, 1, 0])).is_correct);
    assert!(!grade(&store, &reference, &order(vec![0, 1])).is_correct);
}

#[test]
fn register_convert_must_match_target_word_order() {
    let store = content();
    let reference = drill_ref(QuestionType::RegisterConvert, "dr.l21.reg.001", None);

    let right = grade(
        &store,
        &reference,
        &AnswerPayload::Reorder { order: vec![0, 1] },
    );
    assert!(right.is_correct);
    assert_eq!(right.reveal.unwrap().id, "se.l21.001");
    assert!(
        !grade(
            &store,
            &reference,
            &AnswerPayload::Reorder { order: vec![1, 0] }
        )
        .is_correct
    );
}

#[test]
fn conjugate_generates_answer_from_variant() {
    let store = content();
    let eat = drill_ref(QuestionType::Conjugate, "dr.l02.cnj.001", Some(0));
    let drink = drill_ref(QuestionType::Conjugate, "dr.l02.cnj.001", Some(1));

    let right = grade(&store, &eat, &typed("tabemasu"));
    assert!(right.is_correct);
    assert_eq!(right.correct_display, "{ja:食べます|たべます}");
    assert!(!grade(&store, &drink, &typed("tabemasu")).is_correct);
    assert!(grade(&store, &drink, &typed("のみます")).is_correct);

    let out_of_range = drill_ref(QuestionType::Conjugate, "dr.l02.cnj.001", Some(2));
    assert!(matches!(
        grade_answer(&store, &out_of_range, &typed("x")),
        Err(QuizError::InvalidInput { .. })
    ));
}

#[test]
fn minimal_pair_variant_selects_correct_option() {
    let store = content();
    let play_a = drill_ref(QuestionType::MinimalPair, "dr.k11.mpr.001", Some(0));
    let play_b = drill_ref(QuestionType::MinimalPair, "dr.k11.mpr.001", Some(1));

    let right = grade(&store, &play_a, &choose("a"));
    assert!(right.is_correct);
    assert_eq!(right.correct_display, "{ja:か} 清音");
    assert!(!grade(&store, &play_a, &choose("b")).is_correct);
    assert!(grade(&store, &play_b, &choose("b")).is_correct);

    let bad = drill_ref(QuestionType::MinimalPair, "dr.k11.mpr.001", Some(2));
    assert!(matches!(
        grade_answer(&store, &bad, &choose("a")),
        Err(QuizError::InvalidInput { .. })
    ));
}

#[test]
fn kana_word_grading_for_both_modes() {
    let store = content();
    let choice = drill_ref(QuestionType::KanaWord, "dr.k05.kwd.001", None);
    let typing = drill_ref(QuestionType::KanaWord, "dr.k11.kwd.002", None);

    let right = grade(&store, &choice, &choose("c0"));
    assert!(right.is_correct);
    assert_eq!(right.correct_display, "狗");
    assert!(!grade(&store, &choice, &choose("c1")).is_correct);

    let spelled = grade(&store, &typing, &typed("kagi"));
    assert!(spelled.is_correct);
    assert_eq!(spelled.correct_display, "{ja:かぎ} 鑰匙");
    assert!(!grade(&store, &typing, &typed("kaki")).is_correct);
}

#[test]
fn shadowing_is_not_graded() {
    let store = content();
    let reference = drill_ref(QuestionType::Shadowing, "dr.l01.shd.001", None);

    for level in [ShadowLevel::Kept, ShadowLevel::Almost, ShadowLevel::Lost] {
        let result = grade(&store, &reference, &AnswerPayload::Shadow { level });
        assert!(result.is_correct);
        assert_eq!(result.reveal.as_ref().unwrap().id, "se.l01.002");
    }
}

#[test]
fn kana_questions_compare_item_ids() {
    let store = content();
    let read = content_ref(QuestionType::KanaRead, "ka.hira.a");
    let listen = content_ref(QuestionType::KanaListen, "ka.hira.a");
    let confuse = content_ref(QuestionType::KanaConfuse, "ka.hira.nu");

    let right = grade(&store, &read, &choose("ka.hira.a"));
    assert!(right.is_correct);
    assert_eq!(right.correct_display, "a");
    assert!(!grade(&store, &read, &choose("ka.hira.i")).is_correct);
    assert_eq!(
        grade(&store, &listen, &choose("ka.hira.a")).correct_display,
        "{ja:あ} a"
    );
    assert_eq!(
        grade(&store, &confuse, &choose("ka.hira.nu")).correct_display,
        "{ja:ぬ}"
    );
}

#[test]
fn match_is_reported_by_dart() {
    let store = content();
    let reference = content_ref(QuestionType::KanaMatch, "ka.hira.a");

    assert!(
        grade(
            &store,
            &reference,
            &AnswerPayload::Match { all_correct: true }
        )
        .is_correct
    );
    assert!(
        !grade(
            &store,
            &reference,
            &AnswerPayload::Match { all_correct: false }
        )
        .is_correct
    );
}

#[test]
fn vocab_choice_and_self_grade() {
    let store = content();
    let recog = content_ref(QuestionType::Recog, "vo.hai");
    let produce = content_ref(QuestionType::Produce, "vo.gohan");

    let right = grade(&store, &recog, &choose("vo.hai"));
    assert!(right.is_correct);
    assert_eq!(right.correct_display, "是、好");
    assert_eq!(right.reveal.unwrap().id, "vo.hai");
    assert!(!grade(&store, &recog, &choose("vo.gohan")).is_correct);

    let again = AnswerPayload::SelfGrade {
        rating: Rating::Again,
    };
    let good = AnswerPayload::SelfGrade {
        rating: Rating::Good,
    };
    assert!(!grade(&store, &recog, &again).is_correct);
    assert!(grade(&store, &recog, &good).is_correct);

    let recalled = grade(&store, &produce, &good);
    assert!(recalled.is_correct);
    assert_eq!(recalled.correct_display, "{ja:ご飯|ごはん}");
}

#[test]
fn use_card_example_fallback_grades_self_rating() {
    let store = content();
    let reference = QuestionRef {
        card_id: Some("gr.desu:use".to_string()),
        ..content_ref(QuestionType::Recog, "gr.desu")
    };

    let result = grade(
        &store,
        &reference,
        &AnswerPayload::SelfGrade {
            rating: Rating::Hard,
        },
    );

    assert!(result.is_correct);
    assert_eq!(result.correct_display, "{ja:です}：是");
    assert_eq!(result.reveal, None);
}

#[test]
fn auto_listen_meaning_and_shadowing_use_sentence_id() {
    let store = content();
    let listen = content_ref(QuestionType::ListenMeaning, "se.l01.003");
    let shadow = content_ref(QuestionType::Shadowing, "se.l01.003");

    let right = grade(&store, &listen, &choose("s:se.l01.003"));
    assert!(right.is_correct);
    assert_eq!(right.correct_display, "是的，是學生。");
    assert_eq!(right.reveal.unwrap().id, "se.l01.003");
    assert!(!grade(&store, &listen, &choose("s:se.l01.004")).is_correct);

    let followed = AnswerPayload::Shadow {
        level: ShadowLevel::Almost,
    };
    assert!(grade(&store, &shadow, &followed).is_correct);
}

#[test]
fn mismatched_payload_is_invalid_input() {
    let store = content();

    let cases = [
        (
            drill_ref(QuestionType::ParticleFill, "dr.l01.par.001", None),
            typed("x"),
        ),
        (content_ref(QuestionType::KanaRead, "ka.hira.a"), typed("a")),
        (
            content_ref(QuestionType::KanaMatch, "ka.hira.a"),
            choose("a"),
        ),
        (content_ref(QuestionType::Produce, "vo.gohan"), choose("a")),
        (
            content_ref(QuestionType::ListenMeaning, "se.l01.003"),
            typed("a"),
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
fn unknown_items_are_not_found() {
    let store = content();

    let cases = [
        drill_ref(QuestionType::ParticleFill, "dr.nope", None),
        content_ref(QuestionType::KanaRead, "ka.hira.nope"),
        content_ref(QuestionType::Recog, "vo.nope"),
        content_ref(QuestionType::Produce, "vo.nope"),
        content_ref(QuestionType::ListenMeaning, "se.nope"),
    ];
    for reference in cases {
        assert!(
            matches!(
                grade_answer(&store, &reference, &choose("x")),
                Err(QuizError::NotFound { .. })
            ),
            "{reference:?}"
        );
    }
}

#[test]
fn drill_reference_is_graded_without_regenerating_the_question() {
    let store = content();
    let known = all_known(&store);

    for seed in 0..40 {
        let context = with_seed(&ctx(&store, &known), seed);
        let question = drill_question(
            &context,
            drill(&store, "dr.l01.lsn.001"),
            QuestionKey::plain("dr.l01.lsn.001"),
            None,
        )
        .unwrap();
        let answer = choose(correct_id(&question));
        assert!(grade(&store, &question.reference, &answer).is_correct);
    }
}

#[test]
fn review_grade_follows_payload_kind() {
    let self_rated = AnswerPayload::SelfGrade {
        rating: Rating::Easy,
    };
    assert_eq!(
        review_grade(&self_rated, true, false, 1),
        Grade::SelfRated(Rating::Easy)
    );

    let auto = review_grade(&choose("a"), true, false, 2);
    assert_eq!(
        auto,
        Grade::Auto {
            is_correct: true,
            hint_used: false,
            attempts: 2
        }
    );
}

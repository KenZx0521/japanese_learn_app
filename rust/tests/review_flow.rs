//! §11.2 `review_flow`：透過公開 API 走新卡→學習→複習，評分、log、連點防護。

mod common;

use chrono::Duration;
use common::*;
use jp_core::api::dto_plan::StartLevel;
use jp_core::api::dto_study::{
    AnswerDto, AnswerPayload, QuestionRefDto, QuestionType, Rating, SessionNextDto,
};
use jp_core::api::error::CoreError;

/// 第一天學完 3 字，切到第二天。
fn app_on_day_two() -> TestApp {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);
    app.next_day();
    app
}

#[test]
fn new_card_moves_through_learning_into_review() {
    let mut app = app_on_day_two();
    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    assert_eq!(card.expected_reps, 0);
    let id = card.card_id.clone();

    let first = app
        .core
        .submit_answer(answer_for(&card, correct_payload(&card.question)))
        .unwrap();
    assert_eq!(first.rating, Rating::Good);
    assert!(first.next_due_in_minutes > 0);

    // 學習階段過後再答一次，進入複習（間隔以天計）
    app.advance(Duration::minutes(first.next_due_in_minutes + 1));
    let mut interval = first.next_due_in_minutes;
    for _ in 0..4 {
        let next = expect_card(app.core.session_next(SEED, true).unwrap());
        if next.card_id != id {
            break;
        }
        let result = app
            .core
            .submit_answer(answer_for(&next, correct_payload(&next.question)))
            .unwrap();
        interval = result.next_due_in_minutes;
        if interval >= 24 * 60 {
            break;
        }
        app.advance(Duration::minutes(interval + 1));
    }
    assert!(
        interval >= 24 * 60,
        "連續答對應進入以天計的間隔：{interval} 分鐘"
    );

    let stats = app.core.stats_overview().unwrap();
    assert!(stats.total_reviews >= 2);
    assert!(stats.cards_review >= 1);
}

#[test]
fn wrong_answer_rates_again_and_hint_or_retry_rates_hard() {
    let app = app_on_day_two();

    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    let wrong = app
        .core
        .submit_answer(answer_for(&card, wrong_payload(&card.question)))
        .unwrap();
    assert!(!wrong.is_correct);
    assert_eq!(wrong.rating, Rating::Again);

    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    let answer = AnswerDto {
        hint_used: true,
        ..answer_for(&card, correct_payload(&card.question))
    };
    assert_eq!(app.core.submit_answer(answer).unwrap().rating, Rating::Hard);

    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    let answer = AnswerDto {
        attempts: 2,
        ..answer_for(&card, correct_payload(&card.question))
    };
    assert_eq!(app.core.submit_answer(answer).unwrap().rating, Rating::Hard);
}

#[test]
fn double_tap_returns_stale_card_and_writes_once() {
    let app = app_on_day_two();
    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    let answer = answer_for(&card, correct_payload(&card.question));

    app.core.submit_answer(answer.clone()).unwrap();
    let err = app.core.submit_answer(answer).unwrap_err();

    assert!(matches!(err, CoreError::StaleCard { .. }), "{err:?}");
    assert_eq!(app.core.stats_overview().unwrap().total_reviews, 1);
}

#[test]
fn activity_counts_first_contact_and_duration() {
    let app = app_on_day_two();
    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    app.core
        .submit_answer(answer_for(&card, correct_payload(&card.question)))
        .unwrap();

    let rows = app
        .core
        .activity_range("2026-03-03".into(), "2026-03-03".into())
        .unwrap();

    assert_eq!(rows[0].date, "2026-03-03");
    assert_eq!(rows[0].answers, 1);
    assert!(rows[0].study_minutes > 0.0);
}

#[test]
fn submit_rejects_references_that_do_not_resolve_to_a_card() {
    let app = app_on_day_two();
    let card = expect_card(app.core.session_next(SEED, true).unwrap());

    // 沒有 card_id
    let no_card = AnswerDto {
        reference: QuestionRefDto {
            card_id: None,
            ..card.question.reference.clone()
        },
        ..answer_for(&card, correct_payload(&card.question))
    };
    assert!(matches!(
        app.core.submit_answer(no_card).unwrap_err(),
        CoreError::InvalidInput { .. }
    ));

    // 卡片不存在
    let missing = AnswerDto {
        reference: QuestionRefDto {
            card_id: Some("ka.hira.ka:read".to_owned()),
            content_id: "ka.hira.ka".to_owned(),
            question_type: QuestionType::KanaRead,
            drill_id: None,
            variant: None,
        },
        ..answer_for(
            &card,
            AnswerPayload::Choice {
                option_id: "ka.hira.ka".to_owned(),
            },
        )
    };
    assert!(matches!(
        app.core.submit_answer(missing).unwrap_err(),
        CoreError::NotFound { .. }
    ));
}

#[test]
fn session_summary_matches_the_queue_and_audio_filter() {
    let app = app_on_day_two();

    let summary = app.core.session_summary(true).unwrap();
    assert_eq!(summary.due_reviews, 0);
    assert_eq!(summary.learning, 0);
    assert_eq!(summary.new_cards, 3);
    assert_eq!(summary.reviews_done_today, 0);
    assert!(summary.review_cap >= 1);

    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    assert_eq!(card.remaining_estimate, 3);
    let next = app.core.session_next(SEED, false).unwrap();
    assert!(
        matches!(next, SessionNextDto::Card { .. }),
        "read 卡不需要語音"
    );
}

#[test]
fn queue_requires_an_active_plan() {
    let app = TestApp::new();

    assert!(matches!(
        app.core.session_next(SEED, true).unwrap_err(),
        CoreError::NoActivePlan
    ));
    assert!(matches!(
        app.core.today_view(true).unwrap_err(),
        CoreError::NoActivePlan
    ));
    assert!(matches!(
        app.core.plan_view().unwrap_err(),
        CoreError::NoActivePlan
    ));
}

#[test]
fn kana_session_for_free_practice_does_not_create_cards_or_need_a_plan() {
    let app = TestApp::new();

    let questions = app.core.kana_session("le.k01".into(), SEED, true).unwrap();
    assert!(!questions.is_empty());
    let read = questions
        .iter()
        .find(|q| q.question_type == QuestionType::KanaRead)
        .unwrap();

    let first = app
        .core
        .kana_submit(read.reference.clone(), correct_payload(read), 1_000)
        .unwrap();
    let second = app
        .core
        .kana_submit(read.reference.clone(), correct_payload(read), 1_000)
        .unwrap();

    assert_eq!(first.mastery.as_ref().unwrap().run, 1);
    let mastery = second.mastery.unwrap();
    assert!(mastery.mastered);
    assert_eq!(mastery.required, 2);
    assert!(mastery.fast_badge);
    let counts = app.core.stats_overview().unwrap();
    assert_eq!(counts.cards_new, 0, "自由練習不建卡");
    assert_eq!(counts.kana_mastered, 1);
}

#[test]
fn kana_submit_ignores_mastery_for_match_and_rejects_unknown_lessons() {
    let app = TestApp::new();
    let questions = app.core.kana_session("le.k01".into(), SEED, true).unwrap();
    let matching = questions
        .iter()
        .find(|q| q.question_type == QuestionType::KanaMatch)
        .expect("K01 有 kana_match");

    let result = app
        .core
        .kana_submit(
            matching.reference.clone(),
            AnswerPayload::Match { all_correct: true },
            1_000,
        )
        .unwrap();

    assert!(result.is_correct);
    assert!(result.mastery.is_none());
    assert!(matches!(
        app.core
            .kana_session("le.nope".into(), SEED, true)
            .unwrap_err(),
        CoreError::NotFound { .. }
    ));
}

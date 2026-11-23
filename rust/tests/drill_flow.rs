//! 演練、聽力、檢定（rust-core.md §7.4、§8.4、§8.5）。

mod common;

use common::*;
use jp_core::api::dto_plan::{StartLevel, TaskDto};
use jp_core::api::dto_study::{
    AnswerDto, AnswerPayload, DrillFilterDto, QuestionBodyDto, QuestionDto, QuestionType,
    ShadowLevel,
};
use jp_core::api::error::CoreError;

/// 學完 L01 全部字與文法，游標停在整合日。
fn app_after_l01_slices() -> TestApp {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));
    for _ in 0..2 {
        study_full_day(&app, true);
        app.next_day();
    }
    app
}

/// L01 全部完成的隔天：不是整合日，`Drill`、`Listen` 都會列出。
fn app_with_practice_tasks() -> TestApp {
    let mut app = app_after_l01_slices();
    study_full_day(&app, true);
    app.next_day();
    app
}

fn answer(question: &QuestionDto, response: AnswerPayload) -> AnswerDto {
    AnswerDto {
        reference: question.reference.clone(),
        expected_reps: 0,
        response,
        hint_used: false,
        attempts: 1,
        duration_ms: 700,
    }
}

fn answers_today(app: &TestApp) -> u32 {
    let date = app.today().logical_date;
    app.core
        .activity_range(date.clone(), date)
        .unwrap()
        .first()
        .map_or(0, |row| row.answers)
}

#[test]
fn drill_session_by_lesson_only_uses_introduced_items() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));

    let filter = DrillFilterDto {
        lesson_id: Some("le.l01".to_owned()),
        ..DrillFilterDto::default()
    };
    assert!(app
        .core
        .drill_session(filter.clone(), SEED, true)
        .unwrap()
        .is_empty());
    let app = app_after_l01_slices();

    let questions = app.core.drill_session(filter, SEED, true).unwrap();
    assert!(!questions.is_empty());
    let fixed = app.core.drill_session(
        DrillFilterDto {
            lesson_id: Some("le.l01".to_owned()),
            ..DrillFilterDto::default()
        },
        SEED,
        true,
    );
    assert_eq!(fixed.unwrap(), questions, "同種子同結果");
}

#[test]
fn drill_session_honors_count_explicit_ids_and_audio() {
    let app = app_after_l01_slices();

    let limited = DrillFilterDto {
        lesson_id: Some("le.l01".to_owned()),
        count: 2,
        ..DrillFilterDto::default()
    };
    assert_eq!(
        app.core.drill_session(limited, SEED, true).unwrap().len(),
        2
    );

    let explicit = DrillFilterDto {
        drill_ids: vec!["dr.l01.lsn.001".to_owned()],
        ..DrillFilterDto::default()
    };
    assert_eq!(
        app.core
            .drill_session(explicit.clone(), SEED, true)
            .unwrap()
            .len(),
        1
    );
    assert!(
        app.core
            .drill_session(explicit, SEED, false)
            .unwrap()
            .is_empty(),
        "聽力題需要語音"
    );

    let by_target = DrillFilterDto {
        target: Some("gr.desu".to_owned()),
        count: 1,
        ..DrillFilterDto::default()
    };
    assert_eq!(
        app.core.drill_session(by_target, SEED, true).unwrap().len(),
        1
    );
}

#[test]
fn drill_task_key_resolves_lessons_and_question_count_from_the_snapshot() {
    let app = app_with_practice_tasks();
    let today = app.today();
    let (key, questions) = today
        .tasks
        .iter()
        .find_map(|t| match t {
            TaskDto::Drill { key, questions, .. } => Some((key.clone(), *questions)),
            _ => None,
        })
        .expect("L01 學過後應列 Drill");

    let filter = DrillFilterDto {
        task_key: Some(key),
        ..DrillFilterDto::default()
    };
    let drawn = app.core.drill_session(filter, SEED, true).unwrap();

    assert_eq!(drawn.len() as u32, questions);
    assert!(questions >= 2, "夾具要有足夠的題目才能驗 count 覆寫");
    let overridden = DrillFilterDto {
        task_key: Some("drill".to_owned()),
        count: 1,
        ..DrillFilterDto::default()
    };
    assert_eq!(
        app.core
            .drill_session(overridden, SEED, true)
            .unwrap()
            .len(),
        1
    );
    let unknown = DrillFilterDto {
        task_key: Some("review".to_owned()),
        ..DrillFilterDto::default()
    };
    assert!(matches!(
        app.core.drill_session(unknown, SEED, true).unwrap_err(),
        CoreError::NotFound { .. }
    ));
}

#[test]
fn grade_drill_is_judged_by_rust_and_counts_practice_only() {
    let app = app_after_l01_slices();
    let filter = DrillFilterDto {
        drill_ids: vec!["dr.l01.par.001".to_owned()],
        ..DrillFilterDto::default()
    };
    let question = app
        .core
        .drill_session(filter, SEED, true)
        .unwrap()
        .remove(0);
    let reviews_before = app.core.stats_overview().unwrap().total_reviews;
    let answered_before = answers_today(&app);

    let right = app
        .core
        .grade_drill(question.reference.clone(), correct_payload(&question))
        .unwrap();
    let wrong = app
        .core
        .grade_drill(question.reference.clone(), wrong_payload(&question))
        .unwrap();

    assert!(right.is_correct);
    assert!(!wrong.is_correct);
    assert!(!right.correct_display.is_empty());
    assert_eq!(answers_today(&app), answered_before + 2);
    assert_eq!(
        app.core.stats_overview().unwrap().total_reviews,
        reviews_before,
        "演練不寫 FSRS"
    );
}

#[test]
fn listen_session_mixes_shadowing_and_needs_audio() {
    let app = app_with_practice_tasks();
    let today = app.today();
    let key = today
        .tasks
        .iter()
        .find_map(|t| match t {
            TaskDto::Listen { key, .. } => Some(key.clone()),
            _ => None,
        })
        .expect("句子可用後應列 Listen");

    let wrong_key = app.core.listen_session("nope".to_owned(), SEED, true);
    assert!(matches!(wrong_key.unwrap_err(), CoreError::NotFound { .. }));
    let questions = app.core.listen_session(key.clone(), SEED, true).unwrap();

    assert!(!questions.is_empty());
    assert!(app
        .core
        .listen_session(key, SEED, false)
        .unwrap()
        .is_empty());
    if let Some(shadow) = questions
        .iter()
        .find(|q| q.question_type == QuestionType::Shadowing)
    {
        assert!(matches!(shadow.body, QuestionBodyDto::Shadow { .. }));
        let before = answers_today(&app);
        let result = app
            .core
            .grade_drill(
                shadow.reference.clone(),
                AnswerPayload::Shadow {
                    level: ShadowLevel::Almost,
                },
            )
            .unwrap();
        assert!(result.is_correct);
        assert_eq!(answers_today(&app), before + 1);
    }
}

#[test]
fn checkpoint_finish_scores_and_reports_weak_ids() {
    let app = TestApp::new();
    let exam = app
        .core
        .checkpoint_start("ms.hira".into(), SEED, true)
        .unwrap();
    assert!(!exam.is_empty());

    let mut answers: Vec<AnswerDto> = exam.iter().map(|q| answer(q, correct_payload(q))).collect();
    let weak = exam[0].reference.content_id.clone();
    answers[0] = answer(&exam[0], wrong_payload(&exam[0]));
    // 同一題重複時只算第一筆
    answers.push(answer(&exam[0], correct_payload(&exam[0])));

    let result = app
        .core
        .checkpoint_finish("ms.hira".into(), answers)
        .unwrap();

    assert_eq!(result.total as usize, exam.len());
    assert_eq!(result.correct as usize, exam.len() - 1);
    assert_eq!(result.weak_ids, [weak]);
    assert_eq!(result.score_percent, result.correct * 100 / result.total);
    assert_eq!(
        app.core.stats_overview().unwrap().total_reviews,
        0,
        "檢定不寫 FSRS"
    );
}

#[test]
fn checkpoint_rejects_empty_answers_and_unknown_milestones() {
    let app = TestApp::new();

    assert!(matches!(
        app.core
            .checkpoint_finish("ms.hira".into(), Vec::new())
            .unwrap_err(),
        CoreError::InvalidInput { .. }
    ));
    assert!(matches!(
        app.core
            .checkpoint_start("ms.nope".into(), SEED, true)
            .unwrap_err(),
        CoreError::NotFound { .. }
    ));
}

#[test]
fn passed_checkpoint_shows_on_the_plan_with_its_best_score() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    let exam = app
        .core
        .checkpoint_start("ms.hira".into(), SEED, true)
        .unwrap();
    let answers = exam.iter().map(|q| answer(q, correct_payload(q))).collect();

    let result = app
        .core
        .checkpoint_finish("ms.hira".into(), answers)
        .unwrap();

    assert!(result.passed);
    let plan = app.core.plan_view().unwrap();
    let milestone = plan.milestones.iter().find(|m| m.id == "ms.hira").unwrap();
    assert!(milestone.passed);
    assert_eq!(milestone.best_score_percent, Some(100));
}

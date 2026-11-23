//! §11.2 `plan_flow`：快照、同日改計畫、受限與回鍋、再學一批、檢定。

mod common;

use chrono::Duration;
use common::*;
use jp_core::api::dto_content::LessonStatus;
use jp_core::api::dto_plan::{PlanInputDto, PlanStatus, RecoveryReason, StartLevel, TaskDto};
use jp_core::api::dto_study::{AnswerDto, QuestionType, SessionNextDto};
use jp_core::api::error::CoreError;

fn has_checkpoint(app: &TestApp, id: &str) -> bool {
    app.today()
        .tasks
        .iter()
        .any(|task| matches!(task, TaskDto::Checkpoint { milestone_id, .. } if milestone_id == id))
}

#[test]
fn snapshot_stays_frozen_while_the_day_progresses() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    let before = app.today();

    study_full_day(&app, true);

    let after = app.today();
    let keys = |view: &jp_core::api::dto_plan::TodayViewDto| {
        view.tasks
            .iter()
            .map(|t| task_key(t).to_owned())
            .collect::<Vec<_>>()
    };
    assert_eq!(keys(&before), keys(&after));
    assert_eq!(before.budget, after.budget);
}

#[test]
fn updating_the_plan_the_same_day_rebuilds_today() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    assert_eq!(app.today().budget.kana_chars_limit, 5);
    // S0 的 review 8 分＝480 秒，沒有到期卡：60 張，積壓判定用的容量與上限相同。
    assert_eq!(app.today().budget.capacity, 60);

    let view = app
        .core
        .update_plan(plan_input(45, StartLevel::Zero))
        .unwrap();

    assert_eq!(view.input.daily_minutes, 45);
    let today = app.today();
    assert_eq!(today.budget.kana_chars_limit, 10);
    let TaskDto::NewContent { kana, .. } = &today.tasks[1] else {
        panic!();
    };
    assert_eq!(*kana, 3, "第一批固定 3 字");
}

/// 只改目標日不影響今天：游標已前進，重建會多給一個切片（§7.1）。
#[test]
fn updating_only_the_target_date_keeps_todays_tasks() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));
    study_full_day(&app, true);
    let before = app.today();
    assert!(before.tasks.iter().all(task_done));

    let view = app
        .core
        .update_plan(PlanInputDto {
            target_date: Some("2027-01-01".to_owned()),
            ..plan_input(20, StartLevel::Kana)
        })
        .unwrap();

    assert_eq!(view.input.target_date.as_deref(), Some("2027-01-01"));
    let after = app.today();
    assert_eq!(new_content_key(&after), new_content_key(&before));
    assert!(after.tasks.iter().all(task_done));
}

/// 新增略過的課會改變切片，今天的快照要重算。
#[test]
fn newly_skipped_lessons_rebuild_today() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    let before = new_content_key(&app.today());

    app.core
        .update_plan(PlanInputDto {
            known_kana_lessons: vec!["le.k01".to_owned()],
            ..plan_input(20, StartLevel::Zero)
        })
        .unwrap();

    assert_ne!(new_content_key(&app.today()), before);
}

#[test]
fn update_plan_without_a_plan_reports_no_active_plan() {
    let app = TestApp::new();

    assert!(matches!(
        app.core
            .update_plan(plan_input(20, StartLevel::Zero))
            .unwrap_err(),
        CoreError::NoActivePlan
    ));
}

#[test]
fn plan_stays_active_when_timezone_moves_logical_day_before_effective_date() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));

    app.advance(Duration::days(-1));

    assert!(app.core.today_view(true).is_ok());
    assert_eq!(app.core.plan_view().unwrap().input.daily_minutes, 20);
}

#[test]
fn plan_input_is_validated_at_the_boundary() {
    let app = TestApp::new();
    let cases = [
        (
            "daily_minutes",
            PlanInputDto {
                daily_minutes: 15,
                ..plan_input(20, StartLevel::Zero)
            },
        ),
        (
            "weekdays",
            PlanInputDto {
                weekdays: vec![],
                ..plan_input(20, StartLevel::Zero)
            },
        ),
        (
            "weekdays",
            PlanInputDto {
                weekdays: vec![8],
                ..plan_input(20, StartLevel::Zero)
            },
        ),
        (
            "target_date",
            PlanInputDto {
                target_date: Some("2026-13-01".to_owned()),
                ..plan_input(20, StartLevel::Zero)
            },
        ),
        (
            "known_kana_lessons",
            PlanInputDto {
                known_kana_lessons: vec!["le.l01".to_owned()],
                ..plan_input(20, StartLevel::Zero)
            },
        ),
    ];

    for (field, input) in cases {
        match app.core.create_plan(input).unwrap_err() {
            CoreError::InvalidInput { field: actual, .. } => assert_eq!(actual, field),
            other => panic!("{field}: {other:?}"),
        }
    }
}

#[test]
fn non_study_days_only_offer_due_reviews_and_the_next_date() {
    let mut app = TestApp::new();
    // 只排週一：2026-03-02 是學習日，隔天不是
    app.start_plan(&PlanInputDto {
        weekdays: vec![1],
        ..plan_input(20, StartLevel::Zero)
    });
    assert!(app.today().is_study_day);
    study_full_day(&app, true);

    app.next_day();
    let today = app.today();

    assert!(!today.is_study_day);
    assert_eq!(today.next_study_date.as_deref(), Some("2026-03-09"));
    assert!(!today
        .tasks
        .iter()
        .any(|t| matches!(t, TaskDto::NewContent { .. })));
    assert!(!today.can_learn_more);
}

#[test]
fn skipped_lessons_are_marked_and_the_cursor_starts_after_them() {
    let app = TestApp::new();
    let input = PlanInputDto {
        known_kana_lessons: vec!["le.k01".to_owned(), "le.k02".to_owned()],
        ..plan_input(20, StartLevel::Zero)
    };

    let view = app.core.create_plan(input).unwrap();

    assert_eq!(view.current_lesson_id.as_deref(), Some("le.k03"));
    assert_eq!(view.input.known_kana_lessons, ["le.k01", "le.k02"]);
    let overview = app.core.course_overview().unwrap();
    let status_of = |id: &str| overview.lessons.iter().find(|l| l.id == id).unwrap().status;
    assert_eq!(status_of("le.k01"), LessonStatus::Skipped);
    assert_eq!(status_of("le.k03"), LessonStatus::Current);
    assert_eq!(status_of("le.k04"), LessonStatus::NotStarted);
}

#[test]
fn hiragana_start_level_begins_with_l01() {
    let app = TestApp::new();

    let view = app
        .core
        .create_plan(plan_input(20, StartLevel::Hiragana))
        .unwrap();

    assert_eq!(view.current_lesson_id.as_deref(), Some("le.l01"));
    assert_eq!(view.stage_id.as_deref(), Some("st.s1"));
    assert!(
        view.input.known_kana_lessons.is_empty(),
        "start_level 跳過的課不算個別略過"
    );
}

#[test]
fn preview_does_not_write_and_works_before_a_plan_exists() {
    let app = TestApp::new();

    let preview = app
        .core
        .plan_preview(plan_input(20, StartLevel::Kana))
        .unwrap();

    assert_eq!(preview.current_lesson_id.as_deref(), Some("le.l01"));
    assert!(preview.main_forecast_end.is_some());
    assert_eq!(preview.status, PlanStatus::NoTarget);
    assert!(preview
        .milestones
        .iter()
        .all(|m| m.planned_date.is_none() && m.delay_days == 0));
    assert!(matches!(
        app.core.plan_view().unwrap_err(),
        CoreError::NoActivePlan
    ));
    assert_eq!(
        app.core
            .course_overview()
            .unwrap()
            .current_lesson_id
            .as_deref(),
        Some("le.k01")
    );
}

#[test]
fn target_date_reports_behind_with_a_suggestion() {
    let app = TestApp::new();
    let input = PlanInputDto {
        target_date: Some("2026-03-20".to_owned()),
        ..plan_input(10, StartLevel::Zero)
    };

    let view = app.core.create_plan(input).unwrap();

    assert_eq!(view.status, PlanStatus::Behind);
    assert_eq!(view.input.target_date.as_deref(), Some("2026-03-20"));
}

#[test]
fn reachable_target_is_on_track_and_has_no_suggestion() {
    let app = TestApp::new();
    let input = PlanInputDto {
        target_date: Some("2036-01-01".to_owned()),
        ..plan_input(20, StartLevel::Zero)
    };

    let view = app.core.create_plan(input).unwrap();

    assert_eq!(view.status, PlanStatus::OnTrack);
    assert_eq!(view.suggested_minutes, None, "§7.5 只有 Behind 才建議");
}

#[test]
fn behind_plan_suggests_a_longer_preset_when_one_reaches_the_target() {
    let app = TestApp::new();
    let relaxed = app
        .core
        .plan_preview(plan_input(45, StartLevel::Zero))
        .unwrap();
    let reachable_by_45 = relaxed.main_forecast_end.unwrap();
    let input = PlanInputDto {
        target_date: Some(reachable_by_45),
        ..plan_input(10, StartLevel::Zero)
    };

    let view = app.core.create_plan(input).unwrap();

    assert_eq!(view.status, PlanStatus::Behind);
    assert!(view.suggested_minutes.is_some_and(|minutes| minutes > 10));
}

#[test]
fn milestones_merge_baseline_with_the_live_forecast() {
    let mut app = TestApp::new();
    let created = app
        .core
        .create_plan(plan_input(20, StartLevel::Zero))
        .unwrap();
    let first = &created.milestones[0];
    assert_eq!(first.id, "ms.hira");
    assert_eq!(first.forecast_date, first.planned_date);
    assert_eq!(first.delay_days, 0);
    assert!((first.pass_ratio - 0.9).abs() < 1e-9);
    assert_eq!(first.questions, 20);

    // 缺席 3 天，游標沒動，預測整體後移
    app.advance(Duration::days(3));
    let later = app.core.plan_view().unwrap();

    assert_eq!(later.milestones[0].delay_days, 3);
    assert_eq!(later.milestones[0].planned_date, first.planned_date);
}

#[test]
fn three_missed_study_days_trigger_return_after_break() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);

    app.advance(Duration::days(4));
    let today = app.today();

    assert_eq!(
        today.recovery_reason,
        Some(RecoveryReason::ReturnAfterBreak)
    );
    assert!(!today.minimal_new);
    assert!(!today
        .tasks
        .iter()
        .any(|t| matches!(t, TaskDto::NewContent { .. })));
}

#[test]
fn unseen_cards_block_new_content_for_two_days_then_a_minimal_slice() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));
    // 結案了卻沒作答：教過但還沒做的 state=0 卡（6 張以上）留到隔天
    let key = new_content_key(&app.today()).unwrap();
    app.core
        .new_content_session(key.clone(), SEED, true)
        .unwrap();
    app.core.complete_task(key, 1_000, true).unwrap();

    for _ in 0..2 {
        app.next_day();
        let today = app.today();
        assert_eq!(today.recovery_reason, Some(RecoveryReason::UnseenNewCards));
        assert!(!today.minimal_new);
        assert!(new_content_key(&today).is_none());
    }

    app.next_day();
    let today = app.today();
    assert_eq!(today.recovery_reason, Some(RecoveryReason::UnseenNewCards));
    assert!(today.minimal_new);
    let task = today
        .tasks
        .iter()
        .find(|t| matches!(t, TaskDto::NewContent { .. }))
        .unwrap();
    assert!(matches!(
        task,
        TaskDto::NewContent {
            words: 3,
            grammar: 0,
            ..
        }
    ));
}

#[test]
fn thirty_days_of_normal_use_never_report_unseen_new_cards() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));

    for day in 0..30 {
        let today = study_full_day(&app, true);
        assert_ne!(
            today.recovery_reason,
            Some(RecoveryReason::UnseenNewCards),
            "第 {day} 天"
        );
        app.next_day();
    }

    assert!(app.core.stats_overview().unwrap().streak_current >= 29);
}

#[test]
fn muted_learner_with_same_form_words_is_not_blocked() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));

    for day in 0..10 {
        let today = app.core.today_view(false).unwrap();
        assert_ne!(
            today.recovery_reason,
            Some(RecoveryReason::UnseenNewCards),
            "第 {day} 天"
        );
        assert!(!today
            .tasks
            .iter()
            .any(|t| matches!(t, TaskDto::Listen { .. })));
        study_full_day(&app, false);
        loop {
            match app.core.session_next(SEED, false).unwrap() {
                SessionNextDto::Done { .. } => break,
                SessionNextDto::Card { card } => {
                    assert_ne!(card.facet, "listen");
                    app.core
                        .submit_answer(answer_for(&card, correct_payload(&card.question)))
                        .unwrap();
                }
            }
        }
        app.next_day();
    }
}

#[test]
fn learn_more_appends_the_next_slice_without_blocking_tomorrow() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));

    assert!(matches!(
        app.core.learn_more(true).unwrap_err(),
        CoreError::InvalidInput { .. }
    ));

    study_full_day(&app, true);
    let done = app.today();
    assert!(done.can_learn_more);

    let more = app.core.learn_more(true).unwrap();
    let new_tasks = more
        .tasks
        .iter()
        .filter(|t| matches!(t, TaskDto::NewContent { .. }))
        .count();
    assert_eq!(new_tasks, 2, "附加第二個切片");

    let TaskDto::NewContent { key, .. } = more
        .tasks
        .iter()
        .rev()
        .find(|t| matches!(t, TaskDto::NewContent { .. }))
        .unwrap()
    else {
        unreachable!();
    };
    let session = app
        .core
        .new_content_session(key.clone(), SEED, true)
        .unwrap();
    walk_new_content(&app.core, &session);
    app.core.complete_task(key.clone(), 1_000, true).unwrap();

    app.next_day();
    assert_ne!(
        app.today().recovery_reason,
        Some(RecoveryReason::UnseenNewCards)
    );
}

#[test]
fn unknown_task_key_is_not_found() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));

    assert!(matches!(
        app.core
            .complete_task("new:nope".into(), 0, true)
            .unwrap_err(),
        CoreError::NotFound { .. }
    ));
}

#[test]
fn checkpoint_appears_after_k19_even_with_an_earlier_failed_placement() {
    let mut app = TestApp::new();
    // 引導時的畢業考不需要計畫
    let exam = app
        .core
        .checkpoint_start("ms.hira".into(), SEED, true)
        .unwrap();
    assert!(!exam.is_empty());
    let answers: Vec<AnswerDto> = exam
        .iter()
        .map(|q| AnswerDto {
            reference: q.reference.clone(),
            expected_reps: 0,
            response: wrong_payload(q),
            hint_used: false,
            attempts: 1,
            duration_ms: 500,
        })
        .collect();
    let result = app
        .core
        .checkpoint_finish("ms.hira".into(), answers)
        .unwrap();
    assert!(!result.passed);

    app.next_day();
    app.start_plan(&PlanInputDto {
        known_kana_lessons: known_k_lessons_except(&["le.k19"]),
        ..plan_input(20, StartLevel::Zero)
    });
    study_full_day(&app, true);
    assert_eq!(
        app.core
            .lesson_detail("le.k19".into())
            .unwrap()
            .summary
            .status,
        LessonStatus::Done
    );

    app.next_day();
    assert!(has_checkpoint(&app, "ms.hira"));
}

/// P1 入口考完不經 `complete_task`：今日清單也要顯示完成，不用再考一次。
#[test]
fn a_checkpoint_taken_outside_the_task_list_is_done_today() {
    let mut app = TestApp::new();
    app.start_plan(&PlanInputDto {
        known_kana_lessons: known_k_lessons_except(&["le.k19"]),
        ..plan_input(20, StartLevel::Zero)
    });
    study_full_day(&app, true);
    app.next_day();
    assert!(has_checkpoint(&app, "ms.hira"));

    let questions = app
        .core
        .checkpoint_start("ms.hira".into(), SEED, true)
        .unwrap();
    let answers = questions
        .iter()
        .map(|question| AnswerDto {
            reference: question.reference.clone(),
            expected_reps: 0,
            response: correct_payload(question),
            hint_used: false,
            attempts: 1,
            duration_ms: 500,
        })
        .collect();
    app.core
        .checkpoint_finish("ms.hira".into(), answers)
        .unwrap();

    let today = app.today();
    let task = today
        .tasks
        .iter()
        .find(|task| matches!(task, TaskDto::Checkpoint { .. }))
        .unwrap();
    assert!(task_done(task));
}

#[test]
fn checkpoint_dismiss_removes_it_from_today_and_later_days() {
    let mut app = TestApp::new();
    app.start_plan(&PlanInputDto {
        known_kana_lessons: known_k_lessons_except(&["le.k19"]),
        ..plan_input(20, StartLevel::Zero)
    });
    study_full_day(&app, true);
    app.next_day();
    assert!(has_checkpoint(&app, "ms.hira"));

    let view = app.core.checkpoint_dismiss("ms.hira".into(), true).unwrap();

    assert!(!view
        .tasks
        .iter()
        .any(|t| matches!(t, TaskDto::Checkpoint { .. })));
    let plan = app.core.plan_view().unwrap();
    assert!(
        plan.milestones
            .iter()
            .find(|m| m.id == "ms.hira")
            .unwrap()
            .dismissed
    );
    app.next_day();
    assert!(!has_checkpoint(&app, "ms.hira"));
}

#[test]
fn second_day_only_has_state_new_cards_so_review_is_done_and_tail_counts_them() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);

    app.next_day();
    let today = app.today();

    assert!(matches!(
        today.tasks[0],
        TaskDto::Review {
            due: 0,
            learning: 0,
            new_cards: 3,
            done: true,
            ..
        }
    ));
    assert_eq!(today.learning_tail, 3);
    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    assert_eq!(card.question.question_type, QuestionType::KanaRead);
}

#[test]
fn five_days_of_wrong_answers_keep_the_queue_working() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);

    for _ in 0..5 {
        app.next_day();
        let mut answered = 0;
        while answered < 12 {
            match app.core.session_next(SEED, true).unwrap() {
                SessionNextDto::Done { .. } => break,
                SessionNextDto::Card { card } => {
                    let wrong = wrong_payload(&card.question);
                    let result = app.core.submit_answer(answer_for(&card, wrong)).unwrap();
                    assert!(!result.is_correct);
                    answered += 1;
                }
            }
        }
    }

    let stats = app.core.stats_overview().unwrap();
    assert!(stats.total_reviews >= 5);
    assert!(stats.cards_learning >= 1, "連錯的卡留在學習中");
}

#[test]
fn calendar_covers_whole_weeks_from_this_monday() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);
    app.next_day();

    let days = app.core.calendar(4).unwrap();

    assert_eq!(days.len(), 28);
    assert_eq!(days[0].date, "2026-03-02");
    assert!(days[0].is_active);
    assert!(!days[1].is_active);
    assert!(days.iter().all(|d| d.is_study_day));
    assert!(days[1..].iter().any(|d| !d.lesson_ids.is_empty()));
    let plan = app.core.plan_view().unwrap();
    let hira_date = plan.milestones[0].forecast_date.clone();
    let on_calendar = days.iter().find(|d| Some(&d.date) == hira_date.as_ref());
    if let Some(day) = on_calendar {
        assert_eq!(day.milestone_id.as_deref(), Some("ms.hira"));
    }
    for weeks in [0, 54] {
        assert!(matches!(
            app.core.calendar(weeks).unwrap_err(),
            CoreError::InvalidInput { .. }
        ));
    }
}

#[test]
fn activity_range_validates_dates() {
    let app = TestApp::new();

    assert!(matches!(
        app.core
            .activity_range("2026-03-02".into(), "soon".into())
            .unwrap_err(),
        CoreError::InvalidInput { .. }
    ));
    assert!(matches!(
        app.core
            .activity_range("2026-03-03".into(), "2026-03-02".into())
            .unwrap_err(),
        CoreError::InvalidInput { .. }
    ));
    assert!(app
        .core
        .activity_range("2026-03-01".into(), "2026-03-02".into())
        .unwrap()
        .is_empty());
}

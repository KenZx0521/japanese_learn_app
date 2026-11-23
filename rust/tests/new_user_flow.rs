//! 新使用者完整流程：open → create_plan → today_view → new_content_session → 答題
//! → complete_task → 隔日 → session_next。

mod common;

use common::*;
use jp_core::api::dto_content::KanaStatus;
use jp_core::api::dto_plan::{StartLevel, TaskDto, TodayViewDto};
use jp_core::api::dto_study::{
    NewContentSessionDto, NewContentStepDto, QuestionBodyDto, QuestionType, SessionNextDto,
};

fn assert_first_day_tasks(today: &TodayViewDto) {
    assert_eq!(today.logical_date, "2026-03-02");
    assert!(today.is_study_day);
    assert_eq!(today.tasks.len(), 2);
    assert!(matches!(
        today.tasks[0],
        TaskDto::Review {
            due: 0,
            learning: 0,
            done: true,
            ..
        }
    ));
    let TaskDto::NewContent {
        kana,
        done,
        title_zh,
        ..
    } = &today.tasks[1]
    else {
        panic!("第二項應為 NewContent：{:?}", today.tasks[1]);
    };
    assert_eq!(*kana, 3, "第一批固定 3 字");
    assert!(!done);
    assert!(
        title_zh.contains("{ja:"),
        "title_zh 保留 MixedText 標記：{title_zh}"
    );
}

/// 呈現三個字，接該批的測驗；第一批是三選一，考的都是剛呈現過的字。
fn assert_first_batch_session(session: &NewContentSessionDto) {
    assert_eq!(session.lesson_id, "le.k01");
    assert_eq!(session.steps.len(), 4);
    let presented: Vec<String> = session.steps[..3]
        .iter()
        .map(|step| match step {
            NewContentStepDto::Kana { detail } => detail.cell.id.clone(),
            other => panic!("前三步應為 Kana：{other:?}"),
        })
        .collect();
    assert_eq!(presented, ["ka.hira.a", "ka.hira.i", "ka.hira.u"]);
    let NewContentStepDto::KanaQuiz { questions } = &session.steps[3] else {
        panic!("第四步應為 KanaQuiz");
    };
    assert_eq!(questions.len(), 6, "每字兩題");
    for question in questions {
        assert!(presented.contains(&question.reference.content_id));
        let QuestionBodyDto::Choice { options, .. } = &question.body else {
            panic!("假名題應為選擇題");
        };
        assert_eq!(options.len(), 3);
    }
}

/// 完成切片；重複完成同一個 key 是 no-op，時間不重複累計。
fn complete_first_slice(app: &TestApp, key: String) {
    let after = app.core.complete_task(key.clone(), 120_000, true).unwrap();
    assert!(matches!(
        after.tasks[1],
        TaskDto::NewContent { done: true, .. }
    ));
    assert_eq!(after.streak, 1, "完成假名切片算活躍日");
    assert!(
        matches!(after.tasks[0], TaskDto::Review { new_cards: 0, .. }),
        "當天建的卡隔天才進佇列"
    );

    let again = app.core.complete_task(key, 120_000, true).unwrap();
    assert_eq!(again.streak, 1);
    let activity = app
        .core
        .activity_range("2026-03-02".into(), "2026-03-02".into())
        .unwrap();
    assert_eq!(activity.len(), 1);
    assert!((activity[0].study_minutes - 2.0).abs() < 1e-9);
}

/// Review 只剩 state=0 卡時算 done，由收尾接觸。
fn assert_second_day_queue(app: &TestApp) {
    let today = app.today();
    assert_eq!(today.logical_date, "2026-03-03");
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
    assert_eq!(today.streak, 1, "今天還沒學，不算斷");

    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    assert_eq!(card.question.question_type, QuestionType::KanaRead);
    assert_eq!(card.facet, "read");
    assert_eq!(card.expected_reps, 0);
    assert_eq!(card.rating_previews.len(), 4);
    let payload = correct_payload(&card.question);
    assert!(
        app.core
            .submit_answer(answer_for(&card, payload))
            .unwrap()
            .is_correct
    );
}

#[test]
fn new_user_learns_three_kana_then_reviews_them_the_next_day() {
    let mut app = TestApp::new();

    let view = app
        .core
        .create_plan(plan_input(20, StartLevel::Zero))
        .unwrap();
    assert_eq!(view.current_lesson_id.as_deref(), Some("le.k01"));
    assert_eq!(view.stage_id.as_deref(), Some("st.s0"));
    let today = app.today();
    assert_first_day_tasks(&today);

    let key = new_content_key(&today).unwrap();
    let session = app
        .core
        .new_content_session(key.clone(), SEED, true)
        .unwrap();
    assert_first_batch_session(&session);

    // 每字兩題全對就熟練，當下建 :read 卡
    walk_new_content(&app.core, &session);
    let cell = app.core.kana_detail("ka.hira.a".into()).unwrap().cell;
    assert_eq!(cell.status, KanaStatus::Mastered);
    complete_first_slice(&app, key);

    app.next_day();
    assert_second_day_queue(&app);

    assert!(drain_queue(&app.core, true) >= 2);
    assert!(matches!(
        app.core.session_next(SEED, true).unwrap(),
        SessionNextDto::Done { .. }
    ));
    let stats = app.core.stats_overview().unwrap();
    assert_eq!(stats.kana_mastered, 3);
    assert!(stats.total_reviews >= 3);
}

#[test]
fn day_rollover_hour_separates_logical_dates_for_the_fixed_clock() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    assert_eq!(app.today().logical_date, "2026-03-02");

    // 台北 03:59 隔天凌晨仍是同一個邏輯日
    app.advance(chrono::Duration::minutes(18 * 60 + 59));
    assert_eq!(app.today().logical_date, "2026-03-02");

    app.advance(chrono::Duration::minutes(1));
    assert_eq!(app.today().logical_date, "2026-03-03");
}

#[test]
fn restart_keeps_the_frozen_snapshot_and_progress() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    let before = app.today();

    app.advance(chrono::Duration::hours(1));

    assert_eq!(app.today().tasks, before.tasks);
    assert_eq!(app.core.settings().unwrap().day_rollover_hour, 4);
}

#[test]
fn utc_offset_change_moves_the_logical_date() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    // 台北隔天 03:59，換日前最後一分鐘
    app.advance(chrono::Duration::minutes(18 * 60 + 59));
    assert_eq!(app.today().logical_date, "2026-03-02");

    // 飛到東京：同一個 UTC 時刻已過換日點
    app.core.set_utc_offset(540).unwrap();

    assert_eq!(app.today().logical_date, "2026-03-03");
    assert!(app.core.set_utc_offset(841).is_err());
}

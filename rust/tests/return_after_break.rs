//! §7.2 `ReturnAfterBreak` 的邊界：最後活躍日只看學習計畫的活動，而且一定有出口（RULINGS O12）。

mod common;

use chrono::Duration;
use common::*;
use jp_core::api::dto_plan::{RecoveryReason, StartLevel, TaskDto, TodayViewDto};
use jp_core::api::dto_study::{AnswerDto, QuestionDto};

const LONG_WAIT_DAYS: i64 = 4;
const AWAY_DAYS: i64 = 9;
const WATCHED_DAYS: i64 = 8;

fn exam_answer(question: &QuestionDto) -> AnswerDto {
    AnswerDto {
        reference: question.reference.clone(),
        expected_reps: 0,
        response: correct_payload(question),
        hint_used: false,
        attempts: 1,
        duration_ms: 1000,
    }
}

fn take_checkpoint(app: &TestApp) {
    let exam = app
        .core
        .checkpoint_start("ms.hira".into(), SEED, true)
        .unwrap();
    app.core
        .checkpoint_finish("ms.hira".into(), exam.iter().map(exam_answer).collect())
        .unwrap();
}

fn answer_one_free_kana(app: &TestApp) {
    let questions = app.core.kana_session("le.k01".into(), SEED, true).unwrap();
    answer_all_kana(&app.core, &questions[..1]);
}

fn offers_a_slice(view: &TodayViewDto) -> bool {
    view.tasks
        .iter()
        .any(|task| matches!(task, TaskDto::NewContent { .. }))
}

/// 學習者把當天列出來的都做完；什麼都沒有的日子就只是打開看看。
fn do_everything_listed(app: &TestApp, view: &TodayViewDto) {
    let keys: Vec<String> = view
        .tasks
        .iter()
        .filter(|task| !task_done(task))
        .map(|task| task_key(task).to_owned())
        .collect();
    for key in keys {
        app.core.complete_task(key, 1000, true).unwrap();
    }
    drain_queue(&app.core, true);
}

/// 定級檢定不是學習計畫的活動：考完隔幾天才開始，不是「回鍋」（review_rc RC1）。
#[test]
fn placement_then_a_long_wait_still_offers_new_content() {
    let mut app = TestApp::new();
    take_checkpoint(&app);
    app.start_plan(&plan_input(20, StartLevel::Zero));

    app.advance(Duration::days(LONG_WAIT_DAYS));
    let view = app.today();

    assert_eq!(view.recovery_reason, None);
    assert!(offers_a_slice(&view), "tasks: {:?}", view.tasks);
}

/// 連續天數照算，但缺席中答一題自由練習，不會取消隔天的回鍋保護（review_rc RC3）。
#[test]
fn one_free_kana_answer_does_not_cancel_the_return_day() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);
    app.advance(Duration::days(AWAY_DAYS));
    answer_one_free_kana(&app);
    assert_eq!(app.today().streak, 1, "自由練習的日子算連續天數");

    app.next_day();

    assert_eq!(
        app.today().recovery_reason,
        Some(RecoveryReason::ReturnAfterBreak)
    );
}

#[test]
fn a_checkpoint_during_the_break_does_not_cancel_the_return_day() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);
    app.advance(Duration::days(AWAY_DAYS));
    take_checkpoint(&app);

    app.next_day();

    assert_eq!(
        app.today().recovery_reason,
        Some(RecoveryReason::ReturnAfterBreak)
    );
}

/// 回鍋日沒有任何可複習的卡時，今天做不了事也就不會變成活躍日，不能因此天天判回鍋。
#[test]
fn return_with_nothing_to_review_never_gets_stuck() {
    for away in 3..=AWAY_DAYS {
        let mut app = TestApp::new();
        app.start_plan(&plan_input(20, StartLevel::Zero));
        study_full_day(&app, true);
        app.next_day();
        drain_queue(&app.core, true);
        app.advance(Duration::days(away + 1));
        let mut stuck_days = 0;
        for _ in 0..WATCHED_DAYS {
            let view = app.today();
            let idle = view.recovery_reason == Some(RecoveryReason::ReturnAfterBreak)
                && !offers_a_slice(&view)
                && view.tasks.iter().all(task_done)
                && view.learning_tail == 0;
            stuck_days = if idle { stuck_days + 1 } else { 0 };
            assert!(stuck_days < 2, "away={away}：連續兩天回鍋且沒事可做");
            do_everything_listed(&app, &view);
            app.next_day();
        }
    }
}

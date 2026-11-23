//! T3「今天學了 N 分鐘、答了 N 題」的來源（§7.4、§7.6）：時間只算一次，題數照實際作答。

mod common;

use common::*;
use jp_core::api::dto_plan::{DayActivityDto, PlanInputDto, StartLevel};
use jp_core::api::dto_study::{AnswerDto, NewContentStepDto, QuestionDto};

const ONE_MINUTE_MS: u32 = 60_000;
const HALF_MINUTE_MS: u32 = 30_000;

fn activity_today(app: &TestApp) -> DayActivityDto {
    let day = app.today().logical_date;
    app.core
        .activity_range(day.clone(), day)
        .unwrap()
        .into_iter()
        .next()
        .expect("今天應有活動紀錄")
}

fn assert_minutes(actual: f64, expected: f64) {
    assert!(
        (actual - expected).abs() < 1e-9,
        "實際 {actual} 分鐘，應為 {expected}"
    );
}

/// 單題已累加作答時間，`complete_task` 帶的整段時鐘不再重複計入。
#[test]
fn a_one_minute_review_counts_as_one_minute() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);
    app.next_day();
    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    let payload = correct_payload(&card.question);

    app.core
        .submit_answer(AnswerDto {
            duration_ms: ONE_MINUTE_MS,
            ..answer_for(&card, payload)
        })
        .unwrap();
    app.core
        .complete_task("review".into(), ONE_MINUTE_MS, true)
        .unwrap();

    assert_minutes(activity_today(&app).study_minutes, 1.0);
}

/// `first_card` 的作答時間已在單題累加，結案只補上呈現與收尾的部分。
#[test]
fn new_content_first_cards_are_not_counted_twice() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));
    let key = new_content_key(&app.today()).unwrap();
    let session = app
        .core
        .new_content_session(key.clone(), SEED, true)
        .unwrap();
    let card = session
        .steps
        .iter()
        .find_map(|step| match step {
            NewContentStepDto::Vocab {
                first_card: Some(card),
                ..
            } => Some(card),
            _ => None,
        })
        .expect("應有 first_card");
    let payload = correct_payload(&card.question);
    app.core
        .submit_answer(AnswerDto {
            duration_ms: HALF_MINUTE_MS,
            ..answer_for(card, payload)
        })
        .unwrap();

    app.core.complete_task(key, ONE_MINUTE_MS, true).unwrap();

    assert_minutes(activity_today(&app).study_minutes, 1.0);
}

#[test]
fn tasks_without_per_question_time_keep_the_task_clock() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    let key = new_content_key(&app.today()).unwrap();

    app.core.complete_task(key, ONE_MINUTE_MS, true).unwrap();

    assert_minutes(activity_today(&app).study_minutes, 1.0);
}

fn kana_questions(steps: &[NewContentStepDto]) -> Vec<QuestionDto> {
    steps
        .iter()
        .filter_map(|step| match step {
            NewContentStepDto::KanaQuiz { questions } => Some(questions.clone()),
            _ => None,
        })
        .flatten()
        .collect()
}

/// 3 字切片每字兩題：T3 要顯示 6 題，不是字數。
#[test]
fn kana_slice_counts_every_answered_question() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    let key = new_content_key(&app.today()).unwrap();
    let session = app
        .core
        .new_content_session(key.clone(), SEED, true)
        .unwrap();
    let questions = kana_questions(&session.steps);
    assert!(questions.len() > 3, "每字兩題");

    answer_all_kana(&app.core, &questions);
    let view = app.core.complete_task(key, ONE_MINUTE_MS, true).unwrap();

    let expected = u32::try_from(questions.len()).unwrap();
    assert_eq!(activity_today(&app).answers, expected);
    assert_eq!(view.streak, 1, "作答過的假名日仍是活躍日");
}

/// 規則課的 `minimal_pair` 與易混字組的 `kana_confuse` 也是切片內的作答。
#[test]
fn rule_and_confusable_slices_count_their_answers() {
    for lesson in ["le.k10", "le.k16"] {
        let app = TestApp::new();
        let order = &app.content.course().order;
        let known = order
            .iter()
            .take_while(|id| id.as_str() != lesson)
            .filter(|id| id.starts_with("le.k"))
            .cloned()
            .collect();
        app.start_plan(&PlanInputDto {
            known_kana_lessons: known,
            ..plan_input(20, StartLevel::Zero)
        });
        let key = new_content_key(&app.today()).unwrap();
        let session = app
            .core
            .new_content_session(key.clone(), SEED, true)
            .unwrap();
        let questions = kana_questions(&session.steps);
        assert!(!questions.is_empty(), "{lesson} 應有測驗");

        answer_all_kana(&app.core, &questions);
        app.core.complete_task(key, ONE_MINUTE_MS, true).unwrap();

        let expected = u32::try_from(questions.len()).unwrap();
        assert_eq!(activity_today(&app).answers, expected, "{lesson}");
    }
}

/// K1 自由練習不在今日切片內，不推進計畫（C06），但作答的日子算活躍日（RULINGS O12、rust.F4）。
#[test]
fn free_kana_practice_counts_as_an_active_day_without_advancing_the_plan() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    let before = app.today();
    let key = new_content_key(&before).unwrap();

    let questions = app.core.kana_session("le.k02".into(), SEED, true).unwrap();
    answer_all_kana(&app.core, &questions);

    let expected = u32::try_from(questions.len()).unwrap();
    assert_eq!(activity_today(&app).answers, expected);
    let after = app.today();
    assert_eq!(after.streak, 1, "只做自由練習的日子也算連續天數");
    assert_eq!(new_content_key(&after), Some(key), "今日切片不變");
    assert!(!after
        .tasks
        .iter()
        .any(|task| task_key(task).starts_with("new:") && task_done(task)));
}

fn exam_answer(question: &QuestionDto) -> AnswerDto {
    AnswerDto {
        reference: question.reference.clone(),
        expected_reps: 0,
        response: correct_payload(question),
        hint_used: false,
        attempts: 1,
        duration_ms: HALF_MINUTE_MS,
    }
}

/// 只考檢定的日子也是活躍日，檢定的題數計入 T3（RULINGS O12、rust.F4）。
#[test]
fn a_day_with_only_a_checkpoint_counts_as_active() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);
    app.next_day();
    let exam = app
        .core
        .checkpoint_start("ms.hira".into(), SEED, true)
        .unwrap();

    app.core
        .checkpoint_finish("ms.hira".into(), exam.iter().map(exam_answer).collect())
        .unwrap();

    let expected = u32::try_from(exam.len()).unwrap();
    assert_eq!(activity_today(&app).answers, expected);
    assert_eq!(app.today().streak, 2);
    assert_eq!(app.core.stats_overview().unwrap().streak_current, 2);
}

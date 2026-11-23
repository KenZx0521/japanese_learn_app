//! 先教後考（RULINGS C04）：第一次接觸在 `NewContent` 內完成，以及「已會」與切片、卡片的關係（§9.4）。

mod common;

use common::*;
use jp_core::api::dto_content::{LessonStatus, VocabFlagsDto};
use jp_core::api::dto_plan::{RecoveryReason, StartLevel, TodayViewDto};
use jp_core::api::dto_study::{NewContentSessionDto, NewContentStepDto, SessionNextDto};
use jp_store::{PlanRepo, SqliteRepository, SrsRepo};

const MAX_DAYS_TO_FINISH_L01: usize = 12;

fn app_at_l01(minutes: u32) -> TestApp {
    let app = TestApp::new();
    app.start_plan(&plan_input(minutes, StartLevel::Kana));
    app
}

fn open_session(app: &TestApp, key: &str) -> NewContentSessionDto {
    app.core
        .new_content_session(key.to_owned(), SEED, true)
        .unwrap()
}

fn repo_of(app: &TestApp) -> SqliteRepository {
    SqliteRepository::open(&app.db_path).unwrap()
}

fn set_known(app: &TestApp, word: &str, known: bool) {
    let flags = VocabFlagsDto {
        known,
        starred: false,
    };
    app.core.set_vocab_flags(word.to_owned(), flags).unwrap();
}

fn word_of_key(key: &str) -> String {
    key.strip_prefix("new:").expect("new:<項目>").to_owned()
}

fn first_card_of<'s>(
    session: &'s NewContentSessionDto,
    word: &str,
) -> Option<&'s jp_core::api::dto_study::SessionCardDto> {
    session.steps.iter().find_map(|step| match step {
        NewContentStepDto::Vocab { detail, first_card } if detail.summary.id == word => {
            first_card.as_ref()
        }
        _ => None,
    })
}

fn assert_nothing_queued(today: &TodayViewDto, app: &TestApp) {
    assert_eq!(today.learning_tail, 0, "沒教過的卡不該列進收尾");
    assert!(
        matches!(
            app.core.session_next(SEED, true).unwrap(),
            SessionNextDto::Done { .. }
        ),
        "沒教過的卡不該由佇列取出"
    );
}

/// 開了 L3 就離開：隔天不受限、不先考，切片相同，`first_card` 照常出題。
#[test]
fn new_content_left_unfinished_is_taught_again_instead_of_quizzed() {
    for minutes in [10, 20] {
        let mut app = app_at_l01(minutes);
        let key = new_content_key(&app.today()).unwrap();
        open_session(&app, &key);

        app.next_day();

        let today = app.today();
        assert_eq!(today.recovery_reason, None, "{minutes} 分方案");
        assert_eq!(new_content_key(&today).as_deref(), Some(key.as_str()));
        assert_nothing_queued(&today, &app);
        let session = open_session(&app, &key);
        assert!(first_card_of(&session, &word_of_key(&key)).is_some());
    }
}

/// 結案過的 state=0 卡（已 `item_intro`）照舊由收尾取用，也仍計入條件 3。
#[test]
fn a_completed_slice_never_answered_is_still_picked_up_by_the_tail() {
    let mut app = app_at_l01(10);
    let key = new_content_key(&app.today()).unwrap();
    open_session(&app, &key);
    app.core.complete_task(key.clone(), 1_000, true).unwrap();

    app.next_day();

    let today = app.today();
    assert_eq!(
        today.recovery_reason,
        Some(RecoveryReason::UnseenNewCards),
        "10 分方案 3 字加文法，超過上限"
    );
    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    assert!(card.card_id.starts_with(&word_of_key(&key)));
}

#[test]
fn word_marked_known_in_todays_slice_never_enters_review() {
    let mut app = app_at_l01(20);
    let key = new_content_key(&app.today()).unwrap();
    let word = word_of_key(&key);
    set_known(&app, &word, true);

    let session = open_session(&app, &key);
    assert!(first_card_of(&session, &word).is_none(), "已會的字不出題");
    walk_new_content(&app.core, &session);
    app.core.complete_task(key, 1_000, true).unwrap();

    let card = repo_of(&app).card(&format!("{word}:recog")).unwrap();
    assert!(card.expect("卡片已建立").suspended);
    app.next_day();
    assert!(!drain_queue_ids(&app).iter().any(|id| id.contains(&word)));
}

/// 收尾把佇列拉到 Done，回傳出現過的卡。
fn drain_queue_ids(app: &TestApp) -> Vec<String> {
    let mut ids = Vec::new();
    while let SessionNextDto::Card { card } = app.core.session_next(SEED, true).unwrap() {
        let payload = correct_payload(&card.question);
        app.core.submit_answer(answer_for(&card, payload)).unwrap();
        ids.push(card.card_id);
    }
    ids
}

#[test]
fn word_marked_known_without_opening_the_session_gets_no_cards_when_completed() {
    let app = app_at_l01(20);
    let key = new_content_key(&app.today()).unwrap();
    let word = word_of_key(&key);
    set_known(&app, &word, true);

    app.core.complete_task(key, 1_000, true).unwrap();

    assert_eq!(repo_of(&app).card(&format!("{word}:recog")).unwrap(), None);
}

/// 尚未教的字標已會再取消：回到正常切片，不留 `item_intro`、不提前建卡。
#[test]
fn unmarking_an_untaught_word_returns_it_to_the_slices() {
    let app = app_at_l01(20);

    for word in ["vo.gohan", "vo.taberu"] {
        set_known(&app, word, true);
        assert!(repo_of(&app).introduced_items().unwrap().contains(word));

        set_known(&app, word, false);

        assert!(!repo_of(&app).introduced_items().unwrap().contains(word));
        assert_eq!(repo_of(&app).card(&format!("{word}:recog")).unwrap(), None);
    }
}

/// L3 開過（卡已建立、仍 state=0）後標已會再取消，一樣要回到「沒教過」。
#[test]
fn unmarking_a_word_of_an_open_session_does_not_leave_it_introduced() {
    let mut app = app_at_l01(20);
    let key = new_content_key(&app.today()).unwrap();
    let word = word_of_key(&key);
    open_session(&app, &key);
    set_known(&app, &word, true);

    set_known(&app, &word, false);

    assert!(!repo_of(&app).introduced_items().unwrap().contains(&word));
    app.next_day();
    assert_nothing_queued(&app.today(), &app);
}

#[test]
fn unmarking_a_word_of_a_finished_lesson_keeps_it_introduced() {
    let mut app = app_at_l01(45);
    for _ in 0..MAX_DAYS_TO_FINISH_L01 {
        study_full_day(&app, true);
        app.next_day();
        let lesson = app.core.lesson_detail("le.l01".into()).unwrap();
        if lesson.summary.status == LessonStatus::Done {
            break;
        }
    }
    let status = app
        .core
        .lesson_detail("le.l01".into())
        .unwrap()
        .summary
        .status;
    assert_eq!(status, LessonStatus::Done);
    let word = "vo.hajimemashite";
    let repo = repo_of(&app);
    let card_id = format!("{word}:recog");
    assert!(repo.card(&card_id).unwrap().is_some(), "L01 已教過");

    set_known(&app, word, true);
    assert!(repo.card(&card_id).unwrap().unwrap().suspended);
    set_known(&app, word, false);

    assert!(!repo.card(&card_id).unwrap().unwrap().suspended);
    assert!(repo.introduced_items().unwrap().contains(word));
}

//! §11.2 `new_content_flow`：卡片建立、斷點續做、步驟組成、課完成條件。

mod common;

use common::*;
use jp_core::api::dto_content::LessonStatus;
use jp_core::api::dto_plan::{PlanInputDto, StartLevel, TaskDto};
use jp_core::api::dto_study::{
    NewContentSessionDto, NewContentStepDto, QuestionBodyDto, QuestionType,
};
use jp_core::api::error::CoreError;

fn app_at_l01() -> TestApp {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));
    app
}

fn session_of(app: &TestApp) -> (String, NewContentSessionDto) {
    let key = new_content_key(&app.today()).expect("今天應有 NewContent");
    let session = app
        .core
        .new_content_session(key.clone(), SEED, true)
        .unwrap();
    (key, session)
}

fn lesson_status(app: &TestApp, lesson: &str) -> LessonStatus {
    app.core
        .lesson_detail(lesson.to_owned())
        .unwrap()
        .summary
        .status
}

fn only_lesson(app: &TestApp, lesson: &str) -> PlanInputDto {
    let order = &app.content.course().order;
    let known = order
        .iter()
        .take_while(|id| id.as_str() != lesson)
        .filter(|id| id.starts_with("le.k"))
        .cloned()
        .collect();
    PlanInputDto {
        known_kana_lessons: known,
        ..plan_input(20, StartLevel::Zero)
    }
}

#[test]
fn l01_first_slice_lists_words_before_grammar_with_usable_examples() {
    let app = app_at_l01();

    let (_, session) = session_of(&app);

    assert_eq!(session.lesson_id, "le.l01");
    let words = session
        .steps
        .iter()
        .take_while(|s| matches!(s, NewContentStepDto::Vocab { .. }))
        .count();
    assert_eq!(words, 5, "20 分方案每天 5 字");
    let tail = &session.steps[words..];
    assert!(!tail.is_empty());
    assert!(tail
        .iter()
        .all(|s| matches!(s, NewContentStepDto::Grammar { .. })));
    for step in &session.steps {
        let examples = match step {
            NewContentStepDto::Vocab { detail, .. } => &detail.examples,
            NewContentStepDto::Grammar { detail, .. } => &detail.examples,
            other => panic!("{other:?}"),
        };
        assert!(!examples.is_empty(), "{step:?}");
    }
}

#[test]
fn grammar_with_drills_gets_a_real_question_not_self_grade() {
    let app = app_at_l01();
    let (_, session) = session_of(&app);

    let grammar = session
        .steps
        .iter()
        .find_map(|s| match s {
            NewContentStepDto::Grammar {
                first_card: Some(card),
                ..
            } => Some(card),
            _ => None,
        })
        .expect("L01 應有文法 first_card");

    assert_eq!(grammar.facet, "use");
    assert!(!matches!(
        grammar.question.body,
        QuestionBodyDto::SelfGrade { .. }
    ));
}

#[test]
fn answering_first_card_leaves_state_new_so_the_session_resumes() {
    let app = app_at_l01();
    let (key, session) = session_of(&app);
    let NewContentStepDto::Vocab {
        first_card: Some(card),
        detail,
    } = &session.steps[0]
    else {
        panic!("第一步應為帶 first_card 的 Vocab");
    };
    assert_eq!(detail.summary.id, "vo.watashi");
    assert_eq!(card.card_id, "vo.watashi:recog");
    assert_eq!(card.expected_reps, 0);

    app.core
        .submit_answer(answer_for(card, correct_payload(&card.question)))
        .unwrap();

    let resumed = app.core.new_content_session(key, SEED, true).unwrap();
    let NewContentStepDto::Vocab { first_card, .. } = &resumed.steps[0] else {
        panic!();
    };
    assert!(first_card.is_none(), "已離開 state=0 不再出題");
    assert!(matches!(
        &resumed.steps[1],
        NewContentStepDto::Vocab {
            first_card: Some(_),
            ..
        }
    ));
}

#[test]
fn same_form_word_creates_a_listen_card_too() {
    let app = app_at_l01();

    let (_, session) = session_of(&app);

    assert!(session.steps.iter().any(|s| matches!(
        s,
        NewContentStepDto::Vocab { detail, first_card: Some(card) }
            if detail.summary.id == "vo.sensei" && card.facet == "recog"
    )));
    // vo.watashi 只建 recog；vo.sensei 多一張 listen
    let stats = app.core.stats_overview().unwrap();
    let vocab_words = session
        .steps
        .iter()
        .filter(|s| matches!(s, NewContentStepDto::Vocab { .. }))
        .count() as u32;
    let grammar_points = session.steps.len() as u32 - vocab_words;
    assert_eq!(stats.cards_new, vocab_words + grammar_points + 1);
}

#[test]
fn complete_task_records_item_intro_and_lesson_finishes_after_integration() {
    let mut app = app_at_l01();
    assert_eq!(lesson_status(&app, "le.l01"), LessonStatus::Current);

    // L01 有 8 字：第 1、2 天是單字切片，第 3 天整合，之後完成
    for day in 0..3 {
        let today = study_full_day(&app, true);
        assert!(
            today
                .tasks
                .iter()
                .any(|t| matches!(t, TaskDto::NewContent { .. } | TaskDto::Integration { .. })),
            "第 {day} 天應有主線任務"
        );
        app.next_day();
    }

    assert_eq!(lesson_status(&app, "le.l01"), LessonStatus::Done);
    assert_eq!(lesson_status(&app, "le.kk01"), LessonStatus::Skipped);
    assert_eq!(lesson_status(&app, "le.l02"), LessonStatus::Current);
    assert!(app.core.vocab_detail("vo.ocha".into()).is_ok());
    let detail = app.core.lesson_detail("le.l01".into()).unwrap();
    assert_eq!(detail.integration_days_done, 1);
    assert_eq!(detail.integration_days_needed, 1);
}

#[test]
fn kana_lesson_completes_only_after_all_characters_are_introduced() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(10, StartLevel::Zero));

    // 第一批 3 字後 K01 還有 2 字，10 分方案第二天取 2 字
    study_full_day(&app, true);
    assert_eq!(lesson_status(&app, "le.k01"), LessonStatus::Current);
    app.next_day();
    study_full_day(&app, true);

    assert_eq!(lesson_status(&app, "le.k01"), LessonStatus::Done);
}

#[test]
fn mastering_kana_inside_the_slice_creates_its_read_card_before_completion() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));

    let (_, session) = session_of(&app);
    walk_new_content(&app.core, &session);

    // 三個字各答對兩次，complete_task 之前就建好 :read 卡
    assert_eq!(app.core.stats_overview().unwrap().cards_new, 3);
}

#[test]
fn k10_is_one_slice_of_confusables_followed_by_kana_confuse() {
    let app = TestApp::new();
    app.start_plan(&only_lesson(&app, "le.k10"));

    let task = app.today().tasks[1].clone();
    assert!(
        matches!(
            task,
            TaskDto::NewContent {
                rules: 1,
                kana: 0,
                ..
            }
        ),
        "{task:?}"
    );
    let (key, session) = session_of(&app);

    assert!(matches!(
        session.steps[0],
        NewContentStepDto::Confusable { .. }
    ));
    let NewContentStepDto::KanaQuiz { questions } = &session.steps[1] else {
        panic!("Confusable 後應接 KanaQuiz：{:?}", session.steps);
    };
    assert!(questions
        .iter()
        .all(|q| q.question_type == QuestionType::KanaConfuse));

    answer_all_kana(&app.core, questions);
    let after = app.core.complete_task(key, 1_000, true).unwrap();
    assert!(matches!(
        after.tasks[1],
        TaskDto::NewContent { done: true, .. }
    ));
    assert_eq!(lesson_status(&app, "le.k10"), LessonStatus::Done);
}

#[test]
fn k16_rule_step_is_followed_by_minimal_pairs() {
    let app = TestApp::new();
    app.start_plan(&only_lesson(&app, "le.k16"));

    let (_, session) = session_of(&app);

    let NewContentStepDto::Rule { card } = &session.steps[0] else {
        panic!("應為 Rule：{:?}", session.steps);
    };
    assert_eq!(card.id, "ka.rule.sokuon");
    assert_eq!(card.drill_ids, ["dr.k16.mpr.001"]);
    let NewContentStepDto::KanaQuiz { questions } = &session.steps[1] else {
        panic!();
    };
    assert_eq!(questions[0].question_type, QuestionType::MinimalPair);
}

#[test]
fn k19_rule_without_playable_drills_has_no_quiz_step_but_keeps_accent_group() {
    let app = TestApp::new();
    app.start_plan(&only_lesson(&app, "le.k19"));

    let (_, session) = session_of(&app);

    assert_eq!(
        session.steps.len(),
        1,
        "listen_disabled 的題濾完就沒有 KanaQuiz"
    );
    let NewContentStepDto::Rule { card } = &session.steps[0] else {
        panic!();
    };
    assert!(card.drill_ids.is_empty());
    assert_eq!(card.sound_groups[0].id, "ka.sg.accent_ame");
}

#[test]
fn yoon_rows_stay_together_in_one_batch() {
    let app = TestApp::new();
    app.start_plan(&only_lesson(&app, "le.k14"));

    let (_, session) = session_of(&app);

    let mut batches: Vec<Vec<String>> = vec![Vec::new()];
    for step in &session.steps {
        match step {
            NewContentStepDto::Kana { detail } => {
                batches.last_mut().unwrap().push(detail.cell.id.clone())
            }
            NewContentStepDto::KanaQuiz { .. } => batches.push(Vec::new()),
            _ => {}
        }
    }
    assert_eq!(batches[0], ["ka.hira.kya", "ka.hira.kyu", "ka.hira.kyo"]);
    assert_eq!(batches[1], ["ka.hira.sha", "ka.hira.shu", "ka.hira.sho"]);
}

#[test]
fn already_taught_characters_fill_the_distractor_slots() {
    let app = TestApp::new();
    app.start_plan(&PlanInputDto {
        known_kana_lessons: vec!["le.k01".to_owned()],
        ..plan_input(20, StartLevel::Zero)
    });

    let (_, session) = session_of(&app);

    // 第一批的第 1 題已有 3 個干擾項：K01 五字已 item_intro
    let NewContentStepDto::KanaQuiz { questions } = session
        .steps
        .iter()
        .find(|s| matches!(s, NewContentStepDto::KanaQuiz { .. }))
        .unwrap()
    else {
        unreachable!();
    };
    let QuestionBodyDto::Choice { options, .. } = &questions[0].body else {
        panic!();
    };
    assert_eq!(options.len(), 4);
}

#[test]
fn later_batches_can_use_earlier_batches_of_the_session_as_distractors() {
    let app = TestApp::new();
    app.start_plan(&PlanInputDto {
        known_kana_lessons: vec!["le.k01".to_owned()],
        ..plan_input(20, StartLevel::Zero)
    });

    let (_, session) = session_of(&app);

    // K02 五字分成 ka ki ku／ke ko；ke 的同行、同段候選只有 ko 與 e 不在第一批
    let second_batch = session
        .steps
        .iter()
        .filter_map(|s| match s {
            NewContentStepDto::KanaQuiz { questions } => Some(questions),
            _ => None,
        })
        .nth(1)
        .expect("K02 應分成兩批");
    let question = second_batch
        .iter()
        .find(|q| {
            q.reference.content_id == "ka.hira.ke" && q.question_type == QuestionType::KanaRead
        })
        .expect("ke 應有 kana_read");
    let QuestionBodyDto::Choice { options, .. } = &question.body else {
        panic!();
    };
    let first_batch = ["ka.hira.ka", "ka.hira.ki", "ka.hira.ku"];
    assert!(
        options.iter().any(|o| first_batch.contains(&o.id.as_str())),
        "{options:?}"
    );
}

#[test]
fn unknown_or_wrong_type_task_key_is_not_found() {
    let app = app_at_l01();
    app.today();

    for key in ["review", "new:vo.nope"] {
        assert!(
            matches!(
                app.core
                    .new_content_session(key.to_owned(), SEED, true)
                    .unwrap_err(),
                CoreError::NotFound { .. }
            ),
            "{key}"
        );
        assert!(matches!(
            app.core
                .listen_session(key.to_owned(), SEED, true)
                .unwrap_err(),
            CoreError::NotFound { .. }
        ));
    }
}

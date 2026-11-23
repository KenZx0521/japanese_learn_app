//! §8.5 檢定。

mod common;

use std::collections::HashSet;

use chrono::{DateTime, Utc};
use common::*;
use jp_content::ContentStore;
use jp_lang::clock::DayContext;
use jp_quiz::checkpoint::{checkpoint_dismiss, checkpoint_finish, checkpoint_start};
use jp_quiz::model::{Answer, AnswerPayload, Question, QuestionBody};
use jp_quiz::{QuestionType, QuizError};
use jp_store::{PlanRepo, SqliteRepository, SrsRepo};

fn day() -> DayContext {
    DayContext {
        now: DateTime::parse_from_rfc3339("2026-03-04T12:00:00Z")
            .unwrap()
            .with_timezone(&Utc),
        utc_offset_minutes: 480,
        rollover_hour: 4,
    }
}

fn start(store: &ContentStore, known: &HashSet<String>, milestone: &str) -> Vec<Question> {
    checkpoint_start(&ctx(store, known), milestone).unwrap()
}

fn right_answer(question: &Question) -> AnswerPayload {
    match &question.body {
        QuestionBody::Choice {
            correct_option_id, ..
        } => AnswerPayload::Choice {
            option_id: correct_option_id.clone(),
        },
        QuestionBody::Reorder { accept_orders, .. } => AnswerPayload::Reorder {
            order: accept_orders[0].clone(),
        },
        QuestionBody::Typing {
            expected_reading, ..
        } => AnswerPayload::Typing {
            input: expected_reading.clone(),
        },
        other => panic!("檢定不應出現 {other:?}"),
    }
}

fn answer(question: &Question, response: AnswerPayload) -> Answer {
    Answer {
        reference: question.reference.clone(),
        expected_reps: 0,
        response,
        hint_used: false,
        attempts: 1,
        duration_ms: 1_000,
    }
}

fn wrong_answer(question: &Question) -> AnswerPayload {
    match &question.body {
        QuestionBody::Typing { .. } => AnswerPayload::Typing {
            input: "zzz".to_string(),
        },
        QuestionBody::Reorder { .. } => AnswerPayload::Reorder { order: vec![] },
        _ => AnswerPayload::Choice {
            option_id: "nope".to_string(),
        },
    }
}

#[test]
fn hiragana_exam_works_with_empty_item_intro() {
    let store = content();
    let known = HashSet::new();

    let questions = start(&store, &known, "ms.hira");

    assert_eq!(questions.len(), 20);
    let reads: Vec<_> = questions
        .iter()
        .filter(|q| q.question_type == QuestionType::KanaRead)
        .collect();
    assert!(!reads.is_empty());
    assert!(reads.iter().all(|q| options(q).len() == 4));
}

#[test]
fn kana_exam_only_uses_kana_and_rule_question_types() {
    let store = content();
    let known = HashSet::new();

    for milestone in ["ms.hira", "ms.kata"] {
        for question in start(&store, &known, milestone) {
            assert!(
                matches!(
                    question.question_type,
                    QuestionType::KanaRead
                        | QuestionType::KanaListen
                        | QuestionType::KanaWord
                        | QuestionType::MinimalPair
                ),
                "{:?}",
                question.question_type
            );
        }
    }
}

#[test]
fn katakana_exam_stays_in_script_and_returns_what_it_can() {
    let store = content();
    let known = HashSet::new();

    let questions = start(&store, &known, "ms.kata");

    assert_eq!(questions.len(), 15, "夾具只有 15 個非符號片假名");
    for question in &questions {
        assert!(question.reference.content_id.starts_with("ka.kata."));
        assert!(option_ids(question)
            .iter()
            .all(|id| id.starts_with("ka.kata.")));
    }
}

#[test]
fn disabled_pairs_and_marks_never_appear() {
    let store = content();
    let known = HashSet::new();

    for seed in 0..15 {
        let context = with_seed(&ctx(&store, &known), seed);
        for question in checkpoint_start(&context, "ms.hira").unwrap() {
            assert_ne!(
                question.reference.drill_id.as_deref(),
                Some("dr.k19.mpr.001")
            );
            // 手寫題的 content_id 是 targets[0]，可能指向符號；這裡只看單字元題
            if question.reference.drill_id.is_none() {
                assert!(!question.reference.content_id.contains("sokuon"));
                assert!(!question.reference.content_id.contains("small_"));
            }
        }
    }
}

#[test]
fn silent_kana_exam_has_no_audio_questions() {
    let store = content();
    let known = HashSet::new();
    let context = silent(&ctx(&store, &known));

    let questions = checkpoint_start(&context, "ms.hira").unwrap();

    assert_eq!(questions.len(), 20);
    assert!(questions.iter().all(|q| !q.question_type.needs_audio()));
}

#[test]
fn kana_exam_includes_handwritten_drills_when_available() {
    let store = content();
    let known = HashSet::new();

    let types: HashSet<_> = start(&store, &known, "ms.hira")
        .iter()
        .map(|q| q.question_type)
        .collect();

    assert!(types.contains(&QuestionType::KanaWord) || types.contains(&QuestionType::MinimalPair));
    assert!(types.contains(&QuestionType::KanaRead));
    assert!(types.contains(&QuestionType::KanaListen));
}

fn with_exam_size(questions: u32) -> ContentStore {
    content_with(&[(
        r#""title_zh": "聽懂朋友說話的第一步", "pass_ratio": 0.8, "questions": 20"#,
        &format!(
            r#""title_zh": "聽懂朋友說話的第一步", "pass_ratio": 0.8, "questions": {questions}"#
        ),
    )])
}

fn is_vocab(question: &Question) -> bool {
    question.question_type == QuestionType::Recog
}

#[test]
fn lesson_exam_mixes_vocab_and_grammar_evenly() {
    let store = with_exam_size(12);
    let known = all_known(&store);

    let questions = start(&store, &known, "ms.casual");

    assert_eq!(questions.len(), 12);
    assert_eq!(questions.iter().filter(|q| is_vocab(q)).count(), 6);
    assert!(questions
        .iter()
        .all(|q| q.reference.content_id.starts_with("vo.")
            || q.reference.content_id.starts_with("gr.")));
}

#[test]
fn lesson_exam_tops_up_grammar_when_vocab_runs_out() {
    let store = content();
    let known = all_known(&store);

    let questions = start(&store, &known, "ms.casual");

    // 夾具只有 9 個單字湊得出 2 個干擾項（pos 為 n、phrase）
    assert_eq!(questions.len(), 20);
    assert_eq!(questions.iter().filter(|q| is_vocab(q)).count(), 9);
}

#[test]
fn lesson_exam_splits_recent_and_older_lessons() {
    let store = with_exam_size(8);
    let known = all_known(&store);

    for seed in 0..15 {
        let context = with_seed(&ctx(&store, &known), seed);
        let questions = checkpoint_start(&context, "ms.casual").unwrap();

        // 最後 3 個有單字或文法的課是 L21、L08、L03，L01、L02 算較舊
        let recent_vocab = questions.iter().filter(is_vocab_of(&store, true)).count();
        let older_vocab = questions.iter().filter(is_vocab_of(&store, false)).count();
        assert_eq!((recent_vocab, older_vocab), (2, 2), "seed {seed}");
        let recent_grammar = questions
            .iter()
            .filter(|q| q.reference.content_id == "gr.plain_style")
            .count();
        assert_eq!(recent_grammar, 2, "seed {seed}");
    }
}

fn is_vocab_of(store: &ContentStore, recent: bool) -> impl Fn(&&Question) -> bool + '_ {
    move |question| {
        store
            .vocab_by_id(&question.reference.content_id)
            .is_some_and(|v| {
                ["le.l21", "le.l08", "le.l03"].contains(&v.def.lesson.as_str()) == recent
            })
    }
}

#[test]
fn lesson_exam_excludes_later_lessons_and_unintroduced_items() {
    let store = content();
    let mut known = all_known(&store);
    known.remove("vo.gohan");
    known.remove("gr.wo_obj");

    let questions = start(&store, &known, "ms.survive");

    for question in &questions {
        let id = question.reference.content_id.as_str();
        assert_ne!(id, "vo.gohan");
        assert_ne!(id, "gr.wo_obj");
        let lesson = store.vocab_by_id(id).map(|v| v.def.lesson.as_str());
        if let Some(lesson) = lesson {
            assert!(["le.l01", "le.l02", "le.l03"].contains(&lesson), "{id}");
        }
        assert_ne!(question.question_type, QuestionType::Shadowing);
    }
}

#[test]
fn lesson_exam_returns_actual_count_when_short() {
    let store = content();
    let known = set(&["vo.gohan", "vo.ocha", "vo.sensei"]);

    let questions = start(&store, &known, "ms.survive");

    assert_eq!(questions.len(), 3);
    assert!(questions
        .iter()
        .all(|q| matches!(q.body, QuestionBody::Choice { .. })));
}

#[test]
fn start_is_deterministic_for_a_seed() {
    let store = content();
    let known = all_known(&store);

    assert_eq!(
        start(&store, &known, "ms.casual"),
        start(&store, &known, "ms.casual")
    );
}

#[test]
fn unknown_milestone_is_not_found() {
    let store = content();
    let known = HashSet::new();

    assert!(matches!(
        checkpoint_start(&ctx(&store, &known), "ms.nope"),
        Err(QuizError::NotFound { .. })
    ));
}

#[test]
fn finish_passes_at_ratio_and_writes_result_without_fsrs() {
    let store = content();
    let repo = SqliteRepository::open_in_memory().unwrap();
    let known = HashSet::new();
    let questions = start(&store, &known, "ms.hira");
    let answers: Vec<_> = questions
        .iter()
        .enumerate()
        .map(|(i, q)| {
            answer(
                q,
                if i < 2 {
                    wrong_answer(q)
                } else {
                    right_answer(q)
                },
            )
        })
        .collect();

    let result = checkpoint_finish(&repo, &store, &day(), "ms.hira", &answers).unwrap();

    assert_eq!((result.correct, result.total), (18, 20));
    assert_eq!(result.score_percent, 90);
    assert!(result.passed);
    assert_eq!(result.weak_ids.len(), 2);
    assert_eq!(result.weak_ids[0], questions[0].reference.content_id);
    let saved = repo.milestone_results().unwrap();
    assert_eq!(saved.len(), 1);
    assert_eq!(saved[0].milestone_id, "ms.hira");
    assert_eq!(
        (saved[0].correct, saved[0].total, saved[0].passed),
        (18, 20, true)
    );
    assert_eq!(saved[0].logical_date, day().today());
    assert_eq!(repo.card_counts().unwrap().total_reviews, 0);
}

#[test]
fn finish_fails_below_ratio_and_weak_ids_are_deduplicated() {
    let store = content();
    let repo = SqliteRepository::open_in_memory().unwrap();
    let known = HashSet::new();
    let questions = start(&store, &known, "ms.hira");
    let first = &questions[0];
    let mut twin = answer(first, wrong_answer(first));
    twin.reference.variant = Some(99);
    let answers: Vec<_> = vec![
        answer(first, wrong_answer(first)),
        twin,
        answer(&questions[1], right_answer(&questions[1])),
    ];

    let result = checkpoint_finish(&repo, &store, &day(), "ms.hira", &answers).unwrap();

    assert_eq!((result.correct, result.total), (1, 3));
    assert_eq!(result.score_percent, 33);
    assert!(!result.passed);
    assert_eq!(result.weak_ids, vec![first.reference.content_id.clone()]);
}

#[test]
fn repeated_references_count_only_the_first_answer() {
    let store = content();
    let repo = SqliteRepository::open_in_memory().unwrap();
    let known = HashSet::new();
    let questions = start(&store, &known, "ms.hira");
    let question = &questions[0];
    let answers = vec![
        answer(question, wrong_answer(question)),
        answer(question, right_answer(question)),
    ];

    let result = checkpoint_finish(&repo, &store, &day(), "ms.hira", &answers).unwrap();

    assert_eq!((result.correct, result.total), (0, 1));
}

#[test]
fn finish_rejects_empty_answers_and_unknown_milestone() {
    let store = content();
    let repo = SqliteRepository::open_in_memory().unwrap();

    assert!(matches!(
        checkpoint_finish(&repo, &store, &day(), "ms.hira", &[]),
        Err(QuizError::InvalidInput { .. })
    ));
    let known = HashSet::new();
    let questions = start(&store, &known, "ms.hira");
    let answers = vec![answer(&questions[0], right_answer(&questions[0]))];
    assert!(matches!(
        checkpoint_finish(&repo, &store, &day(), "ms.nope", &answers),
        Err(QuizError::NotFound { .. })
    ));
    assert_eq!(repo.milestone_results().unwrap().len(), 0);
}

#[test]
fn dismiss_writes_and_rejects_unknown() {
    let store = content();
    let repo = SqliteRepository::open_in_memory().unwrap();

    checkpoint_dismiss(&repo, &store, &day(), "ms.hira").unwrap();

    assert!(repo.dismissed_milestones().unwrap().contains("ms.hira"));
    assert!(matches!(
        checkpoint_dismiss(&repo, &store, &day(), "ms.nope"),
        Err(QuizError::NotFound { .. })
    ));
}

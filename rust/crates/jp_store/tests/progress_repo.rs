//! §5.4 PlanRepo：complete_task、假名熟練、里程碑、單字旗標。

mod common;

use chrono::Duration;
use common::*;
use jp_store::{
    ActivityDelta, ActivityRepo, CompleteTaskWrite, ItemIntroRow, KanaMasteryRow,
    LessonProgressUpdate, MilestoneResultRow, PlanRepo, SrsRepo, StoreError, VocabFlagRow,
    VocabFlagsWrite,
};

fn task(key: &str) -> CompleteTaskWrite {
    CompleteTaskWrite {
        logical_date: d(TODAY),
        task_key: key.to_string(),
        done_at: ts(NOW),
        item_intros: vec![],
        new_cards: vec![],
        lesson_updates: vec![],
        activity: ActivityDelta::default(),
    }
}

fn intro(item_id: &str, lesson_id: &str) -> ItemIntroRow {
    ItemIntroRow {
        item_id: item_id.to_string(),
        lesson_id: lesson_id.to_string(),
        logical_date: d(TODAY),
        introduced_at: ts(NOW),
    }
}

fn integration_day(lesson_id: &str, completed: bool) -> LessonProgressUpdate {
    LessonProgressUpdate {
        lesson_id: lesson_id.to_string(),
        integration_days_added: 1,
        integration_dialogue: None,
        completed,
    }
}

#[test]
fn complete_task_applies_every_side_effect_together() {
    let db = temp_db();
    let write = CompleteTaskWrite {
        item_intros: vec![intro("vo.a", "le.l01"), intro("gr.a", "le.l01")],
        new_cards: vec![old_card("vo.a:recog", 0)],
        lesson_updates: vec![LessonProgressUpdate {
            integration_dialogue: Some("di.extra_1".to_string()),
            ..integration_day("le.l01", true)
        }],
        activity: ActivityDelta {
            lessons_done: 1,
            study_ms: 60_000,
            ..ActivityDelta::default()
        },
        ..task("new:vo.a")
    };

    db.repo.complete_task(&write).unwrap();

    assert!(db.repo.task_done(d(TODAY)).unwrap().contains("new:vo.a"));
    let introduced = db.repo.introduced_items().unwrap();
    assert!(introduced.contains("vo.a") && introduced.contains("gr.a"));
    assert!(db.repo.card("vo.a:recog").unwrap().is_some());
    let lesson = db.repo.lesson_progress().unwrap().remove("le.l01").unwrap();
    assert_eq!(lesson.integration_days_done, 1);
    assert_eq!(lesson.integration_dialogue.as_deref(), Some("di.extra_1"));
    assert_eq!(lesson.completed_date, Some(d(TODAY)));
    assert_eq!(lesson.completed_at, Some(ts(NOW)));
    assert!(!lesson.skipped);
    let activity = db.repo.activity_range(d(TODAY), d(TODAY)).unwrap();
    assert_eq!(activity[0].lessons_done, 1);
    assert_eq!(activity[0].study_ms, 60_000);
}

#[test]
fn repeating_a_task_key_is_a_no_op() {
    let db = temp_db();
    let write = CompleteTaskWrite {
        lesson_updates: vec![integration_day("le.l01", false)],
        activity: ActivityDelta {
            study_ms: 1000,
            ..ActivityDelta::default()
        },
        ..task("integration:le.l01:1")
    };

    db.repo.complete_task(&write).unwrap();
    db.repo.complete_task(&write).unwrap();

    let lesson = db.repo.lesson_progress().unwrap().remove("le.l01").unwrap();
    assert_eq!(lesson.integration_days_done, 1);
    let activity = db.repo.activity_range(d(TODAY), d(TODAY)).unwrap();
    assert_eq!(activity[0].study_ms, 1000);
}

#[test]
fn same_key_on_another_day_runs_again() {
    let db = temp_db();
    let write = CompleteTaskWrite {
        activity: ActivityDelta {
            study_ms: 1000,
            ..ActivityDelta::default()
        },
        ..task("review")
    };
    let tomorrow = CompleteTaskWrite {
        logical_date: d("2026-03-05"),
        ..write.clone()
    };

    db.repo.complete_task(&write).unwrap();
    db.repo.complete_task(&tomorrow).unwrap();

    assert_eq!(db.repo.task_done(d(TODAY)).unwrap().len(), 1);
    assert_eq!(db.repo.task_done(d("2026-03-05")).unwrap().len(), 1);
    assert_eq!(db.repo.task_done(d("2026-03-06")).unwrap().len(), 0);
}

#[test]
fn complete_task_is_atomic() {
    let db = temp_db();
    let mut bad_card = old_card("vo.a:recog", 0);
    bad_card.facet = "write".to_string();
    let write = CompleteTaskWrite {
        item_intros: vec![intro("vo.a", "le.l01")],
        new_cards: vec![bad_card],
        lesson_updates: vec![integration_day("le.l01", true)],
        ..task("new:vo.a")
    };

    let err = db.repo.complete_task(&write).unwrap_err();

    assert!(matches!(err, StoreError::Storage { .. }), "{err:?}");
    assert!(db.repo.task_done(d(TODAY)).unwrap().is_empty());
    assert!(db.repo.introduced_items().unwrap().is_empty());
    assert!(db.repo.lesson_progress().unwrap().is_empty());
}

#[test]
fn lesson_progress_accumulates_days_and_keeps_first_completion() {
    let db = temp_db();
    let day_one = CompleteTaskWrite {
        lesson_updates: vec![LessonProgressUpdate {
            integration_dialogue: Some("di.extra_1".to_string()),
            ..integration_day("le.l01", false)
        }],
        ..task("integration:le.l01:1")
    };
    let day_two = CompleteTaskWrite {
        logical_date: d("2026-03-05"),
        done_at: ts(NOW) + Duration::days(1),
        lesson_updates: vec![integration_day("le.l01", true)],
        ..task("integration:le.l01:2")
    };
    let late_repeat = CompleteTaskWrite {
        logical_date: d("2026-03-06"),
        done_at: ts(NOW) + Duration::days(2),
        lesson_updates: vec![LessonProgressUpdate {
            integration_days_added: 0,
            ..integration_day("le.l01", true)
        }],
        ..task("other")
    };

    db.repo.complete_task(&day_one).unwrap();
    assert_eq!(
        db.repo.lesson_progress().unwrap()["le.l01"].completed_date,
        None
    );
    db.repo.complete_task(&day_two).unwrap();
    db.repo.complete_task(&late_repeat).unwrap();

    let lesson = db.repo.lesson_progress().unwrap().remove("le.l01").unwrap();
    assert_eq!(lesson.integration_days_done, 2);
    assert_eq!(lesson.integration_dialogue.as_deref(), Some("di.extra_1"));
    assert_eq!(lesson.completed_date, Some(d("2026-03-05")));
}

#[test]
fn intros_keep_the_first_record() {
    let db = temp_db();
    let earlier = CompleteTaskWrite {
        item_intros: vec![intro("vo.a", "le.l01")],
        ..task("new:vo.a")
    };
    let later = CompleteTaskWrite {
        item_intros: vec![ItemIntroRow {
            lesson_id: "le.l02".to_string(),
            ..intro("vo.a", "le.l02")
        }],
        ..task("new:vo.b")
    };

    db.repo.complete_task(&earlier).unwrap();
    db.repo.complete_task(&later).unwrap();

    let lesson: String = raw(&db.path)
        .query_row(
            "SELECT lesson_id FROM item_intro WHERE item_id = 'vo.a'",
            [],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(lesson, "le.l01");
}

#[test]
fn insert_item_intros_reports_new_rows_only() {
    let db = temp_db();
    let rows = [intro("vo.a", "le.l01"), intro("vo.b", "le.l01")];

    assert_eq!(db.repo.insert_item_intros(&rows).unwrap(), 2);
    assert_eq!(db.repo.insert_item_intros(&rows).unwrap(), 0);
    assert_eq!(db.repo.introduced_items().unwrap().len(), 2);
}

#[test]
fn kana_mastery_upserts_and_lists() {
    let db = temp_db();
    assert_eq!(db.repo.kana_mastery("ka.hira.a").unwrap(), None);
    let first = KanaMasteryRow {
        kana_id: "ka.hira.a".to_string(),
        correct_run: 1,
        fast_run: 1,
        attempts: 1,
        mastered_at: None,
        fast_badge_at: None,
    };
    let updated = KanaMasteryRow {
        correct_run: 2,
        fast_run: 2,
        attempts: 2,
        mastered_at: Some(ts(NOW)),
        fast_badge_at: Some(ts(NOW)),
        ..first.clone()
    };
    let other = KanaMasteryRow {
        kana_id: "ka.hira.i".to_string(),
        ..first.clone()
    };

    db.repo.put_kana_mastery(&first).unwrap();
    db.repo.put_kana_mastery(&updated).unwrap();
    db.repo.put_kana_mastery(&other).unwrap();

    assert_eq!(
        db.repo.kana_mastery("ka.hira.a").unwrap(),
        Some(updated.clone())
    );
    assert_eq!(db.repo.all_kana_mastery().unwrap(), vec![updated, other]);
}

#[test]
fn milestone_results_append_in_order() {
    let db = temp_db();
    assert!(db.repo.milestone_results().unwrap().is_empty());
    let failed = MilestoneResultRow {
        milestone_id: "ms.hira".to_string(),
        correct: 5,
        total: 10,
        passed: false,
        logical_date: d("2026-03-01"),
        taken_at: ts(LONG_AGO),
    };
    let passed = MilestoneResultRow {
        correct: 10,
        passed: true,
        logical_date: d(TODAY),
        taken_at: ts(NOW),
        ..failed.clone()
    };

    db.repo.insert_milestone_result(&failed).unwrap();
    db.repo.insert_milestone_result(&passed).unwrap();

    assert_eq!(db.repo.milestone_results().unwrap(), vec![failed, passed]);
}

#[test]
fn dismissing_a_milestone_twice_keeps_it_dismissed() {
    let db = temp_db();

    db.repo
        .dismiss_milestone("ms.hira", d(TODAY), ts(NOW))
        .unwrap();
    db.repo
        .dismiss_milestone("ms.hira", d("2026-03-05"), ts(NOW))
        .unwrap();

    let dismissed = db.repo.dismissed_milestones().unwrap();
    assert_eq!(dismissed.len(), 1);
    assert!(dismissed.contains("ms.hira"));
}

#[test]
fn vocab_flags_upsert() {
    let db = temp_db();
    assert!(db.repo.vocab_flags().unwrap().is_empty());
    let known = VocabFlagRow {
        vocab_id: "vo.a".to_string(),
        known: true,
        starred: false,
        updated_at: ts(LONG_AGO),
    };
    let starred = VocabFlagRow {
        known: false,
        starred: true,
        updated_at: ts(NOW),
        ..known.clone()
    };

    db.repo.put_vocab_flags(&known).unwrap();
    db.repo.put_vocab_flags(&starred).unwrap();

    let flags = db.repo.vocab_flags().unwrap();
    assert_eq!(flags.len(), 1);
    assert_eq!(flags["vo.a"], starred);
}

fn flag(vocab_id: &str, known: bool) -> VocabFlagRow {
    VocabFlagRow {
        vocab_id: vocab_id.to_string(),
        known,
        starred: false,
        updated_at: ts(NOW),
    }
}

fn is_suspended(db: &TestDb, card_id: &str) -> bool {
    db.repo.card(card_id).unwrap().unwrap().suspended
}

#[test]
fn apply_vocab_flags_writes_suspension_intro_and_flag_together() {
    let db = temp_db();
    db.repo.insert_cards(&[old_card("vo.a:recog", 0)]).unwrap();

    db.repo
        .apply_vocab_flags(&VocabFlagsWrite {
            flag: flag("vo.a", true),
            suspended: Some(true),
            add_intro: Some(intro("vo.a", "le.l01")),
            remove_intro: false,
            new_cards: vec![],
        })
        .unwrap();

    assert!(is_suspended(&db, "vo.a:recog"));
    assert!(db.repo.introduced_items().unwrap().contains("vo.a"));
    assert!(db.repo.vocab_flags().unwrap()["vo.a"].known);
}

#[test]
fn apply_vocab_flags_can_forget_an_intro_and_create_cards() {
    let db = temp_db();
    db.repo
        .insert_item_intros(&[intro("vo.a", "le.l01")])
        .unwrap();

    db.repo
        .apply_vocab_flags(&VocabFlagsWrite {
            flag: flag("vo.a", false),
            suspended: Some(false),
            add_intro: None,
            remove_intro: true,
            new_cards: vec![old_card("vo.a:recog", 0)],
        })
        .unwrap();

    assert!(!db.repo.introduced_items().unwrap().contains("vo.a"));
    assert!(db.repo.card("vo.a:recog").unwrap().is_some());
}

/// 任何一步失敗都整筆回滾：不留下「卡片已暫停、旗標未寫」的中間狀態。
#[test]
fn apply_vocab_flags_rolls_back_when_a_step_fails() {
    let db = temp_db();
    db.repo.insert_cards(&[old_card("vo.a:recog", 0)]).unwrap();
    let mut invalid = old_card("vo.b:recog", 0);
    invalid.facet = "no_such_facet".to_string();

    let result = db.repo.apply_vocab_flags(&VocabFlagsWrite {
        flag: flag("vo.a", true),
        suspended: Some(true),
        add_intro: Some(intro("vo.a", "le.l01")),
        remove_intro: false,
        new_cards: vec![invalid],
    });

    assert!(result.is_err());
    assert!(!is_suspended(&db, "vo.a:recog"));
    assert!(!db.repo.introduced_items().unwrap().contains("vo.a"));
    assert!(db.repo.vocab_flags().unwrap().is_empty());
}

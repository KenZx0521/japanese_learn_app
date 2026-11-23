//! §5.4 PlanRepo：計畫版本、略過、快照。進度相關的寫入在 progress_repo.rs。

mod common;

use chrono::{DateTime, NaiveDate, Utc};
use common::*;
use jp_store::{
    ActivityDelta, CompleteTaskWrite, ItemIntroRow, LessonProgressUpdate, NewPlan, PlanRepo,
    SkipWrite, SnapshotRow, StoreError,
};

fn plan(effective_from: &str, minutes: u32) -> NewPlan {
    NewPlan {
        effective_from: d(effective_from),
        daily_minutes: minutes,
        weekday_mask: 127,
        start_level: "zero".to_string(),
        target_date: None,
        created_at: ts(NOW),
    }
}

fn no_skips() -> SkipWrite {
    SkipWrite {
        item_intros: vec![],
        lesson_ids: vec![],
        completed_date: d(TODAY),
        completed_at: ts(NOW),
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

fn snapshot(on: NaiveDate, plan_id: i64, payload: &str) -> SnapshotRow {
    SnapshotRow {
        logical_date: on,
        plan_version_id: plan_id,
        payload_json: payload.to_string(),
        created_at: ts(NOW),
    }
}

fn baseline_of(pairs: &[(&str, &str)]) -> Vec<(String, NaiveDate)> {
    pairs
        .iter()
        .map(|(id, on)| (id.to_string(), d(on)))
        .collect()
}

fn insert(repo: &impl PlanRepo, new_plan: &NewPlan) -> i64 {
    repo.insert_plan(new_plan, &[], &no_skips()).unwrap()
}

#[test]
fn active_plan_is_none_without_plans() {
    let db = temp_db();

    assert_eq!(db.repo.active_plan(d(TODAY)).unwrap(), None);
    assert!(db.repo.plan_versions().unwrap().is_empty());
}

#[test]
fn active_plan_falls_back_to_earliest_plan_before_any_effective_date() {
    let db = temp_db();
    let earliest = insert(&db.repo, &plan("2026-03-01", 10));
    insert(&db.repo, &plan("2026-03-09", 45));

    let row = db.repo.active_plan(d("2026-02-28")).unwrap().unwrap();

    assert_eq!(row.id, earliest);
}

#[test]
fn active_plan_fallback_picks_highest_id_when_earliest_date_is_shared() {
    let db = temp_db();
    insert(&db.repo, &plan("2026-03-01", 10));
    let updated_same_day = insert(&db.repo, &plan("2026-03-01", 20));

    let row = db.repo.active_plan(d("2026-02-28")).unwrap().unwrap();

    assert_eq!(row.id, updated_same_day);
}

#[test]
fn plan_round_trips_every_field() {
    let db = temp_db();
    let created: DateTime<Utc> = ts(NOW);
    let new_plan = NewPlan {
        effective_from: d(TODAY),
        daily_minutes: 45,
        weekday_mask: 0b0010101,
        start_level: "hiragana".to_string(),
        target_date: Some(d("2027-01-01")),
        created_at: created,
    };

    let id = insert(&db.repo, &new_plan);

    let row = db.repo.active_plan(d(TODAY)).unwrap().unwrap();
    assert_eq!(row.id, id);
    assert_eq!(row.effective_from, d(TODAY));
    assert_eq!(row.daily_minutes, 45);
    assert_eq!(row.weekday_mask, 0b0010101);
    assert_eq!(row.start_level, "hiragana");
    assert_eq!(row.target_date, Some(d("2027-01-01")));
    assert_eq!(row.created_at, created);
}

#[test]
fn active_plan_picks_latest_effective_and_highest_id_on_same_day() {
    let db = temp_db();
    let early = insert(&db.repo, &plan("2026-03-01", 10));
    let first_same_day = insert(&db.repo, &plan(TODAY, 20));
    let second_same_day = insert(&db.repo, &plan(TODAY, 30));
    insert(&db.repo, &plan("2026-03-09", 45));

    assert_eq!(
        db.repo.active_plan(d("2026-03-02")).unwrap().unwrap().id,
        early
    );
    assert_eq!(
        db.repo.active_plan(d(TODAY)).unwrap().unwrap().id,
        second_same_day
    );
    assert_ne!(first_same_day, second_same_day);
    assert_eq!(
        db.repo.active_plan(d("2026-03-08")).unwrap().unwrap().id,
        second_same_day
    );
}

#[test]
fn plan_versions_lists_in_effective_order() {
    let db = temp_db();
    let later = insert(&db.repo, &plan("2026-03-09", 45));
    let earlier = insert(&db.repo, &plan("2026-03-01", 10));

    let ids: Vec<i64> = db
        .repo
        .plan_versions()
        .unwrap()
        .iter()
        .map(|p| p.id)
        .collect();

    assert_eq!(ids, vec![earlier, later]);
}

#[test]
fn insert_plan_stores_baseline() {
    let db = temp_db();
    let pairs = [("ms.kata", "2026-05-01"), ("ms.hira", "2026-04-01")];

    let id = db
        .repo
        .insert_plan(&plan(TODAY, 20), &baseline_of(&pairs), &no_skips())
        .unwrap();

    assert_eq!(
        db.repo.baseline(id).unwrap(),
        baseline_of(&[("ms.hira", "2026-04-01"), ("ms.kata", "2026-05-01")])
    );
    assert!(db.repo.baseline(id + 1).unwrap().is_empty());
}

#[test]
fn insert_plan_is_atomic() {
    let db = temp_db();
    let duplicated = baseline_of(&[("ms.hira", "2026-04-01"), ("ms.hira", "2026-05-01")]);
    let skips = SkipWrite {
        item_intros: vec![intro("ka.hira.a", "le.k01")],
        lesson_ids: vec!["le.k01".to_string()],
        ..no_skips()
    };

    let err = db
        .repo
        .insert_plan(&plan(TODAY, 20), &duplicated, &skips)
        .unwrap_err();

    assert!(matches!(err, StoreError::Storage { .. }), "{err:?}");
    assert!(db.repo.plan_versions().unwrap().is_empty());
    assert!(db.repo.introduced_items().unwrap().is_empty());
    assert!(db.repo.lesson_progress().unwrap().is_empty());
}

#[test]
fn insert_plan_deletes_snapshot_of_its_effective_date_only() {
    let db = temp_db();
    let first = insert(&db.repo, &plan("2026-03-01", 20));
    db.repo
        .put_snapshot(&snapshot(d(TODAY), first, "{}"))
        .unwrap();
    db.repo
        .put_snapshot(&snapshot(d("2026-03-03"), first, "{}"))
        .unwrap();

    insert(&db.repo, &plan(TODAY, 30));

    assert_eq!(db.repo.snapshot(d(TODAY)).unwrap(), None);
    assert!(db.repo.snapshot(d("2026-03-03")).unwrap().is_some());
}

#[test]
fn skips_write_intros_and_mark_lessons_skipped() {
    let db = temp_db();
    let skips = SkipWrite {
        item_intros: vec![intro("ka.hira.a", "le.k01"), intro("ka.hira.i", "le.k01")],
        lesson_ids: vec!["le.k01".to_string()],
        ..no_skips()
    };

    db.repo.insert_plan(&plan(TODAY, 20), &[], &skips).unwrap();

    let introduced = db.repo.introduced_items().unwrap();
    assert!(introduced.contains("ka.hira.a") && introduced.contains("ka.hira.i"));
    let progress = db.repo.lesson_progress().unwrap();
    let lesson = &progress["le.k01"];
    assert!(lesson.skipped);
    assert_eq!(lesson.completed_date, Some(d(TODAY)));
    assert_eq!(lesson.completed_at, Some(ts(NOW)));
    assert_eq!(lesson.integration_days_done, 0);
}

#[test]
fn skips_are_idempotent_and_keep_original_completion() {
    let db = temp_db();
    let first = SkipWrite {
        item_intros: vec![intro("ka.hira.a", "le.k01")],
        lesson_ids: vec!["le.k01".to_string()],
        completed_date: d("2026-03-01"),
        completed_at: ts(LONG_AGO),
    };
    db.repo
        .insert_plan(&plan("2026-03-01", 20), &[], &first)
        .unwrap();
    let second = SkipWrite {
        completed_date: d(TODAY),
        completed_at: ts(NOW),
        ..first.clone()
    };

    db.repo.insert_plan(&plan(TODAY, 30), &[], &second).unwrap();

    let lesson = db.repo.lesson_progress().unwrap().remove("le.k01").unwrap();
    assert_eq!(lesson.completed_date, Some(d("2026-03-01")));
    assert_eq!(db.repo.introduced_items().unwrap().len(), 1);
}

#[test]
fn skip_finishes_a_lesson_that_was_started_but_leaves_finished_lessons_alone() {
    let db = temp_db();
    let started = CompleteTaskWrite {
        logical_date: d("2026-03-01"),
        task_key: "started".to_string(),
        done_at: ts(LONG_AGO),
        item_intros: vec![],
        new_cards: vec![],
        lesson_updates: vec![
            LessonProgressUpdate {
                lesson_id: "le.k01".to_string(),
                integration_days_added: 0,
                integration_dialogue: None,
                completed: false,
            },
            LessonProgressUpdate {
                lesson_id: "le.k02".to_string(),
                integration_days_added: 0,
                integration_dialogue: None,
                completed: true,
            },
        ],
        activity: ActivityDelta::default(),
    };
    db.repo.complete_task(&started).unwrap();
    let skips = SkipWrite {
        lesson_ids: vec!["le.k01".to_string(), "le.k02".to_string()],
        ..no_skips()
    };

    db.repo.insert_plan(&plan(TODAY, 20), &[], &skips).unwrap();

    let progress = db.repo.lesson_progress().unwrap();
    assert!(progress["le.k01"].skipped);
    assert_eq!(progress["le.k01"].completed_date, Some(d(TODAY)));
    assert!(!progress["le.k02"].skipped);
    assert_eq!(progress["le.k02"].completed_date, Some(d("2026-03-01")));
}

#[test]
fn snapshot_upserts_and_reads_back() {
    let db = temp_db();
    let id = insert(&db.repo, &plan("2026-03-01", 20));
    let on = d(TODAY);

    assert_eq!(db.repo.snapshot(on).unwrap(), None);
    db.repo
        .put_snapshot(&snapshot(on, id, "{\"v\":1}"))
        .unwrap();
    assert_eq!(
        db.repo.snapshot(on).unwrap().unwrap().payload_json,
        "{\"v\":1}"
    );

    db.repo
        .put_snapshot(&snapshot(on, id, "{\"v\":2}"))
        .unwrap();
    let row = db.repo.snapshot(on).unwrap().unwrap();
    assert_eq!(row, snapshot(on, id, "{\"v\":2}"));
}

#[test]
fn latest_snapshot_before_is_strictly_earlier() {
    let db = temp_db();
    let id = insert(&db.repo, &plan("2026-03-01", 20));
    db.repo
        .put_snapshot(&snapshot(d("2026-03-01"), id, "a"))
        .unwrap();
    db.repo
        .put_snapshot(&snapshot(d("2026-03-03"), id, "b"))
        .unwrap();
    db.repo.put_snapshot(&snapshot(d(TODAY), id, "c")).unwrap();

    let latest = db.repo.latest_snapshot_before(d(TODAY)).unwrap().unwrap();

    assert_eq!(latest.payload_json, "b");
    assert_eq!(
        db.repo.latest_snapshot_before(d("2026-03-01")).unwrap(),
        None
    );
}

#[test]
fn delete_snapshot_removes_only_that_day_and_tolerates_missing() {
    let db = temp_db();
    let id = insert(&db.repo, &plan("2026-03-01", 20));
    db.repo.put_snapshot(&snapshot(d(TODAY), id, "a")).unwrap();
    db.repo
        .put_snapshot(&snapshot(d("2026-03-03"), id, "b"))
        .unwrap();

    db.repo.delete_snapshot(d(TODAY)).unwrap();
    db.repo.delete_snapshot(d(TODAY)).unwrap();

    assert_eq!(db.repo.snapshot(d(TODAY)).unwrap(), None);
    assert!(db.repo.snapshot(d("2026-03-03")).unwrap().is_some());
}

#[test]
fn snapshot_for_unknown_plan_is_rejected_by_foreign_key() {
    let db = temp_db();

    let err = db
        .repo
        .put_snapshot(&snapshot(d(TODAY), 99, "{}"))
        .unwrap_err();

    assert!(matches!(err, StoreError::Storage { .. }), "{err:?}");
}

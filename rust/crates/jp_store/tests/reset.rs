//! §5.5 reset_all 與 delete_database。

mod common;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;

use common::*;
use jp_store::{
    delete_database, ActivityDelta, ActivityRepo, MilestoneResultRow, NewPlan, PlanRepo,
    SettingsRepo, SettingsRow, SkipWrite, SqliteRepository, SrsRepo, StoreError,
    LATEST_SCHEMA_VERSION,
};

fn plan() -> NewPlan {
    NewPlan {
        effective_from: d(TODAY),
        daily_minutes: 20,
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

/// 把 append-only 的三張表與設定都寫入資料。
fn populate(repo: &SqliteRepository) {
    repo.insert_cards(&[old_card("vo.a:recog", 0)]).unwrap();
    repo.apply_review(&review_write("vo.a:recog", 0, 0, 1, ts(NOW), d(TODAY)))
        .unwrap();
    repo.insert_plan(&plan(), &[], &no_skips()).unwrap();
    repo.insert_milestone_result(&MilestoneResultRow {
        milestone_id: "ms.hira".to_string(),
        correct: 1,
        total: 2,
        passed: false,
        logical_date: d(TODAY),
        taken_at: ts(NOW),
    })
    .unwrap();
    repo.put_settings(&SettingsRow {
        tts_rate: 0.7,
        ..SettingsRow::default()
    })
    .unwrap();
}

#[test]
fn reset_clears_all_data_including_append_only_tables_and_settings() {
    let db = temp_db();
    populate(&db.repo);

    db.repo.reset_all().unwrap();

    assert_eq!(db.repo.card("vo.a:recog").unwrap(), None);
    assert!(db.repo.reviews_for_card("vo.a:recog").unwrap().is_empty());
    assert!(db.repo.plan_versions().unwrap().is_empty());
    assert!(db.repo.milestone_results().unwrap().is_empty());
    assert!(db
        .repo
        .activity_range(d(TODAY), d(TODAY))
        .unwrap()
        .is_empty());
    assert_eq!(db.repo.get_settings().unwrap(), SettingsRow::default());
}

#[test]
fn connection_stays_usable_and_on_disk_after_reset() {
    let db = temp_db();
    populate(&db.repo);

    db.repo.reset_all().unwrap();
    populate(&db.repo);

    assert_eq!(db.repo.reviews_for_card("vo.a:recog").unwrap().len(), 1);
    drop(db.repo);
    let conn = raw(&db.path);
    assert_eq!(user_version(&conn), LATEST_SCHEMA_VERSION);
    assert_eq!(count_rows(&conn, "review_log"), 1);
    let mode: String = conn
        .query_row("PRAGMA journal_mode", [], |row| row.get(0))
        .unwrap();
    assert_eq!(mode, "wal");
}

#[test]
fn reset_keeps_triggers_in_force() {
    let db = temp_db();
    db.repo.reset_all().unwrap();
    populate(&db.repo);

    let err = raw(&db.path)
        .execute_batch("DELETE FROM review_log;")
        .unwrap_err();

    assert!(err.to_string().contains("append-only"), "{err}");
}

#[test]
fn reset_works_on_in_memory_repository() {
    let repo = SqliteRepository::open_in_memory().unwrap();
    populate(&repo);

    repo.reset_all().unwrap();

    assert!(repo.plan_versions().unwrap().is_empty());
    populate(&repo);
    assert_eq!(repo.plan_versions().unwrap().len(), 1);
}

#[test]
fn failed_reset_reports_storage_and_next_open_starts_fresh() {
    let dir = tempfile::tempdir().unwrap();
    let data_dir = dir.path().join("data");
    std::fs::create_dir(&data_dir).unwrap();
    let path = data_dir.join("jp_core.db");
    let repo = SqliteRepository::open(&path).unwrap();
    populate(&repo);
    std::fs::remove_dir_all(&data_dir).unwrap();

    let err = repo.reset_all().unwrap_err();

    assert!(matches!(err, StoreError::Storage { .. }), "{err:?}");
    // 連線停在沒有 schema 的記憶體庫：回錯誤，不 panic，也不會把資料寫到別處。
    assert!(matches!(
        repo.get_settings().unwrap_err(),
        StoreError::Storage { .. }
    ));
    drop(repo);

    std::fs::create_dir(&data_dir).unwrap();
    let reopened = SqliteRepository::open(&path).unwrap();
    assert!(reopened.plan_versions().unwrap().is_empty());
}

#[test]
fn concurrent_calls_never_observe_the_swap() {
    let db = temp_db();
    db.repo
        .add_activity(d(TODAY), ActivityDelta::default())
        .unwrap();
    let repo = Arc::new(db.repo);
    let stop = Arc::new(AtomicBool::new(false));
    let readers: Vec<_> = (0..4)
        .map(|_| {
            let repo = Arc::clone(&repo);
            let stop = Arc::clone(&stop);
            thread::spawn(move || {
                while !stop.load(Ordering::Relaxed) {
                    repo.card_counts().unwrap();
                    repo.get_settings().unwrap();
                }
            })
        })
        .collect();

    for _ in 0..20 {
        repo.reset_all().unwrap();
    }

    stop.store(true, Ordering::Relaxed);
    for reader in readers {
        reader.join().unwrap();
    }
}

#[test]
fn delete_database_removes_db_wal_and_shm() {
    let dir = tempfile::tempdir().unwrap();
    let path = db_path(&dir);
    let siblings = ["jp_core.db", "jp_core.db-wal", "jp_core.db-shm"];
    for name in siblings {
        std::fs::write(dir.path().join(name), b"x").unwrap();
    }
    let unrelated = dir.path().join("jp_core.db.bak");
    std::fs::write(&unrelated, b"x").unwrap();

    delete_database(&path).unwrap();

    for name in siblings {
        assert!(!dir.path().join(name).exists(), "{name} 應已刪除");
    }
    assert!(unrelated.exists());
}

#[test]
fn delete_database_tolerates_missing_files() {
    let dir = tempfile::tempdir().unwrap();

    delete_database(db_path(&dir)).unwrap();
}

#[test]
fn delete_database_reports_failure_but_still_tries_the_rest() {
    let dir = tempfile::tempdir().unwrap();
    let path = db_path(&dir);
    std::fs::write(&path, b"x").unwrap();
    // 目錄無法用 remove_file 刪除，模擬 -wal 刪除失敗。
    std::fs::create_dir(dir.path().join("jp_core.db-wal")).unwrap();
    let shm = dir.path().join("jp_core.db-shm");
    std::fs::write(&shm, b"x").unwrap();

    let err = delete_database(&path).unwrap_err();

    assert!(matches!(err, StoreError::Storage { .. }), "{err:?}");
    assert!(!path.exists());
    assert!(!shm.exists());
}

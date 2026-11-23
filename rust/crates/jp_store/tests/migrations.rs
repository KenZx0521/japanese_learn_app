//! §5.1 開檔與 §5.2 遷移。

mod common;

use common::*;
use jp_store::{SettingsRepo, SettingsRow, SqliteRepository, StoreError, LATEST_SCHEMA_VERSION};
use rusqlite::Connection;

#[test]
fn migrates_empty_database_to_latest_version() {
    let db = temp_db();

    let conn = raw(&db.path);

    assert_eq!(user_version(&conn), LATEST_SCHEMA_VERSION);
    assert!(table_exists(&conn, "srs_card"));
    assert!(table_exists(&conn, "vocab_flag"));
}

#[test]
fn reopening_is_idempotent_and_keeps_data() {
    let db = temp_db();
    let saved = SettingsRow {
        tts_rate: 0.7,
        ..SettingsRow::default()
    };
    db.repo.put_settings(&saved).unwrap();
    drop(db.repo);

    let reopened = SqliteRepository::open(&db.path).unwrap();

    assert_eq!(reopened.get_settings().unwrap(), saved);
    assert_eq!(user_version(&raw(&db.path)), LATEST_SCHEMA_VERSION);
}

#[test]
fn failed_migration_rolls_back_version_and_ddl() {
    let dir = tempfile::tempdir().unwrap();
    let path = db_path(&dir);
    // 001_init.sql 最後才建 vocab_flag，先佔用名稱讓遷移在前面的 DDL 都成功之後失敗。
    let conn = Connection::open(&path).unwrap();
    conn.execute_batch("CREATE TABLE vocab_flag(x INTEGER);")
        .unwrap();

    let err = SqliteRepository::open(&path).unwrap_err();

    assert!(
        matches!(
            err,
            StoreError::MigrationFailed {
                from_version: 0,
                ..
            }
        ),
        "{err:?}"
    );
    assert_eq!(user_version(&conn), 0);
    assert!(!table_exists(&conn, "app_setting"));
    assert!(!table_exists(&conn, "srs_card"));
}

#[test]
fn migration_can_succeed_after_earlier_failure_is_cleared() {
    let dir = tempfile::tempdir().unwrap();
    let path = db_path(&dir);
    let conn = Connection::open(&path).unwrap();
    conn.execute_batch("CREATE TABLE vocab_flag(x INTEGER);")
        .unwrap();
    SqliteRepository::open(&path).unwrap_err();
    conn.execute_batch("DROP TABLE vocab_flag;").unwrap();

    SqliteRepository::open(&path).unwrap();

    assert_eq!(user_version(&conn), LATEST_SCHEMA_VERSION);
}

#[test]
fn rejects_database_newer_than_app_without_touching_it() {
    let dir = tempfile::tempdir().unwrap();
    let path = db_path(&dir);
    let newer = LATEST_SCHEMA_VERSION + 98;
    let conn = Connection::open(&path).unwrap();
    conn.pragma_update(None, "user_version", newer).unwrap();

    let err = SqliteRepository::open(&path).unwrap_err();

    match err {
        StoreError::MigrationFailed { from_version, .. } => assert_eq!(from_version, newer),
        other => panic!("預期 MigrationFailed，得到 {other:?}"),
    }
    assert_eq!(user_version(&conn), newer);
    assert!(!table_exists(&conn, "srs_card"));
}

#[test]
fn rejects_negative_user_version() {
    let dir = tempfile::tempdir().unwrap();
    let path = db_path(&dir);
    let conn = Connection::open(&path).unwrap();
    conn.pragma_update(None, "user_version", -1).unwrap();

    let err = SqliteRepository::open(&path).unwrap_err();

    assert!(
        matches!(
            err,
            StoreError::MigrationFailed {
                from_version: -1,
                ..
            }
        ),
        "{err:?}"
    );
}

#[test]
fn opening_file_database_enables_wal() {
    let db = temp_db();

    let mode: String = raw(&db.path)
        .query_row("PRAGMA journal_mode", [], |row| row.get(0))
        .unwrap();

    assert_eq!(mode, "wal");
}

#[test]
fn opening_non_database_file_is_a_storage_error() {
    let dir = tempfile::tempdir().unwrap();
    let path = db_path(&dir);
    std::fs::write(&path, b"this is definitely not a sqlite database file!").unwrap();

    let err = SqliteRepository::open(&path).unwrap_err();

    assert!(matches!(err, StoreError::Storage { .. }), "{err:?}");
}

#[test]
fn opening_inside_missing_directory_is_a_storage_error() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("missing").join("jp_core.db");

    let err = SqliteRepository::open(&path).unwrap_err();

    assert!(matches!(err, StoreError::Storage { .. }), "{err:?}");
}

#[test]
fn in_memory_repository_is_migrated() {
    let repo = SqliteRepository::open_in_memory().unwrap();

    assert_eq!(repo.get_settings().unwrap(), SettingsRow::default());
}

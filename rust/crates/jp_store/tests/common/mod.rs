//! 整合測試共用的夾具。每個測試執行檔只用到其中一部分。
#![allow(dead_code)]

use std::path::{Path, PathBuf};

use chrono::{DateTime, Duration, NaiveDate, Utc};
use jp_lang::clock::DayContext;
use jp_store::{
    ActivityDelta, CardReviewUpdate, NewCard, ReviewLogEntry, ReviewWrite, SqliteRepository,
};
use rusqlite::{params, Connection};
use tempfile::TempDir;

pub struct TestDb {
    pub dir: TempDir,
    pub path: PathBuf,
    pub repo: SqliteRepository,
}

pub fn db_path(dir: &TempDir) -> PathBuf {
    dir.path().join("jp_core.db")
}

pub fn temp_db() -> TestDb {
    let dir = tempfile::tempdir().unwrap();
    let path = db_path(&dir);
    let repo = SqliteRepository::open(&path).unwrap();
    TestDb { dir, path, repo }
}

/// 第二條連線，用來檢查 Repository 沒有暴露的狀態，或直接擺放卡片狀態。
pub fn raw(path: &Path) -> Connection {
    let conn = Connection::open(path).unwrap();
    conn.execute_batch("PRAGMA foreign_keys = ON;").unwrap();
    conn
}

pub fn ts(text: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(text).unwrap().to_utc()
}

pub fn d(text: &str) -> NaiveDate {
    text.parse().unwrap()
}

pub const NOW: &str = "2026-03-04T12:00:00Z";
pub const END_OF_TODAY: &str = "2026-03-04T20:00:00Z";
pub const START_OF_TODAY: &str = "2026-03-03T20:00:00Z";
pub const TODAY: &str = "2026-03-04";
pub const LONG_AGO: &str = "2026-03-01T00:00:00Z";

/// 台北時區、換日 4 點：邏輯日 2026-03-04 的範圍是 03-03T20:00Z 到 03-04T20:00Z。
pub fn ctx() -> DayContext {
    DayContext {
        now: ts(NOW),
        utc_offset_minutes: 480,
        rollover_hour: 4,
    }
}

pub fn new_card(card_id: &str, priority: u8, created_at: DateTime<Utc>) -> NewCard {
    let (content_id, facet) = card_id.split_once(':').unwrap();
    NewCard {
        card_id: card_id.to_string(),
        content_id: content_id.to_string(),
        facet: facet.to_string(),
        priority,
        created_at,
    }
}

pub fn old_card(card_id: &str, priority: u8) -> NewCard {
    new_card(card_id, priority, ts(LONG_AGO))
}

pub fn place_card(conn: &Connection, card_id: &str, state: u8, due_at: DateTime<Utc>) {
    let changed = conn
        .execute(
            "UPDATE srs_card SET state = ?1, due_at = ?2 WHERE card_id = ?3",
            params![state, due_at.timestamp_millis(), card_id],
        )
        .unwrap();
    assert_eq!(changed, 1, "{card_id} 不存在");
}

pub fn mark_reviewed_on(conn: &Connection, card_id: &str, date: &str) {
    conn.execute(
        "UPDATE srs_card SET last_logical_date = ?1 WHERE card_id = ?2",
        params![date, card_id],
    )
    .unwrap();
}

pub fn review_write(
    card_id: &str,
    expected_reps: i32,
    state_before: u8,
    state_after: u8,
    at: DateTime<Utc>,
    logical_date: NaiveDate,
) -> ReviewWrite {
    ReviewWrite {
        card_id: card_id.to_string(),
        expected_reps,
        card: CardReviewUpdate {
            state: state_after,
            due_at: at + Duration::days(4),
            last_review_at: at,
            stability: 4.351,
            difficulty: 5.267,
            elapsed_days: 0,
            scheduled_days: 4,
            reps: expected_reps + 1,
            lapses: 0,
        },
        log: ReviewLogEntry {
            rating: 3,
            state_before,
            state_after,
            elapsed_days: 0,
            scheduled_days: 0,
            stability_after: 4.351,
            difficulty_after: 5.267,
            reviewed_at: at,
            logical_date,
            utc_offset_minutes: 480,
            duration_ms: 1500,
            question_type: "recog".to_string(),
            clock_skewed: false,
        },
        activity: ActivityDelta {
            reviews_done: 1,
            study_ms: 1500,
            ..ActivityDelta::default()
        },
    }
}

pub fn table_exists(conn: &Connection, name: &str) -> bool {
    conn.query_row(
        "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?1",
        [name],
        |row| row.get::<_, i64>(0),
    )
    .unwrap()
        == 1
}

pub fn user_version(conn: &Connection) -> i32 {
    conn.query_row("PRAGMA user_version", [], |row| row.get(0))
        .unwrap()
}

pub fn count_rows(conn: &Connection, table: &str) -> i64 {
    conn.query_row(&format!("SELECT COUNT(*) FROM {table}"), [], |row| {
        row.get(0)
    })
    .unwrap()
}

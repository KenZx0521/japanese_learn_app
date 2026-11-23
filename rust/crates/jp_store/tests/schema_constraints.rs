//! §5.3：append-only 觸發器、STRICT、CHECK、外鍵。

mod common;

use common::*;
use rusqlite::Connection;

type Column = (&'static str, &'static str);

fn insert_sql(table: &str, row: &[Column], changed: Column) -> String {
    let columns: Vec<&str> = row.iter().map(|(name, _)| *name).collect();
    let values: Vec<&str> = row
        .iter()
        .map(|(name, value)| {
            if *name == changed.0 {
                changed.1
            } else {
                *value
            }
        })
        .collect();
    format!(
        "INSERT INTO {table}({}) VALUES ({});",
        columns.join(", "),
        values.join(", ")
    )
}

/// 在交易內執行後一律回滾，讓同一張表的案例彼此獨立。
fn try_sql(conn: &Connection, sql: &str) -> Result<(), String> {
    let tx = conn.unchecked_transaction().unwrap();
    let result = tx.execute_batch(sql).map_err(|err| err.to_string());
    tx.rollback().unwrap();
    result
}

const SRS_CARD: &[Column] = &[
    ("card_id", "'vo.a:recog'"),
    ("content_id", "'vo.a'"),
    ("facet", "'recog'"),
    ("priority", "0"),
    ("state", "0"),
    ("due_at", "1"),
    ("last_review_at", "1"),
    ("stability", "0.0"),
    ("difficulty", "0.0"),
    ("elapsed_days", "0"),
    ("scheduled_days", "0"),
    ("reps", "0"),
    ("lapses", "0"),
    ("suspended", "0"),
    ("introduced_seq", "1"),
    ("created_at", "1"),
];
const REVIEW_LOG: &[Column] = &[
    ("card_id", "'vo.a:recog'"),
    ("rating", "3"),
    ("state_before", "0"),
    ("state_after", "1"),
    ("elapsed_days", "0"),
    ("scheduled_days", "0"),
    ("stability_after", "1.0"),
    ("difficulty_after", "5.0"),
    ("reviewed_at", "1"),
    ("logical_date", "'2026-03-04'"),
    ("utc_offset_minutes", "480"),
    ("duration_ms", "10"),
    ("question_type", "'recog'"),
    ("clock_skewed", "0"),
];
const PLAN_VERSION: &[Column] = &[
    ("effective_from", "'2026-03-04'"),
    ("daily_minutes", "20"),
    ("weekday_mask", "127"),
    ("start_level", "'zero'"),
    ("created_at", "1"),
];
const MILESTONE_RESULT: &[Column] = &[
    ("milestone_id", "'ms.hira'"),
    ("correct", "1"),
    ("total", "2"),
    ("passed", "0"),
    ("logical_date", "'2026-03-04'"),
    ("taken_at", "1"),
];
const LESSON_PROGRESS: &[Column] = &[("lesson_id", "'le.k01'"), ("skipped", "0")];
const VOCAB_FLAG: &[Column] = &[
    ("vocab_id", "'vo.a'"),
    ("known", "0"),
    ("starred", "0"),
    ("updated_at", "1"),
];

const CHECK_CASES: &[(&str, &[Column], &[Column])] = &[
    (
        "srs_card",
        SRS_CARD,
        &[
            ("facet", "'write'"),
            ("priority", "2"),
            ("state", "4"),
            ("state", "-1"),
            ("stability", "-0.1"),
            ("difficulty", "10.5"),
            ("suspended", "2"),
        ],
    ),
    (
        "review_log",
        REVIEW_LOG,
        &[
            ("rating", "0"),
            ("rating", "5"),
            ("state_before", "4"),
            ("state_after", "4"),
            ("stability_after", "0.0"),
            ("difficulty_after", "0.5"),
            ("difficulty_after", "10.5"),
            ("duration_ms", "-1"),
            ("clock_skewed", "2"),
        ],
    ),
    (
        "plan_version",
        PLAN_VERSION,
        &[
            ("daily_minutes", "15"),
            ("weekday_mask", "0"),
            ("weekday_mask", "128"),
            ("start_level", "'expert'"),
        ],
    ),
    (
        "milestone_result",
        MILESTONE_RESULT,
        &[("correct", "-1"), ("total", "0"), ("passed", "2")],
    ),
    ("lesson_progress", LESSON_PROGRESS, &[("skipped", "2")]),
    (
        "vocab_flag",
        VOCAB_FLAG,
        &[("known", "2"), ("starred", "2")],
    ),
];

#[test]
fn check_constraints_reject_out_of_range_values() {
    let db = temp_db();
    let conn = raw(&db.path);

    for (table, row, bad_values) in CHECK_CASES {
        let (first_column, first_value) = row[0];
        try_sql(&conn, &insert_sql(table, row, (first_column, first_value)))
            .unwrap_or_else(|err| panic!("{table} 的合法列被拒絕：{err}"));
        for bad in *bad_values {
            let err = try_sql(&conn, &insert_sql(table, row, *bad))
                .expect_err(&format!("{table} 應拒絕 {bad:?}"));
            assert!(
                err.contains("CHECK constraint failed"),
                "{table} {bad:?}: {err}"
            );
        }
    }
}

#[test]
fn strict_tables_reject_wrong_types() {
    let db = temp_db();
    let conn = raw(&db.path);

    let cases = [
        insert_sql("srs_card", SRS_CARD, ("reps", "'many'")),
        insert_sql("srs_card", SRS_CARD, ("stability", "'stable'")),
        insert_sql("review_log", REVIEW_LOG, ("reviewed_at", "'yesterday'")),
        "INSERT INTO daily_activity(logical_date, reviews_done) VALUES ('2026-03-04', 'x');"
            .to_string(),
    ];

    for sql in cases {
        let err = try_sql(&conn, &sql).expect_err(&sql);
        assert!(err.contains("cannot store"), "{sql}: {err}");
    }
}

#[test]
fn every_table_is_strict() {
    let db = temp_db();
    let conn = raw(&db.path);

    let mut stmt = conn
        .prepare(
            "SELECT name, strict FROM pragma_table_list
             WHERE schema = 'main' AND type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .unwrap();
    let tables: Vec<(String, i64)> = stmt
        .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
        .unwrap()
        .map(Result::unwrap)
        .collect();

    assert_eq!(tables.len(), 14, "{tables:?}");
    for (name, strict) in tables {
        assert_eq!(strict, 1, "{name} 不是 STRICT");
    }
}

#[test]
fn append_only_tables_reject_update_and_delete() {
    let db = temp_db();
    let conn = raw(&db.path);
    let tables: [(&str, &[Column], &str); 3] = [
        ("review_log", REVIEW_LOG, "rating = 4"),
        ("plan_version", PLAN_VERSION, "daily_minutes = 30"),
        ("milestone_result", MILESTONE_RESULT, "passed = 1"),
    ];

    for (table, row, assignment) in tables {
        let (first_column, first_value) = row[0];
        conn.execute_batch(&insert_sql(table, row, (first_column, first_value)))
            .unwrap();

        let update_err = try_sql(&conn, &format!("UPDATE {table} SET {assignment};")).unwrap_err();
        let delete_err = try_sql(&conn, &format!("DELETE FROM {table};")).unwrap_err();

        let expected = format!("{table} is append-only");
        assert!(update_err.contains(&expected), "{update_err}");
        assert!(delete_err.contains(&expected), "{delete_err}");
        assert_eq!(count_rows(&conn, table), 1);
    }
}

#[test]
fn review_log_keeps_rows_for_cards_that_no_longer_exist() {
    let db = temp_db();
    let conn = raw(&db.path);

    let sql = insert_sql("review_log", REVIEW_LOG, ("card_id", "'vo.gone:recog'"));

    assert_eq!(try_sql(&conn, &sql), Ok(()));
}

#[test]
fn foreign_keys_reject_rows_for_unknown_plans() {
    let db = temp_db();
    let conn = raw(&db.path);
    let cases = [
        "INSERT INTO plan_baseline VALUES (99, 'ms.hira', '2026-03-04');",
        "INSERT INTO daily_plan_snapshot VALUES ('2026-03-04', 99, '{}', 1);",
    ];

    for sql in cases {
        let err = try_sql(&conn, sql).expect_err(sql);
        assert!(
            err.contains("FOREIGN KEY constraint failed"),
            "{sql}: {err}"
        );
    }
}

#[test]
fn schema_defines_every_documented_index() {
    let db = temp_db();
    let conn = raw(&db.path);

    let expected = [
        "idx_card_sched",
        "idx_card_new",
        "idx_card_content",
        "idx_log_card",
        "idx_log_date",
        "idx_plan_effective",
        "idx_intro_lesson",
        "idx_milestone",
    ];

    for name in expected {
        let found: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'index' AND name = ?1",
                [name],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(found, 1, "缺少索引 {name}");
    }
}

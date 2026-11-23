//! `item_intro`、`lesson_progress`、`daily_task_done`、假名熟練、里程碑與單字旗標的 SQL。

use std::collections::{HashMap, HashSet};

use chrono::{DateTime, NaiveDate, Utc};
use rusqlite::{named_params, params, Connection, OptionalExtension, Params, Row, Transaction};

use crate::convert::{date_at, date_text, millis, opt_date_at, opt_millis, opt_time_at, time_at};
use crate::error::StoreError;
use crate::records::*;
use crate::sqlite_activity::upsert_activity;
use crate::srs_write::{insert_new_cards, update_content_suspended};

const KANA_COLUMNS: &str = "kana_id, correct_run, fast_run, attempts, mastered_at, fast_badge_at";

fn lesson_from_row(row: &Row<'_>) -> rusqlite::Result<LessonProgressRow> {
    Ok(LessonProgressRow {
        lesson_id: row.get(0)?,
        integration_days_done: row.get(1)?,
        integration_dialogue: row.get(2)?,
        skipped: row.get(3)?,
        completed_date: opt_date_at(row, 4)?,
        completed_at: opt_time_at(row, 5)?,
    })
}

fn kana_from_row(row: &Row<'_>) -> rusqlite::Result<KanaMasteryRow> {
    Ok(KanaMasteryRow {
        kana_id: row.get(0)?,
        correct_run: row.get(1)?,
        fast_run: row.get(2)?,
        attempts: row.get(3)?,
        mastered_at: opt_time_at(row, 4)?,
        fast_badge_at: opt_time_at(row, 5)?,
    })
}

fn milestone_from_row(row: &Row<'_>) -> rusqlite::Result<MilestoneResultRow> {
    Ok(MilestoneResultRow {
        milestone_id: row.get(0)?,
        correct: row.get(1)?,
        total: row.get(2)?,
        passed: row.get(3)?,
        logical_date: date_at(row, 4)?,
        taken_at: time_at(row, 5)?,
    })
}

fn vocab_flag_from_row(row: &Row<'_>) -> rusqlite::Result<VocabFlagRow> {
    Ok(VocabFlagRow {
        vocab_id: row.get(0)?,
        known: row.get(1)?,
        starred: row.get(2)?,
        updated_at: time_at(row, 3)?,
    })
}

fn string_set(
    conn: &Connection,
    sql: &str,
    args: impl Params,
) -> Result<HashSet<String>, StoreError> {
    let mut stmt = conn.prepare_cached(sql)?;
    let rows = stmt.query_map(args, |row| row.get(0))?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

pub(crate) fn introduced_items(conn: &Connection) -> Result<HashSet<String>, StoreError> {
    string_set(conn, "SELECT item_id FROM item_intro", [])
}

/// 已介紹過的項目保留第一筆紀錄。
pub(crate) fn insert_intros(
    tx: &Transaction<'_>,
    rows: &[ItemIntroRow],
) -> Result<u32, StoreError> {
    let mut stmt = tx.prepare_cached(
        "INSERT INTO item_intro(item_id, lesson_id, logical_date, introduced_at) \
         VALUES (?1, ?2, ?3, ?4) ON CONFLICT(item_id) DO NOTHING",
    )?;
    let mut inserted = 0;
    for row in rows {
        let changed = stmt.execute(params![
            row.item_id,
            row.lesson_id,
            date_text(row.logical_date),
            millis(row.introduced_at),
        ])?;
        if changed > 0 {
            inserted += 1;
        }
    }
    Ok(inserted)
}

pub(crate) fn lesson_progress(
    conn: &Connection,
) -> Result<HashMap<String, LessonProgressRow>, StoreError> {
    let mut stmt = conn.prepare_cached(
        "SELECT lesson_id, integration_days_done, integration_dialogue, skipped, completed_date, \
         completed_at FROM lesson_progress",
    )?;
    let rows = stmt.query_map([], |row| {
        let lesson = lesson_from_row(row)?;
        Ok((lesson.lesson_id.clone(), lesson))
    })?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

pub(crate) fn task_done(conn: &Connection, on: NaiveDate) -> Result<HashSet<String>, StoreError> {
    string_set(
        conn,
        "SELECT task_key FROM daily_task_done WHERE logical_date = ?1",
        [date_text(on)],
    )
}

/// 完成日只寫一次，課完成後再有更新也不會改寫。
fn apply_lesson_update(
    tx: &Transaction<'_>,
    update: &LessonProgressUpdate,
    write: &CompleteTaskWrite,
) -> Result<(), StoreError> {
    let (completed_date, completed_at) = if update.completed {
        (
            Some(date_text(write.logical_date)),
            Some(millis(write.done_at)),
        )
    } else {
        (None, None)
    };
    tx.prepare_cached(
        "INSERT INTO lesson_progress(lesson_id, integration_days_done, integration_dialogue, \
         completed_date, completed_at) VALUES (:lesson_id, :days, :dialogue, :date, :at) \
         ON CONFLICT(lesson_id) DO UPDATE SET \
         integration_days_done = integration_days_done + excluded.integration_days_done, \
         integration_dialogue = COALESCE(excluded.integration_dialogue, integration_dialogue), \
         completed_date = COALESCE(completed_date, excluded.completed_date), \
         completed_at = COALESCE(completed_at, excluded.completed_at)",
    )?
    .execute(named_params! {
        ":lesson_id": update.lesson_id,
        ":days": update.integration_days_added,
        ":dialogue": update.integration_dialogue,
        ":date": completed_date,
        ":at": completed_at,
    })?;
    Ok(())
}

pub(crate) fn complete_task(
    tx: &Transaction<'_>,
    write: &CompleteTaskWrite,
) -> Result<(), StoreError> {
    let first_time =
        tx.prepare_cached(
            "INSERT INTO daily_task_done(logical_date, task_key, done_at) \
             VALUES (?1, ?2, ?3) ON CONFLICT(logical_date, task_key) DO NOTHING",
        )?
        .execute(params![
            date_text(write.logical_date),
            write.task_key,
            millis(write.done_at),
        ])? > 0;
    if !first_time {
        return Ok(());
    }
    insert_intros(tx, &write.item_intros)?;
    insert_new_cards(tx, &write.new_cards)?;
    for update in &write.lesson_updates {
        apply_lesson_update(tx, update, write)?;
    }
    upsert_activity(tx, write.logical_date, write.activity)
}

pub(crate) fn kana_mastery(
    conn: &Connection,
    id: &str,
) -> Result<Option<KanaMasteryRow>, StoreError> {
    let sql = format!("SELECT {KANA_COLUMNS} FROM kana_mastery WHERE kana_id = ?1");
    Ok(conn
        .prepare_cached(&sql)?
        .query_row([id], kana_from_row)
        .optional()?)
}

pub(crate) fn all_kana_mastery(conn: &Connection) -> Result<Vec<KanaMasteryRow>, StoreError> {
    let sql = format!("SELECT {KANA_COLUMNS} FROM kana_mastery ORDER BY kana_id");
    let mut stmt = conn.prepare_cached(&sql)?;
    let rows = stmt.query_map([], kana_from_row)?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

pub(crate) fn put_kana_mastery(
    tx: &Transaction<'_>,
    row: &KanaMasteryRow,
) -> Result<(), StoreError> {
    tx.prepare_cached(
        "INSERT OR REPLACE INTO kana_mastery(kana_id, correct_run, fast_run, attempts, \
         mastered_at, fast_badge_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    )?
    .execute(params![
        row.kana_id,
        row.correct_run,
        row.fast_run,
        row.attempts,
        opt_millis(row.mastered_at),
        opt_millis(row.fast_badge_at),
    ])?;
    Ok(())
}

/// 檢定的作答同一個 transaction 計入當天的 `drills_done`：只考檢定的日子也是活躍日（RULINGS O12）。
pub(crate) fn insert_milestone_result(
    tx: &Transaction<'_>,
    row: &MilestoneResultRow,
) -> Result<(), StoreError> {
    let answered = ActivityDelta {
        drills_done: row.total,
        ..ActivityDelta::default()
    };
    upsert_activity(tx, row.logical_date, answered)?;
    tx.prepare_cached(
        "INSERT INTO milestone_result(milestone_id, correct, total, passed, logical_date, \
         taken_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    )?
    .execute(params![
        row.milestone_id,
        row.correct,
        row.total,
        row.passed,
        date_text(row.logical_date),
        millis(row.taken_at),
    ])?;
    Ok(())
}

pub(crate) fn milestone_results(conn: &Connection) -> Result<Vec<MilestoneResultRow>, StoreError> {
    let mut stmt = conn.prepare_cached(
        "SELECT milestone_id, correct, total, passed, logical_date, taken_at \
         FROM milestone_result ORDER BY id",
    )?;
    let rows = stmt.query_map([], milestone_from_row)?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

pub(crate) fn dismiss_milestone(
    tx: &Transaction<'_>,
    id: &str,
    on: NaiveDate,
    at: DateTime<Utc>,
) -> Result<(), StoreError> {
    tx.prepare_cached(
        "INSERT INTO milestone_dismissed(milestone_id, logical_date, dismissed_at) \
         VALUES (?1, ?2, ?3) ON CONFLICT(milestone_id) DO NOTHING",
    )?
    .execute(params![id, date_text(on), millis(at)])?;
    Ok(())
}

pub(crate) fn dismissed_milestones(conn: &Connection) -> Result<HashSet<String>, StoreError> {
    string_set(conn, "SELECT milestone_id FROM milestone_dismissed", [])
}

pub(crate) fn vocab_flags(conn: &Connection) -> Result<HashMap<String, VocabFlagRow>, StoreError> {
    let mut stmt =
        conn.prepare_cached("SELECT vocab_id, known, starred, updated_at FROM vocab_flag")?;
    let rows = stmt.query_map([], |row| {
        let flag = vocab_flag_from_row(row)?;
        Ok((flag.vocab_id.clone(), flag))
    })?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

pub(crate) fn put_vocab_flags(tx: &Transaction<'_>, row: &VocabFlagRow) -> Result<(), StoreError> {
    tx.prepare_cached(
        "INSERT OR REPLACE INTO vocab_flag(vocab_id, known, starred, updated_at) \
         VALUES (?1, ?2, ?3, ?4)",
    )?
    .execute(params![
        row.vocab_id,
        row.known,
        row.starred,
        millis(row.updated_at)
    ])?;
    Ok(())
}

fn remove_intro(tx: &Transaction<'_>, item_id: &str) -> Result<(), StoreError> {
    tx.prepare_cached("DELETE FROM item_intro WHERE item_id = ?1")?
        .execute([item_id])?;
    Ok(())
}

pub(crate) fn apply_vocab_flags(
    tx: &Transaction<'_>,
    write: &VocabFlagsWrite,
) -> Result<(), StoreError> {
    if let Some(suspended) = write.suspended {
        update_content_suspended(tx, &write.flag.vocab_id, suspended)?;
    }
    if let Some(intro) = &write.add_intro {
        insert_intros(tx, std::slice::from_ref(intro))?;
    }
    if write.remove_intro {
        remove_intro(tx, &write.flag.vocab_id)?;
    }
    insert_new_cards(tx, &write.new_cards)?;
    put_vocab_flags(tx, &write.flag)
}

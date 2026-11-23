//! `plan_version`、`plan_baseline`、`daily_plan_snapshot` 的 SQL。

use chrono::NaiveDate;
use rusqlite::{named_params, params, Connection, OptionalExtension, Row, Transaction};

use crate::convert::{date_at, date_text, millis, opt_date_at, opt_date_text, time_at};
use crate::error::StoreError;
use crate::plan_progress::insert_intros;
use crate::records::{NewPlan, PlanVersionRow, SkipWrite, SnapshotRow};

const PLAN_COLUMNS: &str =
    "id, effective_from, daily_minutes, weekday_mask, start_level, target_date, created_at";
const SNAPSHOT_COLUMNS: &str = "logical_date, plan_version_id, payload_json, created_at";

fn plan_from_row(row: &Row<'_>) -> rusqlite::Result<PlanVersionRow> {
    Ok(PlanVersionRow {
        id: row.get(0)?,
        effective_from: date_at(row, 1)?,
        daily_minutes: row.get(2)?,
        weekday_mask: row.get(3)?,
        start_level: row.get(4)?,
        target_date: opt_date_at(row, 5)?,
        created_at: time_at(row, 6)?,
    })
}

fn snapshot_from_row(row: &Row<'_>) -> rusqlite::Result<SnapshotRow> {
    Ok(SnapshotRow {
        logical_date: date_at(row, 0)?,
        plan_version_id: row.get(1)?,
        payload_json: row.get(2)?,
        created_at: time_at(row, 3)?,
    })
}

/// `on` 當天生效的計畫；同一天多筆取 id 最大者。
///
/// 時區往西會讓建立計畫當天的邏輯日早於 `effective_from`，這時還沒有計畫生效，
/// 退回最早生效的計畫，否則使用者會被當成尚未完成引導（`NoActivePlan`）。
pub(crate) fn active_plan(
    conn: &Connection,
    on: NaiveDate,
) -> Result<Option<PlanVersionRow>, StoreError> {
    let effective = format!(
        "SELECT {PLAN_COLUMNS} FROM plan_version WHERE effective_from <= ?1 \
         ORDER BY effective_from DESC, id DESC LIMIT 1"
    );
    let found = conn
        .prepare_cached(&effective)?
        .query_row([date_text(on)], plan_from_row)
        .optional()?;
    if found.is_some() {
        return Ok(found);
    }
    let earliest = format!(
        "SELECT {PLAN_COLUMNS} FROM plan_version ORDER BY effective_from ASC, id DESC LIMIT 1"
    );
    Ok(conn
        .prepare_cached(&earliest)?
        .query_row([], plan_from_row)
        .optional()?)
}

pub(crate) fn plan_versions(conn: &Connection) -> Result<Vec<PlanVersionRow>, StoreError> {
    let sql = format!("SELECT {PLAN_COLUMNS} FROM plan_version ORDER BY effective_from, id");
    let mut stmt = conn.prepare_cached(&sql)?;
    let rows = stmt.query_map([], plan_from_row)?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

fn insert_plan_row(tx: &Transaction<'_>, plan: &NewPlan) -> Result<i64, StoreError> {
    tx.prepare_cached(
        "INSERT INTO plan_version(effective_from, daily_minutes, weekday_mask, start_level, \
         target_date, created_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    )?
    .execute(params![
        date_text(plan.effective_from),
        plan.daily_minutes,
        plan.weekday_mask,
        plan.start_level,
        opt_date_text(plan.target_date),
        millis(plan.created_at),
    ])?;
    Ok(tx.last_insert_rowid())
}

fn insert_baseline(
    tx: &Transaction<'_>,
    plan_id: i64,
    baseline: &[(String, NaiveDate)],
) -> Result<(), StoreError> {
    let mut stmt = tx.prepare_cached(
        "INSERT INTO plan_baseline(plan_version_id, milestone_id, planned_date) VALUES (?1, ?2, ?3)",
    )?;
    for (milestone_id, planned_date) in baseline {
        stmt.execute(params![plan_id, milestone_id, date_text(*planned_date)])?;
    }
    Ok(())
}

/// 已完成的課不覆寫，所以重複略過冪等，也不會把正常學完的課改成略過。回傳實際改變的課數。
fn mark_lessons_skipped(tx: &Transaction<'_>, skips: &SkipWrite) -> Result<usize, StoreError> {
    let mut stmt = tx.prepare_cached(
        "INSERT INTO lesson_progress(lesson_id, skipped, completed_date, completed_at) \
         VALUES (:lesson_id, 1, :completed_date, :completed_at) \
         ON CONFLICT(lesson_id) DO UPDATE SET skipped = 1, \
         completed_date = excluded.completed_date, completed_at = excluded.completed_at \
         WHERE completed_date IS NULL",
    )?;
    let mut changed = 0;
    for lesson_id in &skips.lesson_ids {
        changed += stmt.execute(named_params! {
            ":lesson_id": lesson_id,
            ":completed_date": date_text(skips.completed_date),
            ":completed_at": millis(skips.completed_at),
        })?;
    }
    Ok(changed)
}

/// 分鐘、學習日、起點都沒變時今天的任務也不會變，例如只改目標日。
fn keeps_schedule(previous: Option<&PlanVersionRow>, plan: &NewPlan) -> bool {
    previous.is_some_and(|row| {
        row.daily_minutes == plan.daily_minutes
            && row.weekday_mask == plan.weekday_mask
            && row.start_level == plan.start_level
    })
}

pub(crate) fn insert_plan(
    tx: &Transaction<'_>,
    plan: &NewPlan,
    baseline: &[(String, NaiveDate)],
    skips: &SkipWrite,
) -> Result<i64, StoreError> {
    let previous = active_plan(tx, plan.effective_from)?;
    let plan_id = insert_plan_row(tx, plan)?;
    insert_baseline(tx, plan_id, baseline)?;
    let new_intros = insert_intros(tx, &skips.item_intros)?;
    let new_skips = mark_lessons_skipped(tx, skips)?;
    // 今日任務完成後游標已前進，排程沒變卻重建會多給一個切片（§7.1）
    if new_intros > 0 || new_skips > 0 || !keeps_schedule(previous.as_ref(), plan) {
        delete_snapshot(tx, plan.effective_from)?;
    }
    Ok(plan_id)
}

pub(crate) fn baseline(
    conn: &Connection,
    plan_id: i64,
) -> Result<Vec<(String, NaiveDate)>, StoreError> {
    let mut stmt = conn.prepare_cached(
        "SELECT milestone_id, planned_date FROM plan_baseline \
         WHERE plan_version_id = ?1 ORDER BY milestone_id",
    )?;
    let rows = stmt.query_map([plan_id], |row| Ok((row.get(0)?, date_at(row, 1)?)))?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

pub(crate) fn snapshot(
    conn: &Connection,
    on: NaiveDate,
) -> Result<Option<SnapshotRow>, StoreError> {
    let sql = format!("SELECT {SNAPSHOT_COLUMNS} FROM daily_plan_snapshot WHERE logical_date = ?1");
    Ok(conn
        .prepare_cached(&sql)?
        .query_row([date_text(on)], snapshot_from_row)
        .optional()?)
}

pub(crate) fn latest_snapshot_before(
    conn: &Connection,
    on: NaiveDate,
) -> Result<Option<SnapshotRow>, StoreError> {
    let sql = format!(
        "SELECT {SNAPSHOT_COLUMNS} FROM daily_plan_snapshot WHERE logical_date < ?1 \
         ORDER BY logical_date DESC LIMIT 1"
    );
    Ok(conn
        .prepare_cached(&sql)?
        .query_row([date_text(on)], snapshot_from_row)
        .optional()?)
}

pub(crate) fn put_snapshot(tx: &Transaction<'_>, row: &SnapshotRow) -> Result<(), StoreError> {
    tx.prepare_cached(
        "INSERT INTO daily_plan_snapshot(logical_date, plan_version_id, payload_json, created_at) \
         VALUES (?1, ?2, ?3, ?4) \
         ON CONFLICT(logical_date) DO UPDATE SET plan_version_id = excluded.plan_version_id, \
         payload_json = excluded.payload_json, created_at = excluded.created_at",
    )?
    .execute(params![
        date_text(row.logical_date),
        row.plan_version_id,
        row.payload_json,
        millis(row.created_at),
    ])?;
    Ok(())
}

pub(crate) fn delete_snapshot(tx: &Transaction<'_>, on: NaiveDate) -> Result<(), StoreError> {
    tx.prepare_cached("DELETE FROM daily_plan_snapshot WHERE logical_date = ?1")?
        .execute([date_text(on)])?;
    Ok(())
}

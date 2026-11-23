//! ActivityRepo 的 SQLite 實作。

use std::collections::BTreeSet;

use chrono::NaiveDate;
use rusqlite::{named_params, params, Connection, Row, Transaction};

use crate::convert::{date_at, date_text};
use crate::db::SqliteRepository;
use crate::error::StoreError;
use crate::records::{ActivityDelta, DailyActivityRow};
use crate::repo::ActivityRepo;

/// 共用於 `add_activity`、`apply_review`、`complete_task`。
pub(crate) fn upsert_activity(
    tx: &Transaction<'_>,
    on: NaiveDate,
    delta: ActivityDelta,
) -> Result<(), StoreError> {
    tx.prepare_cached(
        "INSERT INTO daily_activity(logical_date, reviews_done, new_done, relearn_done, \
         lessons_done, drills_done, study_ms, shadow_kept, shadow_almost, shadow_lost) \
         VALUES (:on, :reviews, :new, :relearn, :lessons, :drills, :study, :kept, :almost, :lost) \
         ON CONFLICT(logical_date) DO UPDATE SET \
         reviews_done = reviews_done + excluded.reviews_done, \
         new_done = new_done + excluded.new_done, \
         relearn_done = relearn_done + excluded.relearn_done, \
         lessons_done = lessons_done + excluded.lessons_done, \
         drills_done = drills_done + excluded.drills_done, \
         study_ms = study_ms + excluded.study_ms, \
         shadow_kept = shadow_kept + excluded.shadow_kept, \
         shadow_almost = shadow_almost + excluded.shadow_almost, \
         shadow_lost = shadow_lost + excluded.shadow_lost",
    )?
    .execute(named_params! {
        ":on": date_text(on),
        ":reviews": delta.reviews_done,
        ":new": delta.new_done,
        ":relearn": delta.relearn_done,
        ":lessons": delta.lessons_done,
        ":drills": delta.drills_done,
        ":study": delta.study_ms,
        ":kept": delta.shadow_kept,
        ":almost": delta.shadow_almost,
        ":lost": delta.shadow_lost,
    })?;
    Ok(())
}

fn activity_from_row(row: &Row<'_>) -> rusqlite::Result<DailyActivityRow> {
    Ok(DailyActivityRow {
        logical_date: date_at(row, 0)?,
        reviews_done: row.get(1)?,
        new_done: row.get(2)?,
        relearn_done: row.get(3)?,
        lessons_done: row.get(4)?,
        drills_done: row.get(5)?,
        study_ms: row.get(6)?,
        shadow_kept: row.get(7)?,
        shadow_almost: row.get(8)?,
        shadow_lost: row.get(9)?,
    })
}

fn load_active_dates(conn: &Connection) -> Result<BTreeSet<NaiveDate>, StoreError> {
    // 跟讀的三級自評也是作答；只有 study_ms 的日子不算活躍。
    let mut stmt = conn.prepare_cached(
        "SELECT logical_date FROM daily_activity \
         WHERE reviews_done + new_done + relearn_done + drills_done + lessons_done \
         + shadow_kept + shadow_almost + shadow_lost >= 1",
    )?;
    let rows = stmt.query_map([], |row| date_at(row, 0))?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

/// K1 自由練習與檢定也累加在 `drills_done`，它們只算連續天數，不算回到學習計畫（RULINGS O12）。
/// 所以這裡不看 `drills_done`；計畫內的演練以完成任務（`daily_task_done`）為準。
fn load_plan_active_dates(conn: &Connection) -> Result<BTreeSet<NaiveDate>, StoreError> {
    let mut stmt = conn.prepare_cached(
        "SELECT logical_date FROM daily_activity \
         WHERE reviews_done + new_done + relearn_done + lessons_done \
         + shadow_kept + shadow_almost + shadow_lost >= 1 \
         UNION SELECT logical_date FROM daily_task_done",
    )?;
    let rows = stmt.query_map([], |row| date_at(row, 0))?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

impl ActivityRepo for SqliteRepository {
    fn activity_range(
        &self,
        from: NaiveDate,
        to: NaiveDate,
    ) -> Result<Vec<DailyActivityRow>, StoreError> {
        self.with_conn(|conn| {
            let mut stmt = conn.prepare_cached(
                "SELECT logical_date, reviews_done, new_done, relearn_done, lessons_done, \
                 drills_done, study_ms, shadow_kept, shadow_almost, shadow_lost \
                 FROM daily_activity WHERE logical_date BETWEEN ?1 AND ?2 ORDER BY logical_date",
            )?;
            let rows =
                stmt.query_map(params![date_text(from), date_text(to)], activity_from_row)?;
            Ok(rows.collect::<rusqlite::Result<_>>()?)
        })
    }

    fn active_dates(&self) -> Result<BTreeSet<NaiveDate>, StoreError> {
        self.with_conn(load_active_dates)
    }

    fn plan_active_dates(&self) -> Result<BTreeSet<NaiveDate>, StoreError> {
        self.with_conn(load_plan_active_dates)
    }

    fn add_activity(&self, on: NaiveDate, delta: ActivityDelta) -> Result<(), StoreError> {
        self.with_tx(|tx| upsert_activity(tx, on, delta))
    }
}

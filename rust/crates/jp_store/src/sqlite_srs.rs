//! SrsRepo 的 SQLite 實作。關鍵查詢的條件來自 §5.3，每個條件都有對應的索引。

use std::collections::HashSet;

use chrono::{DateTime, Duration, NaiveDate, Utc};
use jp_lang::clock::DayContext;
use rusqlite::types::ToSql;
use rusqlite::{named_params, params, Connection, OptionalExtension, Row};

use crate::convert::{date_at, date_text, millis, opt_date_at, parse_millis, time_at};
use crate::db::SqliteRepository;
use crate::error::StoreError;
use crate::records::*;
use crate::repo::{QueueFilter, SrsRepo};
use crate::srs_write::{
    apply_review, ensure_review_is_finite, insert_new_cards, update_content_suspended,
};

const CARD_COLUMNS: &str = "c.card_id, c.content_id, c.facet, c.priority, c.state, \
     c.due_at, c.last_review_at, c.stability, c.difficulty, c.elapsed_days, c.scheduled_days, \
     c.reps, c.lapses, c.last_logical_date, c.suspended, c.introduced_seq, c.created_at";

const LEARNING_FILTER: &str = "c.suspended = 0 AND c.state IN (1,3) AND c.due_at <= :limit \
     AND (:audio = 1 OR c.facet <> 'listen')";
const DUE_REVIEW_FILTER: &str = "c.suspended = 0 AND c.state = 2 AND c.due_at < :end_of_today \
     AND (:audio = 1 OR c.facet <> 'listen')";
/// C04：主線字卡要等 `item_intro` 才算教過。`NewContent` 打開就建卡，中途離開時卡仍未教，
/// 留在 state=0 等切片再教一次。假名 `:read` 沒有這個第一次接觸，不受限。
const INTRODUCED: &str = "EXISTS (SELECT 1 FROM item_intro i WHERE i.item_id = c.content_id)";
const SIBLING_DONE_TODAY: &str = "EXISTS (SELECT 1 FROM srs_card s \
     WHERE s.content_id = c.content_id AND s.card_id <> c.card_id \
     AND s.last_logical_date = :today)";
const NEW_FILTER: &str = "c.suspended = 0 AND c.state = 0 AND c.priority = :priority \
     AND c.created_at < :start_of_today AND (:audio = 1 OR c.facet <> 'listen')";
const UNSEEN_NEW_FILTER: &str = "c.suspended = 0 AND c.state = 0 AND c.priority = 0 \
     AND c.created_at < :start_of_today AND c.content_id NOT GLOB 'ka.*' \
     AND c.facet <> 'listen'";

/// 收尾新卡＝今日起點以前建立的卡；今天第一次接觸（`state_before = 0`）的張數。
const TAIL_NEW_DONE_SQL: &str = "SELECT COUNT(*) FROM review_log l \
     JOIN srs_card c ON c.card_id = l.card_id \
     WHERE l.logical_date = :today AND l.state_before = 0 AND c.created_at < :start_of_today";

type SqlParams<'a> = &'a [(&'a str, &'a dyn ToSql)];

fn next_due_review_sql() -> String {
    format!(
        "SELECT {CARD_COLUMNS} FROM srs_card c WHERE {} \
         ORDER BY c.due_at, c.card_id LIMIT 1",
        due_review_filter()
    )
}

/// 與 `next_due_review` 相同的取卡條件，到期數才對得上佇列實際可取的卡。
fn due_review_filter() -> String {
    format!("{DUE_REVIEW_FILTER} AND NOT {SIBLING_DONE_TODAY}")
}

fn new_filter_with_siblings() -> String {
    format!(
        "{NEW_FILTER} AND (c.content_id GLOB 'ka.*' OR {INTRODUCED}) \
         AND (:priority = 0 OR NOT {SIBLING_DONE_TODAY})"
    )
}

fn unseen_new_filter() -> String {
    format!("{UNSEEN_NEW_FILTER} AND {INTRODUCED}")
}

fn next_new_sql() -> String {
    format!(
        "SELECT {CARD_COLUMNS} FROM srs_card c WHERE {} ORDER BY c.introduced_seq LIMIT 1",
        new_filter_with_siblings()
    )
}

fn next_learning_sql() -> String {
    format!(
        "SELECT {CARD_COLUMNS} FROM srs_card c WHERE {LEARNING_FILTER} \
         ORDER BY c.due_at, c.card_id LIMIT 1"
    )
}

fn card_from_row(row: &Row<'_>) -> rusqlite::Result<CardRow> {
    Ok(CardRow {
        card_id: row.get(0)?,
        content_id: row.get(1)?,
        facet: row.get(2)?,
        priority: row.get(3)?,
        state: row.get(4)?,
        due_at: time_at(row, 5)?,
        last_review_at: time_at(row, 6)?,
        stability: row.get(7)?,
        difficulty: row.get(8)?,
        elapsed_days: row.get(9)?,
        scheduled_days: row.get(10)?,
        reps: row.get(11)?,
        lapses: row.get(12)?,
        last_logical_date: opt_date_at(row, 13)?,
        suspended: row.get(14)?,
        introduced_seq: row.get(15)?,
        created_at: time_at(row, 16)?,
    })
}

fn review_log_from_row(row: &Row<'_>) -> rusqlite::Result<ReviewLogRow> {
    Ok(ReviewLogRow {
        id: row.get(0)?,
        card_id: row.get(1)?,
        entry: ReviewLogEntry {
            rating: row.get(2)?,
            state_before: row.get(3)?,
            state_after: row.get(4)?,
            elapsed_days: row.get(5)?,
            scheduled_days: row.get(6)?,
            stability_after: row.get(7)?,
            difficulty_after: row.get(8)?,
            reviewed_at: time_at(row, 9)?,
            logical_date: date_at(row, 10)?,
            utc_offset_minutes: row.get(11)?,
            duration_ms: row.get(12)?,
            question_type: row.get(13)?,
            clock_skewed: row.get(14)?,
        },
    })
}

fn one_card(
    conn: &Connection,
    sql: &str,
    args: SqlParams<'_>,
) -> Result<Option<CardRow>, StoreError> {
    Ok(conn
        .prepare_cached(sql)?
        .query_row(args, card_from_row)
        .optional()?)
}

fn count(conn: &Connection, filter: &str, args: SqlParams<'_>) -> Result<u32, StoreError> {
    let sql = format!("SELECT COUNT(*) FROM srs_card c WHERE {filter}");
    Ok(conn
        .prepare_cached(&sql)?
        .query_row(args, |row| row.get(0))?)
}

fn start_of_today(ctx: &DayContext) -> i64 {
    millis(ctx.end_of_today_utc() - Duration::days(1))
}

impl SrsRepo for SqliteRepository {
    fn card(&self, id: &str) -> Result<Option<CardRow>, StoreError> {
        let sql = format!("SELECT {CARD_COLUMNS} FROM srs_card c WHERE c.card_id = :id");
        self.with_conn(|conn| one_card(conn, &sql, &[(":id", &id)]))
    }

    fn next_learning(
        &self,
        limit_at: DateTime<Utc>,
        queue: QueueFilter,
    ) -> Result<Option<CardRow>, StoreError> {
        let args = named_params! { ":limit": millis(limit_at), ":audio": queue.audio_available };
        self.with_conn(|conn| one_card(conn, &next_learning_sql(), args))
    }

    fn next_due_review(
        &self,
        ctx: &DayContext,
        queue: QueueFilter,
    ) -> Result<Option<CardRow>, StoreError> {
        let today = date_text(ctx.today());
        let args = named_params! {
            ":end_of_today": millis(ctx.end_of_today_utc()),
            ":today": today,
            ":audio": queue.audio_available,
        };
        self.with_conn(|conn| one_card(conn, &next_due_review_sql(), args))
    }

    fn next_new(
        &self,
        priority: u8,
        ctx: &DayContext,
        queue: QueueFilter,
    ) -> Result<Option<CardRow>, StoreError> {
        let today = date_text(ctx.today());
        let args = named_params! {
            ":priority": priority,
            ":start_of_today": start_of_today(ctx),
            ":today": today,
            ":audio": queue.audio_available,
        };
        self.with_conn(|conn| one_card(conn, &next_new_sql(), args))
    }

    fn earliest_learning_due(
        &self,
        queue: QueueFilter,
    ) -> Result<Option<DateTime<Utc>>, StoreError> {
        self.with_conn(|conn| {
            let value: Option<i64> = conn
                .prepare_cached(
                    "SELECT MIN(c.due_at) FROM srs_card c WHERE c.suspended = 0 \
                     AND c.state IN (1,3) AND (:audio = 1 OR c.facet <> 'listen')",
                )?
                .query_row(named_params! { ":audio": queue.audio_available }, |row| {
                    row.get(0)
                })?;
            Ok(value.map(|ms| parse_millis(0, ms)).transpose()?)
        })
    }

    fn due_review_facets(
        &self,
        ctx: &DayContext,
        queue: QueueFilter,
    ) -> Result<Vec<String>, StoreError> {
        let sql = format!(
            "SELECT c.facet FROM srs_card c WHERE {} ORDER BY c.due_at, c.card_id",
            due_review_filter()
        );
        let today = date_text(ctx.today());
        self.with_conn(|conn| {
            let mut stmt = conn.prepare_cached(&sql)?;
            let rows = stmt.query_map(
                named_params! {
                    ":end_of_today": millis(ctx.end_of_today_utc()),
                    ":today": today,
                    ":audio": queue.audio_available,
                },
                |row| row.get(0),
            )?;
            Ok(rows.collect::<rusqlite::Result<_>>()?)
        })
    }

    fn count_due_reviews(&self, ctx: &DayContext, queue: QueueFilter) -> Result<u32, StoreError> {
        let today = date_text(ctx.today());
        let args = named_params! {
            ":end_of_today": millis(ctx.end_of_today_utc()),
            ":today": today,
            ":audio": queue.audio_available,
        };
        self.with_conn(|conn| count(conn, &due_review_filter(), args))
    }

    fn count_learning(
        &self,
        limit_at: DateTime<Utc>,
        created_before: Option<DateTime<Utc>>,
        queue: QueueFilter,
    ) -> Result<u32, StoreError> {
        let filter = format!(
            "{LEARNING_FILTER} AND (:created_before IS NULL OR c.created_at < :created_before)"
        );
        let args = named_params! {
            ":limit": millis(limit_at),
            ":created_before": created_before.map(millis),
            ":audio": queue.audio_available,
        };
        self.with_conn(|conn| count(conn, &filter, args))
    }

    fn count_new(
        &self,
        priority: u8,
        ctx: &DayContext,
        queue: QueueFilter,
    ) -> Result<u32, StoreError> {
        let today = date_text(ctx.today());
        let args = named_params! {
            ":priority": priority,
            ":start_of_today": start_of_today(ctx),
            ":today": today,
            ":audio": queue.audio_available,
        };
        self.with_conn(|conn| count(conn, &new_filter_with_siblings(), args))
    }

    fn count_unseen_new(&self, ctx: &DayContext) -> Result<u32, StoreError> {
        let args = named_params! { ":start_of_today": start_of_today(ctx) };
        self.with_conn(|conn| count(conn, &unseen_new_filter(), args))
    }

    fn count_new_done(&self, priority: u8, on: NaiveDate) -> Result<u32, StoreError> {
        self.with_conn(|conn| {
            Ok(conn
                .prepare_cached(
                    "SELECT COUNT(*) FROM review_log l JOIN srs_card c ON c.card_id = l.card_id \
                     WHERE l.logical_date = ?1 AND l.state_before = 0 AND c.priority = ?2",
                )?
                .query_row(params![date_text(on), priority], |row| row.get(0))?)
        })
    }

    fn count_tail_new_done(&self, ctx: &DayContext) -> Result<u32, StoreError> {
        let args = named_params! {
            ":today": date_text(ctx.today()),
            ":start_of_today": start_of_today(ctx),
        };
        self.with_conn(|conn| {
            Ok(conn
                .prepare_cached(TAIL_NEW_DONE_SQL)?
                .query_row(args, |row| row.get(0))?)
        })
    }

    fn insert_cards(&self, cards: &[NewCard]) -> Result<u32, StoreError> {
        self.with_tx(|tx| insert_new_cards(tx, cards))
    }

    fn apply_review(&self, write: &ReviewWrite) -> Result<(), StoreError> {
        ensure_review_is_finite(write)?;
        self.with_tx(|tx| apply_review(tx, write))
    }

    fn set_content_suspended(&self, content_id: &str, suspended: bool) -> Result<u32, StoreError> {
        self.with_tx(|tx| update_content_suspended(tx, content_id, suspended))
    }

    fn suspend_missing(&self, keep: &HashSet<String>) -> Result<u32, StoreError> {
        self.with_tx(|tx| {
            let active: Vec<String> = tx
                .prepare_cached("SELECT DISTINCT content_id FROM srs_card WHERE suspended = 0")?
                .query_map([], |row| row.get(0))?
                .collect::<rusqlite::Result<_>>()?;
            active
                .iter()
                .filter(|id| !keep.contains(*id))
                .try_fold(0u32, |total, id| {
                    Ok(total + update_content_suspended(tx, id, true)?)
                })
        })
    }

    fn reviews_for_card(&self, id: &str) -> Result<Vec<ReviewLogRow>, StoreError> {
        self.with_conn(|conn| {
            let mut stmt = conn.prepare_cached(
                "SELECT id, card_id, rating, state_before, state_after, elapsed_days, \
                 scheduled_days, stability_after, difficulty_after, reviewed_at, logical_date, \
                 utc_offset_minutes, duration_ms, question_type, clock_skewed \
                 FROM review_log WHERE card_id = ?1 ORDER BY id",
            )?;
            let rows = stmt.query_map([id], review_log_from_row)?;
            Ok(rows.collect::<rusqlite::Result<_>>()?)
        })
    }

    fn card_counts(&self) -> Result<CardCounts, StoreError> {
        self.with_conn(|conn| {
            Ok(conn
                .prepare_cached(
                    "SELECT COALESCE(SUM(state = 0), 0), \
                     COALESCE(SUM(state IN (1,3)), 0), \
                     COALESCE(SUM(state = 2 AND scheduled_days < :mastered), 0), \
                     COALESCE(SUM(state = 2 AND scheduled_days >= :mastered), 0), \
                     (SELECT COUNT(*) FROM review_log) \
                     FROM srs_card WHERE suspended = 0",
                )?
                .query_row(
                    named_params! { ":mastered": MASTERED_MIN_SCHEDULED_DAYS },
                    |row| {
                        Ok(CardCounts {
                            cards_new: row.get(0)?,
                            cards_learning: row.get(1)?,
                            cards_review: row.get(2)?,
                            cards_mastered: row.get(3)?,
                            total_reviews: row.get(4)?,
                        })
                    },
                )?)
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn query_plan(repo: &SqliteRepository, sql: &str) -> Vec<String> {
        repo.with_conn(|conn| {
            let mut stmt = conn.prepare(&format!("EXPLAIN QUERY PLAN {sql}"))?;
            let bound: Vec<_> = named_params! {
                ":limit": 1,
                ":end_of_today": 1,
                ":start_of_today": 1,
                ":today": "2026-03-04",
                ":audio": 1,
                ":priority": 0,
            }
            .iter()
            .filter(|(name, _)| sql.contains(name))
            .copied()
            .collect();
            let details = stmt.query_map(bound.as_slice(), |row| row.get(3))?;
            Ok(details.collect::<rusqlite::Result<_>>()?)
        })
        .unwrap()
    }

    /// §5.3：關鍵查詢全部走索引。
    #[test]
    fn key_queries_never_scan_the_whole_card_table() {
        let repo = SqliteRepository::open_in_memory().unwrap();
        let cases = [
            next_learning_sql(),
            next_due_review_sql(),
            next_new_sql(),
            format!(
                "SELECT COUNT(*) FROM srs_card c WHERE {}",
                new_filter_with_siblings()
            ),
            format!(
                "SELECT COUNT(*) FROM srs_card c WHERE {}",
                unseen_new_filter()
            ),
            format!(
                "SELECT COUNT(*) FROM srs_card c WHERE {}",
                due_review_filter()
            ),
        ];

        for sql in cases {
            let plan = query_plan(&repo, &sql);
            assert!(
                plan.iter().any(|step| step.starts_with("SEARCH c USING")),
                "{sql}\n{plan:?}"
            );
            assert!(
                !plan.iter().any(|step| step.starts_with("SCAN c")),
                "{sql}\n{plan:?}"
            );
        }
    }
}

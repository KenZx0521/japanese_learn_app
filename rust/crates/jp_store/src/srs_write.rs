//! SrsRepo 的寫入：建卡、作答、暫停。在呼叫端開好的 transaction 內執行。

use rusqlite::{named_params, params, Transaction};

use crate::convert::{date_text, millis};
use crate::error::{ensure_finite, StoreError};
use crate::records::{NewCard, ReviewLogEntry, ReviewWrite};
use crate::sqlite_activity::upsert_activity;

/// 共用於 `insert_cards` 與 `complete_task`。`introduced_seq` 在同一 transaction 內遞增，
/// 已存在的卡不占序號。用 `ON CONFLICT DO NOTHING` 而不是 `INSERT OR IGNORE`：
/// 後者連 CHECK 違規都會靜默跳過。
pub(crate) fn insert_new_cards(tx: &Transaction<'_>, cards: &[NewCard]) -> Result<u32, StoreError> {
    let mut seq: i64 = tx.query_row(
        "SELECT COALESCE(MAX(introduced_seq), 0) FROM srs_card",
        [],
        |row| row.get(0),
    )?;
    let mut stmt = tx.prepare_cached(
        "INSERT INTO srs_card(card_id, content_id, facet, priority, state, \
         due_at, last_review_at, stability, difficulty, elapsed_days, scheduled_days, reps, \
         lapses, introduced_seq, created_at) \
         VALUES (?1, ?2, ?3, ?4, 0, ?5, ?5, 0.0, 0.0, 0, 0, 0, 0, ?6, ?5) \
         ON CONFLICT(card_id) DO NOTHING",
    )?;
    let mut inserted = 0;
    for card in cards {
        let changed = stmt.execute(params![
            card.card_id,
            card.content_id,
            card.facet,
            card.priority,
            millis(card.created_at),
            seq + 1,
        ])?;
        if changed > 0 {
            seq += 1;
            inserted += 1;
        }
    }
    Ok(inserted)
}

fn update_reviewed_card(tx: &Transaction<'_>, write: &ReviewWrite) -> Result<usize, StoreError> {
    let card = &write.card;
    Ok(tx
        .prepare_cached(
            "UPDATE srs_card SET state = :state, due_at = :due_at, \
             last_review_at = :last_review_at, stability = :stability, difficulty = :difficulty, \
             elapsed_days = :elapsed_days, scheduled_days = :scheduled_days, reps = :reps, \
             lapses = :lapses, last_logical_date = :logical_date \
             WHERE card_id = :card_id AND reps = :expected_reps",
        )?
        .execute(named_params! {
            ":state": card.state,
            ":due_at": millis(card.due_at),
            ":last_review_at": millis(card.last_review_at),
            ":stability": card.stability,
            ":difficulty": card.difficulty,
            ":elapsed_days": card.elapsed_days,
            ":scheduled_days": card.scheduled_days,
            ":reps": card.reps,
            ":lapses": card.lapses,
            ":logical_date": date_text(write.log.logical_date),
            ":card_id": write.card_id,
            ":expected_reps": write.expected_reps,
        })?)
}

fn insert_review_log(
    tx: &Transaction<'_>,
    card_id: &str,
    log: &ReviewLogEntry,
) -> Result<(), StoreError> {
    tx.prepare_cached(
        "INSERT INTO review_log(card_id, rating, state_before, state_after, elapsed_days, \
         scheduled_days, stability_after, difficulty_after, reviewed_at, logical_date, \
         utc_offset_minutes, duration_ms, question_type, clock_skewed) \
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)",
    )?
    .execute(params![
        card_id,
        log.rating,
        log.state_before,
        log.state_after,
        log.elapsed_days,
        log.scheduled_days,
        log.stability_after,
        log.difficulty_after,
        millis(log.reviewed_at),
        date_text(log.logical_date),
        log.utc_offset_minutes,
        log.duration_ms,
        log.question_type,
        log.clock_skewed,
    ])?;
    Ok(())
}

pub(crate) fn ensure_review_is_finite(write: &ReviewWrite) -> Result<(), StoreError> {
    ensure_finite("stability", write.card.stability)?;
    ensure_finite("difficulty", write.card.difficulty)?;
    ensure_finite("stability_after", write.log.stability_after)?;
    ensure_finite("difficulty_after", write.log.difficulty_after)
}

pub(crate) fn update_content_suspended(
    tx: &Transaction<'_>,
    content_id: &str,
    suspended: bool,
) -> Result<u32, StoreError> {
    let changed = tx
        .prepare_cached(
            "UPDATE srs_card SET suspended = ?1 WHERE content_id = ?2 AND suspended <> ?1",
        )?
        .execute(params![suspended, content_id])?;
    Ok(u32::try_from(changed).unwrap_or(u32::MAX))
}

/// 以 `reps` 做樂觀檢查，0 列代表連點或卡片不存在；任一步失敗整筆回滾。
pub(crate) fn apply_review(tx: &Transaction<'_>, write: &ReviewWrite) -> Result<(), StoreError> {
    if update_reviewed_card(tx, write)? == 0 {
        return Err(StoreError::StaleCard {
            card_id: write.card_id.clone(),
        });
    }
    insert_review_log(tx, &write.card_id, &write.log)?;
    upsert_activity(tx, write.log.logical_date, write.activity)
}

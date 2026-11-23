//! 假名熟練（§6.5）。不寫 `review_log`，只用 `kana_mastery` 表。

use chrono::{DateTime, Utc};
use jp_content::ContentStore;
use jp_store::{KanaMasteryRow, PlanRepo, SettingsRepo, SrsRepo};

use crate::error::SrsError;
use crate::facets::cards_for_content;

pub const MASTERY_RUN_REQUIRED: u32 = 2;
pub const FAST_RUN_REQUIRED: u32 = 2;
pub const FAST_ANSWER_MS: u32 = 3000;

const COUNTED_QUESTION_TYPES: [&str; 3] = ["kana_read", "kana_listen", "kana_confuse"];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct KanaAnswer<'a> {
    pub kana_id: &'a str,
    /// §8.6 的 snake_case 名稱。
    pub question_type: &'a str,
    pub is_correct: bool,
    pub duration_ms: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KanaMasteryStatus {
    pub kana_id: String,
    pub run: u32,
    pub required: u32,
    pub mastered: bool,
    pub fast_badge: bool,
}

/// `kana_match`、`minimal_pair`、`kana_word` 不計入熟練。
pub fn counts_toward_mastery(question_type: &str) -> bool {
    COUNTED_QUESTION_TYPES.contains(&question_type)
}

fn empty_row(kana_id: &str) -> KanaMasteryRow {
    KanaMasteryRow {
        kana_id: kana_id.to_string(),
        correct_run: 0,
        fast_run: 0,
        attempts: 0,
        mastered_at: None,
        fast_badge_at: None,
    }
}

/// 答錯時 `correct_run` 歸零，答慢不歸零。`mastered_at`、`fast_badge_at` 一旦設定就保留。
pub fn next_mastery(
    previous: Option<&KanaMasteryRow>,
    answer: &KanaAnswer<'_>,
    time_limit: bool,
    now: DateTime<Utc>,
) -> KanaMasteryRow {
    let before = previous
        .cloned()
        .unwrap_or_else(|| empty_row(answer.kana_id));
    let is_fast = answer.is_correct && answer.duration_ms <= FAST_ANSWER_MS;
    let correct_run = if answer.is_correct {
        before.correct_run + 1
    } else {
        0
    };
    let fast_run = if is_fast { before.fast_run + 1 } else { 0 };
    let mastered_at = before
        .mastered_at
        .or_else(|| (correct_run >= MASTERY_RUN_REQUIRED).then_some(now));
    let earns_badge = if time_limit {
        fast_run >= FAST_RUN_REQUIRED
    } else {
        answer.is_correct && mastered_at.is_some()
    };
    KanaMasteryRow {
        kana_id: before.kana_id,
        correct_run,
        fast_run,
        attempts: before.attempts + 1,
        mastered_at,
        fast_badge_at: before.fast_badge_at.or_else(|| earns_badge.then_some(now)),
    }
}

fn status_of(row: &KanaMasteryRow) -> KanaMasteryStatus {
    KanaMasteryStatus {
        kana_id: row.kana_id.clone(),
        run: row.correct_run.min(MASTERY_RUN_REQUIRED),
        required: MASTERY_RUN_REQUIRED,
        mastered: row.mastered_at.is_some(),
        fast_badge: row.fast_badge_at.is_some(),
    }
}

/// 字已介紹或在今日切片內時，建 state＝0 的 `:read` 卡。K1 自由練習兩者都不是，只更新熟練。
fn create_read_card_if_taught<R>(
    repo: &R,
    content: &ContentStore,
    kana_id: &str,
    in_today_slice: bool,
    now: DateTime<Utc>,
) -> Result<(), SrsError>
where
    R: SrsRepo + PlanRepo + ?Sized,
{
    if in_today_slice || repo.introduced_items()?.contains(kana_id) {
        repo.insert_cards(&cards_for_content(kana_id, content, now))?;
    }
    Ok(())
}

/// 回傳 `None` 代表這個題型不計入熟練（`KanaSubmitResultDto.mastery`）。
/// `in_today_slice` 由呼叫端依今日快照判定，jp_srs 不解析快照。
pub fn record_kana_answer<R>(
    repo: &R,
    content: &ContentStore,
    answer: &KanaAnswer<'_>,
    in_today_slice: bool,
    now: DateTime<Utc>,
) -> Result<Option<KanaMasteryStatus>, SrsError>
where
    R: SrsRepo + PlanRepo + SettingsRepo + ?Sized,
{
    if !counts_toward_mastery(answer.question_type) {
        return Ok(None);
    }
    if content.kana_by_id(answer.kana_id).is_none() {
        return Err(SrsError::NotFound {
            entity: "kana".to_string(),
            id: answer.kana_id.to_string(),
        });
    }
    let previous = repo.kana_mastery(answer.kana_id)?;
    let time_limit = repo.get_settings()?.kana_time_limit;
    let row = next_mastery(previous.as_ref(), answer, time_limit, now);
    repo.put_kana_mastery(&row)?;
    let was_mastered = previous.is_some_and(|p| p.mastered_at.is_some());
    if row.mastered_at.is_some() && !was_mastered {
        create_read_card_if_taught(repo, content, answer.kana_id, in_today_slice, now)?;
    }
    Ok(Some(status_of(&row)))
}

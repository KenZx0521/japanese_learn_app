//! §5.4 的 record 型別，都是不可變值，更新時產生新 record。
//!
//! 卡片的 `facet`、`start_level`、題型等欄位由上層 crate 定義 enum，這裡只存其字串，
//! 內容的合法性由 schema 的 CHECK 把關。

use chrono::{DateTime, NaiveDate, Utc};

pub const STATE_NEW: u8 = 0;
pub const STATE_LEARNING: u8 = 1;
pub const STATE_REVIEW: u8 = 2;
pub const STATE_RELEARNING: u8 = 3;

/// `state = Review` 且 `scheduled_days` 達此值視為精熟（§9.5 `SrsStateLabel`）。
pub const MASTERED_MIN_SCHEDULED_DAYS: i64 = 21;

#[derive(Debug, Clone, PartialEq)]
pub struct CardRow {
    pub card_id: String,
    pub content_id: String,
    pub facet: String,
    pub priority: u8,
    pub state: u8,
    pub due_at: DateTime<Utc>,
    pub last_review_at: DateTime<Utc>,
    pub stability: f64,
    pub difficulty: f64,
    pub elapsed_days: i64,
    pub scheduled_days: i64,
    pub reps: i32,
    pub lapses: i32,
    pub last_logical_date: Option<NaiveDate>,
    pub suspended: bool,
    pub introduced_seq: i64,
    pub created_at: DateTime<Utc>,
}

/// 新卡一律 state＝0，`due_at`、`last_review_at` 取 `created_at`（§6.3）；
/// `introduced_seq` 由 `insert_cards` 依插入順序指派。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewCard {
    pub card_id: String,
    pub content_id: String,
    pub facet: String,
    pub priority: u8,
    pub created_at: DateTime<Utc>,
}

/// 作答後的卡片狀態。`last_logical_date` 取 `ReviewLogEntry.logical_date`。
#[derive(Debug, Clone, PartialEq)]
pub struct CardReviewUpdate {
    pub state: u8,
    pub due_at: DateTime<Utc>,
    pub last_review_at: DateTime<Utc>,
    pub stability: f64,
    pub difficulty: f64,
    pub elapsed_days: i64,
    pub scheduled_days: i64,
    pub reps: i32,
    pub lapses: i32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ReviewLogEntry {
    pub rating: u8,
    pub state_before: u8,
    pub state_after: u8,
    pub elapsed_days: i64,
    pub scheduled_days: i64,
    pub stability_after: f64,
    pub difficulty_after: f64,
    pub reviewed_at: DateTime<Utc>,
    pub logical_date: NaiveDate,
    pub utc_offset_minutes: i32,
    pub duration_ms: u32,
    pub question_type: String,
    pub clock_skewed: bool,
}

/// `activity` 累加到 `log.logical_date` 那一天。
#[derive(Debug, Clone, PartialEq)]
pub struct ReviewWrite {
    pub card_id: String,
    pub expected_reps: i32,
    pub card: CardReviewUpdate,
    pub log: ReviewLogEntry,
    pub activity: ActivityDelta,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ReviewLogRow {
    pub id: i64,
    pub card_id: String,
    pub entry: ReviewLogEntry,
}

/// 四個狀態互斥：`cards_review` 不含已達 `MASTERED_MIN_SCHEDULED_DAYS` 的卡；暫停的卡不計。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct CardCounts {
    pub cards_new: u32,
    pub cards_learning: u32,
    pub cards_review: u32,
    pub cards_mastered: u32,
    pub total_reviews: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanVersionRow {
    pub id: i64,
    pub effective_from: NaiveDate,
    pub daily_minutes: u32,
    pub weekday_mask: u8,
    pub start_level: String,
    pub target_date: Option<NaiveDate>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewPlan {
    pub effective_from: NaiveDate,
    pub daily_minutes: u32,
    pub weekday_mask: u8,
    pub start_level: String,
    pub target_date: Option<NaiveDate>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ItemIntroRow {
    pub item_id: String,
    pub lesson_id: String,
    pub logical_date: NaiveDate,
    pub introduced_at: DateTime<Utc>,
}

/// `insert_plan` 同一 transaction 寫入的略過紀錄（§7.1），可重複寫入。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SkipWrite {
    pub item_intros: Vec<ItemIntroRow>,
    pub lesson_ids: Vec<String>,
    pub completed_date: NaiveDate,
    pub completed_at: DateTime<Utc>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LessonProgressRow {
    pub lesson_id: String,
    pub integration_days_done: u32,
    pub integration_dialogue: Option<String>,
    pub skipped: bool,
    pub completed_date: Option<NaiveDate>,
    pub completed_at: Option<DateTime<Utc>>,
}

/// `completed = true` 時以該次任務的日期寫入完成日，已完成的課不會被改寫。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LessonProgressUpdate {
    pub lesson_id: String,
    pub integration_days_added: u32,
    pub integration_dialogue: Option<String>,
    pub completed: bool,
}

/// §7.4 `complete_task` 的全部副作用，在同一 transaction 內寫入。
/// 相同的 `(logical_date, task_key)` 再次寫入是 no-op。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CompleteTaskWrite {
    pub logical_date: NaiveDate,
    pub task_key: String,
    pub done_at: DateTime<Utc>,
    pub item_intros: Vec<ItemIntroRow>,
    pub new_cards: Vec<NewCard>,
    pub lesson_updates: Vec<LessonProgressUpdate>,
    pub activity: ActivityDelta,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SnapshotRow {
    pub logical_date: NaiveDate,
    pub plan_version_id: i64,
    pub payload_json: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KanaMasteryRow {
    pub kana_id: String,
    pub correct_run: u32,
    pub fast_run: u32,
    pub attempts: u32,
    pub mastered_at: Option<DateTime<Utc>>,
    pub fast_badge_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MilestoneResultRow {
    pub milestone_id: String,
    pub correct: u32,
    pub total: u32,
    pub passed: bool,
    pub logical_date: NaiveDate,
    pub taken_at: DateTime<Utc>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VocabFlagRow {
    pub vocab_id: String,
    pub known: bool,
    pub starred: bool,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DailyActivityRow {
    pub logical_date: NaiveDate,
    pub reviews_done: u32,
    pub new_done: u32,
    pub relearn_done: u32,
    pub lessons_done: u32,
    pub drills_done: u32,
    pub study_ms: i64,
    pub shadow_kept: u32,
    pub shadow_almost: u32,
    pub shadow_lost: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct ActivityDelta {
    pub reviews_done: u32,
    pub new_done: u32,
    pub relearn_done: u32,
    pub lessons_done: u32,
    pub drills_done: u32,
    pub study_ms: i64,
    pub shadow_kept: u32,
    pub shadow_almost: u32,
    pub shadow_lost: u32,
}

/// `set_vocab_flags`（§9.4）的全部寫入。`suspended` 為 `None` 時不動卡片。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VocabFlagsWrite {
    pub flag: VocabFlagRow,
    pub suspended: Option<bool>,
    pub add_intro: Option<ItemIntroRow>,
    pub remove_intro: bool,
    pub new_cards: Vec<NewCard>,
}

/// 列舉值存成字串，由根 crate 的 `app/mapping.rs` 與 DTO 互轉。
#[derive(Debug, Clone, PartialEq)]
pub struct SettingsRow {
    pub day_rollover_hour: u32,
    pub desired_retention: f64,
    pub romaji_override: Option<String>,
    pub furigana_override: Option<String>,
    pub tts_rate: f64,
    pub autoplay: bool,
    pub voice_id: Option<String>,
    pub theme_mode: String,
    pub silent_mode: bool,
    pub kana_time_limit: bool,
    pub show_rating_intervals: bool,
    pub romaji_off_confirmed: bool,
    pub seen_question_hints: Vec<String>,
}

const THEME_MODE_SYSTEM: &str = "system";
const DEFAULT_DESIRED_RETENTION: f64 = 0.9;
const DEFAULT_TTS_RATE: f64 = 1.0;

impl Default for SettingsRow {
    /// §9.5 的預設值。
    fn default() -> Self {
        Self {
            day_rollover_hour: jp_lang::clock::DEFAULT_ROLLOVER_HOUR,
            desired_retention: DEFAULT_DESIRED_RETENTION,
            romaji_override: None,
            furigana_override: None,
            tts_rate: DEFAULT_TTS_RATE,
            autoplay: true,
            voice_id: None,
            theme_mode: THEME_MODE_SYSTEM.to_string(),
            silent_mode: false,
            kana_time_limit: true,
            show_rating_intervals: false,
            romaji_off_confirmed: false,
            seen_question_hints: Vec::new(),
        }
    }
}

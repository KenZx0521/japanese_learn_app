//! §5.4 的 Repository traits。方法全部收 `&self`，並發由實作內部的 Mutex 處理。

use std::collections::{BTreeSet, HashMap, HashSet};

use chrono::{DateTime, NaiveDate, Utc};
use jp_lang::clock::DayContext;

use crate::error::StoreError;
use crate::records::*;

type Result<T> = std::result::Result<T, StoreError>;

/// `audio_available = false` 時排除 `facet = 'listen'`（§9.4）。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct QueueFilter {
    pub audio_available: bool,
}

pub trait SrsRepo {
    fn card(&self, id: &str) -> Result<Option<CardRow>>;
    fn next_learning(&self, limit_at: DateTime<Utc>, queue: QueueFilter)
        -> Result<Option<CardRow>>;
    fn next_due_review(&self, ctx: &DayContext, queue: QueueFilter) -> Result<Option<CardRow>>;
    fn next_new(
        &self,
        priority: u8,
        ctx: &DayContext,
        queue: QueueFilter,
    ) -> Result<Option<CardRow>>;
    fn earliest_learning_due(&self, queue: QueueFilter) -> Result<Option<DateTime<Utc>>>;
    /// 依 `due_at`、`card_id` 排序。
    fn due_review_facets(&self, ctx: &DayContext, queue: QueueFilter) -> Result<Vec<String>>;
    fn count_due_reviews(&self, ctx: &DayContext, queue: QueueFilter) -> Result<u32>;
    fn count_learning(
        &self,
        limit_at: DateTime<Utc>,
        created_before: Option<DateTime<Utc>>,
        queue: QueueFilter,
    ) -> Result<u32>;
    fn count_new(&self, priority: u8, ctx: &DayContext, queue: QueueFilter) -> Result<u32>;
    /// §7.2 條件 3，不計 `facet = 'listen'`。
    fn count_unseen_new(&self, ctx: &DayContext) -> Result<u32>;
    /// 該邏輯日第一次接觸（`state_before = 0`）的卡數，供 §6.4 第 4 步的當日上限。
    fn count_new_done(&self, priority: u8, on: NaiveDate) -> Result<u32>;
    /// 今天第一次接觸、而且在今日起點以前建立的卡數（收尾新卡），供 §6.4 第 3、4 步的當日上限。
    fn count_tail_new_done(&self, ctx: &DayContext) -> Result<u32>;
    /// 已存在的卡不動，回傳實際新增的張數。
    fn insert_cards(&self, cards: &[NewCard]) -> Result<u32>;
    fn apply_review(&self, write: &ReviewWrite) -> Result<()>;
    /// 回傳狀態實際改變的張數。
    fn set_content_suspended(&self, content_id: &str, suspended: bool) -> Result<u32>;
    fn suspend_missing(&self, keep: &HashSet<String>) -> Result<u32>;
    fn reviews_for_card(&self, id: &str) -> Result<Vec<ReviewLogRow>>;
    fn card_counts(&self) -> Result<CardCounts>;
}

pub trait PlanRepo {
    fn active_plan(&self, on: NaiveDate) -> Result<Option<PlanVersionRow>>;
    fn plan_versions(&self) -> Result<Vec<PlanVersionRow>>;
    /// 同一 transaction 寫入計畫、基準線、略過紀錄。排程或略過的課有變動時，
    /// 刪除 `effective_from` 當日的快照（§7.1）。
    fn insert_plan(
        &self,
        plan: &NewPlan,
        baseline: &[(String, NaiveDate)],
        skips: &SkipWrite,
    ) -> Result<i64>;
    fn baseline(&self, plan_id: i64) -> Result<Vec<(String, NaiveDate)>>;
    fn introduced_items(&self) -> Result<HashSet<String>>;
    /// 已存在的項目不動，回傳實際新增的筆數。供 `set_vocab_flags`（§9.4）標記尚未介紹的字。
    fn insert_item_intros(&self, rows: &[ItemIntroRow]) -> Result<u32>;
    fn lesson_progress(&self) -> Result<HashMap<String, LessonProgressRow>>;
    fn snapshot(&self, on: NaiveDate) -> Result<Option<SnapshotRow>>;
    fn latest_snapshot_before(&self, on: NaiveDate) -> Result<Option<SnapshotRow>>;
    /// UPSERT；再學一批會改寫當日快照。
    fn put_snapshot(&self, row: &SnapshotRow) -> Result<()>;
    fn delete_snapshot(&self, on: NaiveDate) -> Result<()>;
    fn task_done(&self, on: NaiveDate) -> Result<HashSet<String>>;
    /// §7.4 全部副作用同一 tx；重複的 key 是 no-op。
    fn complete_task(&self, write: &CompleteTaskWrite) -> Result<()>;
    fn kana_mastery(&self, id: &str) -> Result<Option<KanaMasteryRow>>;
    fn all_kana_mastery(&self) -> Result<Vec<KanaMasteryRow>>;
    fn put_kana_mastery(&self, row: &KanaMasteryRow) -> Result<()>;
    fn insert_milestone_result(&self, row: &MilestoneResultRow) -> Result<()>;
    fn milestone_results(&self) -> Result<Vec<MilestoneResultRow>>;
    fn dismiss_milestone(&self, id: &str, on: NaiveDate, at: DateTime<Utc>) -> Result<()>;
    fn dismissed_milestones(&self) -> Result<HashSet<String>>;
    fn vocab_flags(&self) -> Result<HashMap<String, VocabFlagRow>>;
    fn put_vocab_flags(&self, row: &VocabFlagRow) -> Result<()>;
    /// `set_vocab_flags`（§9.4）的全部寫入，在同一 transaction 內完成。
    fn apply_vocab_flags(&self, write: &VocabFlagsWrite) -> Result<()>;
}

pub trait ActivityRepo {
    /// 含兩端，依日期排序。
    fn activity_range(&self, from: NaiveDate, to: NaiveDate) -> Result<Vec<DailyActivityRow>>;
    /// §7.6：答題數或完成課數 ≥ 1 的日子。
    fn active_dates(&self) -> Result<BTreeSet<NaiveDate>>;
    /// §7.2 回鍋判定用：有學習計畫活動的日子（不含只有自由練習、檢定的 `drills_done`）。
    fn plan_active_dates(&self) -> Result<BTreeSet<NaiveDate>>;
    fn add_activity(&self, on: NaiveDate, delta: ActivityDelta) -> Result<()>;
}

pub trait SettingsRepo {
    fn get_settings(&self) -> Result<SettingsRow>;
    fn put_settings(&self, row: &SettingsRow) -> Result<()>;
}

pub trait Repository: SrsRepo + PlanRepo + ActivityRepo + SettingsRepo + Send + Sync {}

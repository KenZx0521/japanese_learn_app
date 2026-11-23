//! PlanRepo 的 SQLite 實作：讀取用連線、寫入用 `BEGIN IMMEDIATE`，SQL 在兩個子模組。

use std::collections::{HashMap, HashSet};

use chrono::{DateTime, NaiveDate, Utc};

use crate::db::SqliteRepository;
use crate::error::StoreError;
use crate::records::*;
use crate::repo::PlanRepo;
use crate::{plan_progress as progress, plan_versions as versions};

type Result<T> = std::result::Result<T, StoreError>;

impl PlanRepo for SqliteRepository {
    fn active_plan(&self, on: NaiveDate) -> Result<Option<PlanVersionRow>> {
        self.with_conn(|conn| versions::active_plan(conn, on))
    }

    fn plan_versions(&self) -> Result<Vec<PlanVersionRow>> {
        self.with_conn(versions::plan_versions)
    }

    fn insert_plan(
        &self,
        plan: &NewPlan,
        baseline: &[(String, NaiveDate)],
        skips: &SkipWrite,
    ) -> Result<i64> {
        self.with_tx(|tx| versions::insert_plan(tx, plan, baseline, skips))
    }

    fn baseline(&self, plan_id: i64) -> Result<Vec<(String, NaiveDate)>> {
        self.with_conn(|conn| versions::baseline(conn, plan_id))
    }

    fn introduced_items(&self) -> Result<HashSet<String>> {
        self.with_conn(progress::introduced_items)
    }

    fn insert_item_intros(&self, rows: &[ItemIntroRow]) -> Result<u32> {
        self.with_tx(|tx| progress::insert_intros(tx, rows))
    }

    fn lesson_progress(&self) -> Result<HashMap<String, LessonProgressRow>> {
        self.with_conn(progress::lesson_progress)
    }

    fn snapshot(&self, on: NaiveDate) -> Result<Option<SnapshotRow>> {
        self.with_conn(|conn| versions::snapshot(conn, on))
    }

    fn latest_snapshot_before(&self, on: NaiveDate) -> Result<Option<SnapshotRow>> {
        self.with_conn(|conn| versions::latest_snapshot_before(conn, on))
    }

    fn put_snapshot(&self, row: &SnapshotRow) -> Result<()> {
        self.with_tx(|tx| versions::put_snapshot(tx, row))
    }

    fn delete_snapshot(&self, on: NaiveDate) -> Result<()> {
        self.with_tx(|tx| versions::delete_snapshot(tx, on))
    }

    fn task_done(&self, on: NaiveDate) -> Result<HashSet<String>> {
        self.with_conn(|conn| progress::task_done(conn, on))
    }

    fn complete_task(&self, write: &CompleteTaskWrite) -> Result<()> {
        self.with_tx(|tx| progress::complete_task(tx, write))
    }

    fn kana_mastery(&self, id: &str) -> Result<Option<KanaMasteryRow>> {
        self.with_conn(|conn| progress::kana_mastery(conn, id))
    }

    fn all_kana_mastery(&self) -> Result<Vec<KanaMasteryRow>> {
        self.with_conn(progress::all_kana_mastery)
    }

    fn put_kana_mastery(&self, row: &KanaMasteryRow) -> Result<()> {
        self.with_tx(|tx| progress::put_kana_mastery(tx, row))
    }

    fn insert_milestone_result(&self, row: &MilestoneResultRow) -> Result<()> {
        self.with_tx(|tx| progress::insert_milestone_result(tx, row))
    }

    fn milestone_results(&self) -> Result<Vec<MilestoneResultRow>> {
        self.with_conn(progress::milestone_results)
    }

    fn dismiss_milestone(&self, id: &str, on: NaiveDate, at: DateTime<Utc>) -> Result<()> {
        self.with_tx(|tx| progress::dismiss_milestone(tx, id, on, at))
    }

    fn dismissed_milestones(&self) -> Result<HashSet<String>> {
        self.with_conn(progress::dismissed_milestones)
    }

    fn vocab_flags(&self) -> Result<HashMap<String, VocabFlagRow>> {
        self.with_conn(progress::vocab_flags)
    }

    fn put_vocab_flags(&self, row: &VocabFlagRow) -> Result<()> {
        self.with_tx(|tx| progress::put_vocab_flags(tx, row))
    }

    fn apply_vocab_flags(&self, write: &VocabFlagsWrite) -> Result<()> {
        self.with_tx(|tx| progress::apply_vocab_flags(tx, write))
    }
}

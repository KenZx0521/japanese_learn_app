//! `Deps` 組裝與 `Clock` 注入（rust-core.md §1.3、§2、§10）。

use std::collections::HashSet;
use std::sync::Arc;

use chrono::{DateTime, NaiveDate, Utc};
use jp_content::ContentStore;
use jp_lang::clock::{Clock, ClockError, DayContext, FixedClock, SystemClock};
use jp_plan::input::PlanInput;
use jp_plan::CursorState;
use jp_srs::FsrsScheduler;
use jp_store::{PlanRepo, SettingsRepo, SqliteRepository, SrsRepo};

use crate::api::core::CoreConfig;
use crate::api::error::CoreError;

/// 時差一律由 Dart 更新；`fixed_now_utc` 只換掉時刻來源。
pub(crate) struct AppClock {
    system: SystemClock,
    fixed: Option<FixedClock>,
}

impl AppClock {
    fn new(offset_minutes: i32, fixed_now: Option<DateTime<Utc>>) -> Result<Self, ClockError> {
        Ok(Self {
            system: SystemClock::new(offset_minutes)?,
            fixed: fixed_now.map(|now| FixedClock::new(now, offset_minutes)),
        })
    }

    pub(crate) fn set_utc_offset(&self, minutes: i32) -> Result<(), ClockError> {
        self.system.set_utc_offset(minutes)
    }
}

impl Clock for AppClock {
    fn now_utc(&self) -> DateTime<Utc> {
        match &self.fixed {
            Some(fixed) => fixed.now_utc(),
            None => self.system.now_utc(),
        }
    }

    fn utc_offset_minutes(&self) -> i32 {
        self.system.utc_offset_minutes()
    }
}

pub(crate) struct Deps {
    pub content: Arc<ContentStore>,
    pub repo: SqliteRepository,
    pub clock: AppClock,
    pub scheduler: FsrsScheduler,
}

impl Deps {
    pub(crate) fn open(config: &CoreConfig, content: ContentStore) -> Result<Self, CoreError> {
        if config.db_path.is_empty() {
            return Err(CoreError::invalid("db_path", "資料庫路徑不可為空"));
        }
        let clock = AppClock::new(config.utc_offset_minutes, config.fixed_now_utc)?;
        let repo = SqliteRepository::open(&config.db_path)?;
        let scheduler = FsrsScheduler::new(repo.get_settings()?.desired_retention)?;
        // §5.3：內容淘汰的卡片不刪除，啟動時設 suspended，review_log 永久保留
        repo.suspend_missing(&live_content_ids(&content))?;
        Ok(Self {
            content: Arc::new(content),
            repo,
            clock,
            scheduler,
        })
    }

    /// 換日時間可能被使用者改過，每次都由設定讀取。
    pub(crate) fn day_ctx(&self) -> Result<DayContext, CoreError> {
        let rollover = self.repo.get_settings()?.day_rollover_hour;
        Ok(DayContext::from_clock(&self.clock, rollover))
    }

    /// 資料庫的進度，加上生效計畫在記憶體內跳過的課（`basic` 的 L 課）。
    pub(crate) fn cursor_state(&self, today: NaiveDate) -> Result<CursorState, CoreError> {
        let state = CursorState::load(&self.repo)?;
        let Some(plan) = self.repo.active_plan(today)? else {
            return Ok(state);
        };
        let input = PlanInput::from_row(&plan)?;
        Ok(state.with_plan_skips(&input, plan.effective_from, &self.content))
    }
}

/// 可建卡的未淘汰內容。
fn live_content_ids(content: &ContentStore) -> HashSet<String> {
    let kana = content
        .kana()
        .iter()
        .filter(|e| !e.def.retired)
        .map(|e| &e.def.id);
    let vocab = content
        .vocab()
        .iter()
        .filter(|e| !e.def.retired)
        .map(|e| &e.def.id);
    let grammar = content
        .grammar()
        .iter()
        .filter(|e| !e.retired)
        .map(|e| &e.id);
    kana.chain(vocab).chain(grammar).cloned().collect()
}

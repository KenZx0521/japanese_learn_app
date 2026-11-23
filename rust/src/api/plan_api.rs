//! `impl AppCore`：計畫、月曆、統計（rust-core.md §9.4）。

use super::core::AppCore;
use super::dto_plan::{CalendarDayDto, DayActivityDto, PlanInputDto, PlanViewDto, StatsDto};
use super::error::CoreError;
use crate::app::{plan, stats};

impl AppCore {
    pub fn create_plan(&self, input: PlanInputDto) -> Result<PlanViewDto, CoreError> {
        plan::create_plan(&self.deps, &input)
    }

    pub fn update_plan(&self, input: PlanInputDto) -> Result<PlanViewDto, CoreError> {
        plan::update_plan(&self.deps, &input)
    }

    pub fn plan_view(&self) -> Result<PlanViewDto, CoreError> {
        plan::plan_view(&self.deps)
    }

    /// 只計算，不寫入。
    pub fn plan_preview(&self, input: PlanInputDto) -> Result<PlanViewDto, CoreError> {
        plan::plan_preview(&self.deps, &input)
    }

    pub fn calendar(&self, weeks: u32) -> Result<Vec<CalendarDayDto>, CoreError> {
        stats::calendar(&self.deps, weeks)
    }

    pub fn stats_overview(&self) -> Result<StatsDto, CoreError> {
        stats::stats_overview(&self.deps)
    }

    pub fn activity_range(
        &self,
        from_date: String,
        to_date: String,
    ) -> Result<Vec<DayActivityDto>, CoreError> {
        stats::activity_range(&self.deps, &from_date, &to_date)
    }
}

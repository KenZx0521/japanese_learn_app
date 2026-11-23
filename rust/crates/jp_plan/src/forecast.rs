//! 里程碑預測與自動順延（§7.5）。主線與 `slice.rs` 共用同一份切分邏輯。

use chrono::{Duration, NaiveDate};
use jp_content::schema::PlanPresetDef;
use jp_content::ContentStore;

use crate::budget::NewContentMode;
use crate::calendar::is_study_day;
use crate::completion::{apply_effects, integration_completes, slice_effects};
use crate::error::PlanError;
use crate::input::{preset_for, PlanInput};
use crate::slice::{integration_days_needed, next_slice, Slice, SliceQuota};
use crate::state::{cursor, CursorState};

/// 防止內容或計畫有誤時無窮迴圈（約 20 年）。
const MAX_FORECAST_DAYS: u32 = 7300;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ForecastDay {
    pub date: NaiveDate,
    pub lesson_ids: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Forecast {
    pub milestones: Vec<(String, NaiveDate)>,
    pub main_end: Option<NaiveDate>,
    /// 每個學習日切片涉及的課，供 `calendar`。
    pub schedule: Vec<ForecastDay>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ForecastRequest<'a> {
    pub today: NaiveDate,
    /// 今天的切片已完成時，從下一個學習日起算。
    pub today_slice_done: bool,
    pub plan: &'a PlanInput,
}

fn full_quota(preset: &PlanPresetDef) -> SliceQuota {
    SliceQuota {
        mode: NewContentMode::Full,
        words: preset.new_words_per_day,
        kana: preset.kana_chars_per_day,
        integration_days_needed: integration_days_needed(preset.minutes),
    }
}

/// 模擬用：把一個切片的進度套用到狀態（不寫資料庫）。
fn apply_slice(
    sim: &mut CursorState,
    slice: &Slice,
    days_needed: u32,
    on: NaiveDate,
    content: &ContentStore,
) {
    let Slice::Integration {
        lesson_id,
        dialogue_id,
        ..
    } = slice
    else {
        let effects = slice_effects(slice, sim, content);
        apply_effects(sim, &effects, on);
        return;
    };
    let days_after = sim.integration_days.get(lesson_id).copied().unwrap_or(0) + 1;
    sim.integration_days.insert(lesson_id.clone(), days_after);
    if let Some(dialogue) = dialogue_id {
        sim.integration_dialogues
            .insert(lesson_id.clone(), dialogue.clone());
    }
    if integration_completes(lesson_id, days_after, days_needed, sim, content) {
        sim.completed.entry(lesson_id.clone()).or_insert(on);
    }
}

struct Simulation<'a> {
    content: &'a ContentStore,
    quota: SliceQuota,
}

impl Simulation<'_> {
    fn main_step(&self, sim: &mut CursorState, date: NaiveDate) -> Option<ForecastDay> {
        let slice = next_slice(sim, &self.quota, self.content)?;
        let lesson_ids = slice.lesson_ids();
        apply_slice(
            sim,
            &slice,
            self.quota.integration_days_needed,
            date,
            self.content,
        );
        Some(ForecastDay { date, lesson_ids })
    }

    fn is_done(&self, sim: &CursorState) -> bool {
        cursor(sim, self.content).is_none()
    }
}

/// 逐學習日模擬，直到主線完成。
fn run_simulation(
    sim: &mut CursorState,
    setup: &Simulation<'_>,
    start: NaiveDate,
    mask: u8,
) -> Vec<ForecastDay> {
    let mut schedule = Vec::new();
    let mut date = start;
    for _ in 0..MAX_FORECAST_DAYS {
        if setup.is_done(sim) {
            break;
        }
        if is_study_day(mask, date) {
            schedule.extend(setup.main_step(sim, date));
        }
        date += Duration::days(1);
    }
    schedule
}

fn finish(sim: &CursorState, schedule: Vec<ForecastDay>, content: &ContentStore) -> Forecast {
    let milestones = content
        .milestones()
        .iter()
        .filter_map(|m| sim.completed.get(&m.lesson).map(|on| (m.id.clone(), *on)))
        .collect();
    let main_end = cursor(sim, content)
        .is_none()
        .then(|| sim.completed.values().max().copied())
        .flatten();
    Forecast {
        milestones,
        main_end,
        schedule,
    }
}

pub fn forecast(
    state: &CursorState,
    request: &ForecastRequest<'_>,
    content: &ContentStore,
) -> Result<Forecast, PlanError> {
    let minutes = request.plan.daily_minutes;
    let preset = preset_for(minutes, content)
        .ok_or_else(|| PlanError::invalid("daily_minutes", format!("沒有對應的方案：{minutes}")))?;
    let setup = Simulation {
        content,
        quota: full_quota(preset),
    };
    let start = if request.today_slice_done {
        request.today + Duration::days(1)
    } else {
        request.today
    };
    let mut sim = state.with_plan_skips(request.plan, request.today, content);
    let schedule = run_simulation(&mut sim, &setup, start, request.plan.weekday_mask);
    Ok(finish(&sim, schedule, content))
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlanStatus {
    NoTarget,
    OnTrack,
    Behind,
}

pub fn plan_status(target: Option<NaiveDate>, main_end: Option<NaiveDate>) -> PlanStatus {
    match (target, main_end) {
        (None, _) => PlanStatus::NoTarget,
        (Some(target), Some(end)) if end <= target => PlanStatus::OnTrack,
        _ => PlanStatus::Behind,
    }
}

/// 可達標的最小 preset，都不夠時回 `None`。
pub fn suggested_minutes(
    state: &CursorState,
    request: &ForecastRequest<'_>,
    content: &ContentStore,
) -> Result<Option<u32>, PlanError> {
    let Some(target) = request.plan.target_date else {
        return Ok(None);
    };
    let mut presets: Vec<u32> = content.presets().iter().map(|p| p.minutes).collect();
    presets.sort_unstable();
    for minutes in presets {
        let plan = PlanInput {
            daily_minutes: minutes,
            ..request.plan.clone()
        };
        let trial = ForecastRequest {
            plan: &plan,
            ..*request
        };
        if forecast(state, &trial, content)?
            .main_end
            .is_some_and(|end| end <= target)
        {
            return Ok(Some(minutes));
        }
    }
    Ok(None)
}

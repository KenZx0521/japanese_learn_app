//! 建立、調整、檢視與預覽計畫（§7.1、§7.5、§9.4）。

use chrono::NaiveDate;
use jp_lang::clock::DayContext;
use jp_plan::forecast::{
    forecast, plan_status, suggested_minutes, Forecast, ForecastRequest, PlanStatus,
};
use jp_plan::input::{is_kana_lesson, plan_write, skipped_lessons, validate_plan_input, PlanInput};
use jp_plan::milestone::milestone_outlook;
use jp_plan::state::{cursor, stage_for_cursor};
use jp_plan::today::today_slice_done;
use jp_plan::CursorState;
use jp_store::{MilestoneResultRow, PlanRepo, PlanVersionRow};

use super::deps::Deps;
use super::mapping::enums::plan_status as plan_status_dto;
use super::mapping::plan::{plan_input, plan_input_dto};
use crate::api::dto_plan::{MilestoneDto, PlanInputDto, PlanViewDto};
use crate::api::error::CoreError;

const PERCENT: u32 = 100;

fn date_text(date: Option<NaiveDate>) -> Option<String> {
    date.map(|value| value.to_string())
}

/// 計畫列不存 `known_kana_lessons`：由略過紀錄扣掉 `start_level` 本身跳過的課還原。
fn restored_known_lessons(deps: &Deps, input: &PlanInput) -> Result<Vec<String>, CoreError> {
    let progress = deps.repo.lesson_progress()?;
    let by_level = skipped_lessons(input, &deps.content);
    Ok(deps
        .content
        .course()
        .order
        .iter()
        .filter(|id| is_kana_lesson(id) && !by_level.contains(id))
        .filter(|id| progress.get(*id).is_some_and(|p| p.skipped))
        .cloned()
        .collect())
}

/// `plan_view` 與 `plan_preview` 共用的組裝輸入。
struct ViewInputs<'a> {
    input: &'a PlanInput,
    input_dto: PlanInputDto,
    state: &'a CursorState,
    baseline: &'a [(String, NaiveDate)],
}

fn best_score(results: &[MilestoneResultRow], id: &str) -> Option<u32> {
    results
        .iter()
        .filter(|row| row.milestone_id == id)
        .map(|row| row.correct * PERCENT / row.total)
        .max()
}

fn milestone_dtos(
    deps: &Deps,
    forecast: &Forecast,
    baseline: &[(String, NaiveDate)],
) -> Result<Vec<MilestoneDto>, CoreError> {
    let results = deps.repo.milestone_results()?;
    let dismissed = deps.repo.dismissed_milestones()?;
    let outlooks = milestone_outlook(forecast, baseline, &deps.content);
    Ok(deps
        .content
        .milestones()
        .iter()
        .zip(outlooks)
        .map(|(def, outlook)| MilestoneDto {
            id: def.id.clone(),
            title_zh: def.title_zh.clone(),
            lesson_id: def.lesson.clone(),
            pass_ratio: def.pass_ratio,
            questions: def.questions,
            forecast_date: date_text(outlook.forecast_date),
            planned_date: date_text(outlook.planned_date),
            delay_days: outlook.delay_days,
            best_score_percent: best_score(&results, &def.id),
            passed: results
                .iter()
                .any(|row| row.milestone_id == def.id && row.passed),
            dismissed: dismissed.contains(&def.id),
        })
        .collect())
}

fn build_view(
    deps: &Deps,
    today: NaiveDate,
    view: ViewInputs<'_>,
) -> Result<PlanViewDto, CoreError> {
    let request = ForecastRequest {
        today,
        today_slice_done: today_slice_done(&deps.repo, today)?,
        plan: view.input,
    };
    let predicted = forecast(view.state, &request, &deps.content)?;
    let current = cursor(view.state, &deps.content);
    let status = plan_status(view.input.target_date, predicted.main_end);
    // §7.5：達標時不需要建議，只有落後才回傳可達標的最小方案
    let suggested = match status {
        PlanStatus::Behind => suggested_minutes(view.state, &request, &deps.content)?,
        PlanStatus::NoTarget | PlanStatus::OnTrack => None,
    };
    Ok(PlanViewDto {
        input: view.input_dto,
        current_lesson_id: current.map(str::to_owned),
        stage_id: stage_for_cursor(current, &deps.content).map(str::to_owned),
        milestones: milestone_dtos(deps, &predicted, view.baseline)?,
        main_forecast_end: date_text(predicted.main_end),
        status: plan_status_dto(status),
        suggested_minutes: suggested,
    })
}

fn active_plan(deps: &Deps, today: NaiveDate) -> Result<PlanVersionRow, CoreError> {
    deps.repo.active_plan(today)?.ok_or(CoreError::NoActivePlan)
}

fn view_of_active(deps: &Deps, ctx: &DayContext) -> Result<PlanViewDto, CoreError> {
    let today = ctx.today();
    let row = active_plan(deps, today)?;
    let input = PlanInput::from_row(&row)?;
    let known = restored_known_lessons(deps, &input)?;
    let state = deps.cursor_state(today)?;
    let baseline = deps.repo.baseline(row.id)?;
    build_view(
        deps,
        today,
        ViewInputs {
            input_dto: plan_input_dto(&row, known)?,
            input: &input,
            state: &state,
            baseline: &baseline,
        },
    )
}

fn write_plan(deps: &Deps, ctx: &DayContext, dto: &PlanInputDto) -> Result<PlanViewDto, CoreError> {
    let input = plan_input(dto)?;
    let state = CursorState::load(&deps.repo)?;
    let write = plan_write(&input, &state, &deps.content, ctx)?;
    deps.repo
        .insert_plan(&write.plan, &write.baseline, &write.skips)?;
    view_of_active(deps, ctx)
}

pub(crate) fn create_plan(deps: &Deps, input: &PlanInputDto) -> Result<PlanViewDto, CoreError> {
    write_plan(deps, &deps.day_ctx()?, input)
}

pub(crate) fn update_plan(deps: &Deps, input: &PlanInputDto) -> Result<PlanViewDto, CoreError> {
    let ctx = deps.day_ctx()?;
    active_plan(deps, ctx.today())?;
    write_plan(deps, &ctx, input)
}

pub(crate) fn plan_view(deps: &Deps) -> Result<PlanViewDto, CoreError> {
    view_of_active(deps, &deps.day_ctx()?)
}

/// 只計算，不寫入：略過的課只在記憶體內視為完成（§7.1）。
pub(crate) fn plan_preview(deps: &Deps, dto: &PlanInputDto) -> Result<PlanViewDto, CoreError> {
    let today = deps.day_ctx()?.today();
    let input = plan_input(dto)?;
    validate_plan_input(&input, &deps.content)?;
    let state = CursorState::load(&deps.repo)?.with_plan_skips(&input, today, &deps.content);
    build_view(
        deps,
        today,
        ViewInputs {
            input_dto: dto.clone(),
            input: &input,
            state: &state,
            baseline: &[],
        },
    )
}

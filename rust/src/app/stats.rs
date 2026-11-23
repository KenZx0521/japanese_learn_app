//! 月曆、統計、活動紀錄（§9.4）。

use std::collections::HashMap;

use chrono::{Datelike, Duration, NaiveDate};
use jp_lang::clock::DayContext;
use jp_plan::calendar::PlanHistory;
use jp_plan::forecast::{forecast, Forecast, ForecastRequest};
use jp_plan::input::PlanInput;
use jp_plan::streak::{best_streak, current_streak};
use jp_plan::today::today_slice_done;
use jp_store::{ActivityRepo, DailyActivityRow, PlanRepo, SrsRepo};

use super::deps::Deps;
use super::mapping::plan::parse_date;
use crate::api::dto_plan::{CalendarDayDto, DayActivityDto, StatsDto};
use crate::api::error::CoreError;

const DAYS_PER_WEEK: u32 = 7;
const MAX_CALENDAR_WEEKS: u32 = 53;
const MS_PER_MINUTE: f64 = 60_000.0;
const VOCAB_PREFIX: &str = "vo.";
const GRAMMAR_PREFIX: &str = "gr.";

fn current_forecast(deps: &Deps, ctx: &DayContext) -> Result<Forecast, CoreError> {
    let today = ctx.today();
    let plan = deps
        .repo
        .active_plan(today)?
        .ok_or(CoreError::NoActivePlan)?;
    let input = PlanInput::from_row(&plan)?;
    let request = ForecastRequest {
        today,
        today_slice_done: today_slice_done(&deps.repo, today)?,
        plan: &input,
    };
    Ok(forecast(
        &deps.cursor_state(today)?,
        &request,
        &deps.content,
    )?)
}

/// 從本週一起算 `weeks` 週，T3 的「本週已學 N 天」與 P1 的四週月曆共用。
pub(crate) fn calendar(deps: &Deps, weeks: u32) -> Result<Vec<CalendarDayDto>, CoreError> {
    if !(1..=MAX_CALENDAR_WEEKS).contains(&weeks) {
        let reason = format!("須為 1–{MAX_CALENDAR_WEEKS}：{weeks}");
        return Err(CoreError::invalid("weeks", reason));
    }
    let ctx = deps.day_ctx()?;
    let today = ctx.today();
    let monday = today - Duration::days(i64::from(today.weekday().num_days_from_monday()));
    let predicted = current_forecast(deps, &ctx)?;
    let history = PlanHistory::from_rows(&deps.repo.plan_versions()?);
    let active = deps.repo.active_dates()?;
    let lessons: HashMap<NaiveDate, &Vec<String>> = predicted
        .schedule
        .iter()
        .map(|day| (day.date, &day.lesson_ids))
        .collect();
    // 同一天有多個里程碑時取最前面的，所以反向收集讓前者覆蓋後者
    let milestones: HashMap<NaiveDate, &String> = predicted
        .milestones
        .iter()
        .rev()
        .map(|(id, date)| (*date, id))
        .collect();
    Ok((0..i64::from(weeks * DAYS_PER_WEEK))
        .map(|offset| monday + Duration::days(offset))
        .map(|date| CalendarDayDto {
            date: date.to_string(),
            is_study_day: history.is_study_day(date),
            is_active: active.contains(&date),
            lesson_ids: lessons
                .get(&date)
                .map_or_else(Vec::new, |ids| (*ids).clone()),
            milestone_id: milestones.get(&date).map(|id| (*id).clone()),
        })
        .collect())
}

pub(crate) fn stats_overview(deps: &Deps) -> Result<StatsDto, CoreError> {
    let today = deps.day_ctx()?.today();
    let active = deps.repo.active_dates()?;
    let history = PlanHistory::from_rows(&deps.repo.plan_versions()?);
    let is_study_day = |date: NaiveDate| history.is_study_day(date);
    let counts = deps.repo.card_counts()?;
    let introduced = deps.repo.introduced_items()?;
    let count_prefix = |prefix: &str| {
        let matching = introduced
            .iter()
            .filter(|id| id.starts_with(prefix))
            .count();
        u32::try_from(matching).expect("項目數不可能超過 u32")
    };
    let kana_mastered = deps
        .repo
        .all_kana_mastery()?
        .iter()
        .filter(|row| row.mastered_at.is_some())
        .count();
    Ok(StatsDto {
        streak_current: current_streak(&active, today, is_study_day),
        streak_best: best_streak(&active, is_study_day),
        total_reviews: counts.total_reviews,
        cards_new: counts.cards_new,
        cards_learning: counts.cards_learning,
        cards_review: counts.cards_review,
        cards_mastered: counts.cards_mastered,
        kana_mastered: u32::try_from(kana_mastered).expect("假名數不可能超過 u32"),
        vocab_introduced: count_prefix(VOCAB_PREFIX),
        grammar_introduced: count_prefix(GRAMMAR_PREFIX),
    })
}

fn activity_dto(row: &DailyActivityRow) -> DayActivityDto {
    DayActivityDto {
        date: row.logical_date.to_string(),
        answers: row.reviews_done + row.new_done + row.relearn_done + row.drills_done,
        lessons: row.lessons_done,
        study_minutes: row.study_ms as f64 / MS_PER_MINUTE,
    }
}

pub(crate) fn activity_range(
    deps: &Deps,
    from_date: &str,
    to_date: &str,
) -> Result<Vec<DayActivityDto>, CoreError> {
    let from = parse_date("from_date", from_date)?;
    let to = parse_date("to_date", to_date)?;
    if from > to {
        return Err(CoreError::invalid("from_date", "起日不可晚於迄日"));
    }
    Ok(deps
        .repo
        .activity_range(from, to)?
        .iter()
        .map(activity_dto)
        .collect())
}

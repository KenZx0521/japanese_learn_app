//! 今日、完成任務、再學一批、聽力（§9.4、§7.4）。

use jp_plan::tasks::DailyTask;
use jp_plan::today::ensure_snapshot;

use super::deps::Deps;
use super::mapping::plan::today_dto;
use super::mapping::question::questions_dto;
use super::mapping::sentence::KnownCards;
use super::session::QuizInputs;
use crate::api::dto_plan::TodayViewDto;
use crate::api::dto_study::QuestionDto;
use crate::api::error::CoreError;

const TASK_ENTITY: &str = "task";

pub(crate) fn today_view(deps: &Deps, audio_available: bool) -> Result<TodayViewDto, CoreError> {
    let ctx = deps.day_ctx()?;
    let view = jp_plan::today::today_view(&deps.repo, &deps.content, &ctx, audio_available)?;
    Ok(today_dto(&view, &deps.content))
}

pub(crate) fn complete_task(
    deps: &Deps,
    task_key: &str,
    duration_ms: u32,
    audio_available: bool,
) -> Result<TodayViewDto, CoreError> {
    let ctx = deps.day_ctx()?;
    let view = jp_plan::complete::complete_task(
        &deps.repo,
        &deps.content,
        &ctx,
        task_key,
        duration_ms,
        audio_available,
    )?;
    Ok(today_dto(&view, &deps.content))
}

pub(crate) fn learn_more(deps: &Deps, audio_available: bool) -> Result<TodayViewDto, CoreError> {
    let ctx = deps.day_ctx()?;
    let view = jp_plan::today::learn_more(&deps.repo, &deps.content, &ctx, audio_available)?;
    Ok(today_dto(&view, &deps.content))
}

pub(crate) fn listen_session(
    deps: &Deps,
    task_key: &str,
    session_seed: u32,
    audio_available: bool,
) -> Result<Vec<QuestionDto>, CoreError> {
    let ctx = deps.day_ctx()?;
    let snapshot = ensure_snapshot(&deps.repo, &deps.content, &ctx, audio_available)?;
    let sentence_ids = snapshot
        .tasks
        .iter()
        .find_map(|task| match task {
            DailyTask::Listen {
                key, sentence_ids, ..
            } if key == task_key => Some(sentence_ids),
            _ => None,
        })
        .ok_or_else(|| CoreError::not_found(TASK_ENTITY, task_key))?;
    let inputs = QuizInputs::load(deps, ctx.today())?;
    let quiz = inputs.ctx(deps, session_seed, audio_available);
    let questions = jp_quiz::listen_quiz::listen_session(&quiz, sentence_ids)?;
    questions_dto(&questions, KnownCards::new(&deps.repo))
}

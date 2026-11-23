//! 演練與檢定（§7.4、§8.4、§8.5）。

use jp_plan::tasks::DailyTask;
use jp_plan::today::{dismiss_checkpoint, ensure_snapshot};
use jp_quiz::drill::DrillSelection;
use jp_quiz::grade::grade_answer;
use jp_quiz::model::{AnswerPayload as QuizPayload, ShadowLevel};
use jp_store::{ActivityDelta, ActivityRepo};

use super::deps::Deps;
use super::mapping::plan::today_dto;
use super::mapping::question::{
    answer_domain, drill_result_dto, payload_domain, questions_dto, reference_domain,
};
use super::mapping::sentence::KnownCards;
use super::session::QuizInputs;
use crate::api::dto_plan::TodayViewDto;
use crate::api::dto_study::{
    AnswerDto, AnswerPayload, CheckpointResultDto, DrillFilterDto, DrillResultDto, QuestionDto,
    QuestionRefDto,
};
use crate::api::error::CoreError;

/// `task_key` 解成快照內的課與題數；`count = 0` 時沿用快照的題數。
fn resolve_scope(
    deps: &Deps,
    filter: &DrillFilterDto,
    audio_available: bool,
) -> Result<(Vec<String>, u32), CoreError> {
    let Some(key) = filter.task_key.as_deref() else {
        return Ok((filter.lesson_id.iter().cloned().collect(), filter.count));
    };
    let ctx = deps.day_ctx()?;
    let snapshot = ensure_snapshot(&deps.repo, &deps.content, &ctx, audio_available)?;
    snapshot
        .tasks
        .iter()
        .find_map(|task| match task {
            DailyTask::Drill {
                key: task_key,
                lesson_ids,
                question_count,
                ..
            } if task_key == key => {
                let count = if filter.count == 0 {
                    *question_count
                } else {
                    filter.count
                };
                Some((lesson_ids.clone(), count))
            }
            _ => None,
        })
        .ok_or_else(|| CoreError::not_found("task", key))
}

pub(crate) fn drill_session(
    deps: &Deps,
    filter: &DrillFilterDto,
    session_seed: u32,
    audio_available: bool,
) -> Result<Vec<QuestionDto>, CoreError> {
    let (lesson_ids, count) = resolve_scope(deps, filter, audio_available)?;
    let inputs = QuizInputs::load(deps, deps.day_ctx()?.today())?;
    let quiz = inputs.ctx(deps, session_seed, audio_available);
    let selection = DrillSelection {
        lesson_ids: &lesson_ids,
        target: filter.target.as_deref(),
        drill_ids: &filter.drill_ids,
        count,
    };
    let questions = jp_quiz::drill::drill_session(&quiz, &selection)?;
    questions_dto(&questions, KnownCards::new(&deps.repo))
}

fn practice_delta(response: &QuizPayload) -> ActivityDelta {
    let base = ActivityDelta {
        drills_done: 1,
        ..ActivityDelta::default()
    };
    match response {
        QuizPayload::Shadow {
            level: ShadowLevel::Kept,
        } => ActivityDelta {
            shadow_kept: 1,
            ..base
        },
        QuizPayload::Shadow {
            level: ShadowLevel::Almost,
        } => ActivityDelta {
            shadow_almost: 1,
            ..base
        },
        QuizPayload::Shadow {
            level: ShadowLevel::Lost,
        } => ActivityDelta {
            shadow_lost: 1,
            ..base
        },
        _ => base,
    }
}

/// 演練不更新 FSRS，只累計練習統計（§6.1、§7.4）。
pub(crate) fn grade_drill(
    deps: &Deps,
    reference: &QuestionRefDto,
    response: &AnswerPayload,
) -> Result<DrillResultDto, CoreError> {
    let domain_response = payload_domain(response);
    let graded = grade_answer(
        &deps.content,
        &reference_domain(reference),
        &domain_response,
    )?;
    let today = deps.day_ctx()?.today();
    deps.repo
        .add_activity(today, practice_delta(&domain_response))?;
    drill_result_dto(&graded, KnownCards::new(&deps.repo))
}

pub(crate) fn checkpoint_start(
    deps: &Deps,
    milestone_id: &str,
    session_seed: u32,
    audio_available: bool,
) -> Result<Vec<QuestionDto>, CoreError> {
    let inputs = QuizInputs::load(deps, deps.day_ctx()?.today())?;
    let quiz = inputs.ctx(deps, session_seed, audio_available);
    let questions = jp_quiz::checkpoint::checkpoint_start(&quiz, milestone_id)?;
    questions_dto(&questions, KnownCards::new(&deps.repo))
}

pub(crate) fn checkpoint_finish(
    deps: &Deps,
    milestone_id: &str,
    answers: &[AnswerDto],
) -> Result<CheckpointResultDto, CoreError> {
    let ctx = deps.day_ctx()?;
    let domain: Vec<_> = answers.iter().map(answer_domain).collect();
    let result = jp_quiz::checkpoint::checkpoint_finish(
        &deps.repo,
        &deps.content,
        &ctx,
        milestone_id,
        &domain,
    )?;
    Ok(CheckpointResultDto {
        milestone_id: result.milestone_id,
        correct: result.correct,
        total: result.total,
        score_percent: result.score_percent,
        passed: result.passed,
        weak_ids: result.weak_ids,
    })
}

pub(crate) fn checkpoint_dismiss(
    deps: &Deps,
    milestone_id: &str,
    audio_available: bool,
) -> Result<TodayViewDto, CoreError> {
    let ctx = deps.day_ctx()?;
    let view = dismiss_checkpoint(
        &deps.repo,
        &deps.content,
        &ctx,
        milestone_id,
        audio_available,
    )?;
    Ok(today_dto(&view, &deps.content))
}

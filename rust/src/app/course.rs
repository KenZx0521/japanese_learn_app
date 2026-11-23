//! 課程總覽與單課內容（§9.4）。

use jp_content::schema::LessonDef;
use jp_plan::input::is_main_lesson;
use jp_plan::slice::integration_days_needed;
use jp_store::PlanRepo;

use super::deps::Deps;
use super::mapping::enums::content_stage;
use super::views::Views;
use crate::api::dto_content::{
    CourseOverviewDto, LessonDetailDto, LessonStatus, LessonSummaryDto, StageDto,
};
use crate::api::error::CoreError;

/// 沒有計畫時顯示一般方案的天數。
const DEFAULT_PLAN_MINUTES: u32 = 20;

fn lesson_status(views: &Views<'_>, id: &str) -> LessonStatus {
    if views.state.skipped.contains(id) {
        LessonStatus::Skipped
    } else if views.state.is_completed(id) {
        LessonStatus::Done
    } else if views.cursor() == Some(id) {
        LessonStatus::Current
    } else {
        LessonStatus::NotStarted
    }
}

fn lesson_summary(views: &Views<'_>, lesson: &LessonDef) -> LessonSummaryDto {
    LessonSummaryDto {
        id: lesson.id.clone(),
        stage_id: lesson.stage.clone(),
        title_zh: lesson.title_zh.clone(),
        can_do_zh: lesson.can_do_zh.clone(),
        dialogue_id: lesson.dialogue.clone(),
        milestone_id: views
            .content()
            .milestone_for_lesson(&lesson.id)
            .map(|milestone| milestone.id.clone()),
        status: lesson_status(views, &lesson.id),
    }
}

pub(crate) fn course_overview(deps: &Deps) -> Result<CourseOverviewDto, CoreError> {
    let views = Views::load(deps)?;
    let content = views.content();
    let course = content.course();
    Ok(CourseOverviewDto {
        content_stage: content_stage(content.stage()),
        stages: course
            .stages
            .iter()
            .map(|stage| StageDto {
                id: stage.id.clone(),
                title_zh: stage.title_zh.clone(),
            })
            .collect(),
        lessons: course
            .lessons
            .iter()
            .map(|lesson| lesson_summary(&views, lesson))
            .collect(),
        current_lesson_id: views.cursor().map(str::to_owned),
        notes_available: content.notes().iter().any(|note| !note.retired()),
    })
}

fn integration_days_for(deps: &Deps, views: &Views<'_>, lesson_id: &str) -> Result<u32, CoreError> {
    if !is_main_lesson(lesson_id) {
        return Ok(0);
    }
    let minutes = deps
        .repo
        .active_plan(views.today)?
        .map_or(DEFAULT_PLAN_MINUTES, |plan| plan.daily_minutes);
    Ok(integration_days_needed(minutes))
}

pub(crate) fn lesson_detail(deps: &Deps, lesson_id: &str) -> Result<LessonDetailDto, CoreError> {
    let views = Views::load(deps)?;
    let content = views.content();
    let lesson = content
        .lesson(lesson_id)
        .ok_or_else(|| CoreError::not_found("lesson", lesson_id))?;
    let items = content.lesson_items(lesson_id).cloned().unwrap_or_default();
    Ok(LessonDetailDto {
        summary: lesson_summary(&views, lesson),
        kana: items
            .kana
            .iter()
            .map(|&index| views.kana_cell(&content.kana()[index as usize]))
            .collect(),
        rules: items
            .rules
            .iter()
            .map(|&index| views.rule_card(&content.rule_cards()[index as usize]))
            .collect(),
        words: items
            .words
            .iter()
            .map(|&index| views.vocab_summary(&content.vocab()[index as usize]))
            .collect::<Result<_, _>>()?,
        grammar: items
            .grammar
            .iter()
            .map(|&index| views.grammar_summary(&content.grammar()[index as usize]))
            .collect::<Result<_, _>>()?,
        dialogue: lesson
            .dialogue
            .as_deref()
            .and_then(|id| content.dialogue_by_id(id))
            .map(|entry| views.dialogue_summary(entry)),
        integration_days_done: views
            .state
            .integration_days
            .get(lesson_id)
            .copied()
            .unwrap_or(0),
        integration_days_needed: integration_days_for(deps, &views, lesson_id)?,
    })
}

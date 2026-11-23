//! 計畫與今日（§9.5）。

use chrono::NaiveDate;
use jp_content::ContentStore;
use jp_plan::budget::{DayBudget, NewContentMode};
use jp_plan::calendar::{mask_from_weekdays, weekdays_from_mask};
use jp_plan::input::PlanInput;
use jp_plan::tasks::DailyTask;
use jp_plan::today::{ReviewCounts, TaskView, TodayView};
use jp_plan::Slice;
use jp_store::PlanVersionRow;

use super::enums::{recovery_reason, start_level_domain, start_level_dto};
use crate::api::dto_plan::{BudgetDto, PlanInputDto, TaskDto, TodayViewDto};
use crate::api::error::CoreError;

const DATE_FORMAT: &str = "%Y-%m-%d";
const NO_REVIEW_COUNTS: ReviewCounts = ReviewCounts {
    due: 0,
    learning: 0,
    new_cards: 0,
};

fn count(items: usize) -> u32 {
    u32::try_from(items).expect("切片項目數不可能超過 u32")
}

pub(crate) fn parse_date(field: &str, text: &str) -> Result<NaiveDate, CoreError> {
    NaiveDate::parse_from_str(text, DATE_FORMAT)
        .map_err(|_| CoreError::invalid(field, format!("不是 YYYY-MM-DD：{text}")))
}

pub(crate) fn plan_input(dto: &PlanInputDto) -> Result<PlanInput, CoreError> {
    Ok(PlanInput {
        daily_minutes: dto.daily_minutes,
        weekday_mask: mask_from_weekdays(&dto.weekdays)?,
        start_level: start_level_domain(dto.start_level),
        target_date: dto
            .target_date
            .as_deref()
            .map(|text| parse_date("target_date", text))
            .transpose()?,
        known_kana_lessons: dto.known_kana_lessons.clone(),
    })
}

/// `known_kana_lessons` 不存在計畫列，由呼叫端從略過紀錄補上。
pub(crate) fn plan_input_dto(
    row: &PlanVersionRow,
    known_kana_lessons: Vec<String>,
) -> Result<PlanInputDto, CoreError> {
    let input = PlanInput::from_row(row)?;
    Ok(PlanInputDto {
        daily_minutes: row.daily_minutes,
        weekdays: weekdays_from_mask(row.weekday_mask),
        start_level: start_level_dto(input.start_level),
        target_date: row.target_date.map(|date| date.to_string()),
        known_kana_lessons,
    })
}

fn budget_dto(budget: &DayBudget) -> BudgetDto {
    BudgetDto {
        new_minutes: budget.split.new,
        review_minutes: budget.split.review,
        drill_minutes: budget.split.drill,
        listen_minutes: budget.split.listen,
        review_cap: budget.review_cap,
        capacity: budget.capacity,
        new_words_limit: budget.new_words_limit,
        kana_chars_limit: budget.kana_chars_limit,
    }
}

/// `(words, grammar, kana, rules)`；K10 的易混字組也算一張規則卡。
fn slice_counts(slice: &Slice) -> (u32, u32, u32, u32) {
    match slice {
        Slice::Kana { kana, rules, .. } => (0, 0, count(kana.len()), count(rules.len())),
        Slice::KanaRule {
            rules, confusables, ..
        } => (0, 0, 0, count(rules.len() + confusables.len())),
        Slice::Vocab { words, grammar, .. } => (count(words.len()), count(grammar.len()), 0, 0),
        Slice::Integration { .. } => (0, 0, 0, 0),
    }
}

fn lesson_title(content: &ContentStore, lesson_id: &str) -> String {
    content
        .lesson(lesson_id)
        .map_or_else(String::new, |lesson| lesson.title_zh.clone())
}

fn review_task(key: &str, view: &TaskView) -> TaskDto {
    let counts = view.review.unwrap_or(NO_REVIEW_COUNTS);
    TaskDto::Review {
        key: key.to_owned(),
        due: counts.due,
        learning: counts.learning,
        new_cards: counts.new_cards,
        minutes: view.minutes,
        done: view.done,
    }
}

fn new_content_task(
    key: &str,
    lesson_id: &str,
    slice: &Slice,
    view: &TaskView,
    content: &ContentStore,
) -> TaskDto {
    let (words, grammar, kana, rules) = slice_counts(slice);
    TaskDto::NewContent {
        key: key.to_owned(),
        lesson_id: lesson_id.to_owned(),
        title_zh: lesson_title(content, lesson_id),
        words,
        grammar,
        kana,
        rules,
        minutes: view.minutes,
        done: view.done,
    }
}

fn integration_task(
    key: &str,
    lesson_id: &str,
    dialogue_id: Option<&String>,
    phases: &[u32],
    view: &TaskView,
    content: &ContentStore,
) -> TaskDto {
    TaskDto::Integration {
        key: key.to_owned(),
        lesson_id: lesson_id.to_owned(),
        title_zh: lesson_title(content, lesson_id),
        dialogue_id: dialogue_id.cloned(),
        phases: phases.to_vec(),
        minutes: view.minutes,
        done: view.done,
    }
}

fn task_dto(view: &TaskView, content: &ContentStore) -> TaskDto {
    let (key, minutes, done) = (view.task.key().to_owned(), view.minutes, view.done);
    match &view.task {
        DailyTask::Review { .. } => review_task(&key, view),
        DailyTask::NewContent {
            lesson_id, slice, ..
        } => new_content_task(&key, lesson_id, slice, view, content),
        DailyTask::Integration {
            lesson_id,
            dialogue_id,
            phases,
            ..
        } => integration_task(&key, lesson_id, dialogue_id.as_ref(), phases, view, content),
        DailyTask::Drill { question_count, .. } => TaskDto::Drill {
            key,
            questions: *question_count,
            minutes,
            done,
        },
        DailyTask::Listen { sentence_ids, .. } => TaskDto::Listen {
            key,
            sentences: count(sentence_ids.len()),
            minutes,
            done,
        },
        DailyTask::Checkpoint { milestone_id, .. } => TaskDto::Checkpoint {
            key,
            milestone_id: milestone_id.clone(),
            done,
        },
    }
}

pub(crate) fn today_dto(view: &TodayView, content: &ContentStore) -> TodayViewDto {
    TodayViewDto {
        logical_date: view.logical_date.to_string(),
        is_study_day: view.is_study_day,
        next_study_date: view.next_study_date.map(|date| date.to_string()),
        tasks: view
            .tasks
            .iter()
            .map(|task| task_dto(task, content))
            .collect(),
        budget: budget_dto(&view.budget),
        streak: view.streak,
        recovery_reason: view.budget.recovery_reason.map(recovery_reason),
        minimal_new: view.budget.new_content == NewContentMode::Minimal,
        learning_tail: view.learning_tail,
        estimated_minutes: view.estimated_minutes,
        can_learn_more: view.can_learn_more,
    }
}

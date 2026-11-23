//! `complete_task` 的副作用組裝（§7.4）。

use chrono::NaiveDate;
use jp_content::ContentStore;
use jp_lang::clock::DayContext;
use jp_srs::facets::cards_for_content;
use jp_store::{
    ActivityDelta, CompleteTaskWrite, ItemIntroRow, LessonProgressUpdate, NewCard, Repository,
};

use crate::completion::{integration_completes, slice_effects, IntroItem};
use crate::error::PlanError;
use crate::slice::{integration_days_needed, Slice};
use crate::state::CursorState;
use crate::tasks::DailyTask;
use crate::today::{active_plan, current_state, ensure_snapshot, today_view, TodayView};

#[derive(Default)]
struct WriteParts {
    intros: Vec<IntroItem>,
    cards: Vec<NewCard>,
    lesson_updates: Vec<LessonProgressUpdate>,
}

fn completed_update(lesson_id: &str) -> LessonProgressUpdate {
    LessonProgressUpdate {
        lesson_id: lesson_id.to_owned(),
        integration_days_added: 0,
        integration_dialogue: None,
        completed: true,
    }
}

fn new_content_parts(
    slice: &Slice,
    state: &CursorState,
    content: &ContentStore,
    ctx: &DayContext,
) -> WriteParts {
    let effects = slice_effects(slice, state, content);
    let card_items: Vec<&String> = match slice {
        Slice::Kana { kana, .. } => kana.iter().collect(),
        Slice::Vocab { words, grammar, .. } => words.iter().chain(grammar).collect(),
        Slice::KanaRule { .. } | Slice::Integration { .. } => Vec::new(),
    };
    WriteParts {
        cards: card_items
            .iter()
            .flat_map(|id| cards_for_content(id, content, ctx.now))
            .collect(),
        lesson_updates: effects
            .completed_lessons
            .iter()
            .map(|l| completed_update(l))
            .collect(),
        intros: effects.intros,
    }
}

fn integration_parts(
    lesson_id: &str,
    dialogue_id: Option<&String>,
    days_needed: u32,
    state: &CursorState,
    content: &ContentStore,
) -> WriteParts {
    let days_after = state.integration_days.get(lesson_id).copied().unwrap_or(0) + 1;
    WriteParts {
        lesson_updates: vec![LessonProgressUpdate {
            lesson_id: lesson_id.to_owned(),
            integration_days_added: 1,
            integration_dialogue: dialogue_id.cloned(),
            completed: integration_completes(lesson_id, days_after, days_needed, state, content),
        }],
        ..WriteParts::default()
    }
}

fn parts_for_task(
    task: &DailyTask,
    state: &CursorState,
    days_needed: u32,
    content: &ContentStore,
    ctx: &DayContext,
) -> WriteParts {
    match task {
        DailyTask::Review { .. }
        | DailyTask::Drill { .. }
        | DailyTask::Listen { .. }
        | DailyTask::Checkpoint { .. } => WriteParts::default(),
        DailyTask::NewContent { slice, .. } => new_content_parts(slice, state, content, ctx),
        DailyTask::Integration {
            lesson_id,
            dialogue_id,
            ..
        } => integration_parts(lesson_id, dialogue_id.as_ref(), days_needed, state, content),
    }
}

/// 這些卡當天已作答的毫秒數，`submit_review` 已逐題累加到 `study_ms`。
fn answered_ms_today<R: Repository + ?Sized>(
    repo: &R,
    cards: &[NewCard],
    today: NaiveDate,
) -> Result<i64, PlanError> {
    let mut total = 0;
    for card in cards {
        total += repo
            .reviews_for_card(&card.card_id)?
            .iter()
            .filter(|log| log.entry.logical_date == today)
            .map(|log| i64::from(log.entry.duration_ms))
            .sum::<i64>();
    }
    Ok(total)
}

/// `duration_ms` 是整段任務的時鐘，已包含逐題作答的時間，同一段時間只計一次（§7.4）。
fn task_study_ms<R: Repository + ?Sized>(
    repo: &R,
    task: &DailyTask,
    cards: &[NewCard],
    duration_ms: u32,
    today: NaiveDate,
) -> Result<i64, PlanError> {
    let clock = i64::from(duration_ms);
    Ok(match task {
        DailyTask::Review { .. } => 0,
        DailyTask::NewContent { .. } => (clock - answered_ms_today(repo, cards, today)?).max(0),
        _ => clock,
    })
}

/// 已會的字不進複習（§9.4）：`NewContent` 打開時已建卡的話，也已設為暫停。
fn without_known_words<R: Repository + ?Sized>(
    repo: &R,
    cards: Vec<NewCard>,
) -> Result<Vec<NewCard>, PlanError> {
    let flags = repo.vocab_flags()?;
    Ok(cards
        .into_iter()
        .filter(|card| !flags.get(&card.content_id).is_some_and(|row| row.known))
        .collect())
}

fn build_write(
    task_key: &str,
    parts: WriteParts,
    study_ms: i64,
    ctx: &DayContext,
) -> CompleteTaskWrite {
    let today = ctx.today();
    let lessons_done = parts.lesson_updates.iter().filter(|u| u.completed).count();
    CompleteTaskWrite {
        logical_date: today,
        task_key: task_key.to_owned(),
        done_at: ctx.now,
        item_intros: parts
            .intros
            .into_iter()
            .map(|item| ItemIntroRow {
                item_id: item.item_id,
                lesson_id: item.lesson_id,
                logical_date: today,
                introduced_at: ctx.now,
            })
            .collect(),
        new_cards: parts.cards,
        lesson_updates: parts.lesson_updates,
        activity: ActivityDelta {
            lessons_done: u32::try_from(lessons_done).expect("課數不可能超過 u32"),
            study_ms,
            ..ActivityDelta::default()
        },
    }
}

/// 依任務類型在單一 transaction 內完成。重複呼叫同一 key 是 no-op，未知的 key 回 `NotFound`。
pub fn complete_task<R: Repository + ?Sized>(
    repo: &R,
    content: &ContentStore,
    ctx: &DayContext,
    task_key: &str,
    duration_ms: u32,
    audio_available: bool,
) -> Result<TodayView, PlanError> {
    let today = ctx.today();
    let snapshot = ensure_snapshot(repo, content, ctx, audio_available)?;
    let task = snapshot
        .tasks
        .iter()
        .find(|task| task.key() == task_key)
        .ok_or_else(|| PlanError::not_found("task", task_key))?;
    if !repo.task_done(today)?.contains(task_key) {
        let plan = active_plan(repo, today)?;
        let state = current_state(repo, &plan, content)?;
        let days_needed = integration_days_needed(plan.daily_minutes);
        let parts = parts_for_task(task, &state, days_needed, content, ctx);
        let study_ms = task_study_ms(repo, task, &parts.cards, duration_ms, today)?;
        let parts = WriteParts {
            cards: without_known_words(repo, parts.cards)?,
            ..parts
        };
        repo.complete_task(&build_write(task_key, parts, study_ms, ctx))?;
    }
    today_view(repo, content, ctx, audio_available)
}

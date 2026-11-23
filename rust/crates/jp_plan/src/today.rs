//! 快照的讀寫與 `TodayView`（§7.4）。

use std::collections::HashSet;

use chrono::{DateTime, Duration, NaiveDate, Utc};
use jp_content::ContentStore;
use jp_lang::clock::DayContext;
use jp_srs::queue::{available_new_cards, QueueLimits, EARLY_LEARNING_MINUTES};
use jp_store::{PlanVersionRow, QueueFilter, Repository, SnapshotRow};

use crate::budget::{
    estimate_review_minutes, new_cards_minutes, tail_card_limit, DayBudget, NewContentMode,
};
use crate::calendar::{is_study_day, next_study_date, PlanHistory};
use crate::compose::{compose_day, slice_quota_for, task_for_slice, DayFacts};
use crate::error::PlanError;
use crate::input::{preset_for, PlanInput};
use crate::slice::{next_slice, SliceQuota};
use crate::state::CursorState;
use crate::streak::current_streak;
use crate::tasks::{checkpoint_key, DailyTask, DaySnapshot, KEY_REVIEW};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ReviewCounts {
    pub due: u32,
    pub learning: u32,
    pub new_cards: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TaskView {
    pub task: DailyTask,
    pub done: bool,
    pub minutes: f64,
    /// 只有 `Review` 有值。
    pub review: Option<ReviewCounts>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TodayView {
    pub logical_date: NaiveDate,
    pub is_study_day: bool,
    pub next_study_date: Option<NaiveDate>,
    pub tasks: Vec<TaskView>,
    pub budget: DayBudget,
    pub streak: u32,
    pub learning_tail: u32,
    pub estimated_minutes: f64,
    pub can_learn_more: bool,
}

pub(crate) fn active_plan<R: Repository + ?Sized>(
    repo: &R,
    today: NaiveDate,
) -> Result<PlanVersionRow, PlanError> {
    repo.active_plan(today)?
        .ok_or_else(|| PlanError::not_found("plan", today.to_string()))
}

/// 資料庫的進度，加上 `start_level` 在記憶體內跳過的課（`basic` 的 L 課）。
pub(crate) fn current_state<R: Repository + ?Sized>(
    repo: &R,
    plan: &PlanVersionRow,
    content: &ContentStore,
) -> Result<CursorState, PlanError> {
    let input = PlanInput::from_row(plan)?;
    Ok(CursorState::load(repo)?.with_plan_skips(&input, plan.effective_from, content))
}

fn previous_recovery_days<R: Repository + ?Sized>(
    repo: &R,
    today: NaiveDate,
) -> Result<u32, PlanError> {
    let previous = repo.latest_snapshot_before(today)?;
    // 舊快照讀不懂時不接續，只是少算一天，不值得擋住今天。
    Ok(previous
        .and_then(|row| DaySnapshot::from_json(&row.payload_json).ok())
        .map_or(0, |snapshot| snapshot.budget.recovery_days))
}

fn store_snapshot<R: Repository + ?Sized>(
    repo: &R,
    ctx: &DayContext,
    plan_id: i64,
    snapshot: &DaySnapshot,
) -> Result<(), PlanError> {
    repo.put_snapshot(&SnapshotRow {
        logical_date: ctx.today(),
        plan_version_id: plan_id,
        payload_json: snapshot.to_json()?,
        created_at: ctx.now,
    })?;
    Ok(())
}

/// 佇列與 `TaskView` 用的上限都來自快照的預算：收尾上限依當天（可能已合併的）review 分鐘。
pub(crate) fn queue_limits(budget: &DayBudget) -> QueueLimits {
    QueueLimits {
        review_cap: budget.review_cap,
        new_words_per_day: budget.new_words_limit,
        tail_new_cards_per_day: tail_card_limit(budget.split.review),
    }
}

/// 快照當下收尾可取的 state=0 卡，與 `TaskView` 的 `new_cards` 同一個查詢（§7.4）。
/// `available_new_cards` 不看 `review_cap`，所以這裡傳 0 不影響結果；收尾上限要等配比定了才知道，
/// 這裡先不設限，由 `review_cap_after_tail` 依 review 分鐘夾住。
fn snapshot_tail<R: Repository + ?Sized>(
    repo: &R,
    ctx: &DayContext,
    new_words_per_day: u32,
    queue: QueueFilter,
) -> Result<u32, PlanError> {
    let limits = QueueLimits {
        review_cap: 0,
        new_words_per_day,
        tail_new_cards_per_day: u32::MAX,
    };
    Ok(available_new_cards(repo, ctx, limits, queue)?)
}

fn build_snapshot<R: Repository + ?Sized>(
    repo: &R,
    content: &ContentStore,
    ctx: &DayContext,
    audio_available: bool,
) -> Result<DaySnapshot, PlanError> {
    let today = ctx.today();
    let plan = active_plan(repo, today)?;
    let preset = preset_for(plan.daily_minutes, content)
        .ok_or_else(|| PlanError::internal(format!("preset: {}", plan.daily_minutes)))?;
    let state = current_state(repo, &plan, content)?;
    let queue = QueueFilter { audio_available };
    let due_facets = repo.due_review_facets(ctx, queue)?;
    let tail_new_cards = snapshot_tail(repo, ctx, preset.new_words_per_day, queue)?;
    let history = PlanHistory::from_rows(&repo.plan_versions()?);
    let plan_active = repo.plan_active_dates()?;
    let milestone_results = repo.milestone_results()?;
    let dismissed = repo.dismissed_milestones()?;
    let facts = DayFacts {
        today,
        plan: &plan,
        preset,
        state: &state,
        history: &history,
        due_facets: &due_facets,
        tail_new_cards,
        unseen_new: repo.count_unseen_new(ctx)?,
        last_active: plan_active.range(..today).next_back().copied(),
        previous_recovery_days: previous_recovery_days(repo, today)?,
        audio_available,
        milestone_results: &milestone_results,
        dismissed: &dismissed,
    };
    let snapshot = compose_day(&facts, content);
    store_snapshot(repo, ctx, plan.id, &snapshot)?;
    Ok(snapshot)
}

/// 當日首次呼叫時計算並寫入快照，之後整天回同一份。
pub fn ensure_snapshot<R: Repository + ?Sized>(
    repo: &R,
    content: &ContentStore,
    ctx: &DayContext,
    audio_available: bool,
) -> Result<DaySnapshot, PlanError> {
    if let Some(row) = repo.snapshot(ctx.today())? {
        // 快照是可重算的快取；讀不懂（例如 App 升級改了格式）就重建。
        if let Ok(snapshot) = DaySnapshot::from_json(&row.payload_json) {
            return Ok(snapshot);
        }
    }
    build_snapshot(repo, content, ctx, audio_available)
}

/// 今日起點＝`end_of_today_utc() - 1 天`（§6.4）。
fn start_of_today(ctx: &DayContext) -> DateTime<Utc> {
    ctx.end_of_today_utc() - Duration::days(1)
}

fn early_limit(ctx: &DayContext) -> DateTime<Utc> {
    ctx.now + Duration::minutes(EARLY_LEARNING_MINUTES)
}

struct LiveCounts {
    review: ReviewCounts,
    due_facets: Vec<String>,
    learning_tail: u32,
}

fn live_counts<R: Repository + ?Sized>(
    repo: &R,
    ctx: &DayContext,
    budget: &DayBudget,
    queue: QueueFilter,
) -> Result<LiveCounts, PlanError> {
    let limits = queue_limits(budget);
    let limit = early_limit(ctx);
    let new_cards = available_new_cards(repo, ctx, limits, queue)?;
    let review = ReviewCounts {
        due: repo.count_due_reviews(ctx, queue)?,
        learning: repo.count_learning(limit, Some(start_of_today(ctx)), queue)?,
        new_cards,
    };
    Ok(LiveCounts {
        review,
        due_facets: repo.due_review_facets(ctx, queue)?,
        learning_tail: repo.count_learning(limit, None, queue)? + new_cards,
    })
}

fn review_view(
    task: DailyTask,
    counts: &LiveCounts,
    budget: &DayBudget,
    done_keys: &HashSet<String>,
) -> TaskView {
    let review = counts.review;
    let minutes = estimate_review_minutes(&counts.due_facets, budget.review_cap, review.new_cards);
    TaskView {
        done: done_keys.contains(KEY_REVIEW) || (review.due == 0 && review.learning == 0),
        minutes,
        task,
        review: Some(review),
    }
}

fn task_views(
    snapshot: &DaySnapshot,
    counts: &LiveCounts,
    done_keys: &HashSet<String>,
    today_is_study: bool,
) -> Vec<TaskView> {
    let keep_review = today_is_study || counts.review.due > 0 || counts.review.learning > 0;
    snapshot
        .tasks
        .iter()
        .filter(|task| keep_review || !matches!(task, DailyTask::Review { .. }))
        .map(|task| {
            if matches!(task, DailyTask::Review { .. }) {
                review_view(task.clone(), counts, &snapshot.budget, done_keys)
            } else {
                TaskView {
                    task: task.clone(),
                    done: done_keys.contains(task.key()),
                    minutes: task.minutes().unwrap_or(0.0),
                    review: None,
                }
            }
        })
        .collect()
}

/// 未完成任務的分鐘；`Review` 已 done 時只算 `new_cards` 的收尾。
fn remaining_minutes(view: &TaskView) -> f64 {
    if view.done {
        view.review
            .map_or(0.0, |counts| new_cards_minutes(counts.new_cards))
    } else {
        view.minutes
    }
}

/// 從 P1 考完檢定不經 `complete_task`，當天有成績就算完成，不必再考一次。
fn done_keys_today<R: Repository + ?Sized>(
    repo: &R,
    today: NaiveDate,
) -> Result<HashSet<String>, PlanError> {
    let taken = repo
        .milestone_results()?
        .into_iter()
        .filter(|row| row.logical_date == today)
        .map(|row| checkpoint_key(&row.milestone_id));
    Ok(repo.task_done(today)?.into_iter().chain(taken).collect())
}

fn view_of<R: Repository + ?Sized>(
    repo: &R,
    content: &ContentStore,
    ctx: &DayContext,
    audio_available: bool,
    snapshot: &DaySnapshot,
) -> Result<TodayView, PlanError> {
    let today = ctx.today();
    let plan = active_plan(repo, today)?;
    let today_is_study = is_study_day(plan.weekday_mask, today);
    let queue = QueueFilter { audio_available };
    let counts = live_counts(repo, ctx, &snapshot.budget, queue)?;
    let done_keys = done_keys_today(repo, today)?;
    let tasks = task_views(snapshot, &counts, &done_keys, today_is_study);
    let history = PlanHistory::from_rows(&repo.plan_versions()?);
    let streak = current_streak(&repo.active_dates()?, today, |date| {
        history.is_study_day(date)
    });
    let state = current_state(repo, &plan, content)?;
    let can_learn_more = can_learn_more(snapshot, &tasks, today_is_study, &state, &plan, content);
    Ok(TodayView {
        logical_date: today,
        is_study_day: today_is_study,
        next_study_date: (!today_is_study)
            .then(|| next_study_date(plan.weekday_mask, today))
            .flatten(),
        estimated_minutes: tasks.iter().map(remaining_minutes).sum(),
        tasks,
        budget: snapshot.budget.clone(),
        streak,
        learning_tail: counts.learning_tail,
        can_learn_more,
    })
}

fn learn_more_quota(
    budget: &DayBudget,
    plan: &PlanVersionRow,
    content: &ContentStore,
) -> Result<SliceQuota, PlanError> {
    let preset = preset_for(plan.daily_minutes, content)
        .ok_or_else(|| PlanError::internal(format!("preset: {}", plan.daily_minutes)))?;
    Ok(SliceQuota {
        words: budget.new_words_limit,
        kana: budget.kana_chars_limit,
        ..slice_quota_for(preset)
    })
}

fn can_learn_more(
    snapshot: &DaySnapshot,
    tasks: &[TaskView],
    today_is_study: bool,
    state: &CursorState,
    plan: &PlanVersionRow,
    content: &ContentStore,
) -> bool {
    let all_done = tasks
        .iter()
        .filter(|view| view.task.blocks_learn_more())
        .all(|view| view.done);
    if !today_is_study || !all_done || snapshot.budget.new_content != NewContentMode::Full {
        return false;
    }
    learn_more_quota(&snapshot.budget, plan, content)
        .is_ok_and(|quota| next_slice(state, &quota, content).is_some())
}

pub fn today_view<R: Repository + ?Sized>(
    repo: &R,
    content: &ContentStore,
    ctx: &DayContext,
    audio_available: bool,
) -> Result<TodayView, PlanError> {
    let snapshot = ensure_snapshot(repo, content, ctx, audio_available)?;
    view_of(repo, content, ctx, audio_available, &snapshot)
}

/// `session_next` 用：快照的 `review_cap`、`new_words_limit` 與收尾上限，必要時先建快照。
pub fn session_limits<R: Repository + ?Sized>(
    repo: &R,
    content: &ContentStore,
    ctx: &DayContext,
    audio_available: bool,
) -> Result<QueueLimits, PlanError> {
    let budget = ensure_snapshot(repo, content, ctx, audio_available)?.budget;
    Ok(queue_limits(&budget))
}

/// 再學一批：今日任務都完成後，把下一個切片附加到快照。
pub fn learn_more<R: Repository + ?Sized>(
    repo: &R,
    content: &ContentStore,
    ctx: &DayContext,
    audio_available: bool,
) -> Result<TodayView, PlanError> {
    let today = ctx.today();
    let snapshot = ensure_snapshot(repo, content, ctx, audio_available)?;
    let view = view_of(repo, content, ctx, audio_available, &snapshot)?;
    if !view.can_learn_more {
        return Err(PlanError::invalid("learn_more", "目前不能再學一批"));
    }
    let plan = active_plan(repo, today)?;
    let state = current_state(repo, &plan, content)?;
    let quota = learn_more_quota(&snapshot.budget, &plan, content)?;
    let slice = next_slice(&state, &quota, content)
        .ok_or_else(|| PlanError::invalid("learn_more", "沒有下一個切片"))?;
    let split = snapshot.budget.split;
    let integration_minutes = split.new + split.drill + split.listen;
    let task = task_for_slice(slice, split.new, integration_minutes);
    let extended = DaySnapshot {
        budget: snapshot.budget.clone(),
        tasks: snapshot.tasks.iter().cloned().chain([task]).collect(),
    };
    store_snapshot(repo, ctx, plan.id, &extended)?;
    view_of(repo, content, ctx, audio_available, &extended)
}

/// `checkpoint_dismiss`：寫 `milestone_dismissed`，並從今日快照移除該任務。
pub fn dismiss_checkpoint<R: Repository + ?Sized>(
    repo: &R,
    content: &ContentStore,
    ctx: &DayContext,
    milestone_id: &str,
    audio_available: bool,
) -> Result<TodayView, PlanError> {
    if !content.milestones().iter().any(|m| m.id == milestone_id) {
        return Err(PlanError::not_found("milestone", milestone_id));
    }
    let today = ctx.today();
    repo.dismiss_milestone(milestone_id, today, ctx.now)?;
    let snapshot = ensure_snapshot(repo, content, ctx, audio_available)?;
    let key = checkpoint_key(milestone_id);
    let tasks: Vec<DailyTask> = snapshot
        .tasks
        .iter()
        .filter(|task| task.key() != key)
        .cloned()
        .collect();
    let updated = DaySnapshot {
        budget: snapshot.budget.clone(),
        tasks,
    };
    store_snapshot(repo, ctx, active_plan(repo, today)?.id, &updated)?;
    view_of(repo, content, ctx, audio_available, &updated)
}

/// 今天的 `NewContent`／`Integration` 是否都已完成，決定 `forecast` 的起算日。
pub fn today_slice_done<R: Repository + ?Sized>(
    repo: &R,
    today: NaiveDate,
) -> Result<bool, PlanError> {
    let Some(row) = repo.snapshot(today)? else {
        return Ok(false);
    };
    let Ok(snapshot) = DaySnapshot::from_json(&row.payload_json) else {
        return Ok(false);
    };
    let done_keys = repo.task_done(today)?;
    let mut slices = snapshot
        .tasks
        .iter()
        .filter(|task| task.is_main_slice())
        .peekable();
    Ok(slices.peek().is_some() && slices.all(|task| done_keys.contains(task.key())))
}

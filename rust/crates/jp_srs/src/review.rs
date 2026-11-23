//! 作答流程（§6.2、§9.6）。對錯由 jp_quiz 判定，這裡接手評分之後的步驟。

use jp_content::ContentStore;
use jp_lang::clock::DayContext;
use jp_store::{
    ActivityDelta, CardReviewUpdate, CardRow, ReviewLogEntry, ReviewWrite, SrsRepo, StoreError,
};

use crate::card_id::CardId;
use crate::error::SrsError;
use crate::facets::unlocks;
use crate::scheduler::{CardState, Outcome, Rating, SrsScheduler, SrsState};

const FIRST_TRY_ATTEMPTS: u32 = 1;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Grade {
    SelfRated(Rating),
    Auto {
        is_correct: bool,
        hint_used: bool,
        attempts: u32,
    },
}

impl Grade {
    /// §6.2。自動判定不給 Easy：選擇題答對不代表記憶很穩。
    pub fn rating(self) -> Rating {
        match self {
            Self::SelfRated(rating) => rating,
            Self::Auto {
                is_correct: false, ..
            } => Rating::Again,
            Self::Auto {
                hint_used,
                attempts,
                ..
            } => {
                if hint_used || attempts > FIRST_TRY_ATTEMPTS {
                    Rating::Hard
                } else {
                    Rating::Good
                }
            }
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ReviewRequest<'a> {
    pub card_id: &'a str,
    pub expected_reps: i32,
    pub grade: Grade,
    /// `review_log.question_type`，snake_case（§8.6）。
    pub question_type: &'a str,
    pub duration_ms: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ReviewResult {
    pub outcome: Outcome,
    pub unlocked_cards: u32,
}

fn load_card<R>(repo: &R, id: &CardId, expected_reps: i32) -> Result<CardRow, SrsError>
where
    R: SrsRepo + ?Sized,
{
    let card_id = id.to_string();
    let row = repo.card(&card_id)?.ok_or_else(|| SrsError::NotFound {
        entity: "card".to_string(),
        id: card_id.clone(),
    })?;
    if row.reps != expected_reps {
        return Err(StoreError::StaleCard { card_id }.into());
    }
    Ok(row)
}

/// `reviews_done` 只算複習卡，`review_cap` 以它為準（§6.4）。
fn activity_for(state_before: SrsState, duration_ms: u32) -> ActivityDelta {
    let base = ActivityDelta {
        study_ms: i64::from(duration_ms),
        ..ActivityDelta::default()
    };
    match state_before {
        SrsState::New => ActivityDelta {
            new_done: 1,
            ..base
        },
        SrsState::Review => ActivityDelta {
            reviews_done: 1,
            ..base
        },
        SrsState::Learning | SrsState::Relearning => ActivityDelta {
            relearn_done: 1,
            ..base
        },
    }
}

fn review_write(request: &ReviewRequest<'_>, outcome: &Outcome, ctx: &DayContext) -> ReviewWrite {
    let after = &outcome.card;
    ReviewWrite {
        card_id: request.card_id.to_string(),
        expected_reps: request.expected_reps,
        card: CardReviewUpdate {
            state: after.state.as_u8(),
            due_at: after.due,
            last_review_at: after.last_review,
            stability: after.stability,
            difficulty: after.difficulty,
            elapsed_days: after.elapsed_days,
            scheduled_days: after.scheduled_days,
            reps: after.reps,
            lapses: after.lapses,
        },
        log: ReviewLogEntry {
            rating: outcome.rating.as_u8(),
            state_before: outcome.state_before.as_u8(),
            state_after: after.state.as_u8(),
            elapsed_days: outcome.elapsed_days,
            scheduled_days: outcome.scheduled_days_before,
            stability_after: after.stability,
            difficulty_after: after.difficulty,
            // 歷史紀錄留裝置當下的時刻與邏輯日，時鐘倒退由 clock_skewed 標示
            reviewed_at: ctx.now,
            logical_date: ctx.today(),
            utc_offset_minutes: ctx.utc_offset_minutes,
            duration_ms: request.duration_ms,
            question_type: request.question_type.to_string(),
            clock_skewed: outcome.clock_skewed,
        },
        activity: activity_for(outcome.state_before, request.duration_ms),
    }
}

/// §9.6 的第 1、3–6 步。第 2 步（判定對錯）在呼叫端，結果放在 `request.grade`。
pub fn submit_review<R>(
    repo: &R,
    content: &ContentStore,
    scheduler: &dyn SrsScheduler,
    ctx: &DayContext,
    request: &ReviewRequest<'_>,
) -> Result<ReviewResult, SrsError>
where
    R: SrsRepo + ?Sized,
{
    let id = CardId::parse(request.card_id)?;
    let row = load_card(repo, &id, request.expected_reps)?;
    let card = CardState::from_row(&row)?;
    let outcome = scheduler.review(&card, request.grade.rating(), ctx)?;
    repo.apply_review(&review_write(request, &outcome, ctx))?;
    let unlocked = unlocks(&id, outcome.card.scheduled_days, content, ctx.now);
    let unlocked_cards = repo.insert_cards(&unlocked)?;
    Ok(ReviewResult {
        outcome,
        unlocked_cards,
    })
}

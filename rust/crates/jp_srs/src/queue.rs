//! 複習佇列（§6.4）。第一個命中的步驟就回傳；每一步都套用 `audio_available`。

use chrono::{DateTime, Duration, Utc};
use jp_lang::clock::DayContext;
use jp_store::{ActivityRepo, CardRow, QueueFilter, SrsRepo};

use crate::error::SrsError;
use crate::facets::{PRIORITY_MAIN, PRIORITY_SECONDARY};

pub const EARLY_LEARNING_MINUTES: i64 = 20;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct QueueLimits {
    pub review_cap: u32,
    pub new_words_per_day: u32,
    /// 第 3、4 步合計，今天第一次接觸的收尾新卡上限（§7.2 `tail_card_limit`）。
    pub tail_new_cards_per_day: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QueueStep {
    Learning,
    DueReview,
    NewPriority0,
    NewPriority1,
    EarlyLearning,
}

#[derive(Debug, Clone, PartialEq)]
pub enum NextCard {
    Card { card: CardRow, step: QueueStep },
    Done { next_due_at: Option<DateTime<Utc>> },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct QueueSummary {
    pub due_reviews: u32,
    /// `now + 20 分鐘` 內到期的學習中卡片。
    pub learning: u32,
    /// 此刻第 3、4 步可取的 state=0 卡（§7.4）。
    pub new_cards: u32,
    pub reviews_done_today: u32,
    pub review_cap: u32,
}

impl QueueSummary {
    /// 給 `SessionCardDto.remaining_estimate`。複習只算上限內還能做的張數。
    pub fn remaining_estimate(&self) -> u32 {
        let reviews_left = self.review_cap.saturating_sub(self.reviews_done_today);
        self.due_reviews.min(reviews_left) + self.learning + self.new_cards
    }
}

fn early_limit(ctx: &DayContext) -> DateTime<Utc> {
    ctx.now + Duration::minutes(EARLY_LEARNING_MINUTES)
}

fn reviews_done_today<R>(repo: &R, ctx: &DayContext) -> Result<u32, SrsError>
where
    R: ActivityRepo + ?Sized,
{
    let today = ctx.today();
    let rows = repo.activity_range(today, today)?;
    Ok(rows.first().map_or(0, |row| row.reviews_done))
}

/// 今天還能接觸的收尾新卡數。
fn tail_left<R>(repo: &R, ctx: &DayContext, limits: QueueLimits) -> Result<u32, SrsError>
where
    R: SrsRepo + ?Sized,
{
    let done = repo.count_tail_new_done(ctx)?;
    Ok(limits.tail_new_cards_per_day.saturating_sub(done))
}

fn next_new_card<R>(
    repo: &R,
    ctx: &DayContext,
    limits: QueueLimits,
    queue: QueueFilter,
) -> Result<Option<NextCard>, SrsError>
where
    R: SrsRepo + ?Sized,
{
    if tail_left(repo, ctx, limits)? == 0 {
        return Ok(None);
    }
    if let Some(card) = repo.next_new(PRIORITY_MAIN, ctx, queue)? {
        let step = QueueStep::NewPriority0;
        return Ok(Some(NextCard::Card { card, step }));
    }
    if repo.count_new_done(PRIORITY_SECONDARY, ctx.today())? < limits.new_words_per_day {
        if let Some(card) = repo.next_new(PRIORITY_SECONDARY, ctx, queue)? {
            let step = QueueStep::NewPriority1;
            return Ok(Some(NextCard::Card { card, step }));
        }
    }
    Ok(None)
}

/// §6.4 的六個步驟依序判定。
pub fn next_card<R>(
    repo: &R,
    ctx: &DayContext,
    limits: QueueLimits,
    queue: QueueFilter,
) -> Result<NextCard, SrsError>
where
    R: SrsRepo + ActivityRepo + ?Sized,
{
    if let Some(card) = repo.next_learning(ctx.now, queue)? {
        let step = QueueStep::Learning;
        return Ok(NextCard::Card { card, step });
    }
    if reviews_done_today(repo, ctx)? < limits.review_cap {
        if let Some(card) = repo.next_due_review(ctx, queue)? {
            let step = QueueStep::DueReview;
            return Ok(NextCard::Card { card, step });
        }
    }
    if let Some(found) = next_new_card(repo, ctx, limits, queue)? {
        return Ok(found);
    }
    if let Some(card) = repo.next_learning(early_limit(ctx), queue)? {
        let step = QueueStep::EarlyLearning;
        return Ok(NextCard::Card { card, step });
    }
    let next_due_at = repo.earliest_learning_due(queue)?;
    Ok(NextCard::Done { next_due_at })
}

/// §7.4：第 3 步全部計入，第 4 步不超過當日剩餘額度；兩步合計不超過今天剩下的收尾上限。
pub fn available_new_cards<R>(
    repo: &R,
    ctx: &DayContext,
    limits: QueueLimits,
    queue: QueueFilter,
) -> Result<u32, SrsError>
where
    R: SrsRepo + ?Sized,
{
    let main = repo.count_new(PRIORITY_MAIN, ctx, queue)?;
    let secondary = repo.count_new(PRIORITY_SECONDARY, ctx, queue)?;
    let done = repo.count_new_done(PRIORITY_SECONDARY, ctx.today())?;
    let available = main + secondary.min(limits.new_words_per_day.saturating_sub(done));
    Ok(available.min(tail_left(repo, ctx, limits)?))
}

pub fn queue_summary<R>(
    repo: &R,
    ctx: &DayContext,
    limits: QueueLimits,
    queue: QueueFilter,
) -> Result<QueueSummary, SrsError>
where
    R: SrsRepo + ActivityRepo + ?Sized,
{
    Ok(QueueSummary {
        due_reviews: repo.count_due_reviews(ctx, queue)?,
        learning: repo.count_learning(early_limit(ctx), None, queue)?,
        new_cards: available_new_cards(repo, ctx, limits, queue)?,
        reviews_done_today: reviews_done_today(repo, ctx)?,
        review_cap: limits.review_cap,
    })
}

//! rs-fsrs 的薄包裝（§6.3）。外部只看到本檔的型別，日後換演算法只改這裡（§0.3）。

use std::sync::atomic::{AtomicU64, Ordering};

use chrono::{DateTime, Duration, Utc};
use jp_lang::clock::DayContext;
use jp_store::{CardRow, STATE_LEARNING, STATE_NEW, STATE_RELEARNING, STATE_REVIEW};
use rs_fsrs::{
    Card, Parameters, Rating as FsrsRating, SchedulingInfo, Seed, State as FsrsState, FSRS,
};

use crate::error::SrsError;

pub const MIN_REQUEST_RETENTION: f64 = 0.80;
pub const MAX_REQUEST_RETENTION: f64 = 0.95;
pub const DEFAULT_REQUEST_RETENTION: f64 = 0.9;
pub const MAXIMUM_INTERVAL_DAYS: i32 = 3650;

/// rs-fsrs 每次排程都會以 now、reps、D×S 改寫種子，這個值不會被用到。
/// 只是不能留 `Seed::Empty`／`Seed::Default`：兩者的 `inner_str` 會無窮遞迴（§0.3）。
const PLACEHOLDER_SEED: &str = "jp_srs";

const MIN_STABILITY_EXCLUSIVE: f64 = 0.0;
const MIN_DIFFICULTY: f64 = 1.0;
const MAX_DIFFICULTY: f64 = 10.0;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Rating {
    Again,
    Hard,
    Good,
    Easy,
}

impl Rating {
    pub const ALL: [Self; 4] = [Self::Again, Self::Hard, Self::Good, Self::Easy];

    /// `review_log.rating` 的值。
    pub const fn as_u8(self) -> u8 {
        match self {
            Self::Again => 1,
            Self::Hard => 2,
            Self::Good => 3,
            Self::Easy => 4,
        }
    }

    const fn to_fsrs(self) -> FsrsRating {
        match self {
            Self::Again => FsrsRating::Again,
            Self::Hard => FsrsRating::Hard,
            Self::Good => FsrsRating::Good,
            Self::Easy => FsrsRating::Easy,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum SrsState {
    New,
    Learning,
    Review,
    Relearning,
}

impl SrsState {
    /// `srs_card.state` 的值。
    pub const fn as_u8(self) -> u8 {
        match self {
            Self::New => STATE_NEW,
            Self::Learning => STATE_LEARNING,
            Self::Review => STATE_REVIEW,
            Self::Relearning => STATE_RELEARNING,
        }
    }

    pub fn from_u8(value: u8) -> Option<Self> {
        match value {
            STATE_NEW => Some(Self::New),
            STATE_LEARNING => Some(Self::Learning),
            STATE_REVIEW => Some(Self::Review),
            STATE_RELEARNING => Some(Self::Relearning),
            _ => None,
        }
    }

    const fn to_fsrs(self) -> FsrsState {
        match self {
            Self::New => FsrsState::New,
            Self::Learning => FsrsState::Learning,
            Self::Review => FsrsState::Review,
            Self::Relearning => FsrsState::Relearning,
        }
    }

    const fn from_fsrs(state: FsrsState) -> Self {
        match state {
            FsrsState::New => Self::New,
            FsrsState::Learning => Self::Learning,
            FsrsState::Review => Self::Review,
            FsrsState::Relearning => Self::Relearning,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct CardState {
    pub state: SrsState,
    pub due: DateTime<Utc>,
    pub last_review: DateTime<Utc>,
    pub stability: f64,
    pub difficulty: f64,
    pub elapsed_days: i64,
    pub scheduled_days: i64,
    pub reps: i32,
    pub lapses: i32,
}

impl CardState {
    /// 取代 `Card::new()`：後者內部呼叫 `Utc::now()`（§0.3）。
    pub fn new_at(now: DateTime<Utc>) -> Self {
        Self {
            state: SrsState::New,
            due: now,
            last_review: now,
            stability: 0.0,
            difficulty: 0.0,
            elapsed_days: 0,
            scheduled_days: 0,
            reps: 0,
            lapses: 0,
        }
    }

    pub fn from_row(row: &CardRow) -> Result<Self, SrsError> {
        let state = SrsState::from_u8(row.state).ok_or_else(|| SrsError::Internal {
            message: format!("card {} has invalid state {}", row.card_id, row.state),
        })?;
        Ok(Self {
            state,
            due: row.due_at,
            last_review: row.last_review_at,
            stability: row.stability,
            difficulty: row.difficulty,
            elapsed_days: row.elapsed_days,
            scheduled_days: row.scheduled_days,
            reps: row.reps,
            lapses: row.lapses,
        })
    }

    fn to_fsrs(&self, last_review: DateTime<Utc>) -> Card {
        Card {
            due: self.due,
            stability: self.stability,
            difficulty: self.difficulty,
            elapsed_days: self.elapsed_days,
            scheduled_days: self.scheduled_days,
            reps: self.reps,
            lapses: self.lapses,
            state: self.state.to_fsrs(),
            last_review,
        }
    }

    fn from_fsrs(card: &Card) -> Self {
        Self {
            state: SrsState::from_fsrs(card.state),
            due: card.due,
            last_review: card.last_review,
            stability: card.stability,
            difficulty: card.difficulty,
            elapsed_days: card.elapsed_days,
            scheduled_days: card.scheduled_days,
            reps: card.reps,
            lapses: card.lapses,
        }
    }
}

/// 一次作答的結果。`card` 寫回 `srs_card`，其餘欄位寫入 `review_log`。
#[derive(Debug, Clone, PartialEq)]
pub struct Outcome {
    pub rating: Rating,
    pub card: CardState,
    pub state_before: SrsState,
    pub elapsed_days: i64,
    /// 作答前的 `scheduled_days`，與 `card.scheduled_days` 不同。
    pub scheduled_days_before: i64,
    /// 夾住時鐘倒退之後的 `now`，用來計算間隔。
    pub reviewed_at: DateTime<Utc>,
    pub clock_skewed: bool,
}

impl Outcome {
    pub fn interval_minutes(&self) -> i64 {
        (self.card.due - self.reviewed_at).num_minutes()
    }

    fn from_scheduling(
        rating: Rating,
        info: &SchedulingInfo,
        reviewed_at: DateTime<Utc>,
        clock_skewed: bool,
    ) -> Self {
        Self {
            rating,
            card: CardState::from_fsrs(&info.card),
            state_before: SrsState::from_fsrs(info.review_log.state),
            elapsed_days: info.review_log.elapsed_days,
            scheduled_days_before: info.review_log.scheduled_days,
            reviewed_at,
            clock_skewed,
        }
    }
}

pub trait SrsScheduler: Send + Sync {
    /// 依 `Rating::ALL` 的順序。
    fn preview(&self, card: &CardState, ctx: &DayContext) -> Result<[Outcome; 4], SrsError>;
    fn review(
        &self,
        card: &CardState,
        rating: Rating,
        ctx: &DayContext,
    ) -> Result<Outcome, SrsError>;
}

/// 記憶保留率由設定決定，可在執行中更新，所以用 atomic，比照 `SystemClock` 的時差。
#[derive(Debug)]
pub struct FsrsScheduler {
    retention_bits: AtomicU64,
    enable_fuzz: bool,
}

impl FsrsScheduler {
    pub fn new(retention: f64) -> Result<Self, SrsError> {
        validate_retention(retention)?;
        Ok(Self {
            retention_bits: AtomicU64::new(retention.to_bits()),
            enable_fuzz: true,
        })
    }

    pub fn set_request_retention(&self, retention: f64) -> Result<(), SrsError> {
        validate_retention(retention)?;
        self.retention_bits
            .store(retention.to_bits(), Ordering::Relaxed);
        Ok(())
    }

    pub fn request_retention(&self) -> f64 {
        f64::from_bits(self.retention_bits.load(Ordering::Relaxed))
    }

    fn parameters(&self) -> Parameters {
        Parameters {
            request_retention: self.request_retention(),
            maximum_interval: MAXIMUM_INTERVAL_DAYS,
            enable_short_term: true,
            enable_fuzz: self.enable_fuzz,
            seed: Seed::new(PLACEHOLDER_SEED),
            ..Parameters::default()
        }
    }
}

impl SrsScheduler for FsrsScheduler {
    fn preview(&self, card: &CardState, ctx: &DayContext) -> Result<[Outcome; 4], SrsError> {
        let [again, hard, good, easy] = Rating::ALL.map(|rating| self.review(card, rating, ctx));
        Ok([again?, hard?, good?, easy?])
    }

    fn review(
        &self,
        card: &CardState,
        rating: Rating,
        ctx: &DayContext,
    ) -> Result<Outcome, SrsError> {
        let (fsrs_card, now, skewed) = prepare(card, ctx);
        let info = FSRS::new(self.parameters()).next(fsrs_card, now, rating.to_fsrs());
        guard(&info.card)?;
        Ok(Outcome::from_scheduling(rating, &info, now, skewed))
    }
}

fn validate_retention(retention: f64) -> Result<(), SrsError> {
    if (MIN_REQUEST_RETENTION..=MAX_REQUEST_RETENTION).contains(&retention) {
        Ok(())
    } else {
        Err(SrsError::InvalidInput {
            field: "desired_retention".to_string(),
            reason: format!("out of range: {retention}"),
        })
    }
}

/// F1：把 `last_review` 校正成讓 rs-fsrs 看到邏輯日差；F2：時鐘倒退時夾住 `now`。
fn prepare(card: &CardState, ctx: &DayContext) -> (Card, DateTime<Utc>, bool) {
    let skewed = ctx.now < card.last_review;
    let now = ctx.now.max(card.last_review);
    let last_review = if card.state == SrsState::New {
        card.last_review
    } else {
        let logical_gap = ctx.logical_date_of(now) - ctx.logical_date_of(card.last_review);
        now - Duration::days(logical_gap.num_days().max(0))
    };
    (card.to_fsrs(last_review), now, skewed)
}

/// F3：SQLite 的 CHECK 擋不住 Infinity。
fn guard(card: &Card) -> Result<(), SrsError> {
    let is_valid = card.stability.is_finite()
        && card.stability > MIN_STABILITY_EXCLUSIVE
        && card.difficulty.is_finite()
        && (MIN_DIFFICULTY..=MAX_DIFFICULTY).contains(&card.difficulty);
    if is_valid {
        Ok(())
    } else {
        Err(SrsError::Internal {
            message: "invalid FSRS output".to_string(),
        })
    }
}

#[cfg(test)]
mod tests;

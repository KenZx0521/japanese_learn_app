//! `CoreError`（rust-core.md §9.2）與各層錯誤的轉換。Dart 依變體顯示繁中文案。

use jp_content::ContentError;
use jp_lang::clock::ClockError;
use jp_plan::PlanError;
use jp_quiz::QuizError;
use jp_srs::SrsError;
use jp_store::StoreError;

const PLAN_ENTITY: &str = "plan";
const UTC_OFFSET_FIELD: &str = "utc_offset_minutes";
const ROLLOVER_FIELD: &str = "day_rollover_hour";

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("not found: {entity} {id}")]
    NotFound { entity: String, id: String },
    #[error("invalid input: {field}")]
    InvalidInput { field: String, reason: String },
    #[error("stale card: {card_id}")]
    StaleCard { card_id: String },
    #[error("no active plan")]
    NoActivePlan,
    #[error("content corrupt: {file}")]
    ContentCorrupt { file: String, detail: String },
    #[error("migration failed")]
    MigrationFailed { from_version: i32, message: String },
    #[error("storage: {message}")]
    Storage { message: String },
    #[error("internal: {message}")]
    Internal { message: String },
}

impl CoreError {
    pub(crate) fn not_found(entity: &str, id: &str) -> Self {
        Self::NotFound {
            entity: entity.to_owned(),
            id: id.to_owned(),
        }
    }

    pub(crate) fn invalid(field: &str, reason: impl Into<String>) -> Self {
        Self::InvalidInput {
            field: field.to_owned(),
            reason: reason.into(),
        }
    }
}

impl From<StoreError> for CoreError {
    fn from(err: StoreError) -> Self {
        match err {
            StoreError::StaleCard { card_id } => Self::StaleCard { card_id },
            StoreError::MigrationFailed {
                from_version,
                message,
            } => Self::MigrationFailed {
                from_version,
                message,
            },
            StoreError::Storage { message } => Self::Storage { message },
            StoreError::Internal { message } => Self::Internal { message },
        }
    }
}

impl From<SrsError> for CoreError {
    fn from(err: SrsError) -> Self {
        match err {
            SrsError::NotFound { entity, id } => Self::NotFound { entity, id },
            SrsError::InvalidInput { field, reason } => Self::InvalidInput { field, reason },
            SrsError::Internal { message } => Self::Internal { message },
            SrsError::Store(inner) => inner.into(),
        }
    }
}

impl From<PlanError> for CoreError {
    fn from(err: PlanError) -> Self {
        match err {
            // 沒有生效的計畫由 jp_plan 回報成 NotFound，Dart 要的是專用變體（§9.2）
            PlanError::NotFound { entity, .. } if entity == PLAN_ENTITY => Self::NoActivePlan,
            PlanError::NotFound { entity, id } => Self::NotFound { entity, id },
            PlanError::InvalidInput { field, reason } => Self::InvalidInput { field, reason },
            PlanError::Internal { message } => Self::Internal { message },
            PlanError::Srs(inner) => inner.into(),
            PlanError::Store(inner) => inner.into(),
        }
    }
}

impl From<QuizError> for CoreError {
    fn from(err: QuizError) -> Self {
        match err {
            QuizError::NotFound { entity, id } => Self::NotFound { entity, id },
            QuizError::InvalidInput { field, reason } => Self::InvalidInput { field, reason },
            QuizError::Internal { message } => Self::Internal { message },
            QuizError::Store(inner) => inner.into(),
            QuizError::Srs(inner) => inner.into(),
        }
    }
}

impl From<ContentError> for CoreError {
    fn from(err: ContentError) -> Self {
        let ContentError::Corrupt { file, detail } = err;
        Self::ContentCorrupt { file, detail }
    }
}

impl From<ClockError> for CoreError {
    fn from(err: ClockError) -> Self {
        let field = match err {
            ClockError::OffsetOutOfRange { .. } => UTC_OFFSET_FIELD,
            ClockError::RolloverOutOfRange { .. } => ROLLOVER_FIELD,
        };
        Self::invalid(field, err.to_string())
    }
}

//! 領域錯誤。根 crate 的 `CoreError` 由此 `From` 轉換。

use jp_srs::SrsError;
use jp_store::StoreError;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum PlanError {
    #[error("not found: {entity} {id}")]
    NotFound { entity: String, id: String },
    #[error("invalid input: {field}: {reason}")]
    InvalidInput { field: String, reason: String },
    #[error("internal: {message}")]
    Internal { message: String },
    #[error(transparent)]
    Srs(#[from] SrsError),
    #[error(transparent)]
    Store(#[from] StoreError),
}

impl PlanError {
    pub(crate) fn not_found(entity: impl Into<String>, id: impl Into<String>) -> Self {
        Self::NotFound {
            entity: entity.into(),
            id: id.into(),
        }
    }

    pub(crate) fn invalid(field: impl Into<String>, reason: impl Into<String>) -> Self {
        Self::InvalidInput {
            field: field.into(),
            reason: reason.into(),
        }
    }

    pub(crate) fn internal(message: impl Into<String>) -> Self {
        Self::Internal {
            message: message.into(),
        }
    }
}

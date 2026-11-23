//! 領域錯誤。根 crate 的 `CoreError` 由此 `From` 轉換。

use jp_srs::SrsError;
use jp_store::StoreError;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum QuizError {
    #[error("not found: {entity} {id}")]
    NotFound { entity: String, id: String },
    #[error("invalid input: {field}: {reason}")]
    InvalidInput { field: String, reason: String },
    #[error("internal: {message}")]
    Internal { message: String },
    #[error(transparent)]
    Store(#[from] StoreError),
    #[error(transparent)]
    Srs(#[from] SrsError),
}

impl QuizError {
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

    /// 內容已在載入時驗證，走到這裡代表內容與程式不一致。
    pub(crate) fn content(id: &str, detail: impl std::fmt::Display) -> Self {
        Self::Internal {
            message: format!("{id}: {detail}"),
        }
    }
}

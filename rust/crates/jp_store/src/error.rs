//! 儲存層錯誤。根 crate 的 `CoreError` 由此 `From` 轉換，變體與 §9.2 同名。

use thiserror::Error;

#[derive(Debug, Error)]
pub enum StoreError {
    #[error("stale card: {card_id}")]
    StaleCard { card_id: String },
    #[error("migration failed from version {from_version}: {message}")]
    MigrationFailed { from_version: i32, message: String },
    #[error("storage: {message}")]
    Storage { message: String },
    #[error("internal: {message}")]
    Internal { message: String },
}

impl StoreError {
    pub(crate) fn storage(message: impl Into<String>) -> Self {
        Self::Storage {
            message: message.into(),
        }
    }
}

impl From<rusqlite::Error> for StoreError {
    fn from(err: rusqlite::Error) -> Self {
        Self::storage(err.to_string())
    }
}

/// F3：SQLite 的 CHECK 擋不住 Infinity，寫入前必須檢查。
pub(crate) fn ensure_finite(field: &str, value: f64) -> Result<(), StoreError> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(StoreError::Internal {
            message: format!("{field} is not finite: {value}"),
        })
    }
}

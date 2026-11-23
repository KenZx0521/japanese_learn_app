//! 領域錯誤。根 crate 的 `CoreError` 由此 `From` 轉換；`Store` 內再分 `StaleCard` 等變體。

use jp_store::StoreError;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum SrsError {
    #[error("not found: {entity} {id}")]
    NotFound { entity: String, id: String },
    #[error("invalid input: {field}: {reason}")]
    InvalidInput { field: String, reason: String },
    #[error("internal: {message}")]
    Internal { message: String },
    #[error(transparent)]
    Store(#[from] StoreError),
}

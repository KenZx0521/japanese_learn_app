//! 內容載入錯誤。`CoreError::ContentCorrupt` 由 root crate 轉換。

use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum ContentError {
    #[error("content corrupt: {file}: {detail}")]
    Corrupt { file: String, detail: String },
}

impl ContentError {
    pub(crate) fn corrupt(file: impl Into<String>, detail: impl Into<String>) -> Self {
        Self::Corrupt {
            file: file.into(),
            detail: detail.into(),
        }
    }
}

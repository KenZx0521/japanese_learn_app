//! API 與領域 crate 之間的組裝層（`Deps`、領域型別→DTO），見 rust-core.md §1.3。

pub(crate) mod course;
pub(crate) mod deps;
pub(crate) mod dialogue;
pub(crate) mod drill;
pub(crate) mod grammar;
pub(crate) mod kana;
pub(crate) mod mapping;
pub(crate) mod new_content;
pub(crate) mod peek;
pub(crate) mod plan;
pub(crate) mod session;
pub(crate) mod settings;
pub(crate) mod stats;
pub(crate) mod today;
pub(crate) mod views;
pub(crate) mod vocab;
mod vocab_search;

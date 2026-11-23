//! 學習計畫引擎（rust-core.md §7）：每日預算、新內容切分、今日任務、里程碑預測、連續天數。

pub mod budget;
pub mod calendar;
pub mod complete;
pub mod completion;
pub mod compose;
pub mod error;
pub mod forecast;
pub mod input;
pub mod milestone;
pub mod slice;
mod slice_kana;
pub mod state;
pub mod streak;
pub mod tasks;
pub mod today;

pub use budget::{DayBudget, NewContentMode, RecoveryReason, Split};
pub use error::PlanError;
pub use input::{PlanInput, StartLevel};
pub use slice::{next_slice, Slice, SliceQuota};
pub use state::CursorState;
pub use tasks::{DailyTask, DaySnapshot};

//! 測驗與演練產生器（rust-core.md §8）：干擾項、各題型、聽力 session、檢定。
//!
//! DTO 在根 crate，這裡只有領域型別；根 crate 的 `app/mapping.rs` 負責轉換。

pub mod card;
pub mod checkpoint;
pub mod context;
pub mod distractor;
pub mod drill;
pub mod error;
pub mod grade;
pub mod kana_quiz;
pub mod listen_quiz;
pub mod model;
pub mod question_type;
pub mod slice_drill;
mod view;
pub mod vocab_quiz;

pub use context::{QuestionKey, QuizContext};
pub use error::QuizError;
pub use model::{AnswerPayload, GradeResult, Question, QuestionBody, QuestionRef};
pub use question_type::QuestionType;

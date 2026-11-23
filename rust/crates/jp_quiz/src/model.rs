//! 題目與作答的領域型別，與 §9.5 的 DTO 一一對應（`is_known` 除外，由根 crate 補上）。

use jp_content::schema::Style;
use jp_content::sentence::{ParsedSentence, Speech};
use jp_srs::Rating;

use crate::question_type::QuestionType;

/// 對應 `SentenceDto`。內嵌 `t` 的 `id` 由題目 ID 組成，`zh` 可為空。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SentenceView {
    pub id: String,
    pub zh: String,
    pub style: Style,
    pub parsed: ParsedSentence,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct QuestionRef {
    pub question_type: QuestionType,
    pub card_id: Option<String>,
    pub drill_id: Option<String>,
    pub content_id: String,
    /// `rows`／`lemmas` 索引，`minimal_pair` 的 a／b（§8.4）。
    pub variant: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Prompt {
    pub instruction_zh: String,
    pub text: Option<SentenceView>,
    pub plain_text: Option<String>,
    pub speech: Option<Speech>,
    pub autoplay: bool,
    pub hide_text_until_answered: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct ChoiceOption {
    pub id: String,
    pub text: String,
    pub sentence: Option<SentenceView>,
    pub speech: Option<Speech>,
    pub why_zh: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReorderChunk {
    pub index: u32,
    pub text: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MatchPair {
    pub left_id: String,
    pub left: String,
    pub right_id: String,
    pub right: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum QuestionBody {
    Choice {
        options: Vec<ChoiceOption>,
        correct_option_id: String,
        blank_word_index: Option<u32>,
    },
    Reorder {
        chunks: Vec<ReorderChunk>,
        accept_orders: Vec<Vec<u32>>,
    },
    Typing {
        expected_reading: String,
        placeholder_zh: String,
    },
    Match {
        pairs: Vec<MatchPair>,
    },
    SelfGrade {
        reveal: Box<SentenceView>,
    },
    Shadow {
        reveal: Box<SentenceView>,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Question {
    pub question_type: QuestionType,
    pub reference: QuestionRef,
    pub prompt: Prompt,
    pub body: QuestionBody,
    pub explain_zh: Option<String>,
    pub focus_ids: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShadowLevel {
    Kept,
    Almost,
    Lost,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AnswerPayload {
    Choice { option_id: String },
    Reorder { order: Vec<u32> },
    Typing { input: String },
    Match { all_correct: bool },
    SelfGrade { rating: Rating },
    Shadow { level: ShadowLevel },
}

/// 對應 `AnswerDto`。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Answer {
    pub reference: QuestionRef,
    pub expected_reps: i32,
    pub response: AnswerPayload,
    pub hint_used: bool,
    pub attempts: u32,
    pub duration_ms: u32,
}

/// 判定結果，`AnswerResultDto`、`DrillResultDto`、`KanaSubmitResultDto` 的共同來源。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GradeResult {
    pub is_correct: bool,
    /// MixedText 字串（§9.5）。
    pub correct_display: String,
    pub explain_zh: Option<String>,
    pub why_zh: Option<String>,
    pub reveal: Option<SentenceView>,
}

impl Question {
    pub(crate) fn new(reference: QuestionRef, prompt: Prompt, body: QuestionBody) -> Self {
        Self {
            question_type: reference.question_type,
            reference,
            prompt,
            body,
            explain_zh: None,
            focus_ids: Vec::new(),
        }
    }

    pub(crate) fn with_focus(self, focus_ids: Vec<String>) -> Self {
        Self { focus_ids, ..self }
    }

    pub(crate) fn with_explain(self, explain_zh: Option<String>) -> Self {
        Self { explain_zh, ..self }
    }
}

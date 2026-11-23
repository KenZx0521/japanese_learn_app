//! 題目、作答與新內容 DTO（rust-core.md §9.5）。

use chrono::{DateTime, Utc};

use super::dto_content::{
    ConfusableDto, GrammarDetailDto, KanaDetailDto, RuleCardDto, SentenceDto, SpeechDto,
    VocabDetailDto,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Rating {
    Again,
    Hard,
    Good,
    Easy,
}

/// 跟上了／差一點／跟不上。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShadowLevel {
    Kept,
    Almost,
    Lost,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QuestionType {
    Recog,
    VocabListen,
    Produce,
    KanaRead,
    KanaListen,
    KanaMatch,
    KanaConfuse,
    MinimalPair,
    KanaWord,
    Substitution,
    Reorder,
    ParticleFill,
    ZhToJaChoice,
    ListenMeaning,
    SituationResponse,
    Conjugate,
    RegisterConvert,
    Shadowing,
    FalseFriend,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SessionSummaryDto {
    pub due_reviews: u32,
    pub learning: u32,
    pub new_cards: u32,
    pub reviews_done_today: u32,
    pub review_cap: u32,
}

// 只用來跨 FFI 傳遞，形狀以 §9.5 為準，不為了列舉大小加 Box
#[allow(clippy::large_enum_variant)]
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SessionNextDto {
    Card { card: SessionCardDto },
    Done { next_due_at: Option<DateTime<Utc>> },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SessionCardDto {
    pub card_id: String,
    pub expected_reps: i32,
    pub facet: String,
    pub question: QuestionDto,
    pub rating_previews: Vec<RatingPreviewDto>,
    pub remaining_estimate: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RatingPreviewDto {
    pub rating: Rating,
    pub interval_minutes: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QuestionDto {
    pub question_type: QuestionType,
    pub reference: QuestionRefDto,
    pub prompt: PromptDto,
    pub body: QuestionBodyDto,
    pub explain_zh: Option<String>,
    /// 答後顯示的語法重點，用 `peek` 取內容。
    pub focus_ids: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QuestionRefDto {
    /// 與 `QuestionDto` 相同，作答時帶回。
    pub question_type: QuestionType,
    pub card_id: Option<String>,
    pub drill_id: Option<String>,
    pub content_id: String,
    /// `rows`／`lemmas` 索引，`minimal_pair` 的 a／b（§8.4）。
    pub variant: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PromptDto {
    pub instruction_zh: String,
    pub text: Option<SentenceDto>,
    /// MixedText 字串（§9.5 末）。
    pub plain_text: Option<String>,
    pub speech: Option<SpeechDto>,
    pub autoplay: bool,
    pub hide_text_until_answered: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum QuestionBodyDto {
    Choice {
        options: Vec<OptionDto>,
        correct_option_id: String,
        blank_word_index: Option<u32>,
    },
    Reorder {
        chunks: Vec<ChunkDto>,
        accept_orders: Vec<Vec<u32>>,
    },
    Typing {
        expected_reading: String,
        placeholder_zh: String,
    },
    Match {
        pairs: Vec<MatchPairDto>,
    },
    /// 單字題由單字合成（§8.3），`use` 卡退回時為例句（§6.1）。
    SelfGrade {
        reveal: SentenceDto,
    },
    Shadow {
        reveal: SentenceDto,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OptionDto {
    pub id: String,
    pub text: String,
    pub sentence: Option<SentenceDto>,
    pub speech: Option<SpeechDto>,
    pub why_zh: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChunkDto {
    pub index: u32,
    pub text: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MatchPairDto {
    pub left_id: String,
    pub left: String,
    pub right_id: String,
    pub right: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AnswerDto {
    pub reference: QuestionRefDto,
    pub expected_reps: i32,
    pub response: AnswerPayload,
    pub hint_used: bool,
    pub attempts: u32,
    pub duration_ms: u32,
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AnswerResultDto {
    pub is_correct: bool,
    pub rating: Rating,
    pub next_due_in_minutes: i64,
    /// MixedText 字串（§9.5 末）。
    pub correct_display: String,
    pub reveal: Option<SentenceDto>,
    pub unlocked_cards: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DrillResultDto {
    pub is_correct: bool,
    pub correct_display: String,
    pub explain_zh: Option<String>,
    pub why_zh: Option<String>,
    pub reveal: Option<SentenceDto>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KanaMasteryDto {
    pub kana_id: String,
    pub run: u32,
    pub required: u32,
    pub mastered: bool,
    pub fast_badge: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KanaSubmitResultDto {
    pub is_correct: bool,
    pub correct_display: String,
    pub mastery: Option<KanaMasteryDto>,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct DrillFilterDto {
    pub task_key: Option<String>,
    pub lesson_id: Option<String>,
    pub target: Option<String>,
    pub drill_ids: Vec<String>,
    pub count: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CheckpointResultDto {
    pub milestone_id: String,
    pub correct: u32,
    pub total: u32,
    pub score_percent: u32,
    pub passed: bool,
    pub weak_ids: Vec<String>,
}

// ---------- 新內容 ----------

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewContentSessionDto {
    pub task_key: String,
    pub lesson_id: String,
    pub title_zh: String,
    pub steps: Vec<NewContentStepDto>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NewContentStepDto {
    Kana {
        detail: KanaDetailDto,
    },
    Rule {
        card: RuleCardDto,
    },
    Confusable {
        group: ConfusableDto,
    },
    KanaQuiz {
        questions: Vec<QuestionDto>,
    },
    Vocab {
        detail: VocabDetailDto,
        first_card: Option<SessionCardDto>,
    },
    Grammar {
        detail: GrammarDetailDto,
        first_card: Option<SessionCardDto>,
    },
}

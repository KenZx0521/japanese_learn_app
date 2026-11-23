//! 計畫、今日、統計、設定類 DTO（rust-core.md §9.5）。

use super::dto_study::QuestionType;

// ---------- 計畫與今日 ----------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StartLevel {
    Zero,
    Hiragana,
    Kana,
    Basic,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanInputDto {
    pub daily_minutes: u32,
    /// 1＝週一 … 7＝週日。
    pub weekdays: Vec<u32>,
    pub start_level: StartLevel,
    pub target_date: Option<String>,
    pub known_kana_lessons: Vec<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanViewDto {
    pub input: PlanInputDto,
    pub current_lesson_id: Option<String>,
    pub stage_id: Option<String>,
    /// 只含已發布內容，UI 依此動態繪製。
    pub milestones: Vec<MilestoneDto>,
    pub main_forecast_end: Option<String>,
    pub status: PlanStatus,
    pub suggested_minutes: Option<u32>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct MilestoneDto {
    pub id: String,
    pub title_zh: String,
    pub lesson_id: String,
    pub pass_ratio: f64,
    pub questions: u32,
    pub forecast_date: Option<String>,
    pub planned_date: Option<String>,
    pub delay_days: i32,
    pub best_score_percent: Option<u32>,
    pub passed: bool,
    pub dismissed: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlanStatus {
    NoTarget,
    OnTrack,
    Behind,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TodayViewDto {
    pub logical_date: String,
    pub is_study_day: bool,
    pub next_study_date: Option<String>,
    pub tasks: Vec<TaskDto>,
    pub budget: BudgetDto,
    pub streak: u32,
    pub recovery_reason: Option<RecoveryReason>,
    pub minimal_new: bool,
    pub learning_tail: u32,
    pub estimated_minutes: f64,
    pub can_learn_more: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RecoveryReason {
    ReviewBacklog,
    ReturnAfterBreak,
    UnseenNewCards,
}

#[derive(Debug, Clone, PartialEq)]
pub struct BudgetDto {
    pub new_minutes: f64,
    pub review_minutes: f64,
    pub drill_minutes: f64,
    pub listen_minutes: f64,
    pub review_cap: u32,
    /// 積壓判定用的複習容量（§7.2，階段配比、不扣收尾新卡）。
    pub capacity: u32,
    pub new_words_limit: u32,
    pub kana_chars_limit: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TaskDto {
    Review {
        key: String,
        due: u32,
        learning: u32,
        new_cards: u32,
        minutes: f64,
        done: bool,
    },
    NewContent {
        key: String,
        lesson_id: String,
        title_zh: String,
        words: u32,
        grammar: u32,
        kana: u32,
        rules: u32,
        minutes: f64,
        done: bool,
    },
    Integration {
        key: String,
        lesson_id: String,
        title_zh: String,
        dialogue_id: Option<String>,
        phases: Vec<u32>,
        minutes: f64,
        done: bool,
    },
    Drill {
        key: String,
        questions: u32,
        minutes: f64,
        done: bool,
    },
    Listen {
        key: String,
        sentences: u32,
        minutes: f64,
        done: bool,
    },
    Checkpoint {
        key: String,
        milestone_id: String,
        done: bool,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct StatsDto {
    pub streak_current: u32,
    pub streak_best: u32,
    pub total_reviews: u32,
    pub cards_new: u32,
    pub cards_learning: u32,
    pub cards_review: u32,
    pub cards_mastered: u32,
    pub kana_mastered: u32,
    pub vocab_introduced: u32,
    pub grammar_introduced: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DayActivityDto {
    pub date: String,
    pub answers: u32,
    pub lessons: u32,
    pub study_minutes: f64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CalendarDayDto {
    pub date: String,
    pub is_study_day: bool,
    pub is_active: bool,
    pub lesson_ids: Vec<String>,
    pub milestone_id: Option<String>,
}

// ---------- 設定與顯示 ----------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ThemeMode {
    System,
    Light,
    Dark,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RomajiMode {
    Shown,
    ShownToggleable,
    TapToReveal,
    LongPressOnly,
    Hidden,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FuriganaMode {
    All,
    UnknownOnly,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DisplayContext {
    pub lesson_id: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DisplayPolicyDto {
    pub romaji: RomajiMode,
    pub furigana: FuriganaMode,
    pub word_spacing: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SettingsDto {
    pub day_rollover_hour: u32,
    pub desired_retention: f64,
    pub romaji_override: Option<RomajiMode>,
    pub furigana_override: Option<FuriganaMode>,
    pub tts_rate: f64,
    pub autoplay: bool,
    pub voice_id: Option<String>,
    pub theme_mode: ThemeMode,
    /// 無聲模式；Dart 據此算 `audio_available`。
    pub silent_mode: bool,
    /// 無障礙：false 時假名不看 3 秒時限。
    pub kana_time_limit: bool,
    /// 評分鈕是否顯示間隔數字。
    pub show_rating_intervals: bool,
    /// 使用者確認 L09 起關閉羅馬字。
    pub romaji_off_confirmed: bool,
    /// 已看過操作提示的題型。
    pub seen_question_hints: Vec<QuestionType>,
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct SettingsPatchDto {
    pub day_rollover_hour: Option<u32>,
    pub desired_retention: Option<f64>,
    pub romaji_override: Option<RomajiMode>,
    pub clear_romaji_override: bool,
    pub furigana_override: Option<FuriganaMode>,
    pub clear_furigana_override: bool,
    pub tts_rate: Option<f64>,
    pub autoplay: Option<bool>,
    pub voice_id: Option<String>,
    pub clear_voice_id: bool,
    pub theme_mode: Option<ThemeMode>,
    pub silent_mode: Option<bool>,
    pub kana_time_limit: Option<bool>,
    pub show_rating_intervals: Option<bool>,
    pub romaji_off_confirmed: Option<bool>,
    pub seen_question_hints: Option<Vec<QuestionType>>,
}

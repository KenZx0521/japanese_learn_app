//! 列舉對應。DTO 與領域型別同形時用巨集，省去逐一 match 的抄寫錯誤。

use jp_content::schema::{
    ConfusableKind, ConjForm, ContentStage as ContentStageDef, DialogueKind, Jlpt, KanaKind, Pos,
    Register, Script, SoundGroupKind, Style, Transitivity, UseLevel,
};
use jp_lang::kana::ReadingMode as LangReadingMode;
use jp_plan::budget::RecoveryReason as PlanRecovery;
use jp_plan::forecast::PlanStatus as PlanPlanStatus;
use jp_plan::input::StartLevel as PlanStartLevel;
use jp_quiz::model::ShadowLevel as QuizShadow;
use jp_quiz::QuestionType as QuizQuestionType;
use jp_srs::Rating as SrsRating;

use crate::api::dto_content::{
    ConfusableKindDto, ContentStage, DialogueKindDto, JlptLevel, KanaKindDto, KanaScript,
    ReadingMode, SoundGroupKindDto, TransitivityDto, UseLevelDto,
};
use crate::api::dto_plan::{PlanStatus, RecoveryReason, StartLevel};
use crate::api::dto_study::{QuestionType, Rating, ShadowLevel};

macro_rules! enum_to_dto {
    ($name:ident, $domain:ident, $dto:ident, [$($variant:ident),+ $(,)?]) => {
        pub(crate) fn $name(value: $domain) -> $dto {
            match value { $($domain::$variant => $dto::$variant),+ }
        }
    };
}

macro_rules! enum_pair {
    ($to_dto:ident, $to_domain:ident, $domain:ident, $dto:ident, [$($variant:ident),+ $(,)?]) => {
        enum_to_dto!($to_dto, $domain, $dto, [$($variant),+]);

        pub(crate) fn $to_domain(value: $dto) -> $domain {
            match value { $($dto::$variant => $domain::$variant),+ }
        }
    };
}

enum_to_dto!(
    content_stage,
    ContentStageDef,
    ContentStage,
    [P0a, P0, Full]
);
enum_to_dto!(
    kana_kind,
    KanaKind,
    KanaKindDto,
    [Basic, Dakuten, Yoon, Extended, Mark]
);
enum_to_dto!(
    confusable_kind,
    ConfusableKind,
    ConfusableKindDto,
    [Shape, CrossScript, KanaKanji, Listen]
);
enum_to_dto!(
    sound_group_kind,
    SoundGroupKind,
    SoundGroupKindDto,
    [Voicing, Length, Sokuon, Yoon, Accent]
);
enum_to_dto!(
    dialogue_kind,
    DialogueKind,
    DialogueKindDto,
    [Lesson, Extra, Casual]
);
enum_to_dto!(jlpt_level, Jlpt, JlptLevel, [N5, N4, Beyond]);
enum_to_dto!(
    use_level,
    UseLevel,
    UseLevelDto,
    [Safe, FriendsOnly, RecognizeOnly]
);
enum_to_dto!(
    recovery_reason,
    PlanRecovery,
    RecoveryReason,
    [ReviewBacklog, ReturnAfterBreak, UnseenNewCards]
);
enum_to_dto!(
    plan_status,
    PlanPlanStatus,
    PlanStatus,
    [NoTarget, OnTrack, Behind]
);

enum_pair!(
    rating_dto,
    rating_domain,
    SrsRating,
    Rating,
    [Again, Hard, Good, Easy]
);
enum_pair!(
    start_level_dto,
    start_level_domain,
    PlanStartLevel,
    StartLevel,
    [Zero, Hiragana, Kana, Basic]
);
enum_pair!(
    question_type_dto,
    question_type_domain,
    QuizQuestionType,
    QuestionType,
    [
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
    ]
);

pub(crate) fn shadow_domain(value: ShadowLevel) -> QuizShadow {
    match value {
        ShadowLevel::Kept => QuizShadow::Kept,
        ShadowLevel::Almost => QuizShadow::Almost,
        ShadowLevel::Lost => QuizShadow::Lost,
    }
}

pub(crate) fn transitivity(value: Transitivity) -> TransitivityDto {
    match value {
        Transitivity::Tr => TransitivityDto::Transitive,
        Transitivity::In => TransitivityDto::Intransitive,
        Transitivity::Both => TransitivityDto::Both,
    }
}

pub(crate) fn script_of(value: KanaScript) -> Script {
    match value {
        KanaScript::Hiragana => Script::Hira,
        KanaScript::Katakana => Script::Kata,
    }
}

pub(crate) fn reading_mode(value: ReadingMode) -> LangReadingMode {
    match value {
        ReadingMode::Word => LangReadingMode::Word,
        ReadingMode::Sentence => LangReadingMode::Sentence,
    }
}

pub(crate) fn style_name(value: Style) -> &'static str {
    match value {
        Style::Polite => "polite",
        Style::Plain => "plain",
        Style::Mixed => "mixed",
        Style::Neutral => "neutral",
    }
}

pub(crate) fn register_name(value: Register) -> &'static str {
    match value {
        Register::Polite => "polite",
        Register::Plain => "plain",
        Register::Neutral => "neutral",
    }
}

pub(crate) fn jlpt_name(value: Jlpt) -> &'static str {
    match value {
        Jlpt::N5 => "n5",
        Jlpt::N4 => "n4",
        Jlpt::Beyond => "beyond",
    }
}

/// `VocabSummaryDto.pos` 與 `VocabFilterDto.pos`，同內容 JSON 的 snake_case。
pub(crate) fn pos_name(value: Pos) -> &'static str {
    match value {
        Pos::N => "n",
        Pos::Pron => "pron",
        Pos::Num => "num",
        Pos::Counter => "counter",
        Pos::V5 => "v5",
        Pos::V1 => "v1",
        Pos::V1S => "v1_s",
        Pos::Vs => "vs",
        Pos::Vk => "vk",
        Pos::AdjI => "adj_i",
        Pos::AdjNa => "adj_na",
        Pos::Adv => "adv",
        Pos::Conj => "conj",
        Pos::Interj => "interj",
        Pos::Phrase => "phrase",
    }
}

/// §4.7 全部形式；不可變化的詞性由 `conjugate_*` 回 `None`，單字的 `conj_omit` 另行略過。
pub(crate) const CONJUGATION_FORMS: [ConjForm; 10] = [
    ConjForm::Masu,
    ConjForm::Te,
    ConjForm::Ta,
    ConjForm::Nai,
    ConjForm::Potential,
    ConjForm::Volitional,
    ConjForm::Ba,
    ConjForm::Imperative,
    ConjForm::Passive,
    ConjForm::Causative,
];

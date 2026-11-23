//! 設定（§9.5）。列舉在資料庫存字串；認不得的值退回預設，升降版時設定頁不會整個打不開。

use jp_quiz::QuestionType as QuizQuestionType;
use jp_store::SettingsRow;

use super::enums::{question_type_domain, question_type_dto};
use crate::api::dto_plan::{FuriganaMode, RomajiMode, SettingsDto, ThemeMode};
use crate::api::dto_study::QuestionType;

pub(crate) fn romaji_name(mode: RomajiMode) -> &'static str {
    match mode {
        RomajiMode::Shown => "shown",
        RomajiMode::ShownToggleable => "shown_toggleable",
        RomajiMode::TapToReveal => "tap_to_reveal",
        RomajiMode::LongPressOnly => "long_press_only",
        RomajiMode::Hidden => "hidden",
    }
}

fn parse_romaji(text: &str) -> Option<RomajiMode> {
    [
        RomajiMode::Shown,
        RomajiMode::ShownToggleable,
        RomajiMode::TapToReveal,
        RomajiMode::LongPressOnly,
        RomajiMode::Hidden,
    ]
    .into_iter()
    .find(|mode| romaji_name(*mode) == text)
}

pub(crate) fn furigana_name(mode: FuriganaMode) -> &'static str {
    match mode {
        FuriganaMode::All => "all",
        FuriganaMode::UnknownOnly => "unknown_only",
    }
}

fn parse_furigana(text: &str) -> Option<FuriganaMode> {
    [FuriganaMode::All, FuriganaMode::UnknownOnly]
        .into_iter()
        .find(|mode| furigana_name(*mode) == text)
}

pub(crate) fn theme_name(mode: ThemeMode) -> &'static str {
    match mode {
        ThemeMode::System => "system",
        ThemeMode::Light => "light",
        ThemeMode::Dark => "dark",
    }
}

fn parse_theme(text: &str) -> ThemeMode {
    [ThemeMode::Light, ThemeMode::Dark]
        .into_iter()
        .find(|mode| theme_name(*mode) == text)
        .unwrap_or(ThemeMode::System)
}

pub(crate) fn hint_name(hint: QuestionType) -> &'static str {
    question_type_domain(hint).as_str()
}

pub(crate) fn settings_dto(row: &SettingsRow) -> SettingsDto {
    SettingsDto {
        day_rollover_hour: row.day_rollover_hour,
        desired_retention: row.desired_retention,
        romaji_override: row.romaji_override.as_deref().and_then(parse_romaji),
        furigana_override: row.furigana_override.as_deref().and_then(parse_furigana),
        tts_rate: row.tts_rate,
        autoplay: row.autoplay,
        voice_id: row.voice_id.clone(),
        theme_mode: parse_theme(&row.theme_mode),
        silent_mode: row.silent_mode,
        kana_time_limit: row.kana_time_limit,
        show_rating_intervals: row.show_rating_intervals,
        romaji_off_confirmed: row.romaji_off_confirmed,
        seen_question_hints: row
            .seen_question_hints
            .iter()
            .filter_map(|hint| QuizQuestionType::parse(hint))
            .map(question_type_dto)
            .collect(),
    }
}

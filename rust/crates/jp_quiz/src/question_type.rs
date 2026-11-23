//! §8.6 `QuestionType` 對照。

use jp_srs::kana_mastery::counts_toward_mastery;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
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
pub enum OptionLanguage {
    Zh,
    Romaji,
    Ja,
    None,
}

impl QuestionType {
    pub const ALL: [Self; 19] = [
        Self::Recog,
        Self::VocabListen,
        Self::Produce,
        Self::KanaRead,
        Self::KanaListen,
        Self::KanaMatch,
        Self::KanaConfuse,
        Self::MinimalPair,
        Self::KanaWord,
        Self::Substitution,
        Self::Reorder,
        Self::ParticleFill,
        Self::ZhToJaChoice,
        Self::ListenMeaning,
        Self::SituationResponse,
        Self::Conjugate,
        Self::RegisterConvert,
        Self::Shadowing,
        Self::FalseFriend,
    ];

    /// `review_log.question_type` 的值。
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Recog => "recog",
            Self::VocabListen => "vocab_listen",
            Self::Produce => "produce",
            Self::KanaRead => "kana_read",
            Self::KanaListen => "kana_listen",
            Self::KanaMatch => "kana_match",
            Self::KanaConfuse => "kana_confuse",
            Self::MinimalPair => "minimal_pair",
            Self::KanaWord => "kana_word",
            Self::Substitution => "substitution",
            Self::Reorder => "reorder",
            Self::ParticleFill => "particle_fill",
            Self::ZhToJaChoice => "zh_to_ja_choice",
            Self::ListenMeaning => "listen_meaning",
            Self::SituationResponse => "situation_response",
            Self::Conjugate => "conjugate",
            Self::RegisterConvert => "register_convert",
            Self::Shadowing => "shadowing",
            Self::FalseFriend => "false_friend",
        }
    }

    pub fn parse(text: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|t| t.as_str() == text)
    }

    pub const fn option_language(self) -> OptionLanguage {
        match self {
            Self::Recog
            | Self::VocabListen
            | Self::MinimalPair
            | Self::KanaWord
            | Self::ListenMeaning
            | Self::FalseFriend => OptionLanguage::Zh,
            Self::KanaRead => OptionLanguage::Romaji,
            Self::KanaListen
            | Self::KanaConfuse
            | Self::Substitution
            | Self::ParticleFill
            | Self::ZhToJaChoice
            | Self::SituationResponse => OptionLanguage::Ja,
            Self::Produce
            | Self::KanaMatch
            | Self::Reorder
            | Self::Conjugate
            | Self::RegisterConvert
            | Self::Shadowing => OptionLanguage::None,
        }
    }

    /// §8.6「需要語音」欄。`Reorder` 只有 `audio_first` 時需要，看 `drill_needs_audio`。
    pub const fn needs_audio(self) -> bool {
        matches!(
            self,
            Self::VocabListen
                | Self::KanaListen
                | Self::MinimalPair
                | Self::ListenMeaning
                | Self::Shadowing
        )
    }

    pub fn counts_toward_kana_mastery(self) -> bool {
        counts_toward_mastery(self.as_str())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn snake_case_values_round_trip() {
        for question_type in QuestionType::ALL {
            assert_eq!(
                QuestionType::parse(question_type.as_str()),
                Some(question_type)
            );
        }
        assert_eq!(QuestionType::parse("nope"), None);
    }

    /// §8.6 全表：(值, 選項語言, 需要語音, 計入假名熟練)。
    #[test]
    fn matches_the_spec_table() {
        use OptionLanguage::{Ja, None as Nil, Romaji, Zh};
        let table = [
            ("recog", Zh, false, false),
            ("vocab_listen", Zh, true, false),
            ("produce", Nil, false, false),
            ("kana_read", Romaji, false, true),
            ("kana_listen", Ja, true, true),
            ("kana_match", Nil, false, false),
            ("kana_confuse", Ja, false, true),
            ("minimal_pair", Zh, true, false),
            ("kana_word", Zh, false, false),
            ("substitution", Ja, false, false),
            ("reorder", Nil, false, false),
            ("particle_fill", Ja, false, false),
            ("zh_to_ja_choice", Ja, false, false),
            ("listen_meaning", Zh, true, false),
            ("situation_response", Ja, false, false),
            ("conjugate", Nil, false, false),
            ("register_convert", Nil, false, false),
            ("shadowing", Nil, true, false),
            ("false_friend", Zh, false, false),
        ];
        assert_eq!(table.len(), QuestionType::ALL.len());
        for (name, language, audio, mastery) in table {
            let question_type = QuestionType::parse(name).expect(name);
            assert_eq!(question_type.option_language(), language, "{name}");
            assert_eq!(question_type.needs_audio(), audio, "{name}");
            assert_eq!(
                question_type.counts_toward_kana_mastery(),
                mastery,
                "{name}"
            );
        }
    }
}

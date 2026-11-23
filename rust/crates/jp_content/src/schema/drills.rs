//! `drills/*`：12 種題型。每個變體開頭都有 `id`、`lesson`、`targets`，結尾都是 `retired`、`replaced_by`。

use std::collections::BTreeMap;

use serde::Deserialize;

use super::enums::{KanaWordMode, Style, TtsMode};
use super::ConjForm;

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case", deny_unknown_fields)]
pub enum DrillDef {
    Substitution {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        frame: String,
        #[serde(default)]
        rows: Vec<SubRowDef>,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    Reorder {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        sentence: String,
        #[serde(default)]
        accept_orders: Vec<Vec<u32>>,
        #[serde(default)]
        audio_first: bool,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    ParticleFill {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        sentence: String,
        #[serde(default)]
        blanks: Vec<BlankDef>,
        explain_zh: Option<String>,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    ZhToJaChoice {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        prompt_zh: String,
        answer: String,
        #[serde(default)]
        distractors: Vec<DistractorDef>,
        tts: Option<TtsMode>,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    ListenMeaning {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        sentence: String,
        #[serde(default)]
        choices_zh: Vec<String>,
        answer_index: u32,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    SituationResponse {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        situation_zh: String,
        style: Option<Style>,
        prompt: Option<String>,
        answer: String,
        #[serde(default)]
        distractors: Vec<DistractorDef>,
        tts: Option<TtsMode>,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    Conjugate {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        form: ConjForm,
        #[serde(default)]
        lemmas: Vec<String>,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    RegisterConvert {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        from: String,
        to: String,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    Shadowing {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        sentence: String,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    FalseFriend {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        note: String,
        prompt_zh: String,
        #[serde(default)]
        choices_zh: Vec<String>,
        answer_index: u32,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    MinimalPair {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        a: String,
        a_zh: String,
        b: String,
        b_zh: String,
        a_kana: Option<String>,
        b_kana: Option<String>,
        a_tts_text: Option<String>,
        b_tts_text: Option<String>,
        #[serde(default)]
        listen_disabled: bool,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
    KanaWord {
        id: String,
        lesson: String,
        #[serde(default)]
        targets: Vec<String>,
        word: String,
        zh: String,
        mode: KanaWordMode,
        #[serde(default)]
        choices_zh: Vec<String>,
        answer_index: Option<u32>,
        #[serde(default)]
        retired: bool,
        replaced_by: Option<String>,
    },
}

/// slots 的鍵是動態的，所以這裡不能 `deny_unknown_fields`；鍵由 lint 比對 `frame`。
#[derive(Debug, Clone, PartialEq, Deserialize)]
pub struct SubRowDef {
    pub zh: String,
    pub tts: Option<TtsMode>,
    #[serde(flatten)]
    pub slots: BTreeMap<String, String>,
}

/// P0：`blanks` 長度固定 1（R12）。
#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BlankDef {
    pub word_index: u32,
    pub choices: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DistractorDef {
    pub t: String,
    pub why_zh: String,
}

/// 各題型共通欄位的借用檢視。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DrillCommon<'a> {
    pub id: &'a str,
    pub lesson: &'a str,
    pub targets: &'a [String],
    pub retired: bool,
}

/// 12 個變體的共通欄位都同名，集中在一個 `match`。
macro_rules! drill_common {
    ($self:ident, $($variant:ident),+ $(,)?) => {
        match $self {
            $(DrillDef::$variant { id, lesson, targets, retired, .. })|+ => DrillCommon {
                id,
                lesson,
                targets,
                retired: *retired,
            },
        }
    };
}

impl DrillDef {
    pub fn common(&self) -> DrillCommon<'_> {
        drill_common!(
            self,
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
            MinimalPair,
            KanaWord
        )
    }

    pub fn id(&self) -> &str {
        self.common().id
    }

    pub fn lesson(&self) -> &str {
        self.common().lesson
    }

    pub fn targets(&self) -> &[String] {
        self.common().targets
    }

    pub fn retired(&self) -> bool {
        self.common().retired
    }

    /// JSON `type` 的值。
    pub fn type_name(&self) -> &'static str {
        match self {
            Self::Substitution { .. } => "substitution",
            Self::Reorder { .. } => "reorder",
            Self::ParticleFill { .. } => "particle_fill",
            Self::ZhToJaChoice { .. } => "zh_to_ja_choice",
            Self::ListenMeaning { .. } => "listen_meaning",
            Self::SituationResponse { .. } => "situation_response",
            Self::Conjugate { .. } => "conjugate",
            Self::RegisterConvert { .. } => "register_convert",
            Self::Shadowing { .. } => "shadowing",
            Self::FalseFriend { .. } => "false_friend",
            Self::MinimalPair { .. } => "minimal_pair",
            Self::KanaWord { .. } => "kana_word",
        }
    }
}

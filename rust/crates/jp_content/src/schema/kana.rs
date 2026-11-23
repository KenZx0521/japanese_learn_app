//! `kana/*`。

use serde::Deserialize;

use super::enums::{ConfusableKind, KanaKind, Script, SoundGroupKind};

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct KanaDef {
    pub id: String,
    pub lesson: String,
    pub script: Script,
    pub kind: KanaKind,
    /// `kind = yoon` 必填。
    pub row: Option<String>,
    #[serde(rename = "char")]
    pub ch: String,
    /// 只有 `kind = mark` 使用。
    pub rule: Option<String>,
    pub origin_kanji: Option<String>,
    pub hint_zh: String,
    #[serde(default)]
    pub confusable: Vec<String>,
    #[serde(default)]
    pub example_words: Vec<ExampleWordDef>,
    /// 省略時送 `ch`。
    pub tts_text: Option<String>,
    #[serde(default)]
    pub listen_disabled: bool,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ExampleWordDef {
    pub surface: String,
    pub zh: String,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ConfusableDef {
    pub id: String,
    pub lesson: String,
    pub kind: ConfusableKind,
    #[serde(default)]
    pub members: Vec<String>,
    #[serde(default)]
    pub literals: Vec<LiteralDef>,
    pub diff_zh: String,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LiteralDef {
    pub text: String,
    pub zh: String,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RuleCardDef {
    pub id: String,
    pub lesson: String,
    pub title_zh: String,
    pub body_zh: String,
    #[serde(default)]
    pub sound_groups: Vec<String>,
    #[serde(default)]
    pub drills: Vec<String>,
    #[serde(default)]
    pub examples: Vec<RuleExampleDef>,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RuleExampleDef {
    pub text: String,
    pub zh: String,
    #[serde(default)]
    pub beats: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SoundGroupDef {
    pub id: String,
    pub lesson: String,
    pub kind: SoundGroupKind,
    pub title_zh: String,
    pub body_zh: String,
    #[serde(default)]
    pub test_drills: Vec<String>,
    #[serde(default)]
    pub pairs: Vec<PairDef>,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PairDef {
    pub a: String,
    pub a_zh: String,
    pub b: String,
    pub b_zh: String,
    pub a_kana: Option<String>,
    pub b_kana: Option<String>,
    pub a_tts_text: Option<String>,
    pub b_tts_text: Option<String>,
    #[serde(default)]
    pub listen_disabled: bool,
}

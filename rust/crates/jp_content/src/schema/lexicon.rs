//! `vocab/*`、`grammar/*`、`sentences/*`。

use serde::Deserialize;

use super::enums::{Jlpt, Register, Style, Transitivity, TtsMode, UseLevel};
use super::{ConjForm, Pos};

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct VocabDef {
    pub id: String,
    pub lesson: String,
    pub lesson_order: u32,
    pub surface: String,
    pub kana: String,
    #[serde(default)]
    pub zh: Vec<String>,
    pub pos: Pos,
    pub trans: Option<Transitivity>,
    pub accent: Option<u8>,
    pub jlpt: Jlpt,
    #[serde(default)]
    pub topics: Vec<String>,
    #[serde(default)]
    pub examples: Vec<String>,
    /// 省略時 `Kana`。
    pub tts: Option<TtsMode>,
    #[serde(default)]
    pub same_form_zh: bool,
    pub hook_zh: Option<String>,
    pub trap_zh: Option<String>,
    #[serde(default)]
    pub notes: Vec<String>,
    pub pair: Option<String>,
    #[serde(default)]
    pub reading_family: Vec<String>,
    /// 省略時 `Safe`。
    pub use_level: Option<UseLevel>,
    /// 引擎算得出、但這個詞實際不用的活用形；單字詳情的活用表略過，`conjugate` 題不得考（RC7）。
    #[serde(default)]
    pub conj_omit: Vec<ConjForm>,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GrammarDef {
    pub id: String,
    pub lesson: String,
    pub lesson_order: u32,
    pub jlpt: Jlpt,
    pub title_zh: String,
    pub pattern: String,
    pub meaning_zh: String,
    pub explain_zh: String,
    pub compare_zh: String,
    pub trap_zh: Option<String>,
    #[serde(default)]
    pub formation: Vec<FormationRowDef>,
    pub register: Register,
    #[serde(default)]
    pub requires: Vec<String>,
    #[serde(default)]
    pub examples: Vec<String>,
    #[serde(default)]
    pub contrast: Vec<String>,
    #[serde(default)]
    pub terms: Vec<String>,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FormationRowDef {
    pub from: String,
    pub to: String,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SentenceDef {
    pub id: String,
    pub lesson: String,
    pub t: String,
    pub zh: String,
    pub style: Style,
    /// 省略時 `Auto`。
    pub tts: Option<TtsMode>,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

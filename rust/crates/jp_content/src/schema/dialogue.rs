//! `dialogues/*`。

use serde::Deserialize;

use super::enums::{DialogueKind, Style, TtsMode};

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DialogueDef {
    pub id: String,
    pub kind: DialogueKind,
    pub lesson: String,
    pub style: Style,
    pub scene_zh: String,
    pub goal_zh: String,
    #[serde(default)]
    pub roles: Vec<RoleDef>,
    #[serde(default)]
    pub turns: Vec<TurnDef>,
    #[serde(default)]
    pub focus: Vec<String>,
    /// `listen_meaning` 的 `dr.*` ID。
    #[serde(default)]
    pub quiz: Vec<String>,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RoleDef {
    pub id: String,
    pub name_zh: String,
    pub voice: String,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TurnDef {
    pub role: String,
    pub t: String,
    pub zh: String,
    pub note_zh: Option<String>,
    pub tts: Option<TtsMode>,
}

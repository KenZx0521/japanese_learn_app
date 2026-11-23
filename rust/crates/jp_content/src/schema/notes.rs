//! `notes/*`：一個檔案一種形狀，依路徑分派，不用 untagged。

use serde::Deserialize;

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FalseFriendNoteDef {
    pub id: String,
    pub surface: String,
    pub vocab: Option<String>,
    pub ja_zh: String,
    pub misread_zh: String,
    pub lesson: Option<String>,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ShinjitaiNoteDef {
    pub id: String,
    pub ja: String,
    pub zh_tw: String,
    pub kind: String,
    #[serde(default)]
    pub vocab: Vec<String>,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ReadingNoteDef {
    pub id: String,
    pub lesson: String,
    pub title_zh: String,
    pub body_zh: String,
    #[serde(default)]
    pub examples: Vec<ReadingExampleDef>,
    #[serde(default)]
    pub vocab: Vec<String>,
    pub caveat_zh: String,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ReadingExampleDef {
    pub hanzi: String,
    pub tai: String,
    pub ja: String,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TransferNoteDef {
    pub id: String,
    pub lesson: String,
    pub title_zh: String,
    pub zh_pattern: String,
    pub wrong: String,
    pub right: String,
    pub explain_zh: String,
    #[serde(default)]
    pub grammar: Vec<String>,
    #[serde(default)]
    pub vocab: Vec<String>,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TermNoteDef {
    pub id: String,
    pub lesson: String,
    pub term: String,
    pub aka_zh: Option<String>,
    pub body_zh: String,
    #[serde(default)]
    pub grammar: Vec<String>,
    #[serde(default)]
    pub retired: bool,
    pub replaced_by: Option<String>,
}

/// 筆記五種形狀的和；`ContentStore` 與 `NoteDto` 都依此分派。
#[derive(Debug, Clone, PartialEq)]
pub enum NoteDef {
    FalseFriend(FalseFriendNoteDef),
    Shinjitai(ShinjitaiNoteDef),
    Reading(ReadingNoteDef),
    Transfer(TransferNoteDef),
    Term(TermNoteDef),
}

impl NoteDef {
    pub fn id(&self) -> &str {
        match self {
            Self::FalseFriend(n) => &n.id,
            Self::Shinjitai(n) => &n.id,
            Self::Reading(n) => &n.id,
            Self::Transfer(n) => &n.id,
            Self::Term(n) => &n.id,
        }
    }

    /// `no.sj.*` 與未指定課的 `no.ff.*` 沒有所屬課。
    pub fn lesson(&self) -> Option<&str> {
        match self {
            Self::FalseFriend(n) => n.lesson.as_deref(),
            Self::Shinjitai(_) => None,
            Self::Reading(n) => Some(&n.lesson),
            Self::Transfer(n) => Some(&n.lesson),
            Self::Term(n) => Some(&n.lesson),
        }
    }

    pub fn retired(&self) -> bool {
        match self {
            Self::FalseFriend(n) => n.retired,
            Self::Shinjitai(n) => n.retired,
            Self::Reading(n) => n.retired,
            Self::Transfer(n) => n.retired,
            Self::Term(n) => n.retired,
        }
    }
}

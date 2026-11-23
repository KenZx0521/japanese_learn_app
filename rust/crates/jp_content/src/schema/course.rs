//! `course.json` 與 `plan/*`。檢定位置只由 `MilestoneDef.lesson` 決定。

use serde::Deserialize;

use super::enums::ContentStage;

#[derive(Debug, Clone, Default, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CourseDef {
    pub schema: Option<u32>,
    #[serde(default)]
    pub stages: Vec<StageDef>,
    #[serde(default)]
    pub order: Vec<String>,
    #[serde(default)]
    pub lessons: Vec<LessonDef>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StageDef {
    pub id: String,
    pub title_zh: String,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LessonDef {
    pub id: String,
    pub stage: String,
    pub content_stage: ContentStage,
    pub title_zh: String,
    pub can_do_zh: String,
    pub dialogue: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PlanPresetDef {
    pub id: String,
    pub minutes: u32,
    pub new_words_per_day: u32,
    pub kana_chars_per_day: u32,
    pub split: SplitDef,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SplitDef {
    pub new: u32,
    pub review: u32,
    pub drill: u32,
    pub listen: u32,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MilestoneDef {
    pub id: String,
    pub lesson: String,
    pub title_zh: String,
    pub pass_ratio: f64,
    pub questions: u32,
}

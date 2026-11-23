//! 工具用的內容走訪（lint、`content_tool verify`、`charset`）：階段過濾後的原始內容與文字欄位。

use serde_json::Value;

pub use crate::filter::{filter_stage, included_lessons};
pub use crate::raw::{parse_files, RawContent};
pub use crate::refs::{t_sites, FrameIssue, TKind, TSite};

use crate::schema::{ContentStage, CourseDef};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FieldKind {
    /// `{ja:…}` 混排的欄位。
    Mixed,
    /// `zh`：不走 MixedText，不得含假名，也不開放標記。
    PlainZh,
    /// 只做繁中字形檢查（`zh_tw`、`hanzi`）。
    ZhOnly,
}

/// §12.2 列舉的中文與混合欄位。
pub fn classify_field(file: &str, key: &str, parent_key: &str) -> Option<FieldKind> {
    if key == "zh" {
        return Some(FieldKind::PlainZh);
    }
    if key == "zh_tw" || key == "hanzi" {
        return Some(FieldKind::ZhOnly);
    }
    if key.ends_with("_zh") || key == "zh_pattern" {
        return Some(FieldKind::Mixed);
    }
    let is_mixed = match key {
        "pattern" => file.starts_with("grammar/"),
        "from" | "to" => parent_key == "formation",
        "term" => file.starts_with("notes/terms"),
        "wrong" | "right" => file.starts_with("notes/transfer"),
        "ja" => file.starts_with("notes/readings") && parent_key == "examples",
        _ => false,
    };
    is_mixed.then_some(FieldKind::Mixed)
}

/// 內容 JSON 裡的一個字串欄位。`owner` 是最近的 `id`，`parent_key` 是外層物件的鍵。
pub struct TextField<'a> {
    pub file: &'a str,
    pub owner: &'a str,
    pub key: &'a str,
    pub parent_key: &'a str,
    pub text: &'a str,
}

fn walk(
    value: &Value,
    file: &str,
    owner: &str,
    key: &str,
    parent_key: &str,
    visit: &mut dyn FnMut(&TextField),
) {
    match value {
        Value::Object(map) => {
            let owner = map.get("id").and_then(Value::as_str).unwrap_or(owner);
            for (child_key, child) in map {
                walk(child, file, owner, child_key, key, visit);
            }
        }
        Value::Array(items) => {
            for item in items {
                walk(item, file, owner, key, parent_key, visit);
            }
        }
        Value::String(text) => visit(&TextField {
            file,
            owner,
            key,
            parent_key,
            text,
        }),
        _ => {}
    }
}

fn is_item_included(item: &Value, file: &str, stage: ContentStage, lessons: &[String]) -> bool {
    if file.starts_with("notes/") && stage == ContentStage::P0a {
        return false;
    }
    item.get("lesson")
        .and_then(Value::as_str)
        .is_none_or(|lesson| lessons.iter().any(|l| l == lesson))
}

fn visit_course(value: &Value, file: &str, lessons: &[String], visit: &mut dyn FnMut(&TextField)) {
    if let Some(items) = value.get("lessons").and_then(Value::as_array) {
        for lesson in items {
            let id = lesson.get("id").and_then(Value::as_str).unwrap_or_default();
            if lessons.iter().any(|l| l == id) {
                walk(lesson, file, file, "", "", visit);
            }
        }
    }
    if let Some(stages) = value.get("stages") {
        walk(stages, file, file, "stages", "", visit);
    }
}

/// 逐檔走訪當前階段項目的全部字串欄位。無法解析的檔案已由載入回報，這裡略過。
pub fn visit_text_fields(
    files: &[(&str, &str)],
    course: &CourseDef,
    stage: ContentStage,
    visit: &mut dyn FnMut(&TextField),
) {
    let lessons: Vec<String> = included_lessons(course, stage).into_iter().collect();
    for (file, text) in files {
        let Ok(value) = serde_json::from_str::<Value>(text) else {
            continue;
        };
        match value.get("items").and_then(Value::as_array) {
            Some(items) => {
                for item in items {
                    if is_item_included(item, file, stage, &lessons) {
                        walk(item, file, file, "", "", visit);
                    }
                }
            }
            None => visit_course(&value, file, &lessons, visit),
        }
    }
}

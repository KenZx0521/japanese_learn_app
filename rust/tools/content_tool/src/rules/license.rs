//! 授權與資料防呆：L01、L02、L04（reuse-and-verification.md §9.2）。

use std::fs;

use serde_json::Value;

use super::font::{bundled_font_assets, FONT_FAMILIES};
use super::{Finding, Input};

const FORBIDDEN_KEYS: [&str; 5] = ["jmdict", "jmdict_id", "seq", "tatoeba_id", "source"];
const NOTICES_FILE: &str = "THIRD_PARTY_NOTICES.md";
const GITIGNORE_FILE: &str = ".gitignore";
const WALLER_NOTICE: &str = "Waller";
const REQUIRED_IGNORES: [&str; 3] = [".verify-cache/", "build/verify/", "build/fonts/"];

fn walk_keys(value: &Value, owner: &str, file: &str, out: &mut Vec<Finding>) {
    match value {
        Value::Object(map) => {
            let owner = map.get("id").and_then(Value::as_str).unwrap_or(owner);
            for (key, child) in map {
                if FORBIDDEN_KEYS.contains(&key.as_str()) {
                    out.push(Finding::error(
                        "L01",
                        owner,
                        key.as_str(),
                        format!("{file} 不得出現鍵 {key}，避免外部資料 ID 進入 App"),
                    ));
                }
                walk_keys(child, owner, file, out);
            }
        }
        Value::Array(items) => {
            for item in items {
                walk_keys(item, owner, file, out);
            }
        }
        _ => {}
    }
}

/// 只看 JSON 鍵，必須在 `load_content` 前跑，否則 `deny_unknown_fields` 會先拒絕載入。
pub fn forbidden_keys(files: &[(String, String)]) -> Vec<Finding> {
    let mut findings = Vec::new();
    for (file, text) in files {
        if let Ok(value) = serde_json::from_str::<Value>(text) {
            walk_keys(&value, file, file, &mut findings);
        }
    }
    findings
}

pub fn l01(input: &Input) -> Vec<Finding> {
    forbidden_keys(&input.scope.files)
}

pub fn l02(input: &Input) -> Vec<Finding> {
    let notices = fs::read_to_string(input.env.repo_root.join(NOTICES_FILE)).unwrap_or_default();
    let mut required: Vec<&str> = bundled_font_assets(&input.env.repo_root)
        .iter()
        .filter_map(|asset| {
            FONT_FAMILIES
                .iter()
                .find(|(prefix, ..)| asset.starts_with(prefix))
                .map(|(_, _, family)| *family)
        })
        .collect();
    if !input.scope.raw.vocab.is_empty() {
        required.push(WALLER_NOTICE);
    }
    required.sort_unstable();
    required.dedup();
    required
        .into_iter()
        .filter(|name| !notices.contains(name))
        .map(|name| {
            Finding::error(
                "L02",
                NOTICES_FILE,
                name,
                format!("{NOTICES_FILE} 未登錄 {name}（§10）"),
            )
        })
        .collect()
}

pub fn l04(input: &Input) -> Vec<Finding> {
    let content = fs::read_to_string(input.env.repo_root.join(GITIGNORE_FILE)).unwrap_or_default();
    let lines: Vec<&str> = content.lines().map(str::trim).collect();
    REQUIRED_IGNORES
        .iter()
        .filter(|entry| {
            !lines
                .iter()
                .any(|line| line.trim_start_matches('/') == **entry)
        })
        .map(|entry| {
            Finding::error(
                "L04",
                GITIGNORE_FILE,
                *entry,
                format!(".gitignore 必須列入 {entry}"),
            )
        })
        .collect()
}

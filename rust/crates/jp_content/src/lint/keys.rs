//! 禁用鍵的掃描（R20 `seq`）。必須在解析結構前做，因為 `deny_unknown_fields` 會直接拒絕。

use serde_json::Value;

use super::Finding;

const SEQ_KEY: &str = "seq";

fn item_label(value: &Value, fallback: &str) -> String {
    value
        .get("id")
        .and_then(Value::as_str)
        .unwrap_or(fallback)
        .to_owned()
}

fn walk(value: &Value, owner: &str, file: &str, out: &mut Vec<Finding>) {
    match value {
        Value::Object(map) => {
            let label = item_label(value, owner);
            for (key, child) in map {
                if key == SEQ_KEY {
                    out.push(Finding::error(
                        "R20",
                        &label,
                        SEQ_KEY,
                        format!("{file} 的內容不得有 seq 鍵，請用 lesson_order"),
                    ));
                } else {
                    walk(child, &label, file, out);
                }
            }
        }
        Value::Array(items) => {
            for item in items {
                walk(item, owner, file, out);
            }
        }
        _ => {}
    }
}

pub(super) fn forbidden_keys(files: &[(&str, &str)]) -> Vec<Finding> {
    let mut findings = Vec::new();
    for (path, text) in files {
        if let Ok(value) = serde_json::from_str::<Value>(text) {
            walk(&value, path, path, &mut findings);
        }
    }
    findings
}

//! 繁中欄位：Z01（非 Big5 字元）、Z02（假名標記）。

use std::collections::BTreeSet;

use encoding_rs::BIG5;
use jp_content::scan::FieldKind;

use super::{is_kanji, Finding, Input};

/// 日文新字體（学、気、発）不在 Big5，是混入中文欄位的主要訊號。
pub fn is_non_big5_han(c: char) -> bool {
    if !is_kanji(c) {
        return false;
    }
    let mut buffer = [0u8; 4];
    let (_, _, had_errors) = BIG5.encode(c.encode_utf8(&mut buffer));
    had_errors
}

fn is_kana(c: char) -> bool {
    matches!(c, '\u{3041}'..='\u{3096}' | '\u{30A1}'..='\u{30FA}')
}

fn kana_run(text: &str) -> String {
    text.chars().filter(|c| is_kana(*c)).collect()
}

pub fn z01(input: &Input) -> Vec<Finding> {
    let mut seen: BTreeSet<(String, char)> = BTreeSet::new();
    input.scope.visit_zh_fields(|field| {
        for c in field.zh.chars().filter(|c| is_non_big5_han(*c)) {
            seen.insert((field.owner.to_owned(), c));
        }
    });
    seen.into_iter()
        .map(|(owner, c)| {
            Finding::warning(
                "Z01",
                owner,
                c.to_string(),
                "中文欄位含非 Big5 字元（可能混入日文新字體）；日文請包在 {ja:…} 內",
            )
        })
        .collect()
}

pub fn z02(input: &Input) -> Vec<Finding> {
    let mut findings = Vec::new();
    input.scope.visit_zh_fields(|field| {
        if let Some(error) = &field.markup_error {
            findings.push(Finding::error(
                "Z02",
                field.owner,
                field.key,
                format!("{} 的 {{ja:…}} 語法錯誤：{error}", field.key),
            ));
        }
        match field.kind {
            FieldKind::Mixed if field.zh.chars().any(is_kana) => findings.push(Finding::error(
                "Z02",
                field.owner,
                kana_run(&field.zh),
                format!("{} 的假名必須包在 {{ja:…}} 內", field.key),
            )),
            FieldKind::PlainZh => {
                if field.text.contains("{ja:") {
                    findings.push(Finding::error(
                        "Z02",
                        field.owner,
                        field.key,
                        format!("{} 不開放 {{ja:…}} 標記", field.key),
                    ));
                }
                if field.text.chars().any(is_kana) {
                    findings.push(Finding::error(
                        "Z02",
                        field.owner,
                        kana_run(field.text),
                        format!("{} 不得含假名", field.key),
                    ));
                }
            }
            _ => {}
        }
    });
    findings
}

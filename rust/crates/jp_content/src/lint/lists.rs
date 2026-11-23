//! `rust/content/lint/*.txt`：只給 lint 使用，不進 App。

use std::collections::{HashMap, HashSet};
use std::fs;
use std::io::ErrorKind;
use std::path::Path;

const COUNT_POLICY_SEED: &str = "seed";

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct LintLists {
    pub tts_risky: Vec<String>,
    pub zh_tw_denylist: Vec<String>,
    pub zh_simplified: HashSet<char>,
    pub unsplit_allow: HashSet<String>,
    /// R10 例外：`vo.*` ID → 理由（`r10_allow.txt` 每行「ID 理由」，理由必填）。
    pub r10_allow: HashMap<String, String>,
    /// `true` 時跳過內容量門檻（R17；RC11 比照）。內容量產完成後刪除 `count_policy.txt`。
    pub seed_content: bool,
}

fn read_lines(path: &Path) -> std::io::Result<Vec<String>> {
    match fs::read_to_string(path) {
        Ok(text) => Ok(text
            .lines()
            .map(str::trim)
            .filter(|line| !line.is_empty() && !line.starts_with('#'))
            .map(str::to_owned)
            .collect()),
        Err(err) if err.kind() == ErrorKind::NotFound => Ok(Vec::new()),
        Err(err) => Err(err),
    }
}

/// 「ID 理由」：第一段空白前是 ID，其後去頭尾空白是理由（可為空，由 R10 報錯）。
fn parse_allow_line(line: &str) -> (String, String) {
    match line.split_once(char::is_whitespace) {
        Some((id, reason)) => (id.to_owned(), reason.trim().to_owned()),
        None => (line.to_owned(), String::new()),
    }
}

impl LintLists {
    /// 讀 `<content_root>/lint/*.txt`；缺檔視為空清單。
    pub fn from_content_root(content_root: &Path) -> std::io::Result<Self> {
        let dir = content_root.join("lint");
        let zh_simplified = read_lines(&dir.join("zh_simplified_chars.txt"))?
            .into_iter()
            .flat_map(|line| line.chars().collect::<Vec<_>>())
            .collect();
        Ok(Self {
            tts_risky: read_lines(&dir.join("tts_risky.txt"))?,
            zh_tw_denylist: read_lines(&dir.join("zh_tw_denylist.txt"))?,
            zh_simplified,
            unsplit_allow: read_lines(&dir.join("unsplit_allow.txt"))?
                .into_iter()
                .collect(),
            r10_allow: read_lines(&dir.join("r10_allow.txt"))?
                .iter()
                .map(String::as_str)
                .map(parse_allow_line)
                .collect(),
            seed_content: read_lines(&dir.join("count_policy.txt"))?
                .first()
                .is_some_and(|policy| policy == COUNT_POLICY_SEED),
        })
    }
}

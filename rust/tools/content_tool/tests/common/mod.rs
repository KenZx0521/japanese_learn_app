//! B 層測試共用：完整夾具加字串替換，以及小型假 JMdict（reuse-and-verification.md §9.9）。
#![allow(dead_code)]

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

use content_tool::data::{jmdict::JmdictIndex, Data};
use content_tool::rules::{Env, Finding, Input, Level};
use content_tool::scope::Scope;
use jp_content::disk::read_content_dir;
use jp_content::schema::{ContentStage, Pos};

pub fn fixture_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../crates/jp_content/tests/fixtures/full")
}

pub fn scope_with(edits: &[(&str, &str)]) -> Scope {
    let mut files = read_content_dir(&fixture_root()).expect("夾具應可讀取");
    for (needle, replacement) in edits {
        let hits = files.iter().filter(|(_, t)| t.contains(needle)).count();
        assert_eq!(hits, 1, "{needle} 應只出現在一個檔案");
        for (_, text) in &mut files {
            *text = text.replacen(needle, replacement, 1);
        }
    }
    Scope::build(files, ContentStage::Full).expect("夾具應可載入")
}

pub fn scope() -> Scope {
    scope_with(&[])
}

/// `entries` 為 `(漢字形, 假名, 詞性)`；漢字形為空字串時是純假名詞條。
pub fn jmdict_json(entries: &[(&str, &str, &[&str])]) -> String {
    let words: Vec<serde_json::Value> = entries
        .iter()
        .enumerate()
        .map(|(index, (kanji, kana, pos))| {
            let kanji_forms = if kanji.is_empty() {
                serde_json::json!([])
            } else {
                serde_json::json!([{ "text": kanji, "tags": [] }])
            };
            serde_json::json!({
                "id": (1000 + index).to_string(),
                "kanji": kanji_forms,
                "kana": [{ "text": kana, "tags": [], "appliesToKanji": ["*"] }],
                "sense": [{ "partOfSpeech": pos, "misc": [] }],
            })
        })
        .collect();
    serde_json::json!({ "words": words }).to_string()
}

pub fn jmdict(entries: &[(&str, &str, &[&str])]) -> JmdictIndex {
    JmdictIndex::parse(jmdict_json(entries).as_bytes(), &HashSet::new())
        .expect("假 JMdict 應可解析")
}

fn pos_tag(pos: Pos) -> &'static str {
    match pos {
        Pos::N => "n",
        Pos::Pron => "pn",
        Pos::Num => "num",
        Pos::Counter => "ctr",
        Pos::V5 => "v5m",
        Pos::V1 => "v1",
        Pos::V1S => "v1-s",
        Pos::Vs => "vs-i",
        Pos::Vk => "vk",
        Pos::AdjI => "adj-i",
        Pos::AdjNa => "adj-na",
        Pos::Adv => "adv",
        Pos::Conj => "conj",
        Pos::Interj => "int",
        Pos::Phrase => "exp",
    }
}

/// 假 JMdict：夾具全部單字與假名例字都查得到（`vocab` 的詞性與內容一致）。
pub fn fixture_jmdict() -> JmdictIndex {
    JmdictIndex::parse(fixture_jmdict_json().as_bytes(), &HashSet::new()).expect("假 JMdict")
}

pub fn fixture_jmdict_json() -> String {
    let scope = scope();
    let mut json_entries: Vec<(String, String, Vec<String>)> = scope
        .raw
        .vocab
        .iter()
        .map(|v| {
            let kana: String = v.kana.split_whitespace().collect();
            let surface: String = if v.surface.chars().any(is_kanji_like) {
                v.surface.clone()
            } else {
                String::new()
            };
            (surface, kana, vec![pos_tag(v.pos).to_owned()])
        })
        .collect();
    for kana in &scope.raw.kana {
        json_entries.extend(
            kana.example_words
                .iter()
                .map(|example| (String::new(), example.surface.clone(), vec!["n".to_owned()])),
        );
    }
    let borrowed: Vec<(&str, &str, Vec<&str>)> = json_entries
        .iter()
        .map(|(surface, kana, pos)| {
            (
                surface.as_str(),
                kana.as_str(),
                pos.iter().map(String::as_str).collect(),
            )
        })
        .collect();
    let entries: Vec<(&str, &str, &[&str])> = borrowed
        .iter()
        .map(|(surface, kana, pos)| (*surface, *kana, pos.as_slice()))
        .collect();
    jmdict_json(&entries)
}

fn is_kanji_like(c: char) -> bool {
    ('\u{4E00}'..='\u{9FFF}').contains(&c)
}

pub fn data_with_jmdict(index: JmdictIndex) -> Data {
    Data {
        jmdict: Some(index),
        ..Data::default()
    }
}

pub fn env_for(repo_root: &Path) -> Env {
    Env {
        repo_root: repo_root.to_path_buf(),
        font_dir: repo_root.join("assets/fonts"),
        strict: false,
        fonts: HashMap::new(),
        coverage_skip: Vec::new(),
        grammar_checklist: None,
    }
}

pub fn run_rule(
    rule: fn(&Input) -> Vec<Finding>,
    scope: &Scope,
    data: &Data,
    env: &Env,
) -> Vec<Finding> {
    rule(&Input { scope, data, env })
}

pub fn find<'a>(findings: &'a [Finding], item: &str) -> Option<&'a Finding> {
    findings.iter().find(|f| f.item == item)
}

pub fn assert_level(findings: &[Finding], item: &str, level: Level) {
    let found = find(findings, item).unwrap_or_else(|| panic!("缺 {item}：{findings:?}"));
    assert_eq!(found.level, level, "{found:?}");
}

pub fn no_errors(findings: &[Finding]) -> bool {
    findings.iter().all(|f| f.level != Level::Error)
}

//! 真實內容的五十音圖：圖表順序取自陣列，教學順序取自 `lesson`（兩者互不影響）。

mod common;

use std::path::Path;

use common::{open, start_time};
use jp_content::disk::{borrow_files, read_content_dir};
use jp_content::schema::ContentStage;
use jp_content::{load_content, ContentStore};
use jp_core::api::dto_content::KanaScript;
use tempfile::TempDir;

const HIRAGANA_ROW_HEADS: [&str; 11] = [
    "あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "ん",
];
const KATAKANA_ROW_HEADS: [&str; 11] = [
    "ア", "カ", "サ", "タ", "ナ", "ハ", "マ", "ヤ", "ラ", "ワ", "ン",
];

fn real_content() -> ContentStore {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("content");
    let files = read_content_dir(&root).expect("rust/content 應可讀取");
    load_content(&borrow_files(&files), ContentStage::P0a).expect("真實內容應可載入")
}

fn basic_row_heads(content: &ContentStore, script: KanaScript) -> Vec<String> {
    let dir = TempDir::new().unwrap();
    let db_path = dir.path().join("jp_core.db").to_string_lossy().into_owned();
    let core = open(&db_path, content, start_time());
    let chart = core.kana_chart(script).unwrap();
    chart[0]
        .rows
        .iter()
        .map(|row| row.cells.iter().flatten().next().unwrap().ch.clone())
        .collect()
}

fn lesson_chars(content: &ContentStore, lesson: &str) -> Vec<String> {
    content
        .kana()
        .iter()
        .filter(|entry| entry.def.lesson == lesson)
        .map(|entry| entry.def.ch.clone())
        .collect()
}

#[test]
fn hiragana_chart_follows_gojuon_order() {
    assert_eq!(
        basic_row_heads(&real_content(), KanaScript::Hiragana),
        HIRAGANA_ROW_HEADS
    );
}

#[test]
fn katakana_chart_follows_gojuon_order() {
    assert_eq!(
        basic_row_heads(&real_content(), KanaScript::Katakana),
        KATAKANA_ROW_HEADS
    );
}

/// 圖表順序修正不可動到教學順序：わ行、ん 仍在 ら行 之前教。
#[test]
fn teaching_order_stays_with_the_lesson_field() {
    let content = real_content();
    assert_eq!(
        lesson_chars(&content, "le.k08"),
        ["や", "ゆ", "よ", "わ", "を", "ん"]
    );
    assert_eq!(
        lesson_chars(&content, "le.k09"),
        ["ら", "り", "る", "れ", "ろ"]
    );
}

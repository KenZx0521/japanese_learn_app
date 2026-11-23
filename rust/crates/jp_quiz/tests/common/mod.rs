//! 整合測試共用夾具。每個測試執行檔只用到其中一部分。
#![allow(dead_code)]

use std::collections::HashSet;

use jp_content::disk::borrow_files;
use jp_content::schema::{ContentStage, DrillDef};
use jp_content::test_support::{fixture_files, load_full_fixture};
use jp_content::{load_content, ContentStore};
use jp_quiz::model::{ChoiceOption, Question, QuestionBody};
use jp_quiz::QuizContext;

pub const SEED: u32 = 42;

pub fn content() -> ContentStore {
    load_full_fixture(ContentStage::Full)
}

/// 完整夾具做字串替換後載入，用來造出夾具沒有的內容組合。
pub fn content_with(edits: &[(&str, &str)]) -> ContentStore {
    let mut files = fixture_files();
    for (needle, replacement) in edits {
        let hits = files
            .iter()
            .filter(|(_, text)| text.contains(needle))
            .count();
        assert_eq!(hits, 1, "{needle} 應只出現在一個檔案");
        for (_, text) in &mut files {
            *text = text.replacen(needle, replacement, 1);
        }
    }
    load_content(&borrow_files(&files), ContentStage::Full).unwrap()
}

/// 全部假名、單字、文法都已介紹。
pub fn all_known(store: &ContentStore) -> HashSet<String> {
    let kana = store.kana().iter().map(|k| k.def.id.clone());
    let vocab = store.vocab().iter().map(|v| v.def.id.clone());
    let grammar = store.grammar().iter().map(|g| g.id.clone());
    kana.chain(vocab).chain(grammar).collect()
}

pub fn set(ids: &[&str]) -> HashSet<String> {
    ids.iter().map(|id| (*id).to_string()).collect()
}

pub fn ctx<'a>(store: &'a ContentStore, known: &'a HashSet<String>) -> QuizContext<'a> {
    QuizContext {
        content: store,
        known,
        cursor_pos: None,
        session_seed: SEED,
        audio_available: true,
    }
}

pub fn with_seed<'a>(context: &QuizContext<'a>, session_seed: u32) -> QuizContext<'a> {
    QuizContext {
        session_seed,
        ..*context
    }
}

pub fn silent<'a>(context: &QuizContext<'a>) -> QuizContext<'a> {
    QuizContext {
        audio_available: false,
        ..*context
    }
}

pub fn drill<'a>(store: &'a ContentStore, id: &str) -> &'a DrillDef {
    store.drill_by_id(id).expect(id)
}

pub fn options(question: &Question) -> &[ChoiceOption] {
    match &question.body {
        QuestionBody::Choice { options, .. } => options,
        other => panic!("預期 Choice，得到 {other:?}"),
    }
}

pub fn option_ids(question: &Question) -> Vec<&str> {
    options(question).iter().map(|o| o.id.as_str()).collect()
}

pub fn option_texts(question: &Question) -> Vec<&str> {
    options(question).iter().map(|o| o.text.as_str()).collect()
}

pub fn sorted(mut items: Vec<&str>) -> Vec<&str> {
    items.sort_unstable();
    items
}

pub fn correct_id(question: &Question) -> &str {
    match &question.body {
        QuestionBody::Choice {
            correct_option_id, ..
        } => correct_option_id,
        other => panic!("預期 Choice，得到 {other:?}"),
    }
}

pub fn blank_index(question: &Question) -> Option<u32> {
    match &question.body {
        QuestionBody::Choice {
            blank_word_index, ..
        } => *blank_word_index,
        other => panic!("預期 Choice，得到 {other:?}"),
    }
}

pub fn chunk_order(question: &Question) -> Vec<u32> {
    match &question.body {
        QuestionBody::Reorder { chunks, .. } => chunks.iter().map(|c| c.index).collect(),
        other => panic!("預期 Reorder，得到 {other:?}"),
    }
}

pub fn accept_orders(question: &Question) -> &[Vec<u32>] {
    match &question.body {
        QuestionBody::Reorder { accept_orders, .. } => accept_orders,
        other => panic!("預期 Reorder，得到 {other:?}"),
    }
}

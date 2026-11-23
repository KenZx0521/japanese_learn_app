//! 新內容切分（§7.3）。不存切分結果，換方案時依新的額度重新切。

use std::collections::HashSet;

use jp_content::schema::DialogueKind;
use jp_content::ContentStore;
use serde::{Deserialize, Serialize};

use crate::budget::NewContentMode;
use crate::input::is_kana_lesson;
use crate::slice_kana::kana_lesson_slice;
use crate::state::{completed_main_lessons, cursor, CursorState};

pub const FIRST_KANA_BATCH: u32 = 3;
pub const MINIMAL_SLICE_ITEMS: u32 = 3;
const MINIMAL_GRAMMAR_ITEMS: usize = 1;
const TEN_MINUTE_PLAN: u32 = 10;
const TEN_MINUTE_INTEGRATION_DAYS: u32 = 2;
const NORMAL_INTEGRATION_DAYS: u32 = 1;
const ROTATION_EVERY_LESSONS: u32 = 3;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SliceQuota {
    pub mode: NewContentMode,
    pub words: u32,
    pub kana: u32,
    pub integration_days_needed: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Slice {
    Kana {
        lesson_ids: Vec<String>,
        kana: Vec<String>,
        rules: Vec<String>,
    },
    KanaRule {
        lesson_id: String,
        rules: Vec<String>,
        confusables: Vec<String>,
    },
    Vocab {
        lesson_id: String,
        words: Vec<String>,
        grammar: Vec<String>,
    },
    Integration {
        lesson_id: String,
        dialogue_id: Option<String>,
        phases: Vec<u32>,
        day_no: u32,
    },
}

impl Slice {
    /// 切片第一個項目的 ID，組成 `new:<ID>` 的 key；沒有項目時退回課 ID。
    pub fn key_item_id(&self) -> &str {
        match self {
            Self::Kana { kana, .. } => kana
                .first()
                .map_or_else(|| self.lesson_id(), String::as_str),
            Self::KanaRule {
                rules, confusables, ..
            } => rules
                .first()
                .or(confusables.first())
                .map_or_else(|| self.lesson_id(), String::as_str),
            Self::Vocab { words, grammar, .. } => words
                .first()
                .or(grammar.first())
                .map_or_else(|| self.lesson_id(), String::as_str),
            Self::Integration { lesson_id, .. } => lesson_id,
        }
    }

    /// 任務歸屬的課：`Kana` 切片跨課時取第一課。
    pub fn lesson_id(&self) -> &str {
        match self {
            Self::Kana { lesson_ids, .. } => lesson_ids.first().map_or("", String::as_str),
            Self::KanaRule { lesson_id, .. }
            | Self::Vocab { lesson_id, .. }
            | Self::Integration { lesson_id, .. } => lesson_id,
        }
    }

    pub(crate) fn lesson_ids(&self) -> Vec<String> {
        match self {
            Self::Kana { lesson_ids, .. } => lesson_ids.clone(),
            other => vec![other.lesson_id().to_owned()],
        }
    }
}

/// 10 分方案 2 天，其他 1 天。
pub fn integration_days_needed(daily_minutes: u32) -> u32 {
    if daily_minutes == TEN_MINUTE_PLAN {
        TEN_MINUTE_INTEGRATION_DAYS
    } else {
        NORMAL_INTEGRATION_DAYS
    }
}

pub fn next_slice(
    state: &CursorState,
    quota: &SliceQuota,
    content: &ContentStore,
) -> Option<Slice> {
    if quota.mode == NewContentMode::None {
        return None;
    }
    let lesson = cursor(state, content)?;
    Some(if is_kana_lesson(lesson) {
        kana_lesson_slice(lesson, state, quota, content)
    } else {
        main_lesson_slice(lesson, state, quota, content)
    })
}

fn main_lesson_slice(
    lesson_id: &str,
    state: &CursorState,
    quota: &SliceQuota,
    content: &ContentStore,
) -> Slice {
    let (words, grammar) = pending_items(lesson_id, state, content);
    if words.is_empty() && grammar.is_empty() {
        return integration_slice(lesson_id, state, quota, content);
    }
    let (word_count, grammar_count) = match quota.mode {
        NewContentMode::Minimal => minimal_counts(&words),
        _ => full_counts(words.len(), grammar.len(), quota.words as usize),
    };
    Slice::Vocab {
        lesson_id: lesson_id.to_owned(),
        words: words.into_iter().take(word_count).collect(),
        grammar: grammar.into_iter().take(grammar_count).collect(),
    }
}

fn pending_items(
    lesson_id: &str,
    state: &CursorState,
    content: &ContentStore,
) -> (Vec<String>, Vec<String>) {
    let Some(items) = content.lesson_items(lesson_id) else {
        return (Vec::new(), Vec::new());
    };
    let unseen = |id: &String| !state.introduced.contains(id);
    let words = items
        .words
        .iter()
        .map(|&i| content.vocab()[i as usize].def.id.clone())
        .filter(unseen)
        .collect();
    let grammar = items
        .grammar
        .iter()
        .map(|&i| content.grammar()[i as usize].id.clone())
        .filter(unseen)
        .collect();
    (words, grammar)
}

/// 單字天數平均分配文法點，先多後少。
fn full_counts(word_count: usize, grammar_count: usize, limit: usize) -> (usize, usize) {
    let days = word_count.div_ceil(limit.max(1)).max(1);
    (limit.min(word_count), grammar_count.div_ceil(days))
}

/// 3 筆單字；該課只剩文法時 1 個文法點。
fn minimal_counts(words: &[String]) -> (usize, usize) {
    if words.is_empty() {
        (0, MINIMAL_GRAMMAR_ITEMS)
    } else {
        (MINIMAL_SLICE_ITEMS as usize, 0)
    }
}

fn integration_slice(
    lesson_id: &str,
    state: &CursorState,
    quota: &SliceQuota,
    content: &ContentStore,
) -> Slice {
    let days_done = state.integration_days.get(lesson_id).copied().unwrap_or(0);
    let day_no = days_done + 1;
    Slice::Integration {
        lesson_id: lesson_id.to_owned(),
        dialogue_id: integration_dialogue(lesson_id, state, content),
        phases: integration_phases(quota.integration_days_needed, day_no),
        day_no,
    }
}

fn integration_phases(days_needed: u32, day_no: u32) -> Vec<u32> {
    match (days_needed, day_no) {
        (TEN_MINUTE_INTEGRATION_DAYS, 1) => vec![1, 2],
        (TEN_MINUTE_INTEGRATION_DAYS, _) => vec![3, 4],
        _ => vec![1, 2, 3, 4],
    }
}

fn integration_dialogue(
    lesson_id: &str,
    state: &CursorState,
    content: &ContentStore,
) -> Option<String> {
    if let Some(scheduled) = state.integration_dialogues.get(lesson_id) {
        return Some(scheduled.clone());
    }
    rotation_dialogue(lesson_id, state, content)
        .or_else(|| content.lesson(lesson_id).and_then(|l| l.dialogue.clone()))
}

/// 每完成 3 課（不含略過）排 1 篇 `pos(lesson) ≤ pos(游標)`、尚未排過的實戰或常體版對話。
fn rotation_dialogue(
    lesson_id: &str,
    state: &CursorState,
    content: &ContentStore,
) -> Option<String> {
    let done = completed_main_lessons(state, content);
    if done == 0 || !done.is_multiple_of(ROTATION_EVERY_LESSONS) {
        return None;
    }
    let cursor_pos = content.lesson_pos(lesson_id)?;
    let used: HashSet<&str> = state
        .integration_dialogues
        .values()
        .map(String::as_str)
        .collect();
    content
        .dialogues()
        .iter()
        .map(|entry| &entry.def)
        .enumerate()
        .filter(|(_, d)| matches!(d.kind, DialogueKind::Extra | DialogueKind::Casual))
        .filter(|(_, d)| !d.retired && !used.contains(d.id.as_str()))
        .filter_map(|(index, d)| {
            let pos = content
                .lesson_pos(&d.lesson)
                .filter(|pos| *pos <= cursor_pos)?;
            Some(((pos, index), d.id.clone()))
        })
        .min_by_key(|(order, _)| *order)
        .map(|(_, id)| id)
}

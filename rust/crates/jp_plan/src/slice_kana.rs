//! 假名切片（§7.3 表格的 K／KK 列）。

use std::collections::HashSet;

use jp_content::schema::{KanaDef, KanaKind};
use jp_content::ContentStore;

use crate::budget::NewContentMode;
use crate::input::is_kana_lesson;
use crate::slice::{Slice, SliceQuota, FIRST_KANA_BATCH, MINIMAL_SLICE_ITEMS};
use crate::state::CursorState;

const FIRST_LESSON: &str = "le.k01";

fn lesson_kana<'c>(lesson_id: &str, content: &'c ContentStore) -> Vec<&'c KanaDef> {
    content
        .lesson_items(lesson_id)
        .map_or(&[][..], |items| items.kana.as_slice())
        .iter()
        .map(|&index| &content.kana()[index as usize].def)
        .collect()
}

fn pending_kana<'c>(
    lesson_id: &str,
    state: &CursorState,
    content: &'c ContentStore,
) -> Vec<&'c KanaDef> {
    lesson_kana(lesson_id, content)
        .into_iter()
        .filter(|kana| kana.kind != KanaKind::Mark && !state.introduced.contains(&kana.id))
        .collect()
}

fn lesson_rules(lesson_id: &str, state: &CursorState, content: &ContentStore) -> Vec<String> {
    content
        .lesson_items(lesson_id)
        .map_or(&[][..], |items| items.rules.as_slice())
        .iter()
        .map(|&index| content.rule_cards()[index as usize].id.clone())
        .filter(|id| !state.introduced.contains(id))
        .collect()
}

fn lesson_confusables(lesson_id: &str, state: &CursorState, content: &ContentStore) -> Vec<String> {
    content
        .lesson_items(lesson_id)
        .map_or(&[][..], |items| items.confusables.as_slice())
        .iter()
        .map(|&index| content.confusables()[index as usize].id.clone())
        .filter(|id| !state.introduced.contains(id))
        .collect()
}

/// 整個計畫的第一批：`le.k01` 還沒有任何 `item_intro`。
fn is_first_batch(state: &CursorState, content: &ContentStore) -> bool {
    !lesson_kana(FIRST_LESSON, content)
        .iter()
        .any(|kana| state.introduced.contains(&kana.id))
}

fn kana_budget(quota: &SliceQuota, state: &CursorState, content: &ContentStore) -> u32 {
    let base = if is_first_batch(state, content) {
        FIRST_KANA_BATCH
    } else {
        quota.kana
    };
    if quota.mode == NewContentMode::Minimal {
        base.min(MINIMAL_SLICE_ITEMS)
    } else {
        base
    }
}

/// 累計取字進度：一般字 1 額度，拗音整行 1 額度。
struct KanaTake<'c> {
    budget: u32,
    spent: u32,
    is_minimal: bool,
    is_stopped: bool,
    kana: Vec<String>,
    rows: HashSet<&'c str>,
}

impl<'c> KanaTake<'c> {
    fn new(budget: u32, is_minimal: bool) -> Self {
        Self {
            budget,
            spent: 0,
            is_minimal,
            is_stopped: false,
            kana: Vec::new(),
            rows: HashSet::new(),
        }
    }

    fn is_full(&self) -> bool {
        self.is_stopped || self.spent >= self.budget
    }

    fn take_row(&mut self, row: &'c str, pending: &[&'c KanaDef]) {
        if !self.rows.insert(row) {
            return;
        }
        if self.is_minimal && !self.kana.is_empty() {
            self.is_stopped = true;
            return;
        }
        self.kana.extend(
            pending
                .iter()
                .filter(|kana| kana.row.as_deref() == Some(row))
                .map(|kana| kana.id.clone()),
        );
        self.spent += 1;
        self.is_stopped = self.is_minimal;
    }

    fn take_lesson(&mut self, pending: &[&'c KanaDef]) {
        for kana in pending {
            if self.is_full() {
                return;
            }
            match kana.row.as_deref().filter(|_| kana.kind == KanaKind::Yoon) {
                Some(row) => self.take_row(row, pending),
                None => {
                    self.kana.push(kana.id.clone());
                    self.spent += 1;
                }
            }
        }
    }
}

/// 從游標課起依 `course.order` 取 K／KK 課，略過已完成的課，遇到 L 課即停。
fn following_kana_lessons<'c>(
    lesson_id: &str,
    state: &CursorState,
    content: &'c ContentStore,
) -> Vec<&'c str> {
    let start = content.lesson_pos(lesson_id).map_or(0, |pos| pos as usize);
    content.course().order[start..]
        .iter()
        .map(String::as_str)
        .take_while(|id| is_kana_lesson(id))
        .filter(|id| !state.is_completed(id))
        .collect()
}

fn rule_slice(lesson_id: &str, state: &CursorState, content: &ContentStore) -> Slice {
    Slice::KanaRule {
        lesson_id: lesson_id.to_owned(),
        rules: lesson_rules(lesson_id, state, content),
        confusables: lesson_confusables(lesson_id, state, content),
    }
}

pub(crate) fn kana_lesson_slice(
    lesson_id: &str,
    state: &CursorState,
    quota: &SliceQuota,
    content: &ContentStore,
) -> Slice {
    if pending_kana(lesson_id, state, content).is_empty() {
        return rule_slice(lesson_id, state, content);
    }
    let is_minimal = quota.mode == NewContentMode::Minimal;
    let mut take = KanaTake::new(kana_budget(quota, state, content), is_minimal);
    let mut lesson_ids = Vec::new();
    let mut rules = Vec::new();
    for lesson in following_kana_lessons(lesson_id, state, content) {
        let pending = pending_kana(lesson, state, content);
        if take.is_full() || pending.is_empty() {
            break;
        }
        let before = take.kana.len();
        take.take_lesson(&pending);
        if take.kana.len() > before {
            lesson_ids.push(lesson.to_owned());
            rules.extend(lesson_rules(lesson, state, content));
        }
    }
    Slice::Kana {
        lesson_ids,
        kana: take.kana,
        rules,
    }
}

//! 學習迴路模擬檢查用的內容索引（`loop_invariants` 的條文依此判斷）。

use std::collections::HashMap;

use jp_content::ContentStore;

/// ID → 所屬課（或其他一個字串欄位）。
type IdMap = HashMap<String, String>;

pub struct ContentFacts {
    pub(super) order: Vec<String>,
    pos: HashMap<String, u32>,
    pub(super) vocab: IdMap,
    pub(super) grammar: IdMap,
    pub(super) milestones: IdMap,
    pub(super) sentence_refs: HashMap<String, Vec<String>>,
}

fn sentence_refs(content: &ContentStore) -> HashMap<String, Vec<String>> {
    content
        .sentences()
        .iter()
        .zip(0u32..)
        .map(|(entry, index)| {
            let refs = content.sentence_ref_ids(index).map(str::to_owned).collect();
            (entry.def.id.clone(), refs)
        })
        .collect()
}

fn vocab_lessons(content: &ContentStore) -> IdMap {
    content
        .vocab()
        .iter()
        .map(|v| (v.def.id.clone(), v.def.lesson.clone()))
        .collect()
}

fn lesson_maps(content: &ContentStore) -> (IdMap, IdMap) {
    let grammar = content
        .grammar()
        .iter()
        .map(|g| (g.id.clone(), g.lesson.clone()))
        .collect();
    let milestones = content
        .milestones()
        .iter()
        .map(|m| (m.id.clone(), m.lesson.clone()))
        .collect();
    (grammar, milestones)
}

impl ContentFacts {
    pub fn new(content: &ContentStore) -> Self {
        let order = content.course().order.clone();
        let (grammar, milestones) = lesson_maps(content);
        Self {
            pos: order
                .iter()
                .filter_map(|id| Some((id.clone(), content.lesson_pos(id)?)))
                .collect(),
            order,
            vocab: vocab_lessons(content),
            grammar,
            milestones,
            sentence_refs: sentence_refs(content),
        }
    }

    pub(super) fn pos(&self, lesson: &str) -> Option<u32> {
        self.pos.get(lesson).copied()
    }

    pub(super) fn at_or_before_cursor(&self, lesson: &str, cursor: Option<&str>) -> bool {
        cursor.is_none_or(|c| self.pos(lesson).is_some() && self.pos(lesson) <= self.pos(c))
    }

    /// 游標從 `before` 走到 `after` 之間完成的課。
    pub(super) fn passed_lessons(&self, before: Option<&str>, after: Option<&str>) -> Vec<String> {
        let start = before.and_then(|id| self.pos(id)).unwrap_or(u32::MAX);
        let end = after.and_then(|id| self.pos(id)).unwrap_or(u32::MAX);
        self.order
            .iter()
            .filter(|id| self.pos(id).is_some_and(|p| p >= start && p < end))
            .cloned()
            .collect()
    }
}

//! 切片完成時的進度變化，`complete_task` 與 `forecast` 共用。

use std::collections::HashSet;

use chrono::NaiveDate;
use jp_content::schema::KanaKind;
use jp_content::ContentStore;

use crate::slice::Slice;
use crate::state::CursorState;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IntroItem {
    pub item_id: String,
    pub lesson_id: String,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SliceEffects {
    pub intros: Vec<IntroItem>,
    pub completed_lessons: Vec<String>,
}

fn intro_of(item_id: &str, lesson_id: &str) -> IntroItem {
    IntroItem {
        item_id: item_id.to_owned(),
        lesson_id: lesson_id.to_owned(),
    }
}

fn kana_or_rule_lesson(id: &str, content: &ContentStore) -> Option<String> {
    content
        .kana_by_id(id)
        .map(|kana| kana.def.lesson.clone())
        .or_else(|| content.rule_card_by_id(id).map(|rule| rule.lesson.clone()))
}

/// K／KK 課：全部非 `mark` 的字與規則卡都介紹了。
fn kana_lesson_is_complete(lesson_id: &str, known: &HashSet<&str>, content: &ContentStore) -> bool {
    let Some(items) = content.lesson_items(lesson_id) else {
        return false;
    };
    let kana_done = items.kana.iter().all(|&index| {
        let kana = &content.kana()[index as usize].def;
        kana.kind == KanaKind::Mark || known.contains(kana.id.as_str())
    });
    kana_done
        && items
            .rules
            .iter()
            .all(|&index| known.contains(content.rule_cards()[index as usize].id.as_str()))
}

/// 課完成時一併補寫該課 `mark` 與 `ka.cf.*` 的 `item_intro`。
fn completion_intros(
    lesson_id: &str,
    known: &HashSet<&str>,
    content: &ContentStore,
) -> Vec<IntroItem> {
    let Some(items) = content.lesson_items(lesson_id) else {
        return Vec::new();
    };
    let marks = items
        .kana
        .iter()
        .map(|&index| &content.kana()[index as usize].def)
        .filter(|kana| kana.kind == KanaKind::Mark)
        .map(|kana| kana.id.as_str());
    let confusables = items
        .confusables
        .iter()
        .map(|&index| content.confusables()[index as usize].id.as_str());
    marks
        .chain(confusables)
        .filter(|id| !known.contains(id))
        .map(|id| intro_of(id, lesson_id))
        .collect()
}

fn kana_effects(
    lesson_ids: &[String],
    written: Vec<IntroItem>,
    state: &CursorState,
    content: &ContentStore,
) -> SliceEffects {
    let known: HashSet<&str> = state
        .introduced
        .iter()
        .map(String::as_str)
        .chain(written.iter().map(|item| item.item_id.as_str()))
        .collect();
    let completed_lessons: Vec<String> = lesson_ids
        .iter()
        .filter(|lesson| kana_lesson_is_complete(lesson, &known, content))
        .cloned()
        .collect();
    let extras: Vec<IntroItem> = completed_lessons
        .iter()
        .flat_map(|lesson| completion_intros(lesson, &known, content))
        .collect();
    SliceEffects {
        intros: written.into_iter().chain(extras).collect(),
        completed_lessons,
    }
}

/// `Kana`、`KanaRule`、`Vocab` 切片完成後要寫的 `item_intro` 與達成完成條件的課。
pub fn slice_effects(slice: &Slice, state: &CursorState, content: &ContentStore) -> SliceEffects {
    match slice {
        Slice::Kana {
            lesson_ids,
            kana,
            rules,
        } => {
            let written = kana
                .iter()
                .chain(rules)
                .filter_map(|id| Some(intro_of(id, &kana_or_rule_lesson(id, content)?)))
                .collect();
            kana_effects(lesson_ids, written, state, content)
        }
        Slice::KanaRule {
            lesson_id,
            rules,
            confusables,
        } => {
            let written = rules
                .iter()
                .chain(confusables)
                .map(|id| intro_of(id, lesson_id))
                .collect();
            kana_effects(std::slice::from_ref(lesson_id), written, state, content)
        }
        Slice::Vocab {
            lesson_id,
            words,
            grammar,
        } => SliceEffects {
            intros: words
                .iter()
                .chain(grammar)
                .map(|id| intro_of(id, lesson_id))
                .collect(),
            completed_lessons: Vec::new(),
        },
        Slice::Integration { .. } => SliceEffects::default(),
    }
}

/// L 課：項目都介紹完，且這次整合之後達到所需天數。
pub fn integration_completes(
    lesson_id: &str,
    days_after: u32,
    days_needed: u32,
    state: &CursorState,
    content: &ContentStore,
) -> bool {
    let Some(items) = content.lesson_items(lesson_id) else {
        return false;
    };
    let words_done = items.words.iter().all(|&i| {
        state
            .introduced
            .contains(&content.vocab()[i as usize].def.id)
    });
    let grammar_done = items
        .grammar
        .iter()
        .all(|&i| state.introduced.contains(&content.grammar()[i as usize].id));
    words_done && grammar_done && days_after >= days_needed
}

/// 模擬用：把切片效果套用到狀態。
pub fn apply_effects(state: &mut CursorState, effects: &SliceEffects, on: NaiveDate) {
    state
        .introduced
        .extend(effects.intros.iter().map(|item| item.item_id.clone()));
    for lesson in &effects.completed_lessons {
        state.completed.entry(lesson.clone()).or_insert(on);
    }
}

//! `CONTENT_STAGE` 過濾與軟引用修剪（rust-core.md §3.4 第 2、5 步）。

use std::collections::HashSet;

use crate::raw::{item_ids, RawContent};
use crate::schema::{ContentStage, CourseDef, DrillDef, GrammarDef, KanaDef, NoteDef, VocabDef};

/// `content_stage` 不高於 `stage` 的課。
pub fn included_lessons(course: &CourseDef, stage: ContentStage) -> HashSet<String> {
    course
        .lessons
        .iter()
        .filter(|lesson| lesson.content_stage <= stage)
        .map(|lesson| lesson.id.clone())
        .collect()
}

fn filter_course(course: CourseDef, included: &HashSet<String>) -> CourseDef {
    let lessons: Vec<_> = course
        .lessons
        .into_iter()
        .filter(|lesson| included.contains(&lesson.id))
        .collect();
    let used_stages: HashSet<&str> = lessons.iter().map(|lesson| lesson.stage.as_str()).collect();
    let stages = course
        .stages
        .into_iter()
        .filter(|stage| used_stages.contains(stage.id.as_str()))
        .collect();
    let order = course
        .order
        .into_iter()
        .filter(|id| included.contains(id))
        .collect();
    CourseDef {
        schema: course.schema,
        stages,
        order,
        lessons,
    }
}

fn filter_notes(
    notes: Vec<NoteDef>,
    stage: ContentStage,
    included: &HashSet<String>,
) -> Vec<NoteDef> {
    if stage == ContentStage::P0a {
        return Vec::new();
    }
    notes
        .into_iter()
        .filter(|note| note.lesson().is_none_or(|lesson| included.contains(lesson)))
        .collect()
}

/// `p0a` 略過全部 `no.*`，以筆記為硬引用的 `false_friend` 演練也一併略過。
/// 其他階段照常保留，筆記 ID 打錯時仍會被硬引用檢查抓到。
fn filter_drills(
    drills: Vec<DrillDef>,
    stage: ContentStage,
    included: &HashSet<String>,
) -> Vec<DrillDef> {
    keep_by_lesson(drills, included, |d| d.lesson())
        .into_iter()
        .filter(|d| stage != ContentStage::P0a || !matches!(d, DrillDef::FalseFriend { .. }))
        .collect()
}

fn keep_by_lesson<T>(
    items: Vec<T>,
    included: &HashSet<String>,
    lesson: impl Fn(&T) -> &str,
) -> Vec<T> {
    items
        .into_iter()
        .filter(|item| included.contains(lesson(item)))
        .collect()
}

/// 只留 `stage` 範圍內的內容。`presets` 永遠保留。
pub fn filter_stage(raw: RawContent, stage: ContentStage) -> RawContent {
    let included = included_lessons(&raw.course, stage);
    RawContent {
        course: filter_course(raw.course, &included),
        kana: keep_by_lesson(raw.kana, &included, |k| &k.lesson),
        confusables: keep_by_lesson(raw.confusables, &included, |c| &c.lesson),
        rule_cards: keep_by_lesson(raw.rule_cards, &included, |c| &c.lesson),
        sound_groups: keep_by_lesson(raw.sound_groups, &included, |s| &s.lesson),
        vocab: keep_by_lesson(raw.vocab, &included, |v| &v.lesson),
        grammar: keep_by_lesson(raw.grammar, &included, |g| &g.lesson),
        sentences: keep_by_lesson(raw.sentences, &included, |s| &s.lesson),
        drills: filter_drills(raw.drills, stage, &included),
        dialogues: keep_by_lesson(raw.dialogues, &included, |d| &d.lesson),
        notes: filter_notes(raw.notes, stage, &included),
        presets: raw.presets,
        milestones: keep_by_lesson(raw.milestones, &included, |m| &m.lesson),
    }
}

fn retain_present(ids: Vec<String>, present: &HashSet<String>) -> Vec<String> {
    ids.into_iter().filter(|id| present.contains(id)).collect()
}

fn prune_vocab(mut vocab: VocabDef, present: &HashSet<String>) -> VocabDef {
    vocab.examples = retain_present(vocab.examples, present);
    vocab.notes = retain_present(vocab.notes, present);
    vocab.reading_family = retain_present(vocab.reading_family, present);
    vocab.pair = vocab.pair.filter(|id| present.contains(id));
    vocab
}

fn prune_grammar(mut grammar: GrammarDef, present: &HashSet<String>) -> GrammarDef {
    grammar.examples = retain_present(grammar.examples, present);
    grammar.contrast = retain_present(grammar.contrast, present);
    grammar.terms = retain_present(grammar.terms, present);
    grammar
}

fn prune_kana(mut kana: KanaDef, present: &HashSet<String>) -> KanaDef {
    kana.confusable = retain_present(kana.confusable, present);
    kana
}

fn prune_note(note: NoteDef, present: &HashSet<String>) -> NoteDef {
    match note {
        NoteDef::FalseFriend(mut n) => {
            n.vocab = n.vocab.filter(|id| present.contains(id));
            NoteDef::FalseFriend(n)
        }
        NoteDef::Shinjitai(mut n) => {
            n.vocab = retain_present(n.vocab, present);
            NoteDef::Shinjitai(n)
        }
        NoteDef::Reading(mut n) => {
            n.vocab = retain_present(n.vocab, present);
            NoteDef::Reading(n)
        }
        NoteDef::Transfer(mut n) => {
            n.vocab = retain_present(n.vocab, present);
            n.grammar = retain_present(n.grammar, present);
            NoteDef::Transfer(n)
        }
        NoteDef::Term(mut n) => {
            n.grammar = retain_present(n.grammar, present);
            NoteDef::Term(n)
        }
    }
}

/// 軟引用可以指向被階段過濾掉的項目，這裡把它們從欄位移除。
pub fn prune_soft_refs(raw: RawContent) -> RawContent {
    let present: HashSet<String> = item_ids(&raw)
        .into_iter()
        .map(|(id, _)| id.to_owned())
        .collect();
    RawContent {
        vocab: raw
            .vocab
            .into_iter()
            .map(|v| prune_vocab(v, &present))
            .collect(),
        grammar: raw
            .grammar
            .into_iter()
            .map(|g| prune_grammar(g, &present))
            .collect(),
        kana: raw
            .kana
            .into_iter()
            .map(|k| prune_kana(k, &present))
            .collect(),
        notes: raw
            .notes
            .into_iter()
            .map(|n| prune_note(n, &present))
            .collect(),
        ..raw
    }
}

//! `ContentStore` 與索引（rust-core.md §3.4）。

use std::collections::{HashMap, HashSet};

use crate::schema::{
    ConfusableDef, ContentStage, DialogueDef, DrillDef, GrammarDef, KanaDef, LessonDef,
    MilestoneDef, NoteDef, PlanPresetDef, Pos, RuleCardDef, SentenceDef, SoundGroupDef, StageDef,
    VocabDef,
};
use crate::sentence::{ParsedSentence, Speech};

mod build;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ItemKind {
    Stage,
    Lesson,
    Kana,
    Confusable,
    RuleCard,
    SoundGroup,
    Vocab,
    Grammar,
    Sentence,
    Drill,
    Dialogue,
    Note,
    Preset,
    Milestone,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ItemRef {
    pub kind: ItemKind,
    pub index: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct KanaEntry {
    pub def: KanaDef,
    pub romaji: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct VocabEntry {
    pub def: VocabDef,
    pub romaji: String,
    pub speech: Speech,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SentenceEntry {
    pub def: SentenceDef,
    pub parsed: ParsedSentence,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DialogueEntry {
    pub def: DialogueDef,
    pub turns: Vec<ParsedSentence>,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct CourseIndex {
    pub stages: Vec<StageDef>,
    pub order: Vec<String>,
    /// 依 `order` 排序。
    pub lessons: Vec<LessonDef>,
}

/// 由各項目 `lesson` 反查，索引指向對應的 `Vec`。淘汰項目不列入。
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct LessonItems {
    pub kana: Vec<u32>,
    pub rules: Vec<u32>,
    pub confusables: Vec<u32>,
    pub sound_groups: Vec<u32>,
    /// 依 `lesson_order`。
    pub words: Vec<u32>,
    /// 依 `lesson_order`。
    pub grammar: Vec<u32>,
    pub sentences: Vec<u32>,
    pub drills: Vec<u32>,
    pub dialogues: Vec<u32>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ContentStore {
    stage: ContentStage,
    kana: Vec<KanaEntry>,
    confusables: Vec<ConfusableDef>,
    rule_cards: Vec<RuleCardDef>,
    sound_groups: Vec<SoundGroupDef>,
    vocab: Vec<VocabEntry>,
    grammar: Vec<GrammarDef>,
    sentences: Vec<SentenceEntry>,
    drills: Vec<DrillDef>,
    dialogues: Vec<DialogueEntry>,
    notes: Vec<NoteDef>,
    course: CourseIndex,
    presets: Vec<PlanPresetDef>,
    milestones: Vec<MilestoneDef>,
    id_index: HashMap<String, ItemRef>,
    lesson_pos: HashMap<String, u32>,
    items_by_lesson: HashMap<String, LessonItems>,
    sentence_refs: Vec<Box<[u32]>>,
    ref_ids: Vec<String>,
    drills_by_target: HashMap<String, Vec<u32>>,
    vocab_by_pos: HashMap<Pos, Vec<u32>>,
    vocab_by_topic: HashMap<String, Vec<u32>>,
}

impl ContentStore {
    pub fn stage(&self) -> ContentStage {
        self.stage
    }

    pub fn course(&self) -> &CourseIndex {
        &self.course
    }

    pub fn item_ref(&self, id: &str) -> Option<ItemRef> {
        self.id_index.get(id).copied()
    }

    fn lookup<'s, T>(&'s self, id: &str, kind: ItemKind, items: &'s [T]) -> Option<&'s T> {
        self.item_ref(id)
            .filter(|item| item.kind == kind)
            .map(|item| &items[item.index as usize])
    }

    /// 依 `course.order` 的位置。不在當前階段的課回 `None`。
    pub fn lesson_pos(&self, id: &str) -> Option<u32> {
        self.lesson_pos.get(id).copied()
    }

    pub fn lesson(&self, id: &str) -> Option<&LessonDef> {
        self.lesson_pos(id)
            .map(|pos| &self.course.lessons[pos as usize])
    }

    pub fn lesson_items(&self, id: &str) -> Option<&LessonItems> {
        self.items_by_lesson.get(id)
    }

    pub fn kana(&self) -> &[KanaEntry] {
        &self.kana
    }

    pub fn kana_by_id(&self, id: &str) -> Option<&KanaEntry> {
        self.lookup(id, ItemKind::Kana, &self.kana)
    }

    pub fn confusables(&self) -> &[ConfusableDef] {
        &self.confusables
    }

    pub fn confusable_by_id(&self, id: &str) -> Option<&ConfusableDef> {
        self.lookup(id, ItemKind::Confusable, &self.confusables)
    }

    pub fn rule_cards(&self) -> &[RuleCardDef] {
        &self.rule_cards
    }

    pub fn rule_card_by_id(&self, id: &str) -> Option<&RuleCardDef> {
        self.lookup(id, ItemKind::RuleCard, &self.rule_cards)
    }

    pub fn sound_groups(&self) -> &[SoundGroupDef] {
        &self.sound_groups
    }

    pub fn sound_group_by_id(&self, id: &str) -> Option<&SoundGroupDef> {
        self.lookup(id, ItemKind::SoundGroup, &self.sound_groups)
    }

    pub fn vocab(&self) -> &[VocabEntry] {
        &self.vocab
    }

    pub fn vocab_by_id(&self, id: &str) -> Option<&VocabEntry> {
        self.lookup(id, ItemKind::Vocab, &self.vocab)
    }

    pub fn grammar(&self) -> &[GrammarDef] {
        &self.grammar
    }

    pub fn grammar_by_id(&self, id: &str) -> Option<&GrammarDef> {
        self.lookup(id, ItemKind::Grammar, &self.grammar)
    }

    pub fn sentences(&self) -> &[SentenceEntry] {
        &self.sentences
    }

    pub fn sentence_by_id(&self, id: &str) -> Option<&SentenceEntry> {
        self.lookup(id, ItemKind::Sentence, &self.sentences)
    }

    pub fn sentence_index(&self, id: &str) -> Option<u32> {
        self.item_ref(id)
            .filter(|item| item.kind == ItemKind::Sentence)
            .map(|item| item.index)
    }

    pub fn drills(&self) -> &[DrillDef] {
        &self.drills
    }

    pub fn drill_by_id(&self, id: &str) -> Option<&DrillDef> {
        self.lookup(id, ItemKind::Drill, &self.drills)
    }

    pub fn dialogues(&self) -> &[DialogueEntry] {
        &self.dialogues
    }

    pub fn dialogue_by_id(&self, id: &str) -> Option<&DialogueEntry> {
        self.lookup(id, ItemKind::Dialogue, &self.dialogues)
    }

    pub fn notes(&self) -> &[NoteDef] {
        &self.notes
    }

    pub fn note_by_id(&self, id: &str) -> Option<&NoteDef> {
        self.lookup(id, ItemKind::Note, &self.notes)
    }

    pub fn presets(&self) -> &[PlanPresetDef] {
        &self.presets
    }

    pub fn preset_by_id(&self, id: &str) -> Option<&PlanPresetDef> {
        self.lookup(id, ItemKind::Preset, &self.presets)
    }

    pub fn milestones(&self) -> &[MilestoneDef] {
        &self.milestones
    }

    pub fn milestone_for_lesson(&self, lesson: &str) -> Option<&MilestoneDef> {
        self.milestones.iter().find(|m| m.lesson == lesson)
    }

    pub fn sentence_ref_ids(&self, index: u32) -> impl Iterator<Item = &str> {
        self.sentence_refs[index as usize]
            .iter()
            .map(|&r| self.ref_ids[r as usize].as_str())
    }

    /// 句子的 `vo.*`、`gr.*` 引用都在已知集合內（§7.3）。
    pub fn sentence_is_usable(&self, index: u32, known: &HashSet<String>) -> bool {
        self.sentence_ref_ids(index).all(|r| known.contains(r))
    }

    pub fn drills_for_target(&self, target: &str) -> &[u32] {
        self.drills_by_target.get(target).map_or(&[], Vec::as_slice)
    }

    /// 同 `pos.family()` 的單字，所以 `v1` 與 `v1_s` 回傳同一組。
    pub fn vocab_with_pos(&self, pos: Pos) -> &[u32] {
        self.vocab_by_pos
            .get(&pos.family())
            .map_or(&[], Vec::as_slice)
    }

    pub fn vocab_with_topic(&self, topic: &str) -> &[u32] {
        self.vocab_by_topic.get(topic).map_or(&[], Vec::as_slice)
    }
}

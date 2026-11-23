//! 規則共用的索引。

use std::collections::{HashMap, HashSet};

use jp_lang::kana::{Morph, Word};

use crate::raw::RawContent;
use crate::refs::{t_sites, TSite};
use crate::schema::{ContentStage, DrillDef, GrammarDef, NoteDef, VocabDef};
use crate::sentence::parse_t;

use super::lists::LintLists;

pub(super) const UNTAUGHT: &str = "未教學";
pub(super) const LESSON_REF_PREFIXES: [&str; 2] = ["vo.", "gr."];

/// 成功解析的 `t`。解析失敗的 `t` 已由 R02 回報，不再進入其他規則。
pub(super) struct ParsedSite<'a> {
    pub site: TSite<'a>,
    pub words: Vec<Word>,
}

impl ParsedSite<'_> {
    pub(super) fn morphs(&self) -> impl Iterator<Item = &Morph> {
        self.words.iter().filter_map(word_morphs).flatten()
    }

    pub(super) fn display(&self) -> String {
        self.words
            .iter()
            .map(|word| match word {
                Word::Punct(punct) => punct.clone(),
                Word::Morphs(morphs) => morphs.iter().map(|m| m.surface.as_str()).collect(),
            })
            .collect()
    }
}

pub(super) fn word_morphs(word: &Word) -> Option<&Vec<Morph>> {
    match word {
        Word::Morphs(morphs) => Some(morphs),
        Word::Punct(_) => None,
    }
}

pub(super) struct Ctx<'a> {
    /// 當前階段的內容，尚未修剪軟引用。
    pub raw: &'a RawContent,
    pub stage: ContentStage,
    pub lists: &'a LintLists,
    pub lesson_pos: HashMap<&'a str, u32>,
    pub item_lesson: HashMap<&'a str, &'a str>,
    pub retired: HashSet<&'a str>,
    pub vocab: HashMap<&'a str, &'a VocabDef>,
    pub grammar: HashMap<&'a str, &'a GrammarDef>,
    pub sentence_lesson: HashMap<&'a str, &'a str>,
    pub sites: Vec<ParsedSite<'a>>,
}

impl<'a> Ctx<'a> {
    pub(super) fn build(
        raw: &'a RawContent,
        all: &'a RawContent,
        stage: ContentStage,
        lists: &'a LintLists,
    ) -> Self {
        let (sites, _) = t_sites(raw);
        let parsed = sites
            .into_iter()
            .filter_map(|site| {
                let words = parse_t(&site.text).ok()?;
                Some(ParsedSite { site, words })
            })
            .collect();
        Self {
            raw,
            stage,
            lists,
            lesson_pos: lesson_positions(raw),
            item_lesson: item_lessons(raw),
            retired: retired_ids(all),
            vocab: raw.vocab.iter().map(|v| (v.id.as_str(), v)).collect(),
            grammar: raw.grammar.iter().map(|g| (g.id.as_str(), g)).collect(),
            sentence_lesson: raw
                .sentences
                .iter()
                .map(|s| (s.id.as_str(), s.lesson.as_str()))
                .collect(),
            sites: parsed,
        }
    }

    pub(super) fn pos(&self, lesson: &str) -> Option<u32> {
        self.lesson_pos.get(lesson).copied()
    }
}

fn lesson_positions(raw: &RawContent) -> HashMap<&str, u32> {
    raw.course
        .order
        .iter()
        .enumerate()
        .map(|(position, id)| (id.as_str(), position as u32))
        .collect()
}

fn item_lessons(raw: &RawContent) -> HashMap<&str, &str> {
    let mut lessons: HashMap<&str, &str> = HashMap::new();
    lessons.extend(raw.kana.iter().map(|k| (k.id.as_str(), k.lesson.as_str())));
    lessons.extend(raw.vocab.iter().map(|v| (v.id.as_str(), v.lesson.as_str())));
    lessons.extend(
        raw.grammar
            .iter()
            .map(|g| (g.id.as_str(), g.lesson.as_str())),
    );
    lessons
}

fn extend_retired<'a, T>(
    retired: &mut HashSet<&'a str>,
    items: &'a [T],
    is_retired: impl Fn(&T) -> bool,
    id: impl Fn(&'a T) -> &'a str,
) {
    retired.extend(items.iter().filter(|item| is_retired(item)).map(id));
}

fn retired_ids(raw: &RawContent) -> HashSet<&str> {
    let mut retired = HashSet::new();
    extend_retired(&mut retired, &raw.kana, |k| k.retired, |k| &k.id);
    extend_retired(&mut retired, &raw.confusables, |c| c.retired, |c| &c.id);
    extend_retired(&mut retired, &raw.rule_cards, |c| c.retired, |c| &c.id);
    extend_retired(&mut retired, &raw.sound_groups, |s| s.retired, |s| &s.id);
    extend_retired(&mut retired, &raw.vocab, |v| v.retired, |v| &v.id);
    extend_retired(&mut retired, &raw.grammar, |g| g.retired, |g| &g.id);
    extend_retired(&mut retired, &raw.sentences, |s| s.retired, |s| &s.id);
    extend_retired(&mut retired, &raw.drills, DrillDef::retired, DrillDef::id);
    extend_retired(&mut retired, &raw.dialogues, |d| d.retired, |d| &d.id);
    extend_retired(&mut retired, &raw.notes, NoteDef::retired, NoteDef::id);
    retired
}

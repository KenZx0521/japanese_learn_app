//! `use` 卡的題目選取（§6.1）。結果交給 jp_quiz 轉成題目。

use std::collections::HashSet;

use jp_content::schema::{DistractorDef, DrillDef};
use jp_content::sentence::{expand_frame, is_inline_t, parse_t};
use jp_content::ContentStore;
use jp_lang::kana::Word;
use jp_lang::quiz::rng::fnv1a;

pub const MIN_USE_CANDIDATES: usize = 3;

const KNOWN_REF_PREFIXES: [&str; 2] = ["vo.", "gr."];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct UseQuery<'a> {
    pub content_id: &'a str,
    /// `pos(游標)`；全部課都完成時為 `None`。
    pub cursor_pos: Option<u32>,
    pub known: &'a HashSet<String>,
    pub audio_available: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UseCandidate {
    /// `ContentStore::drills()` 的下標。
    Drill(u32),
    /// `ContentStore::sentences()` 的下標，由例句自動補的 `listen_meaning`。
    AutoListenMeaning(u32),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UseSelection {
    Question(UseCandidate),
    /// 沒有候選時顯示例句自評，`question_type` 記為 `Recog`。
    SelfGradeExample(Option<u32>),
}

/// §8.6「需要語音」欄。
pub fn drill_needs_audio(drill: &DrillDef) -> bool {
    matches!(
        drill,
        DrillDef::ListenMeaning { .. }
            | DrillDef::Shadowing { .. }
            | DrillDef::MinimalPair { .. }
            | DrillDef::Reorder {
                audio_first: true,
                ..
            }
    )
}

fn is_known_ref_kind(reference: &str) -> bool {
    KNOWN_REF_PREFIXES
        .iter()
        .any(|prefix| reference.starts_with(prefix))
}

fn ref_is_known(reference: &str, known: &HashSet<String>) -> bool {
    !is_known_ref_kind(reference) || known.contains(reference)
}

/// 解析失敗代表這題做不出來，視同不可用。
fn t_is_known(t: &str, known: &HashSet<String>) -> bool {
    parse_t(t).is_ok_and(|words| {
        words
            .iter()
            .filter_map(|word| match word {
                Word::Morphs(morphs) => Some(morphs),
                Word::Punct(_) => None,
            })
            .flatten()
            .all(|morph| ref_is_known(&morph.r#ref, known))
    })
}

fn sentence_is_known(id: &str, known: &HashSet<String>, content: &ContentStore) -> bool {
    content
        .sentence_index(id)
        .is_some_and(|index| content.sentence_is_usable(index, known))
}

fn t_or_sentence_is_known(text: &str, known: &HashSet<String>, content: &ContentStore) -> bool {
    if is_inline_t(text) {
        t_is_known(text, known)
    } else {
        sentence_is_known(text, known, content)
    }
}

fn body_is_known(drill: &DrillDef, known: &HashSet<String>, content: &ContentStore) -> bool {
    let sentence = |id: &str| sentence_is_known(id, known, content);
    let t = |text: &str| t_is_known(text, known);
    let answer_ok = |text: &str| t_or_sentence_is_known(text, known, content);
    let distractors_ok = |list: &[DistractorDef]| list.iter().all(|d| t(&d.t));
    match drill {
        DrillDef::Substitution { frame, rows, .. } => rows
            .iter()
            .all(|row| expand_frame(frame, &row.slots).is_ok_and(|expanded| t(&expanded))),
        DrillDef::ParticleFill {
            sentence: id,
            blanks,
            ..
        } => sentence(id) && blanks.iter().flat_map(|b| &b.choices).all(|c| t(c)),
        DrillDef::ZhToJaChoice {
            answer,
            distractors,
            ..
        } => answer_ok(answer) && distractors_ok(distractors),
        DrillDef::SituationResponse {
            prompt,
            answer,
            distractors,
            ..
        } => prompt.iter().all(|p| t(p)) && answer_ok(answer) && distractors_ok(distractors),
        DrillDef::Reorder { sentence: id, .. }
        | DrillDef::ListenMeaning { sentence: id, .. }
        | DrillDef::Shadowing { sentence: id, .. } => sentence(id),
        DrillDef::Conjugate { lemmas, .. } => lemmas.iter().all(|l| ref_is_known(l, known)),
        DrillDef::RegisterConvert { from, to, .. } => sentence(from) && sentence(to),
        DrillDef::FalseFriend { .. } | DrillDef::MinimalPair { .. } | DrillDef::KanaWord { .. } => {
            true
        }
    }
}

/// 題目內含的 `vo.*`、`gr.*` 都在已知集合內。`Drill` 任務（§7.4）與 `use` 卡共用。
pub fn drill_is_usable(drill: &DrillDef, known: &HashSet<String>, content: &ContentStore) -> bool {
    drill.targets().iter().all(|t| ref_is_known(t, known)) && body_is_known(drill, known, content)
}

fn lesson_is_reached(lesson: &str, cursor_pos: Option<u32>, content: &ContentStore) -> bool {
    content
        .lesson_pos(lesson)
        .is_some_and(|pos| cursor_pos.is_none_or(|cursor| pos <= cursor))
}

/// `listen_disabled` 的 `minimal_pair` 一律不出題（§8.4）。
pub fn is_listen_disabled(drill: &DrillDef) -> bool {
    matches!(
        drill,
        DrillDef::MinimalPair {
            listen_disabled: true,
            ..
        }
    )
}

fn drill_candidates(query: &UseQuery<'_>, content: &ContentStore) -> Vec<UseCandidate> {
    content
        .drills_for_target(query.content_id)
        .iter()
        .filter(|&&index| {
            let drill = &content.drills()[index as usize];
            !matches!(drill, DrillDef::Shadowing { .. })
                && !is_listen_disabled(drill)
                && (query.audio_available || !drill_needs_audio(drill))
                && lesson_is_reached(drill.lesson(), query.cursor_pos, content)
                && drill_is_usable(drill, query.known, content)
        })
        .map(|&index| UseCandidate::Drill(index))
        .collect()
}

fn item_examples<'c>(content_id: &str, content: &'c ContentStore) -> &'c [String] {
    content
        .grammar_by_id(content_id)
        .map(|grammar| grammar.examples.as_slice())
        .unwrap_or_default()
}

/// 未淘汰、課已到、`vo.*`／`gr.*` 都已知；自動補題與其干擾項共用（§8.4）。
pub fn sentence_is_usable_now(index: u32, query: &UseQuery<'_>, content: &ContentStore) -> bool {
    let entry = &content.sentences()[index as usize];
    !entry.def.retired
        && lesson_is_reached(&entry.def.lesson, query.cursor_pos, content)
        && content.sentence_is_usable(index, query.known)
}

/// §8.4：干擾項來自其他可用句子，中文相同者不算。
fn has_distractor(index: u32, query: &UseQuery<'_>, content: &ContentStore) -> bool {
    let sentences = content.sentences();
    let target_zh = &sentences[index as usize].def.zh;
    sentences.iter().zip(0u32..).any(|(other, other_index)| {
        other_index != index
            && other.def.zh != *target_zh
            && sentence_is_usable_now(other_index, query, content)
    })
}

fn auto_listen_candidates(
    query: &UseQuery<'_>,
    content: &ContentStore,
    wanted: usize,
) -> Vec<UseCandidate> {
    if !query.audio_available {
        return Vec::new();
    }
    item_examples(query.content_id, content)
        .iter()
        .filter_map(|id| content.sentence_index(id))
        .filter(|&index| {
            sentence_is_usable_now(index, query, content) && has_distractor(index, query, content)
        })
        .take(wanted)
        .map(UseCandidate::AutoListenMeaning)
        .collect()
}

pub fn use_candidates(query: &UseQuery<'_>, content: &ContentStore) -> Vec<UseCandidate> {
    let drills = drill_candidates(query, content);
    let wanted = MIN_USE_CANDIDATES.saturating_sub(drills.len());
    let top_up = auto_listen_candidates(query, content, wanted);
    drills.into_iter().chain(top_up).collect()
}

/// 沒有可用例句時回 `None`：第一次接觸不能出現還沒教的字（§6.1、§7.3）。
fn fallback_example(query: &UseQuery<'_>, content: &ContentStore) -> Option<u32> {
    item_examples(query.content_id, content)
        .iter()
        .filter_map(|id| content.sentence_index(id))
        .find(|&index| sentence_is_usable_now(index, query, content))
}

/// 取 `candidates[(reps + fnv1a(card_id)) % len]`，靠 `reps` 輪替，不需題目歷史。
pub fn select_use_question(
    query: &UseQuery<'_>,
    reps: i32,
    card_id: &str,
    content: &ContentStore,
) -> UseSelection {
    let candidates = use_candidates(query, content);
    if candidates.is_empty() {
        return UseSelection::SelfGradeExample(fallback_example(query, content));
    }
    let len = candidates.len();
    // 餘數小於 len，轉回 usize 不會截斷
    let hash_turn = (fnv1a(card_id) % len as u64) as usize;
    let reps_turn = usize::try_from(reps).unwrap_or(0);
    UseSelection::Question(candidates[(reps_turn + hash_turn) % len])
}

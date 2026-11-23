//! R12（結構部分）、RC7（含 `conj_omit`）、RC8、RC10。

use std::collections::HashSet;

use jp_lang::grammar::conjugate::{conjugate_kana, conjugate_surface};

use crate::schema::{ConjForm, DistractorDef, DrillDef, KanaWordMode, VocabDef};
use crate::sentence::{analyze_t, parse_t, reorder_chunks, ParsedSentence};

use super::context::Ctx;
use super::Finding;

const MIN_SUBSTITUTION_ROWS: usize = 3;
const REQUIRED_BLANKS: usize = 1;
const MIN_DISTINCT_OPTIONS: usize = 2;

fn sentence_by_id(ctx: &Ctx, id: &str) -> Option<ParsedSentence> {
    let sentence = ctx.raw.sentences.iter().find(|s| s.id == id)?;
    analyze_t(&sentence.t, sentence.tts, None).ok()
}

fn check_blanks_and_rows(drill: &DrillDef) -> Vec<Finding> {
    let id = drill.id();
    let mut findings = Vec::new();
    if let DrillDef::ParticleFill { blanks, .. } = drill {
        if blanks.len() != REQUIRED_BLANKS {
            findings.push(Finding::error(
                "R12",
                id,
                "blanks",
                "particle_fill 的 blanks 長度必為 1",
            ));
        }
        for choice in blanks.iter().flat_map(|blank| &blank.choices) {
            if parse_t(choice).is_err() {
                findings.push(Finding::error(
                    "R12",
                    id,
                    choice,
                    "particle_fill 選項必須帶 ref",
                ));
            }
        }
    }
    if let DrillDef::Substitution { rows, .. } = drill {
        if rows.len() < MIN_SUBSTITUTION_ROWS {
            findings.push(Finding::error(
                "R12",
                id,
                "rows",
                format!("substitution 至少 {MIN_SUBSTITUTION_ROWS} 列"),
            ));
        }
    }
    findings
}

/// RC7：引擎算不出該形，或單字的 `conj_omit` 列了該形（實際不用的形不能考）。
fn conjugate_problem(vocab: &VocabDef, lemma: &str, form: ConjForm) -> Option<String> {
    if vocab.conj_omit.contains(&form) {
        return Some(format!(
            "{lemma} 的 conj_omit 列了 {form:?}，不能出這個形的題"
        ));
    }
    let kana: String = vocab.kana.chars().filter(|c| !c.is_whitespace()).collect();
    let ok = conjugate_kana(&kana, vocab.pos, form).is_some()
        && conjugate_surface(&vocab.surface, &kana, vocab.pos, form).is_some();
    (!ok).then(|| format!("{lemma} 無法產生 {form:?}"))
}

fn check_conjugate(ctx: &Ctx, drill: &DrillDef) -> Vec<Finding> {
    let DrillDef::Conjugate { form, lemmas, .. } = drill else {
        return Vec::new();
    };
    lemmas
        .iter()
        .filter_map(|lemma| {
            let vocab = ctx.vocab.get(lemma.as_str())?;
            let problem = conjugate_problem(vocab, lemma, *form)?;
            Some(Finding::error("RC7", drill.id(), lemma, problem))
        })
        .collect()
}

fn distinct_count<'a>(options: impl Iterator<Item = &'a str>) -> usize {
    options.collect::<HashSet<_>>().len()
}

fn display_of(text: &str) -> String {
    analyze_t(text, None, None).map_or_else(|_| text.to_owned(), |p| p.display)
}

fn choice_problem(drill: &DrillDef) -> Option<String> {
    match drill {
        DrillDef::ParticleFill { blanks, .. } => blanks
            .iter()
            .find(|blank| {
                distinct_count(blank.choices.iter().map(String::as_str)) < MIN_DISTINCT_OPTIONS
            })
            .map(|_| "選項去重後少於 2 個".to_owned()),
        DrillDef::ZhToJaChoice {
            answer,
            distractors,
            ..
        }
        | DrillDef::SituationResponse {
            answer,
            distractors,
            ..
        } => answer_distractor_problem(answer, distractors),
        DrillDef::ListenMeaning {
            choices_zh,
            answer_index,
            ..
        }
        | DrillDef::FalseFriend {
            choices_zh,
            answer_index,
            ..
        } => options_problem(choices_zh.iter().map(String::as_str), *answer_index),
        DrillDef::KanaWord {
            mode: KanaWordMode::Choice,
            choices_zh,
            answer_index,
            ..
        } => kana_word_problem(choices_zh, *answer_index),
        _ => None,
    }
}

fn answer_distractor_problem(answer: &str, distractors: &[DistractorDef]) -> Option<String> {
    let mut options: HashSet<String> = distractors.iter().map(|d| display_of(&d.t)).collect();
    options.insert(display_of(answer));
    (options.len() < MIN_DISTINCT_OPTIONS).then(|| "答案與干擾項去重後少於 2 個".to_owned())
}

fn kana_word_problem(choices_zh: &[String], answer_index: Option<u32>) -> Option<String> {
    match answer_index {
        Some(index) => options_problem(choices_zh.iter().map(String::as_str), index),
        None => Some("choice 模式必須有 answer_index".to_owned()),
    }
}

fn options_problem<'a>(
    options: impl Iterator<Item = &'a str> + Clone,
    answer_index: u32,
) -> Option<String> {
    let total = options.clone().count();
    if distinct_count(options) < MIN_DISTINCT_OPTIONS {
        return Some("選項去重後少於 2 個".to_owned());
    }
    ((answer_index as usize) >= total).then(|| format!("answer_index {answer_index} 超出選項範圍"))
}

fn check_choice_options(drill: &DrillDef) -> Vec<Finding> {
    choice_problem(drill)
        .map(|problem| Finding::error("RC8", drill.id(), "", problem))
        .into_iter()
        .collect()
}

fn word_index_problem(ctx: &Ctx, drill: &DrillDef) -> Option<String> {
    match drill {
        DrillDef::ParticleFill {
            sentence, blanks, ..
        } => {
            let words = sentence_by_id(ctx, sentence)?.words.len() as u32;
            blanks
                .iter()
                .find(|blank| blank.word_index >= words)
                .map(|blank| format!("word_index {} 超出 {sentence} 的詞數", blank.word_index))
        }
        DrillDef::Reorder {
            sentence,
            accept_orders,
            ..
        } => {
            let parsed = sentence_by_id(ctx, sentence)?;
            let chunks = reorder_chunks(&parsed).len();
            accept_orders
                .iter()
                .find(|order| !is_permutation(order, chunks))
                .map(|order| format!("accept_orders {order:?} 不是 {chunks} 個詞塊的排列"))
        }
        _ => None,
    }
}

fn is_permutation(order: &[u32], len: usize) -> bool {
    let mut sorted = order.to_vec();
    sorted.sort_unstable();
    sorted == (0..len as u32).collect::<Vec<_>>()
}

fn check_indexes(ctx: &Ctx, drill: &DrillDef) -> Vec<Finding> {
    word_index_problem(ctx, drill)
        .map(|problem| Finding::error("RC8", drill.id(), "", problem))
        .into_iter()
        .collect()
}

fn check_required_arrays(ctx: &Ctx) -> Vec<Finding> {
    let mut findings = Vec::new();
    let mut required = |item: &str, field: &str, empty: bool| {
        if empty {
            findings.push(Finding::error(
                "RC10",
                item,
                field,
                format!("{field} 不得為空陣列"),
            ));
        }
    };
    for vocab in &ctx.raw.vocab {
        required(&vocab.id, "zh", vocab.zh.is_empty());
        required(&vocab.id, "topics", vocab.topics.is_empty());
    }
    for card in &ctx.raw.rule_cards {
        required(&card.id, "examples", card.examples.is_empty());
    }
    for group in &ctx.raw.sound_groups {
        required(&group.id, "pairs", group.pairs.is_empty());
    }
    for dialogue in &ctx.raw.dialogues {
        required(&dialogue.id, "turns", dialogue.turns.is_empty());
        required(&dialogue.id, "roles", dialogue.roles.is_empty());
    }
    for drill in &ctx.raw.drills {
        check_drill_arrays(drill, &mut required);
    }
    findings
}

fn check_drill_arrays(drill: &DrillDef, required: &mut impl FnMut(&str, &str, bool)) {
    let id = drill.id();
    required(id, "targets", drill.targets().is_empty());
    match drill {
        DrillDef::Substitution { rows, .. } => required(id, "rows", rows.is_empty()),
        DrillDef::Reorder { accept_orders, .. } => {
            required(id, "accept_orders", accept_orders.is_empty())
        }
        DrillDef::ParticleFill { blanks, .. } => required(id, "blanks", blanks.is_empty()),
        DrillDef::ZhToJaChoice { distractors, .. }
        | DrillDef::SituationResponse { distractors, .. } => {
            required(id, "distractors", distractors.is_empty());
        }
        DrillDef::ListenMeaning { choices_zh, .. } | DrillDef::FalseFriend { choices_zh, .. } => {
            required(id, "choices_zh", choices_zh.is_empty());
        }
        DrillDef::Conjugate { lemmas, .. } => required(id, "lemmas", lemmas.is_empty()),
        DrillDef::KanaWord {
            mode: KanaWordMode::Choice,
            choices_zh,
            ..
        } => {
            required(id, "choices_zh", choices_zh.is_empty());
        }
        _ => {}
    }
}

pub(super) fn check(ctx: &Ctx) -> Vec<Finding> {
    let mut findings: Vec<Finding> = ctx
        .raw
        .drills
        .iter()
        .flat_map(|drill| {
            let mut local = check_blanks_and_rows(drill);
            local.extend(check_conjugate(ctx, drill));
            local.extend(check_choice_options(drill));
            local.extend(check_indexes(ctx, drill));
            local
        })
        .collect();
    findings.extend(check_required_arrays(ctx));
    findings
}

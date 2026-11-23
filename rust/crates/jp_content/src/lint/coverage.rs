//! R09（覆蓋）、RC9（`use` 卡可用題）、R20（lesson_order 連號）、R25（同形字）。

use std::collections::{BTreeMap, HashMap, HashSet};

use jp_lang::kana::is_kana_text;

use crate::refs::TKind;
use crate::schema::DrillDef;

use super::context::Ctx;
use super::Finding;

const MIN_VOCAB_SENTENCES: usize = 2;
const MIN_GRAMMAR_SENTENCES: usize = 6;
const MIN_GRAMMAR_DRILLS: usize = 4;
const MIN_GRAMMAR_DRILL_TYPES: usize = 3;

fn sentence_counts<'a>(ctx: &'a Ctx<'a>) -> HashMap<&'a str, usize> {
    let mut counts: HashMap<&str, usize> = HashMap::new();
    for parsed in ctx.sites.iter().filter(|p| p.site.kind == TKind::Sentence) {
        let refs: HashSet<&str> = parsed.morphs().map(|m| m.r#ref.as_str()).collect();
        for reference in refs {
            *counts.entry(reference).or_default() += 1;
        }
    }
    counts
}

fn active_drills<'a>(ctx: &'a Ctx<'a>) -> impl Iterator<Item = &'a DrillDef> {
    ctx.raw.drills.iter().filter(|d| !d.retired())
}

fn drill_stats<'a>(ctx: &'a Ctx<'a>) -> HashMap<&'a str, (usize, HashSet<&'static str>)> {
    let mut stats: HashMap<&str, (usize, HashSet<&'static str>)> = HashMap::new();
    for drill in active_drills(ctx) {
        for target in drill.targets() {
            let entry = stats.entry(target.as_str()).or_default();
            entry.0 += 1;
            entry.1.insert(drill.type_name());
        }
    }
    stats
}

fn check_vocab_coverage(ctx: &Ctx, counts: &HashMap<&str, usize>) -> Vec<Finding> {
    let mut findings = Vec::new();
    for vocab in ctx.raw.vocab.iter().filter(|v| !v.retired) {
        let count = counts.get(vocab.id.as_str()).copied().unwrap_or(0);
        if count < MIN_VOCAB_SENTENCES {
            findings.push(
                Finding::error(
                    "R09",
                    &vocab.id,
                    &vocab.surface,
                    format!("只出現在 {count} 句，至少 2 句"),
                )
                .first_taught(&vocab.lesson),
            );
        }
        let first_same_lesson = vocab
            .examples
            .first()
            .and_then(|id| ctx.sentence_lesson.get(id.as_str()))
            .is_some_and(|lesson| *lesson == vocab.lesson);
        if !first_same_lesson {
            findings.push(
                Finding::error(
                    "R09",
                    &vocab.id,
                    &vocab.surface,
                    "examples[0] 必須與單字同課".to_owned(),
                )
                .first_taught(&vocab.lesson),
            );
        }
    }
    findings
}

fn check_grammar_coverage(
    ctx: &Ctx,
    counts: &HashMap<&str, usize>,
    stats: &HashMap<&str, (usize, HashSet<&'static str>)>,
) -> Vec<Finding> {
    let mut findings = Vec::new();
    for grammar in ctx.raw.grammar.iter().filter(|g| !g.retired) {
        let sentences = counts.get(grammar.id.as_str()).copied().unwrap_or(0);
        let (drills, types) = stats
            .get(grammar.id.as_str())
            .map_or((0, 0), |(count, kinds)| (*count, kinds.len()));
        if sentences < MIN_GRAMMAR_SENTENCES {
            findings.push(Finding::error(
                "R09",
                &grammar.id,
                "",
                format!("只有 {sentences} 句，至少 {MIN_GRAMMAR_SENTENCES} 句"),
            ));
        }
        if drills < MIN_GRAMMAR_DRILLS || types < MIN_GRAMMAR_DRILL_TYPES {
            findings.push(Finding::error(
                "R09",
                &grammar.id,
                "",
                format!("{drills} 題 {types} 種題型，至少 {MIN_GRAMMAR_DRILLS} 題 {MIN_GRAMMAR_DRILL_TYPES} 種"),
            ));
        }
    }
    findings
}

/// RC9：至少一題能當 `use` 卡（`shadowing` 不算）。
fn check_use_card_candidates(ctx: &Ctx) -> Vec<Finding> {
    let usable: HashSet<&str> = active_drills(ctx)
        .filter(|d| !matches!(d, DrillDef::Shadowing { .. }))
        .flat_map(|d| d.targets().iter().map(String::as_str))
        .collect();
    ctx.raw
        .grammar
        .iter()
        .filter(|g| !g.retired)
        .map(|g| g.id.as_str())
        .filter(|id| !usable.contains(id))
        .map(|id| Finding::error("RC9", id, "", "沒有可當 use 卡的題目"))
        .collect()
}

/// 鍵是課 ID：`lesson_order` 在每一課內各自連號。
fn sequence_findings<'a>(
    groups: BTreeMap<&'a str, Vec<(u32, &'a str)>>,
    label: &str,
) -> Vec<Finding> {
    let mut findings = Vec::new();
    for items in groups.into_values() {
        let mut sorted = items;
        sorted.sort_unstable();
        for (expected, (order, id)) in (1u32..).zip(sorted) {
            if order != expected {
                findings.push(Finding::error(
                    "R20",
                    id,
                    order.to_string(),
                    format!("{label} lesson_order 應為 {expected}，實際 {order}"),
                ));
            }
        }
    }
    findings
}

fn check_lesson_order(ctx: &Ctx) -> Vec<Finding> {
    let mut vocab_groups: BTreeMap<&str, Vec<(u32, &str)>> = BTreeMap::new();
    for vocab in &ctx.raw.vocab {
        vocab_groups
            .entry(&vocab.lesson)
            .or_default()
            .push((vocab.lesson_order, &vocab.id));
    }
    let mut grammar_groups: BTreeMap<&str, Vec<(u32, &str)>> = BTreeMap::new();
    for grammar in &ctx.raw.grammar {
        grammar_groups
            .entry(&grammar.lesson)
            .or_default()
            .push((grammar.lesson_order, &grammar.id));
    }
    let mut findings = sequence_findings(vocab_groups, "單字");
    findings.extend(sequence_findings(grammar_groups, "文法"));
    findings
}

fn is_cjk_ideograph(c: char) -> bool {
    ('\u{4E00}'..='\u{9FFF}').contains(&c)
}

fn check_same_form(ctx: &Ctx) -> Vec<Finding> {
    ctx.raw
        .vocab
        .iter()
        .filter(|v| !v.same_form_zh && !v.surface.is_empty())
        .filter(|v| v.surface.chars().all(is_cjk_ideograph) && !is_kana_text(&v.surface))
        .filter(|v| v.zh.contains(&v.surface))
        .map(|v| {
            Finding::warning(
                "R25",
                &v.id,
                &v.surface,
                "全為漢字且與 zh 相同，應標 same_form_zh",
            )
        })
        .collect()
}

pub(super) fn check(ctx: &Ctx) -> Vec<Finding> {
    let counts = sentence_counts(ctx);
    let stats = drill_stats(ctx);
    let mut findings = check_vocab_coverage(ctx, &counts);
    findings.extend(check_grammar_coverage(ctx, &counts, &stats));
    findings.extend(check_use_card_candidates(ctx));
    findings.extend(check_lesson_order(ctx));
    findings.extend(check_same_form(ctx));
    findings
}

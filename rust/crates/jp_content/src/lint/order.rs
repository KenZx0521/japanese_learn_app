//! R04（順序）、R05（@new）、R11（負擔），R12 的順序部分。R10 在 `spaced.rs`。

use std::collections::{HashMap, HashSet};

use crate::refs::TKind;

use super::context::{Ctx, ParsedSite, LESSON_REF_PREFIXES};
use super::Finding;

const NEW_REF_PREFIX: &str = "@new:";
const S0_STAGE: &str = "st.s0";
const NEW_ITEM_LIMIT_SENTENCE: usize = 3;
/// 開頭三課句型還少，一句常同時用到多個新字（負責人裁決）。
const NEW_ITEM_LIMIT_SENTENCE_EARLY: usize = 5;
const EARLY_LESSONS: [&str; 3] = ["le.l01", "le.l02", "le.l03"];
const NEW_ITEM_LIMIT_TURN: usize = 5;
const NEW_RATIO_DENOMINATOR: usize = 10;

/// R12 檢查的選項類；其他歸 R04。
fn is_option_site(kind: TKind) -> bool {
    matches!(
        kind,
        TKind::Row | TKind::Answer | TKind::Distractor | TKind::BlankChoice
    )
}

fn check_t_order(ctx: &Ctx, parsed: &ParsedSite) -> Vec<Finding> {
    let site = &parsed.site;
    let Some(owner_pos) = ctx.pos(site.lesson) else {
        return Vec::new();
    };
    let rule = if is_option_site(site.kind) {
        "R12"
    } else {
        "R04"
    };
    parsed
        .morphs()
        .filter(|m| LESSON_REF_PREFIXES.iter().any(|p| m.r#ref.starts_with(p)))
        .filter_map(|m| {
            let lesson = ctx.item_lesson.get(m.r#ref.as_str())?;
            let ref_pos = ctx.pos(lesson)?;
            (ref_pos > owner_pos).then(|| {
                Finding::error(
                    rule,
                    site.owner,
                    &m.r#ref,
                    format!("{} 使用 {}（尚未教）", site.lesson, m.r#ref),
                )
                .first_taught(*lesson)
            })
        })
        .collect()
}

fn check_requires(ctx: &Ctx) -> Vec<Finding> {
    let mut findings = Vec::new();
    for grammar in &ctx.raw.grammar {
        let Some(owner_pos) = ctx.pos(&grammar.lesson) else {
            continue;
        };
        for required in &grammar.requires {
            let Some(target) = ctx.grammar.get(required.as_str()) else {
                continue;
            };
            let Some(target_pos) = ctx.pos(&target.lesson) else {
                continue;
            };
            let too_late = target_pos > owner_pos
                || (target_pos == owner_pos && target.lesson_order >= grammar.lesson_order);
            if too_late {
                findings.push(
                    Finding::error(
                        "R04",
                        &grammar.id,
                        required,
                        format!("requires {required} 必須早於本文法"),
                    )
                    .first_taught(&target.lesson),
                );
            }
        }
    }
    findings.extend(check_require_cycles(ctx));
    findings
}

fn check_require_cycles(ctx: &Ctx) -> Vec<Finding> {
    let edges: HashMap<&str, Vec<&str>> = ctx
        .raw
        .grammar
        .iter()
        .map(|g| {
            (
                g.id.as_str(),
                g.requires.iter().map(String::as_str).collect(),
            )
        })
        .collect();
    let mut findings = Vec::new();
    let mut done: HashSet<&str> = HashSet::new();
    for start in edges.keys() {
        let mut stack: Vec<&str> = Vec::new();
        if let Some(cycle_at) = find_cycle(start, &edges, &mut done, &mut stack) {
            findings.push(Finding::error(
                "R04",
                cycle_at,
                cycle_at,
                "requires 形成循環".to_owned(),
            ));
        }
    }
    findings
}

/// 深度優先；`stack` 是目前路徑，`done` 是已確認無環的節點。
fn find_cycle<'a>(
    node: &'a str,
    edges: &HashMap<&'a str, Vec<&'a str>>,
    done: &mut HashSet<&'a str>,
    stack: &mut Vec<&'a str>,
) -> Option<&'a str> {
    if done.contains(node) {
        return None;
    }
    if stack.contains(&node) {
        return Some(node);
    }
    stack.push(node);
    let found = edges
        .get(node)
        .into_iter()
        .flatten()
        .find_map(|next| find_cycle(next, edges, done, stack));
    stack.pop();
    if found.is_none() {
        done.insert(node);
    }
    found
}

fn is_counted_sentence(kind: TKind) -> bool {
    matches!(kind, TKind::Sentence | TKind::Turn)
}

pub(super) fn s0_lessons<'a>(ctx: &'a Ctx<'a>) -> HashSet<&'a str> {
    ctx.raw
        .course
        .lessons
        .iter()
        .filter(|l| l.stage == S0_STAGE)
        .map(|l| l.id.as_str())
        .collect()
}

fn new_ref_site_findings(parsed: &ParsedSite, s0: &HashSet<&str>) -> Vec<Finding> {
    let site = &parsed.site;
    let new_refs = parsed
        .morphs()
        .filter(|m| m.r#ref.starts_with(NEW_REF_PREFIX))
        .count();
    let mut findings = Vec::new();
    if new_refs > 1 {
        findings.push(Finding::error(
            "R05",
            site.owner,
            "@new",
            "每句最多 1 個 @new",
        ));
    }
    if new_refs > 0 && (site.in_drill || s0.contains(site.lesson)) {
        findings.push(Finding::error(
            "R05",
            site.owner,
            "@new",
            "S0 與演練題禁用 @new",
        ));
    }
    findings
}

fn new_ratio_findings(ctx: &Ctx) -> Vec<Finding> {
    let mut per_lesson: HashMap<&str, (usize, usize)> = HashMap::new();
    for parsed in ctx
        .sites
        .iter()
        .filter(|p| is_counted_sentence(p.site.kind))
    {
        let has_new = parsed.morphs().any(|m| m.r#ref.starts_with(NEW_REF_PREFIX));
        let entry = per_lesson.entry(parsed.site.lesson).or_default();
        entry.0 += usize::from(has_new);
        entry.1 += 1;
    }
    per_lesson
        .into_iter()
        .filter(|(_, (with_new, total))| with_new * NEW_RATIO_DENOMINATOR > *total)
        .map(|(lesson, (with_new, total))| {
            Finding::error(
                "R05",
                lesson,
                "@new",
                format!("@new 句數 {with_new} 超過該課 {total} 句的 10%"),
            )
        })
        .collect()
}

fn check_new_refs(ctx: &Ctx) -> Vec<Finding> {
    let s0 = s0_lessons(ctx);
    let mut findings: Vec<Finding> = ctx
        .sites
        .iter()
        .flat_map(|parsed| new_ref_site_findings(parsed, &s0))
        .collect();
    findings.extend(new_ratio_findings(ctx));
    findings
}

fn check_load(ctx: &Ctx) -> Vec<Finding> {
    let mut findings = Vec::new();
    for parsed in &ctx.sites {
        let site = &parsed.site;
        let limit = match site.kind {
            TKind::Sentence if EARLY_LESSONS.contains(&site.lesson) => {
                NEW_ITEM_LIMIT_SENTENCE_EARLY
            }
            TKind::Sentence => NEW_ITEM_LIMIT_SENTENCE,
            TKind::Turn => NEW_ITEM_LIMIT_TURN,
            _ => continue,
        };
        let new_items: HashSet<&str> = parsed
            .morphs()
            .filter(|m| m.r#ref.starts_with("vo.") || m.r#ref.starts_with("gr."))
            .filter(|m| {
                ctx.item_lesson
                    .get(m.r#ref.as_str())
                    .is_some_and(|lesson| *lesson == site.lesson)
            })
            .map(|m| m.r#ref.as_str())
            .collect();
        if new_items.len() > limit {
            findings.push(Finding::error(
                "R11",
                site.owner,
                new_items.into_iter().collect::<Vec<_>>().join(","),
                format!("當課新項目超過 {limit} 個"),
            ));
        }
    }
    findings
}

pub(super) fn check(ctx: &Ctx) -> Vec<Finding> {
    let mut findings: Vec<Finding> = ctx
        .sites
        .iter()
        .flat_map(|parsed| check_t_order(ctx, parsed))
        .collect();
    findings.extend(check_requires(ctx));
    findings.extend(check_new_refs(ctx));
    findings.extend(check_load(ctx));
    findings
}

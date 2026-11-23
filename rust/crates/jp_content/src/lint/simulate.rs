//! R18：依 curriculum.md §11.3 切分模擬，每個 L 課的切片日至少一句可用例句。

use std::collections::HashSet;

use crate::schema::{GrammarDef, VocabDef};

use super::context::Ctx;
use super::Finding;

const L_LESSON_PREFIX: &str = "le.l";

struct LessonPlan<'a> {
    words: Vec<&'a VocabDef>,
    grammar: Vec<&'a GrammarDef>,
}

fn lesson_plan<'a>(ctx: &'a Ctx<'a>, lesson: &str) -> LessonPlan<'a> {
    let mut words: Vec<&VocabDef> = ctx
        .raw
        .vocab
        .iter()
        .filter(|v| v.lesson == lesson && !v.retired)
        .collect();
    words.sort_by_key(|v| v.lesson_order);
    let mut grammar: Vec<&GrammarDef> = ctx
        .raw
        .grammar
        .iter()
        .filter(|g| g.lesson == lesson && !g.retired)
        .collect();
    grammar.sort_by_key(|g| g.lesson_order);
    LessonPlan { words, grammar }
}

fn known_before<'a>(ctx: &'a Ctx<'a>, position: u32) -> HashSet<&'a str> {
    let vocab = ctx
        .raw
        .vocab
        .iter()
        .filter(|v| !v.retired && ctx.pos(&v.lesson).is_some_and(|p| p < position));
    let grammar = ctx
        .raw
        .grammar
        .iter()
        .filter(|g| !g.retired && ctx.pos(&g.lesson).is_some_and(|p| p < position));
    vocab
        .map(|v| v.id.as_str())
        .chain(grammar.map(|g| g.id.as_str()))
        .collect()
}

/// 只看該課自己的例句：新內容頁要有當課可用的例句，舊課的句子不算。
fn usable_sentence_exists(ctx: &Ctx, lesson: &str, known: &HashSet<&str>) -> bool {
    ctx.sites.iter().any(|parsed| {
        let site = &parsed.site;
        let in_scope = site.owner.starts_with("se.") && site.lesson == lesson;
        in_scope
            && parsed
                .morphs()
                .filter(|m| m.r#ref.starts_with("vo.") || m.r#ref.starts_with("gr."))
                .all(|m| known.contains(m.r#ref.as_str()))
    })
}

/// 一個切片日：`(單字, 文法)`；文法依剩餘單字天數平均分配，先多後少。
fn slice_days<'a>(
    plan: &LessonPlan<'a>,
    limit: usize,
) -> Vec<(Vec<&'a VocabDef>, Vec<&'a GrammarDef>)> {
    let mut days = Vec::new();
    let mut word_index = 0;
    let mut grammar_index = 0;
    while word_index < plan.words.len() || grammar_index < plan.grammar.len() {
        let remaining_words = plan.words.len() - word_index;
        let remaining_days = remaining_words.div_ceil(limit).max(1);
        let word_count = remaining_words.min(limit);
        let grammar_count = (plan.grammar.len() - grammar_index).div_ceil(remaining_days);
        days.push((
            plan.words[word_index..word_index + word_count].to_vec(),
            plan.grammar[grammar_index..grammar_index + grammar_count].to_vec(),
        ));
        word_index += word_count;
        grammar_index += grammar_count;
    }
    days
}

fn check_lesson(
    ctx: &Ctx,
    lesson: &str,
    position: u32,
    limit: usize,
    preset: &str,
) -> Vec<Finding> {
    let plan = lesson_plan(ctx, lesson);
    let mut known = known_before(ctx, position);
    let mut findings = Vec::new();
    for (day, (words, grammar)) in slice_days(&plan, limit).into_iter().enumerate() {
        let new_ids = words
            .iter()
            .map(|v| v.id.as_str())
            .chain(grammar.iter().map(|g| g.id.as_str()));
        known.extend(new_ids);
        if !usable_sentence_exists(ctx, lesson, &known) {
            findings.push(Finding::error(
                "R18",
                lesson,
                format!("day{}", day + 1),
                format!("方案 {preset} 第 {} 個切片日沒有可用例句", day + 1),
            ));
        }
    }
    findings
}

pub(super) fn check_r18(ctx: &Ctx) -> Vec<Finding> {
    let limits: Vec<(usize, &str)> = ctx
        .raw
        .presets
        .iter()
        .map(|preset| (preset.new_words_per_day as usize, preset.id.as_str()))
        .filter(|(limit, _)| *limit > 0)
        .collect();
    let mut findings = Vec::new();
    for lesson in ctx
        .raw
        .course
        .order
        .iter()
        .filter(|id| id.starts_with(L_LESSON_PREFIX))
    {
        let Some(position) = ctx.pos(lesson) else {
            continue;
        };
        for (limit, preset) in &limits {
            findings.extend(check_lesson(ctx, lesson, position, *limit, preset));
        }
    }
    findings
}

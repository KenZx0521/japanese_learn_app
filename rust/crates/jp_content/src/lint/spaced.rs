//! R10（間隔重現）：新單字在教學後 3 個主線課內至少再出現一次（警告級）。
//!
//! 時間窗只算主線課（非 S0 的 L 課）：假名課不介紹單字，不佔「3 課內」（第三輪裁決 P9）。
//! 刻意設計的例外登錄在 `lint/r10_allow.txt`（每行「ID 理由」），理由必填；
//! 已在時間窗內重現的單字仍登錄者報警告，提醒移除。

use std::collections::{HashMap, HashSet};

use crate::schema::VocabDef;

use super::context::Ctx;
use super::order::s0_lessons;
use super::Finding;

const RULE: &str = "R10";
const REPEAT_WINDOW: u32 = 3;
const ALLOW_FILE: &str = "r10_allow.txt";

/// `rank` 是到該課為止（含）的主線課數，假名課沿用前一個主線課的值。
struct MainLine<'a> {
    rank: HashMap<&'a str, u32>,
    s0: HashSet<&'a str>,
    total: u32,
}

impl<'a> MainLine<'a> {
    fn build(ctx: &'a Ctx<'a>) -> Self {
        let s0 = s0_lessons(ctx);
        let rank: HashMap<&str, u32> = ctx
            .raw
            .course
            .order
            .iter()
            .scan(0_u32, |count, id| {
                *count += u32::from(!s0.contains(id.as_str()));
                Some((id.as_str(), *count))
            })
            .collect();
        let total = rank.values().copied().max().unwrap_or(0);
        Self { rank, s0, total }
    }

    /// 主線課的序號；假名課與不在 `course.order` 的課回 `None`。
    fn main_rank(&self, lesson: &str) -> Option<u32> {
        if self.s0.contains(lesson) {
            return None;
        }
        self.rank.get(lesson).copied()
    }
}

/// 每個 `vo.*` 出現過的主線課序號。
fn main_line_usage<'a>(ctx: &'a Ctx<'a>, line: &MainLine) -> HashMap<&'a str, HashSet<u32>> {
    let mut usage: HashMap<&str, HashSet<u32>> = HashMap::new();
    for parsed in &ctx.sites {
        let Some(rank) = line.main_rank(parsed.site.lesson) else {
            continue;
        };
        for morph in parsed.morphs().filter(|m| m.r#ref.starts_with("vo.")) {
            usage.entry(morph.r#ref.as_str()).or_default().insert(rank);
        }
    }
    usage
}

fn is_tracked(vocab: &&VocabDef) -> bool {
    !vocab.retired
}

/// 教學後 3 個主線課內是否再出現；後面沒有主線課（教在最後一課）時回 `None`。
fn repeated_in_window(
    vocab: &VocabDef,
    line: &MainLine,
    usage: &HashMap<&str, HashSet<u32>>,
) -> Option<bool> {
    let taught = *line.rank.get(vocab.lesson.as_str())?;
    if taught >= line.total {
        return None;
    }
    let window = taught + 1..=taught + REPEAT_WINDOW;
    Some(
        usage
            .get(vocab.id.as_str())
            .is_some_and(|used| used.iter().any(|u| window.contains(u))),
    )
}

fn has_reason(allow: &HashMap<String, String>, id: &str) -> bool {
    allow.get(id).is_some_and(|reason| !reason.is_empty())
}

fn vocab_finding(vocab: &VocabDef, repeated: bool, allowed: bool) -> Option<Finding> {
    let message = match (repeated, allowed) {
        (false, false) => "教學後 3 個主線課內沒有再次出現".to_owned(),
        (true, true) => format!("已在教學後 3 個主線課內重現，請從 {ALLOW_FILE} 移除"),
        _ => return None,
    };
    let token = if allowed { ALLOW_FILE } else { &vocab.surface };
    Some(Finding::warning(RULE, &vocab.id, token, message).first_taught(&vocab.lesson))
}

fn missing_reasons(allow: &HashMap<String, String>) -> Vec<Finding> {
    allow
        .iter()
        .filter(|(_, reason)| reason.is_empty())
        .map(|(id, _)| {
            Finding::error(
                RULE,
                id,
                ALLOW_FILE,
                format!("{ALLOW_FILE} 的覆寫必須寫理由（每行「ID 理由」）"),
            )
        })
        .collect()
}

pub(super) fn check(ctx: &Ctx) -> Vec<Finding> {
    let line = MainLine::build(ctx);
    let usage = main_line_usage(ctx, &line);
    let allow = &ctx.lists.r10_allow;
    let mut findings: Vec<Finding> = ctx
        .raw
        .vocab
        .iter()
        .filter(is_tracked)
        .filter_map(|vocab| {
            let repeated = repeated_in_window(vocab, &line, &usage)?;
            vocab_finding(vocab, repeated, has_reason(allow, &vocab.id))
        })
        .collect();
    findings.extend(missing_reasons(allow));
    findings
}

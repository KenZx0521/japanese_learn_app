//! R06（假名閘門）、R24（假名課完整性）。

use std::collections::{BTreeSet, HashMap};

use jp_lang::kana::is_kana_text;

use crate::schema::{DrillDef, KanaDef, KanaKind};

use super::context::{Ctx, UNTAUGHT};
use super::Finding;

/// K10、K16–K19 不得有非 `mark` 的新字。
const NO_NEW_KANA_LESSONS: [&str; 5] = ["le.k10", "le.k16", "le.k17", "le.k18", "le.k19"];

struct Gate<'a> {
    /// 假名單位（含拗音、擴充拼法）→ (首次教學位置, 課)。
    taught: HashMap<&'a str, (u32, &'a str)>,
    max_unit_chars: usize,
}

impl<'a> Gate<'a> {
    fn build(ctx: &Ctx<'a>) -> Self {
        let taught: HashMap<&str, (u32, &str)> = ctx
            .raw
            .kana
            .iter()
            .filter(|k| !k.retired)
            .filter_map(|k| Some((k.ch.as_str(), (ctx.pos(&k.lesson)?, k.lesson.as_str()))))
            .collect();
        let max_unit_chars = taught
            .keys()
            .map(|unit| unit.chars().count())
            .max()
            .unwrap_or(1);
        Self {
            taught,
            max_unit_chars,
        }
    }

    /// 最長比對切成假名單位，非假名字元略過。
    fn units_of(&self, text: &str) -> BTreeSet<String> {
        let chars: Vec<char> = text.chars().collect();
        let mut units = BTreeSet::new();
        let mut index = 0;
        while index < chars.len() {
            let c = chars[index];
            if !is_kana_text(&c.to_string()) {
                index += 1;
                continue;
            }
            let run = self.longest_unit_at(&chars, index);
            units.insert(chars[index..index + run].iter().collect());
            index += run;
        }
        units
    }

    fn longest_unit_at(&self, chars: &[char], index: usize) -> usize {
        let limit = self.max_unit_chars.min(chars.len() - index);
        (2..=limit)
            .rev()
            .find(|&len| {
                let candidate: String = chars[index..index + len].iter().collect();
                self.taught.contains_key(candidate.as_str())
            })
            .unwrap_or(1)
    }

    fn violations(&self, text: &str, position: u32) -> Vec<(String, Option<&'a str>)> {
        self.units_of(text)
            .into_iter()
            .filter_map(|unit| match self.taught.get(unit.as_str()) {
                Some((pos, _)) if *pos <= position => None,
                Some((_, lesson)) => Some((unit, Some(*lesson))),
                None => Some((unit, None)),
            })
            .collect()
    }

    fn check_text(&self, ctx: &Ctx, item: &str, lesson: &str, text: &str) -> Vec<Finding> {
        let Some(position) = ctx.pos(lesson) else {
            return Vec::new();
        };
        self.violations(text, position)
            .into_iter()
            .map(|(unit, taught)| {
                Finding::error("R06", item, &unit, format!("{lesson} 尚未教過假名 {unit}"))
                    .first_taught(taught.unwrap_or(UNTAUGHT))
            })
            .collect()
    }
}

fn check_sites(ctx: &Ctx, gate: &Gate) -> Vec<Finding> {
    ctx.sites
        .iter()
        .flat_map(|parsed| {
            let site = &parsed.site;
            parsed
                .morphs()
                .flat_map(|m| {
                    let mut findings = gate.check_text(ctx, site.owner, site.lesson, &m.kana);
                    findings.extend(gate.check_text(ctx, site.owner, site.lesson, &m.surface));
                    findings
                })
                .collect::<Vec<_>>()
        })
        .collect()
}

fn check_drills(ctx: &Ctx, gate: &Gate) -> Vec<Finding> {
    ctx.raw
        .drills
        .iter()
        .flat_map(|drill| {
            let (id, lesson) = (drill.id(), drill.lesson());
            match drill {
                DrillDef::KanaWord { word, .. } => gate.check_text(ctx, id, lesson, word),
                DrillDef::MinimalPair {
                    a,
                    b,
                    a_kana,
                    b_kana,
                    ..
                } => pair_sides(a, b, a_kana.as_deref(), b_kana.as_deref())
                    .flat_map(|text| gate.check_text(ctx, id, lesson, text))
                    .collect(),
                _ => Vec::new(),
            }
        })
        .collect()
}

fn pair_sides<'a>(
    a: &'a str,
    b: &'a str,
    a_kana: Option<&'a str>,
    b_kana: Option<&'a str>,
) -> impl Iterator<Item = &'a str> {
    [Some(a), Some(b), a_kana, b_kana].into_iter().flatten()
}

fn check_sound_groups(ctx: &Ctx, gate: &Gate) -> Vec<Finding> {
    ctx.raw
        .sound_groups
        .iter()
        .flat_map(|group| {
            group.pairs.iter().flat_map(|pair| {
                pair_sides(
                    &pair.a,
                    &pair.b,
                    pair.a_kana.as_deref(),
                    pair.b_kana.as_deref(),
                )
                .flat_map(|text| gate.check_text(ctx, &group.id, &group.lesson, text))
                .collect::<Vec<_>>()
            })
        })
        .collect()
}

fn check_lesson_shape(ctx: &Ctx) -> Vec<Finding> {
    ctx.raw.kana.iter().flat_map(check_kana_shape).collect()
}

fn check_kana_shape(kana: &KanaDef) -> Vec<Finding> {
    let mut findings = Vec::new();
    if kana.kind != KanaKind::Mark && NO_NEW_KANA_LESSONS.contains(&kana.lesson.as_str()) {
        findings.push(Finding::error(
            "R24",
            &kana.id,
            &kana.ch,
            format!("{} 不得有新字", kana.lesson),
        ));
    }
    if kana.kind == KanaKind::Yoon && kana.row.is_none() {
        findings.push(Finding::error("R24", &kana.id, &kana.ch, "yoon 必須有 row"));
    }
    if kana.kind != KanaKind::Mark && kana.rule.is_some() {
        findings.push(Finding::error(
            "R24",
            &kana.id,
            &kana.ch,
            "rule 只有 mark 使用",
        ));
    }
    if kana.kind == KanaKind::Mark && !kana.listen_disabled {
        findings.push(Finding::warning(
            "R24",
            &kana.id,
            &kana.ch,
            "mark 預設應 listen_disabled: true",
        ));
    }
    findings
}

pub(super) fn check(ctx: &Ctx) -> Vec<Finding> {
    let gate = Gate::build(ctx);
    let mut findings = check_sites(ctx, &gate);
    findings.extend(check_drills(ctx, &gate));
    findings.extend(check_sound_groups(ctx, &gate));
    findings.extend(check_lesson_shape(ctx));
    findings
}

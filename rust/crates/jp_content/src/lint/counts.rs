//! R17：各類別筆數與 curriculum.md §14 當前階段欄比對。

use crate::raw::RawContent;
use crate::schema::{ContentStage, DialogueKind, DrillDef, KanaKind, NoteDef};

use super::context::Ctx;
use super::Finding;

/// 每列：(類別, p0a, p0, full, 計數器)。
type CountFn = fn(&RawContent) -> usize;
const COUNT_TARGETS: [(&str, usize, usize, usize, CountFn); 20] = [
    ("假名字元", 229, 229, 229, kana_chars),
    ("假名符號", 9, 9, 9, kana_marks),
    ("假名規則卡", 7, 7, 7, |r| {
        r.rule_cards.iter().filter(|c| !c.retired).count()
    }),
    ("易混字組", 53, 53, 53, |r| {
        r.confusables.iter().filter(|c| !c.retired).count()
    }),
    ("語音示範組", 16, 16, 16, |r| {
        r.sound_groups.iter().filter(|s| !s.retired).count()
    }),
    ("課程", 34, 57, 75, |r| r.course.order.len()),
    ("單字", 175, 800, 1400, main_vocab),
    ("文法點", 39, 138, 212, |r| {
        r.grammar.iter().filter(|g| !g.retired).count()
    }),
    ("主線例句", 266, 1140, 1824, main_sentences),
    ("手寫演練（課程）", 210, 900, 1440, course_drills),
    ("手寫演練（假名）", 100, 100, 100, kana_drills),
    ("主對話", 7, 30, 48, |r| {
        dialogues(r, DialogueKind::Lesson)
    }),
    ("實戰對話", 0, 6, 12, |r| {
        dialogues(r, DialogueKind::Extra)
    }),
    ("常體版對話", 0, 12, 16, |r| {
        dialogues(r, DialogueKind::Casual)
    }),
    ("同形異義筆記", 0, 60, 60, |r| {
        notes(r, |n| matches!(n, NoteDef::FalseFriend(_)))
    }),
    ("字形對照", 0, 120, 120, |r| {
        notes(r, |n| matches!(n, NoteDef::Shinjitai(_)))
    }),
    ("讀音規律筆記", 0, 20, 20, |r| {
        notes(r, |n| matches!(n, NoteDef::Reading(_)))
    }),
    ("語言轉移筆記", 0, 20, 20, |r| {
        notes(r, |n| matches!(n, NoteDef::Transfer(_)))
    }),
    ("術語筆記", 0, 12, 12, |r| {
        notes(r, |n| matches!(n, NoteDef::Term(_)))
    }),
    ("計畫預設", 4, 4, 4, |r| r.presets.len()),
];
const MILESTONES_TARGET: (usize, usize, usize) = (3, 6, 8);

fn kana_chars(raw: &RawContent) -> usize {
    raw.kana
        .iter()
        .filter(|k| !k.retired && k.kind != KanaKind::Mark)
        .count()
}

fn kana_marks(raw: &RawContent) -> usize {
    raw.kana
        .iter()
        .filter(|k| !k.retired && k.kind == KanaKind::Mark)
        .count()
}

fn main_vocab(raw: &RawContent) -> usize {
    raw.vocab.iter().filter(|v| !v.retired).count()
}

fn main_sentences(raw: &RawContent) -> usize {
    raw.sentences.iter().filter(|s| !s.retired).count()
}

fn is_kana_drill(drill: &DrillDef) -> bool {
    matches!(
        drill,
        DrillDef::MinimalPair { .. } | DrillDef::KanaWord { .. }
    )
}

fn course_drills(raw: &RawContent) -> usize {
    raw.drills
        .iter()
        .filter(|d| !d.retired() && !is_kana_drill(d))
        .count()
}

fn kana_drills(raw: &RawContent) -> usize {
    raw.drills
        .iter()
        .filter(|d| !d.retired() && is_kana_drill(d))
        .count()
}

fn dialogues(raw: &RawContent, kind: DialogueKind) -> usize {
    raw.dialogues
        .iter()
        .filter(|d| !d.retired && d.kind == kind)
        .count()
}

fn notes(raw: &RawContent, pick: impl Fn(&NoteDef) -> bool) -> usize {
    raw.notes.iter().filter(|n| !n.retired() && pick(n)).count()
}

fn target_for(stage: ContentStage, p0a: usize, p0: usize, full: usize) -> usize {
    match stage {
        ContentStage::P0a => p0a,
        ContentStage::P0 => p0,
        ContentStage::Full => full,
    }
}

fn shortfall(label: &str, actual: usize, target: usize) -> Option<Finding> {
    (actual < target).then(|| {
        Finding::error(
            "R17",
            label,
            actual.to_string(),
            format!("{label} 僅 {actual} 筆，目標 {target}"),
        )
    })
}

/// 種子內容（`count_policy.txt` 為 `seed`）只回報一則警告。
pub(super) fn check_r17(ctx: &Ctx) -> Vec<Finding> {
    if ctx.lists.seed_content {
        return vec![Finding::warning(
            "R17",
            "-",
            "seed",
            "內容仍為種子（lint/count_policy.txt），略過筆數門檻",
        )];
    }
    let (milestone_p0a, milestone_p0, milestone_full) = MILESTONES_TARGET;
    let milestone = shortfall(
        "里程碑",
        ctx.raw.milestones.len(),
        target_for(ctx.stage, milestone_p0a, milestone_p0, milestone_full),
    );
    COUNT_TARGETS
        .iter()
        .filter_map(|&(label, p0a, p0, full, count)| {
            shortfall(label, count(ctx.raw), target_for(ctx.stage, p0a, p0, full))
        })
        .chain(milestone)
        .collect()
}

/// `content_tool stats` 用：(類別, 當前筆數, 當前階段目標)。
pub(super) fn stage_counts(
    raw: &RawContent,
    stage: ContentStage,
) -> Vec<(&'static str, usize, usize)> {
    let mut rows: Vec<(&'static str, usize, usize)> = COUNT_TARGETS
        .iter()
        .map(|&(label, p0a, p0, full, count)| (label, count(raw), target_for(stage, p0a, p0, full)))
        .collect();
    let (milestone_p0a, milestone_p0, milestone_full) = MILESTONES_TARGET;
    rows.push((
        "里程碑",
        raw.milestones.len(),
        target_for(stage, milestone_p0a, milestone_p0, milestone_full),
    ));
    rows
}

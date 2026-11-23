//! 涵蓋率：C01–C06（reuse-and-verification.md §9.2）。

use std::collections::HashSet;

use jp_content::schema::{ContentStage, Jlpt, KanaKind, Script, VocabDef};

use crate::data::jmdict::JmdictIndex;
use crate::data::lists::JlptRow;

use super::{has_kanji, strip_spaces, strip_tilde, Finding, Input, Level};

const MISSING_SAMPLE_SIZE: usize = 5;
const SUBTITLE_TOP_N: usize = 500;

const HIRAGANA_TOTAL: usize = 104;
const KATAKANA_TOTAL: usize = 125;
const MARK_TOTAL: usize = 9;

fn vocab_key(vocab: &VocabDef) -> (String, String) {
    (
        strip_tilde(&vocab.surface).to_owned(),
        strip_spaces(&vocab.kana),
    )
}

/// 內容已有的字，分成漢字配對與純假名。
struct HaveVocab {
    pairs: HashSet<(String, String)>,
    kana: HashSet<String>,
}

impl HaveVocab {
    fn of(input: &Input) -> Self {
        let mut have = Self {
            pairs: HashSet::new(),
            kana: HashSet::new(),
        };
        for vocab in &input.scope.raw.vocab {
            let (surface, kana) = vocab_key(vocab);
            if has_kanji(&surface) {
                have.pairs.insert((surface, kana));
            } else {
                have.kana.insert(kana);
            }
        }
        have
    }

    fn covers(&self, jm: &JmdictIndex, row: &JlptRow) -> bool {
        jm.expansion(&row.id).is_some_and(|entry| {
            entry.pairs.iter().any(|pair| self.pairs.contains(pair))
                || entry.kana.iter().any(|kana| self.kana.contains(kana))
        })
    }
}

fn row_label(row: &JlptRow) -> String {
    if row.kanji.is_empty() {
        row.kana.clone()
    } else {
        format!("{}/{}", row.kanji, row.kana)
    }
}

fn is_skipped(input: &Input, row: &JlptRow) -> bool {
    input.env.coverage_skip.iter().any(|(surface, kana)| {
        kana == &row.kana && (surface == &row.kanji || (row.kanji.is_empty() && surface == kana))
    })
}

/// 一級清單的涵蓋情況（C01、C02，報告與 `coverage.md` 共用）。
pub struct ListCoverage {
    pub label: &'static str,
    pub covered: usize,
    pub total: usize,
    pub missing: Vec<String>,
}

pub fn list_coverage(input: &Input, label: &'static str, rows: &[JlptRow]) -> Option<ListCoverage> {
    let jm = input.data.jmdict.as_ref()?;
    let have = HaveVocab::of(input);
    let considered: Vec<&JlptRow> = rows.iter().filter(|row| !is_skipped(input, row)).collect();
    let missing: Vec<String> = considered
        .iter()
        .filter(|row| !have.covers(jm, row))
        .map(|row| row_label(row))
        .collect();
    Some(ListCoverage {
        label,
        covered: considered.len() - missing.len(),
        total: considered.len(),
        missing,
    })
}

fn coverage_percent(covered: usize, total: usize) -> f64 {
    if total == 0 {
        100.0
    } else {
        covered as f64 * 100.0 / total as f64
    }
}

fn coverage_finding(
    rule: &'static str,
    input: &Input,
    cov: &ListCoverage,
    threshold: Option<f64>,
) -> Finding {
    let sample: Vec<String> = cov
        .missing
        .iter()
        .take(MISSING_SAMPLE_SIZE)
        .map(|label| format!("\"{label}\""))
        .collect();
    let message = format!(
        "{label} coverage {covered}/{total} missing-sample [{sample}]",
        label = cov.label,
        covered = cov.covered,
        total = cov.total,
        sample = sample.join(", ")
    );
    let percent = coverage_percent(cov.covered, cov.total);
    match threshold {
        Some(limit) if input.env.strict && percent < limit => Finding::new(
            rule,
            Level::Error,
            cov.label,
            "",
            format!("{message}（門檻 {limit}%）"),
        ),
        _ => Finding::info(rule, cov.label, "", message),
    }
}

fn c01_threshold(stage: ContentStage) -> Option<f64> {
    match stage {
        ContentStage::P0a => None,
        ContentStage::P0 => Some(85.0),
        ContentStage::Full => Some(95.0),
    }
}

fn c02_threshold(stage: ContentStage) -> Option<f64> {
    matches!(stage, ContentStage::Full).then_some(85.0)
}

pub fn c01(input: &Input) -> Vec<Finding> {
    let (Some(jlpt), true) = (input.data.jlpt.as_ref(), input.data.jmdict.is_some()) else {
        return Vec::new();
    };
    list_coverage(input, "N5", &jlpt.n5)
        .map(|cov| coverage_finding("C01", input, &cov, c01_threshold(input.scope.stage)))
        .into_iter()
        .collect()
}

pub fn c02(input: &Input) -> Vec<Finding> {
    let (Some(jlpt), true) = (input.data.jlpt.as_ref(), input.data.jmdict.is_some()) else {
        return Vec::new();
    };
    list_coverage(input, "N4", &jlpt.n4)
        .map(|cov| coverage_finding("C02", input, &cov, c02_threshold(input.scope.stage)))
        .into_iter()
        .collect()
}

fn checklist_coverage(input: &Input, level: &str) -> ListCoverage {
    let have: HashSet<&str> = input
        .scope
        .raw
        .grammar
        .iter()
        .map(|g| g.id.as_str())
        .collect();
    let items: Vec<&(String, String)> = input
        .env
        .grammar_checklist
        .iter()
        .flatten()
        .filter(|(_, item_level)| item_level == level)
        .collect();
    let missing: Vec<String> = items
        .iter()
        .filter(|(id, _)| !have.contains(id.as_str()))
        .map(|(id, _)| id.clone())
        .collect();
    ListCoverage {
        label: if level == "n5" { "N5" } else { "N4" },
        covered: items.len() - missing.len(),
        total: items.len(),
        missing,
    }
}

fn c03_threshold(stage: ContentStage, level: &str) -> Option<f64> {
    match (stage, level) {
        (ContentStage::P0, "n5") => Some(95.0),
        (ContentStage::Full, "n5") => Some(100.0),
        (ContentStage::Full, "n4") => Some(85.0),
        _ => None,
    }
}

pub fn c03(input: &Input) -> Vec<Finding> {
    if input.env.grammar_checklist.is_none() {
        return vec![Finding::info(
            "C03",
            "-",
            "",
            "未找到 tools/verify/grammar_checklist.toml，略過文法涵蓋率",
        )];
    }
    ["n5", "n4"]
        .iter()
        .map(|level| {
            let cov = checklist_coverage(input, level);
            coverage_finding("C03", input, &cov, c03_threshold(input.scope.stage, level))
        })
        .collect()
}

pub fn c04(input: &Input) -> Vec<Finding> {
    let Some(freq) = input.data.freq.as_ref() else {
        return Vec::new();
    };
    let have = HaveVocab::of(input);
    let missing: Vec<&str> = freq
        .iter()
        .take(SUBTITLE_TOP_N)
        .filter(|entry| {
            !have
                .pairs
                .contains(&(entry.text.clone(), entry.reading.clone()))
                && !have.kana.contains(&entry.text)
                && !have.kana.contains(&entry.reading)
        })
        .map(|entry| entry.text.as_str())
        .collect();
    vec![Finding::info(
        "C04",
        "字幕前 500",
        "",
        format!(
            "未收錄 {}/{SUBTITLE_TOP_N}（清單在 coverage.md）",
            missing.len()
        ),
    )]
}

/// C04 的完整清單（`coverage.md` 用）。
pub fn subtitle_missing(input: &Input) -> Vec<String> {
    let Some(freq) = input.data.freq.as_ref() else {
        return Vec::new();
    };
    let have = HaveVocab::of(input);
    freq.iter()
        .take(SUBTITLE_TOP_N)
        .filter(|entry| {
            !have
                .pairs
                .contains(&(entry.text.clone(), entry.reading.clone()))
                && !have.kana.contains(&entry.text)
                && !have.kana.contains(&entry.reading)
        })
        .map(|entry| entry.text.clone())
        .collect()
}

pub fn c05(input: &Input) -> Vec<Finding> {
    let active: Vec<_> = input.scope.raw.kana.iter().filter(|k| !k.retired).collect();
    let count = |script: Script| {
        active
            .iter()
            .filter(|k| k.script == script && k.kind != KanaKind::Mark)
            .count()
    };
    let hira = count(Script::Hira);
    let kata = count(Script::Kata);
    let marks = active.iter().filter(|k| k.kind == KanaKind::Mark).count();
    [
        ("hira", hira, HIRAGANA_TOTAL),
        ("kata", kata, KATAKANA_TOTAL),
        ("mark", marks, MARK_TOTAL),
    ]
    .into_iter()
    .filter(|(_, actual, expected)| actual != expected)
    .map(|(item, actual, expected)| {
        Finding::error(
            "C05",
            item,
            "",
            format!("假名完整性：實際 {actual}，應為 {expected}（平 104、片 125、符號 9）"),
        )
    })
    .collect()
}

struct ListSets {
    pairs: HashSet<(String, String)>,
    kana: HashSet<String>,
}

fn list_sets(jm: &JmdictIndex, rows: &[JlptRow]) -> ListSets {
    let mut sets = ListSets {
        pairs: HashSet::new(),
        kana: HashSet::new(),
    };
    for entry in rows.iter().filter_map(|row| jm.expansion(&row.id)) {
        sets.pairs.extend(entry.pairs.iter().cloned());
        sets.kana.extend(entry.kana.iter().cloned());
    }
    sets
}

fn vocab_in_list(vocab: &VocabDef, sets: &ListSets) -> bool {
    let (surface, kana) = vocab_key(vocab);
    if has_kanji(&surface) {
        sets.pairs.contains(&(surface, kana))
    } else {
        sets.kana.contains(&kana)
    }
}

fn jlpt_name(jlpt: Jlpt) -> &'static str {
    match jlpt {
        Jlpt::N5 => "n5",
        Jlpt::N4 => "n4",
        Jlpt::Beyond => "beyond",
    }
}

pub fn c06(input: &Input) -> Vec<Finding> {
    let (Some(jlpt), Some(jm)) = (input.data.jlpt.as_ref(), input.data.jmdict.as_ref()) else {
        return Vec::new();
    };
    let n5 = list_sets(jm, &jlpt.n5);
    let n4 = list_sets(jm, &jlpt.n4);
    input
        .scope
        .raw
        .vocab
        .iter()
        .filter_map(|vocab| {
            let expected = if vocab_in_list(vocab, &n5) {
                Jlpt::N5
            } else if vocab_in_list(vocab, &n4) {
                Jlpt::N4
            } else {
                Jlpt::Beyond
            };
            (expected != vocab.jlpt).then(|| {
                Finding::error(
                    "C06",
                    &vocab.id,
                    jlpt_name(vocab.jlpt),
                    format!("jlpt 應為 {}（依 N5／N4 基準清單）", jlpt_name(expected)),
                )
            })
        })
        .collect()
}

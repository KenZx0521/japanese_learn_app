//! JMdict 比對：J01、J01b、J03、J03b、J05、J06、J07、J10。

use jp_content::schema::{DrillDef, Pos, VocabDef};
use jp_lang::kana::{furigana, Ruby};

use crate::data::jmdict::JmdictIndex;
use crate::data::lists::FuriganaSegment;

use super::{has_kanji, strip_spaces, strip_tilde, Finding, Input, Level};

fn vocab_forms(vocab: &VocabDef) -> (&str, String) {
    (strip_tilde(&vocab.surface), strip_spaces(&vocab.kana))
}

fn jm<'a>(input: &'a Input) -> Option<&'a JmdictIndex> {
    input.data.jmdict.as_ref()
}

fn level_for(pos: Pos) -> Level {
    if pos == Pos::Phrase {
        Level::Warning
    } else {
        Level::Error
    }
}

pub fn j01(input: &Input) -> Vec<Finding> {
    let Some(index) = jm(input) else {
        return Vec::new();
    };
    let mut findings = Vec::new();
    for vocab in &input.scope.raw.vocab {
        let (surface, kana) = vocab_forms(vocab);
        let exists = if has_kanji(surface) {
            index.has_pair(surface, &kana)
        } else {
            index.has_kana(&kana)
        };
        if !exists {
            findings.push(Finding::new(
                "J01",
                level_for(vocab.pos),
                &vocab.id,
                format!("{surface}/{kana}"),
                "JMdict 查無此配對：檢查 surface 的漢字與 kana 的讀音",
            ));
        }
    }
    for kana in &input.scope.raw.kana {
        for example in &kana.example_words {
            let surface = strip_tilde(&example.surface);
            let exists = if has_kanji(surface) {
                index.has_kanji_form(surface)
            } else {
                index.has_kana(surface)
            };
            if !exists {
                findings.push(Finding::error(
                    "J01",
                    &kana.id,
                    surface,
                    "example_words 的字在 JMdict 查不到",
                ));
            }
        }
    }
    findings
}

pub fn j01b(input: &Input) -> Vec<Finding> {
    input
        .scope
        .raw
        .vocab
        .iter()
        .filter_map(|vocab| {
            let (surface, kana) = vocab_forms(vocab);
            (!has_kanji(surface) && surface != kana).then(|| {
                Finding::error(
                    "J01b",
                    &vocab.id,
                    format!("{surface}/{kana}"),
                    "純假名的 surface 必須等於去空白的 kana",
                )
            })
        })
        .collect()
}

pub fn j03(input: &Input) -> Vec<Finding> {
    let Some(index) = jm(input) else {
        return Vec::new();
    };
    input
        .scope
        .raw
        .vocab
        .iter()
        .filter_map(|vocab| {
            let (surface, kana) = vocab_forms(vocab);
            let irregular = if has_kanji(surface) {
                index.pair_is_irregular(surface, &kana)
            } else {
                index.kana_is_irregular(&kana)
            };
            irregular.then(|| {
                Finding::warning(
                    "J03",
                    &vocab.id,
                    format!("{surface}/{kana}"),
                    "只以罕用、舊字形或搜尋用形式存在，請改用常見寫法",
                )
            })
        })
        .collect()
}

pub fn j03b(input: &Input) -> Vec<Finding> {
    let Some(index) = jm(input) else {
        return Vec::new();
    };
    input
        .scope
        .raw
        .vocab
        .iter()
        .filter_map(|vocab| {
            let (surface, kana) = vocab_forms(vocab);
            (has_kanji(surface) && index.pair_is_usually_kana(surface, &kana)).then(|| {
                Finding::warning(
                    "J03b",
                    &vocab.id,
                    surface,
                    "第一義項標 uk（通常寫假名），請確認是否應寫假名",
                )
            })
        })
        .collect()
}

/// `n` 前綴只比對 `n`、`n-*`，避免 `num` 被當成名詞。`v1` 與 `v1-s` 分開比對：
/// 呉れる 標成 `v1` 時 J05 會報錯；只寫假名的 くれる 會因同音的 暮れる（`v1`）通過，
/// 這種情形由 `rust/tests/real_content_p0.rs` 的真實內容回歸測試把關。
fn pos_accepts(pos: Pos, tag: &str) -> Option<bool> {
    let prefix = |p: &str| Some(tag.starts_with(p));
    match pos {
        Pos::V5 => prefix("v5"),
        Pos::V1 => Some(tag == "v1"),
        Pos::V1S => Some(tag == "v1-s"),
        Pos::Vs => prefix("vs"),
        Pos::Vk => prefix("vk"),
        Pos::AdjI => prefix("adj-i"),
        Pos::AdjNa => prefix("adj-na"),
        Pos::N => Some(tag == "n" || tag.starts_with("n-")),
        Pos::Pron => Some(tag == "pn"),
        Pos::Num => prefix("num"),
        Pos::Counter => prefix("ctr"),
        Pos::Adv => prefix("adv"),
        Pos::Conj => Some(tag == "conj"),
        Pos::Interj => Some(tag == "int"),
        Pos::Phrase => None,
    }
}

pub fn j05(input: &Input) -> Vec<Finding> {
    let Some(index) = jm(input) else {
        return Vec::new();
    };
    input
        .scope
        .raw
        .vocab
        .iter()
        .filter(|vocab| vocab.pos != Pos::Phrase)
        .filter_map(|vocab| {
            let (surface, kana) = vocab_forms(vocab);
            let accept = |tag: &str| pos_accepts(vocab.pos, tag).unwrap_or(true);
            let matched = if has_kanji(surface) {
                index.pair_pos_matches(surface, &kana, accept)
            } else {
                index.kana_pos_matches(&kana, accept)
            };
            matches!(matched, Some(false)).then(|| {
                Finding::error(
                    "J05",
                    &vocab.id,
                    format!("{surface}/{kana}"),
                    format!(
                        "pos {:?} 與 JMdict 詞性不符，請確認動詞類別或詞性",
                        vocab.pos
                    ),
                )
            })
        })
        .collect()
}

pub fn j06(input: &Input) -> Vec<Finding> {
    let Some(index) = jm(input) else {
        return Vec::new();
    };
    let mut findings = Vec::new();
    for site in &input.scope.sites {
        for morph in site.morphs().filter(|m| m.r#ref.starts_with("@new:")) {
            if has_kanji(&morph.surface) && !index.has_pair(&morph.surface, &morph.kana) {
                findings.push(Finding::warning(
                    "J06",
                    &site.owner,
                    format!("{}/{}", morph.surface, morph.kana),
                    "@new 語素 JMdict 查無配對（活用形查不到屬正常）",
                ));
            }
        }
    }
    findings
}

/// 併連續的振假名段與連續的無振假名段，只比對對齊的邊界。
fn merge_segments(parts: impl IntoIterator<Item = FuriganaSegment>) -> Vec<FuriganaSegment> {
    let mut merged: Vec<FuriganaSegment> = Vec::new();
    for (text, ruby) in parts {
        match (merged.last_mut(), &ruby) {
            (Some((last_text, Some(last_ruby))), Some(ruby)) => {
                last_text.push_str(&text);
                last_ruby.push_str(ruby);
            }
            (Some((last_text, None)), None) => last_text.push_str(&text),
            _ => merged.push((text, ruby)),
        }
    }
    merged
}

fn from_ruby(parts: Vec<Ruby>) -> Vec<FuriganaSegment> {
    parts
        .into_iter()
        .map(|part| (part.base, part.ruby))
        .collect()
}

pub fn j07(input: &Input) -> Vec<Finding> {
    let Some(index) = input.data.furigana.as_ref() else {
        return Vec::new();
    };
    input
        .scope
        .raw
        .vocab
        .iter()
        .filter_map(|vocab| {
            let (surface, kana) = vocab_forms(vocab);
            if !has_kanji(surface) {
                return None;
            }
            let expected = merge_segments(index.get(surface, &kana)?.iter().cloned());
            let ours = merge_segments(from_ruby(furigana(surface, &kana).ok()?));
            (ours != expected).then(|| {
                Finding::warning(
                    "J07",
                    &vocab.id,
                    format!("{surface}/{kana}"),
                    format!("振假名對齊與 JmdictFurigana 不同：{ours:?} ↔ {expected:?}"),
                )
            })
        })
        .collect()
}

const SMALL_KANA: &str = "ゃゅょぁぃぅぇぉゎャュョァィゥェォヮ";
const MIN_MORAE_FOR_J10: usize = 2;

fn mora_count(text: &str) -> usize {
    text.chars().filter(|c| !SMALL_KANA.contains(*c)).count()
}

fn word_exists(index: &JmdictIndex, text: &str, kana: Option<&str>) -> bool {
    if has_kanji(text) {
        return match kana {
            Some(kana) => index.has_pair(text, kana),
            None => index.has_kanji_form(text),
        };
    }
    index.has_kana(text)
}

fn j10_check(
    findings: &mut Vec<Finding>,
    index: &JmdictIndex,
    owner: &str,
    text: &str,
    kana: Option<&str>,
) {
    if mora_count(text) >= MIN_MORAE_FOR_J10 && !word_exists(index, text, kana) {
        findings.push(Finding::warning(
            "J10",
            owner,
            text,
            "JMdict 查不到（活用形查不到屬正常）",
        ));
    }
}

pub fn j10(input: &Input) -> Vec<Finding> {
    let Some(index) = jm(input) else {
        return Vec::new();
    };
    let mut findings = Vec::new();
    for drill in &input.scope.raw.drills {
        match drill {
            DrillDef::KanaWord { id, word, .. } => {
                j10_check(&mut findings, index, id, word, None);
            }
            DrillDef::MinimalPair {
                id,
                a,
                b,
                a_kana,
                b_kana,
                ..
            } => {
                j10_check(&mut findings, index, id, a, a_kana.as_deref());
                j10_check(&mut findings, index, id, b, b_kana.as_deref());
            }
            _ => {}
        }
    }
    for group in &input.scope.raw.sound_groups {
        for pair in &group.pairs {
            j10_check(
                &mut findings,
                index,
                &group.id,
                &pair.a,
                pair.a_kana.as_deref(),
            );
            j10_check(
                &mut findings,
                index,
                &group.id,
                &pair.b,
                pair.b_kana.as_deref(),
            );
        }
    }
    findings
}

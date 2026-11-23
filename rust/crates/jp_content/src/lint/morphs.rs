//! R07（語素一致）、R08（讀音填寫與對齊）、RC1–RC6（羅馬字與切分）。

use std::collections::HashSet;

use jp_lang::grammar::conjugate::legal_stems;
use jp_lang::kana::{
    furigana, is_kana_text, reading_mode_of, to_romaji_reading, to_romaji_word, Morph,
    FIXED_WA_WORDS,
};

use crate::schema::KanaKind;

use super::context::{word_morphs, Ctx, ParsedSite};
use super::Finding;

const LONE_PARTICLES: [&str; 2] = ["は", "へ"];

fn strip_spaces(text: &str) -> String {
    text.chars().filter(|c| !c.is_whitespace()).collect()
}

/// 連續相同 ref 的語素合併，跨詞也算；標點切斷。
fn merged_runs<'p>(parsed: &'p ParsedSite) -> Vec<(&'p str, String, String)> {
    let mut runs: Vec<(&str, String, String)> = Vec::new();
    for word in &parsed.words {
        let Some(morphs) = word_morphs(word) else {
            runs.push(("", String::new(), String::new()));
            continue;
        };
        for morph in morphs {
            match runs.last_mut() {
                Some((reference, surface, kana)) if *reference == morph.r#ref => {
                    surface.push_str(&morph.surface);
                    kana.push_str(&morph.kana);
                }
                _ => runs.push((&morph.r#ref, morph.surface.clone(), morph.kana.clone())),
            }
        }
    }
    runs.retain(|(reference, _, _)| reference.starts_with("vo."));
    runs
}

fn check_consistency(ctx: &Ctx, parsed: &ParsedSite) -> Vec<Finding> {
    merged_runs(parsed)
        .into_iter()
        .filter_map(|(reference, surface, kana)| {
            let vocab = ctx.vocab.get(reference)?;
            let target_kana = strip_spaces(&vocab.kana);
            let stems = legal_stems(&vocab.surface, &target_kana, vocab.pos);
            let matches = if stems.is_empty() {
                surface == vocab.surface && kana == target_kana
            } else {
                stems.iter().any(|(s, k)| *s == surface && *k == kana)
            };
            (!matches).then(|| {
                Finding::error(
                    "R07",
                    parsed.site.owner,
                    format!("{surface}|{kana}"),
                    format!(
                        "與單字 {reference}（{}|{}）不一致",
                        vocab.surface, vocab.kana
                    ),
                )
                .first_taught(&vocab.lesson)
            })
        })
        .collect()
}

/// 純假名語素不得填 kana：只有原始 `t` 看得出是否多填，解析後兩者相同。
fn check_redundant_kana(parsed: &ParsedSite) -> Vec<Finding> {
    parsed
        .site
        .text
        .split_whitespace()
        .flat_map(|token| token.split('+'))
        .filter_map(|part| {
            let fields: Vec<&str> = part.split('|').collect();
            match fields.as_slice() {
                [surface, _, _] if is_kana_text(surface) => Some(Finding::error(
                    "R08",
                    parsed.site.owner,
                    part,
                    "純假名語素不得填 kana",
                )),
                _ => None,
            }
        })
        .collect()
}

fn check_alignment(parsed: &ParsedSite) -> Vec<Finding> {
    parsed
        .morphs()
        .filter(|m| !is_kana_text(&m.surface))
        .filter(|m| furigana(&m.surface, &m.kana).is_err())
        .flat_map(|m| {
            let owner = parsed.site.owner;
            let token = format!("{}|{}", m.surface, m.kana);
            [
                Finding::error("R08", owner, &token, "振假名對齊不唯一"),
                Finding::error("RC2", owner, &token, "furigana 不是恰一解"),
            ]
        })
        .collect()
}

fn check_romaji(parsed: &ParsedSite) -> Vec<Finding> {
    parsed
        .morphs()
        .filter_map(|m| {
            to_romaji_word(&m.kana).err().map(|err| {
                Finding::error(
                    "RC1",
                    parsed.site.owner,
                    &m.kana,
                    format!("讀音無法轉換：{err}"),
                )
            })
        })
        .collect()
}

fn check_vocab_romaji(ctx: &Ctx) -> Vec<Finding> {
    ctx.raw
        .vocab
        .iter()
        .filter_map(|v| {
            to_romaji_reading(&v.kana, reading_mode_of(&v.kana))
                .err()
                .map(|err| Finding::error("RC1", &v.id, &v.kana, format!("讀音無法轉換：{err}")))
        })
        .collect()
}

/// 假名字元必須能轉羅馬字；`mark` 單獨出現沒有音，建索引時略過。
fn check_kana_romaji(ctx: &Ctx) -> Vec<Finding> {
    ctx.raw
        .kana
        .iter()
        .filter(|k| k.kind != KanaKind::Mark)
        .filter_map(|k| {
            to_romaji_word(&k.ch)
                .err()
                .map(|err| Finding::error("RC1", &k.id, &k.ch, format!("假名無法轉換：{err}")))
        })
        .collect()
}

fn check_wo(parsed: &ParsedSite) -> Vec<Finding> {
    parsed
        .words
        .iter()
        .filter_map(word_morphs)
        .filter_map(|morphs| {
            let kana: String = morphs.iter().map(|m| m.kana.as_str()).collect();
            (kana.contains('を') && kana != "を")
                .then(|| Finding::error("RC3", parsed.site.owner, &kana, "を 必須獨立成詞"))
        })
        .collect()
}

fn check_vocab_wo(ctx: &Ctx) -> Vec<Finding> {
    ctx.raw
        .vocab
        .iter()
        .filter(|v| {
            v.kana
                .split(' ')
                .any(|token| token.contains('を') && token != "を")
        })
        .map(|v| Finding::error("RC3", &v.id, &v.kana, "kana 內的 を 必須獨立"))
        .collect()
}

fn check_fixed_words(parsed: &ParsedSite) -> Vec<Finding> {
    parsed
        .words
        .iter()
        .filter_map(word_morphs)
        .filter_map(|morphs| {
            let kana: String = morphs.iter().map(|m| m.kana.as_str()).collect();
            FIXED_WA_WORDS.contains(&kana.as_str()).then(|| {
                Finding::error(
                    "RC4",
                    parsed.site.owner,
                    &kana,
                    "固定語必須切開（こんにち は）",
                )
            })
        })
        .collect()
}

fn check_vocab_fixed_words(ctx: &Ctx) -> Vec<Finding> {
    ctx.raw
        .vocab
        .iter()
        .filter(|v| FIXED_WA_WORDS.contains(&v.kana.as_str()))
        .map(|v| {
            Finding::error(
                "RC4",
                &v.id,
                &v.kana,
                "固定語 kana 必須含空白（こんにち は）",
            )
        })
        .collect()
}

fn known_readings(ctx: &Ctx) -> HashSet<String> {
    ctx.raw
        .vocab
        .iter()
        .map(|v| strip_spaces(&v.kana))
        .collect()
}

fn check_unsplit(ctx: &Ctx, parsed: &ParsedSite, known: &HashSet<String>) -> Vec<Finding> {
    parsed
        .words
        .iter()
        .filter_map(word_morphs)
        .filter_map(|morphs| {
            let kana: String = morphs.iter().map(|m| m.kana.as_str()).collect();
            let stem = kana
                .strip_suffix(LONE_PARTICLES[0])
                .or_else(|| kana.strip_suffix(LONE_PARTICLES[1]))?;
            let unsplit = known.contains(stem)
                && !known.contains(&kana)
                && !ctx.lists.unsplit_allow.contains(&kana);
            unsplit.then(|| {
                Finding::error(
                    "RC5",
                    parsed.site.owner,
                    &kana,
                    format!("{kana} 應把助詞切開，例外登錄 unsplit_allow.txt"),
                )
            })
        })
        .collect()
}

fn vocab_has_split_particle(kana: &str) -> bool {
    kana.split(' ')
        .skip(1)
        .any(|token| LONE_PARTICLES.contains(&token))
}

fn is_lone_particle_vocab_ref(morphs: &[Morph]) -> Option<&Morph> {
    match morphs {
        [only]
            if LONE_PARTICLES.contains(&only.surface.as_str())
                && only.kana == only.surface
                && only.r#ref.starts_with("vo.") =>
        {
            Some(only)
        }
        _ => None,
    }
}

fn check_lone_particle(ctx: &Ctx, parsed: &ParsedSite) -> Vec<Finding> {
    parsed
        .words
        .iter()
        .filter_map(word_morphs)
        .filter_map(|morphs| is_lone_particle_vocab_ref(morphs))
        .filter(|m| {
            ctx.vocab
                .get(m.r#ref.as_str())
                .is_none_or(|vocab| !vocab_has_split_particle(&vocab.kana))
        })
        .map(|m| {
            Finding::error(
                "RC6",
                parsed.site.owner,
                &m.r#ref,
                format!("單獨的 {} 不在固定語白名單，應寫漢字", m.surface),
            )
        })
        .collect()
}

pub(super) fn check(ctx: &Ctx) -> Vec<Finding> {
    let known = known_readings(ctx);
    let mut findings = check_vocab_romaji(ctx);
    findings.extend(check_kana_romaji(ctx));
    findings.extend(check_vocab_wo(ctx));
    findings.extend(check_vocab_fixed_words(ctx));
    for parsed in &ctx.sites {
        findings.extend(check_consistency(ctx, parsed));
        findings.extend(check_redundant_kana(parsed));
        findings.extend(check_alignment(parsed));
        findings.extend(check_romaji(parsed));
        findings.extend(check_wo(parsed));
        findings.extend(check_fixed_words(parsed));
        findings.extend(check_unsplit(ctx, parsed, &known));
        findings.extend(check_lone_particle(ctx, parsed));
    }
    findings
}

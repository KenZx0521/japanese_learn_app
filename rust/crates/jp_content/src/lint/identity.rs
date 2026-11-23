//! R01 的 slug 警告、R03 的淘汰引用。

use jp_lang::kana::{reading_mode_of, to_romaji_reading};

use crate::refs::reference_sites;

use super::context::{Ctx, LESSON_REF_PREFIXES};
use super::Finding;

const VOCAB_ID_PREFIX: &str = "vo.";

fn romaji_of(kana: &str) -> Option<String> {
    to_romaji_reading(kana, reading_mode_of(kana))
        .ok()
        .map(|romaji| romaji.chars().filter(char::is_ascii_alphabetic).collect())
}

fn check_vocab_slug(ctx: &Ctx) -> Vec<Finding> {
    ctx.raw
        .vocab
        .iter()
        .filter_map(|v| {
            let slug = v.id.strip_prefix(VOCAB_ID_PREFIX)?.replace('_', "");
            let romaji = romaji_of(&v.kana)?;
            (!slug.starts_with(&romaji)).then(|| {
                Finding::warning(
                    "R01",
                    &v.id,
                    &v.kana,
                    format!("slug 應以 kana 推導的羅馬字 {romaji} 開頭"),
                )
            })
        })
        .collect()
}

fn check_retired_refs(ctx: &Ctx) -> Vec<Finding> {
    let mut findings: Vec<Finding> = reference_sites(ctx.raw)
        .into_iter()
        .filter(|site| ctx.retired.contains(site.target))
        .map(|site| {
            Finding::error(
                "R03",
                site.owner,
                site.target,
                format!("{} 指向已淘汰的項目", site.field),
            )
        })
        .collect();
    findings.extend(ctx.sites.iter().flat_map(|parsed| {
        let owner = parsed.site.owner;
        parsed
            .morphs()
            .filter(|m| {
                LESSON_REF_PREFIXES.iter().any(|p| m.r#ref.starts_with(p))
                    && ctx.retired.contains(m.r#ref.as_str())
            })
            .map(|m| Finding::error("R03", owner, &m.r#ref, "t 引用已淘汰的項目".to_owned()))
            .collect::<Vec<_>>()
    }));
    findings
}

pub(super) fn check(ctx: &Ctx) -> Vec<Finding> {
    let mut findings = check_vocab_slug(ctx);
    findings.extend(check_retired_refs(ctx));
    findings
}

//! R15（繁中字形與用語）、R16（TTS）、R19（`{ja:…}` 標記）。後兩者對 JSON 原文逐欄走訪。

use crate::mixed::{validate_mixed, MixedSpan};
use crate::scan::{classify_field, visit_text_fields, FieldKind, TextField};
use crate::schema::TtsMode;

use super::context::{Ctx, ParsedSite};
use super::Finding;

fn check_string(field: &TextField, ctx: &Ctx, findings: &mut Vec<Finding>) {
    let Some(kind) = classify_field(field.file, field.key, field.parent_key) else {
        return;
    };
    let zh_text = match kind {
        FieldKind::Mixed => check_mixed(field.text, field.owner, field.key, findings),
        FieldKind::PlainZh => {
            check_plain_zh(field.text, field.owner, field.key, findings);
            field.text.to_owned()
        }
        FieldKind::ZhOnly => field.text.to_owned(),
    };
    check_zh_chars(&zh_text, ctx, field.owner, findings);
}

/// 回傳標記以外的中文部分，供 R15 比對。
fn check_mixed(text: &str, owner: &str, key: &str, findings: &mut Vec<Finding>) -> String {
    match validate_mixed(text) {
        Err(err) => {
            findings.push(Finding::error(
                "R19",
                owner,
                key,
                format!("{key} 的 {{ja:…}} 語法錯誤：{err}"),
            ));
            text.to_owned()
        }
        Ok(spans) => {
            let mut zh_part = String::new();
            for span in &spans {
                match span {
                    MixedSpan::Zh { text: zh } => {
                        check_kana_outside_markup(zh, owner, key, findings);
                        zh_part.push_str(zh);
                    }
                    MixedSpan::Ja { text: ja, ruby } => {
                        check_ja_span(ja, ruby, owner, key, findings)
                    }
                }
            }
            zh_part
        }
    }
}

fn check_ja_span(
    ja: &str,
    ruby: &[jp_lang::kana::Ruby],
    owner: &str,
    key: &str,
    findings: &mut Vec<Finding>,
) {
    let no_reading = ruby.iter().all(|part| part.ruby.is_none());
    if no_reading && ja.chars().any(is_cjk) {
        findings.push(Finding::warning(
            "R19",
            owner,
            ja,
            format!("{key} 的 {{ja:{ja}}} 含漢字但未加讀音"),
        ));
    }
    if no_reading {
        return;
    }
    match alignment_count(ja, ruby) {
        0 => findings.push(Finding::error(
            "R19",
            owner,
            ja,
            format!("{key} 的 {{ja:{ja}}} 讀音對不齊底字，假名與標點要在讀音中原樣出現（rust-core 4.6 節）"),
        )),
        1 => {}
        _ => findings.push(Finding::warning(
            "R19",
            owner,
            ja,
            format!("{key} 的 {{ja:{ja}}} 讀音有多種對齊，執行期退回整段 ruby；請拆成逐詞標記"),
        )),
    }
}

/// 讀音對齊底字的解數（rust-core 4.6 節）。0 解（例如讀音漏了 ？）與多解（整句標記常見，
/// 例如 音楽 可對 おん）執行期都退回整段 ruby，假名與標點跑到振假名底下；0 解是錯誤，多解是警告。
/// 由各段還原讀音再對齊一次即可分辨。
fn alignment_count(ja: &str, ruby: &[jp_lang::kana::Ruby]) -> usize {
    let reading: String = ruby
        .iter()
        .map(|part| part.ruby.as_deref().unwrap_or(&part.base))
        .collect();
    match jp_lang::kana::furigana(ja, &reading) {
        Ok(_) => 1,
        Err(count) => count,
    }
}

fn check_kana_outside_markup(zh: &str, owner: &str, key: &str, findings: &mut Vec<Finding>) {
    if zh.chars().any(is_kana) {
        findings.push(Finding::error(
            "R19",
            owner,
            kana_run(zh),
            format!("{key} 的假名必須包在 {{ja:…}} 內"),
        ));
    }
    if zh
        .chars()
        .zip(zh.chars().skip(1))
        .any(|(a, b)| (is_cjk(a) && is_kana(b)) || (is_kana(a) && is_cjk(b)))
    {
        findings.push(Finding::warning(
            "R19",
            owner,
            zh,
            format!("{key} 有漢字緊鄰假名且不在標記內"),
        ));
    }
}

fn kana_run(text: &str) -> String {
    text.chars().filter(|c| is_kana(*c)).collect()
}

fn check_plain_zh(text: &str, owner: &str, key: &str, findings: &mut Vec<Finding>) {
    if text.contains("{ja:") {
        findings.push(Finding::error(
            "R19",
            owner,
            key,
            format!("{key} 不開放 {{ja:…}} 標記"),
        ));
    }
    if text.chars().any(is_kana) {
        findings.push(Finding::error(
            "R19",
            owner,
            kana_run(text),
            format!("{key} 不得含假名"),
        ));
    }
}

fn check_zh_chars(text: &str, ctx: &Ctx, owner: &str, findings: &mut Vec<Finding>) {
    for c in text.chars().filter(|c| ctx.lists.zh_simplified.contains(c)) {
        findings.push(Finding::error(
            "R15",
            owner,
            c.to_string(),
            "中文欄位含簡體字",
        ));
    }
    for phrase in ctx
        .lists
        .zh_tw_denylist
        .iter()
        .filter(|p| text.contains(p.as_str()))
    {
        findings.push(Finding::error("R15", owner, phrase, "中文欄位含中國用語"));
    }
}

fn is_kana(c: char) -> bool {
    ('\u{3041}'..='\u{3096}').contains(&c) || ('\u{30A1}'..='\u{30FA}').contains(&c)
}

fn is_cjk(c: char) -> bool {
    ('\u{3400}'..='\u{4DBF}').contains(&c)
        || ('\u{4E00}'..='\u{9FFF}').contains(&c)
        || ('\u{F900}'..='\u{FAFF}').contains(&c)
}

/// R15、R19：逐檔走訪中文欄位（只看當前階段的項目）。
pub(super) fn check_fields(files: &[(&str, &str)], ctx: &Ctx) -> Vec<Finding> {
    let mut findings = Vec::new();
    visit_text_fields(files, &ctx.raw.course, ctx.stage, &mut |field| {
        check_string(field, ctx, &mut findings)
    });
    findings
}

fn check_t_tts(ctx: &Ctx, parsed: &ParsedSite) -> Vec<Finding> {
    let site = &parsed.site;
    let effective = site.own_tts.or(site.drill_tts).unwrap_or(TtsMode::Auto);
    let has_name = parsed.morphs().any(|m| m.r#ref == "@name");
    if has_name && effective != TtsMode::Kana {
        return vec![Finding::error(
            "R16",
            site.owner,
            "@name",
            "含 @name 的 t 必須標 tts: kana",
        )];
    }
    if effective == TtsMode::Auto {
        let display = parsed.display();
        return ctx
            .lists
            .tts_risky
            .iter()
            .filter(|word| display.contains(word.as_str()))
            .map(|word| {
                Finding::error(
                    "R16",
                    site.owner,
                    word,
                    format!("{word} 命中 tts_risky.txt，請標 tts: kana"),
                )
            })
            .collect();
    }
    Vec::new()
}

/// R16：TTS 解析順序與 @name。
pub(super) fn check_structured(ctx: &Ctx) -> Vec<Finding> {
    ctx.sites
        .iter()
        .flat_map(|parsed| check_t_tts(ctx, parsed))
        .collect()
}

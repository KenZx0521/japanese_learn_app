//! 假名與常用漢字：J02、J04、J08、J09（reuse-and-verification.md §9.2）。

use std::collections::BTreeSet;

use jp_content::schema::DrillDef;
use jp_lang::kana::{reading_mode_of, to_romaji_reading, typed_answer_matches};
use wana_kana::ConvertJapanese;

use super::{has_kanji, is_kanji, strip_spaces, strip_tilde, Finding, Input, Level};

const WAVE_DASH: char = '\u{301C}';
/// 文法語素可以用 ん／っ 開頭（んです、って）。
const GRAMMAR_REF_PREFIX: &str = "gr.";
const SMALL_KANA: &str = "ぁぃぅぇぉゃゅょゎァィゥェォャュョヮ";
const SMALL_YOON: &str = "ゃゅょャュョ";
const SMALL_YOON_YU: &str = "ュ";
const I_ROW: &str = "きぎしじちぢにひびぴみりキギシジチヂニヒビピミリ";
/// テュ、デュ、フュ、ヴュ 是外來語的合法拼法。
const FOREIGN_YU_HEADS: &str = "テデフヴ";
const VOWELS: &str = "あいうえおアイウエオ";
const HIRAGANA_SMALL_VOWELS: &str = "ぁぃぅぇぉ";
const OLD_KANA: &str = "ゐゑヰヱ";
const NASAL: &str = "んン";
const SOKUON: &str = "っッ";
const LONG_MARK: char = 'ー';

fn is_allowed_kana_char(c: char) -> bool {
    matches!(c, '\u{3041}'..='\u{3096}' | '\u{30A1}'..='\u{30F6}' | 'ー' | '・')
}

/// `allow_nasal_head`：語素屬於 `gr.*`，可以用 ん／っ 開頭。
pub fn kana_issues(text: &str, allow_nasal_head: bool) -> Vec<(Level, String)> {
    let mut issues = Vec::new();
    if text.contains('\u{FF5E}') || text.contains('~') {
        issues.push((Level::Error, "波浪號必須是 U+301C 〜".to_owned()));
    }
    let chars: Vec<char> = text.chars().filter(|c| *c != WAVE_DASH).collect();
    if chars
        .iter()
        .any(|c| !is_allowed_kana_char(*c) && *c != '\u{FF5E}' && *c != '~')
    {
        issues.push((Level::Error, "含不合法的字元".to_owned()));
    }
    check_head(&chars, allow_nasal_head, &mut issues);
    check_sequences(&chars, &mut issues);
    check_warnings(&chars, &mut issues);
    issues
}

fn check_head(chars: &[char], allow_nasal_head: bool, issues: &mut Vec<(Level, String)>) {
    let Some(&head) = chars.first() else {
        return;
    };
    if SMALL_KANA.contains(head) {
        issues.push((Level::Error, "小字不能開頭".to_owned()));
    }
    if head == LONG_MARK {
        issues.push((Level::Error, "長音符不能開頭".to_owned()));
    }
    let nasal_head = NASAL.contains(head) || SOKUON.contains(head);
    if nasal_head && !allow_nasal_head {
        issues.push((Level::Error, "ん／っ 不能開頭".to_owned()));
    }
}

fn check_sequences(chars: &[char], issues: &mut Vec<(Level, String)>) {
    for window in chars.windows(2) {
        let (before, after) = (window[0], window[1]);
        if SMALL_YOON.contains(after) && !yoon_head_allowed(before, after) {
            issues.push((Level::Error, format!("拗音接在非い段之後：{before}{after}")));
        }
        if SOKUON.contains(before)
            && (VOWELS.contains(after) || NASAL.contains(after) || after == LONG_MARK)
        {
            issues.push((Level::Error, format!("っ 不能接 {after}")));
        }
        if NASAL.contains(before) && (SMALL_KANA.contains(after) || after == LONG_MARK) {
            issues.push((Level::Error, format!("ん 不能接 {after}")));
        }
    }
}

fn yoon_head_allowed(before: char, after: char) -> bool {
    I_ROW.contains(before) || (SMALL_YOON_YU.contains(after) && FOREIGN_YU_HEADS.contains(before))
}

fn check_warnings(chars: &[char], issues: &mut Vec<(Level, String)>) {
    if chars.iter().any(|c| HIRAGANA_SMALL_VOWELS.contains(*c)) {
        issues.push((Level::Warning, "小寫母音屬口語寫法".to_owned()));
    }
    if chars
        .windows(2)
        .any(|w| w[0] == LONG_MARK && w[1] == LONG_MARK)
    {
        issues.push((Level::Warning, "連續長音符".to_owned()));
    }
    if chars.iter().any(|c| OLD_KANA.contains(*c)) {
        issues.push((Level::Warning, "舊假名 ゐ ゑ".to_owned()));
    }
}

/// 只有假名時才檢查 surface；含漢字或數字的 surface 只檢查讀音。
fn is_kana_surface(text: &str) -> bool {
    !has_kanji(text)
        && !text
            .chars()
            .any(|c| c.is_ascii_digit() || ('０'..='９').contains(&c))
}

fn push_kana_findings(
    findings: &mut Vec<Finding>,
    owner: &str,
    text: &str,
    allow_nasal_head: bool,
) {
    let cleaned = strip_spaces(text);
    for (level, reason) in kana_issues(&cleaned, allow_nasal_head) {
        findings.push(Finding::new("J04", level, owner, cleaned.as_str(), reason));
    }
}

fn check_vocab(input: &Input, findings: &mut Vec<Finding>) {
    for vocab in &input.scope.raw.vocab {
        if is_kana_surface(&vocab.surface) {
            push_kana_findings(findings, &vocab.id, &vocab.surface, false);
        }
        push_kana_findings(findings, &vocab.id, &vocab.kana, false);
    }
}

fn check_morphs(input: &Input, findings: &mut Vec<Finding>) {
    for site in &input.scope.sites {
        for morph in site.morphs() {
            let allow = morph.r#ref.starts_with(GRAMMAR_REF_PREFIX);
            if is_kana_surface(&morph.surface) {
                push_kana_findings(findings, &site.owner, &morph.surface, allow);
            }
            push_kana_findings(findings, &site.owner, &morph.kana, allow);
        }
    }
}

/// `tts_text` 可能送漢字給 TTS，含漢字時只由人工確認。
fn check_tts(findings: &mut Vec<Finding>, owner: &str, text: &str) {
    if !has_kanji(text) {
        push_kana_findings(findings, owner, text, false);
    }
}

fn check_pair_fields(
    findings: &mut Vec<Finding>,
    owner: &str,
    texts: [&str; 2],
    kana: [Option<&str>; 2],
    tts: [Option<&str>; 2],
) {
    for text in texts.iter().filter(|text| is_kana_surface(text)) {
        push_kana_findings(findings, owner, text, false);
    }
    for text in kana.into_iter().flatten() {
        push_kana_findings(findings, owner, text, false);
    }
    for text in tts.into_iter().flatten() {
        check_tts(findings, owner, text);
    }
}

fn check_drills(input: &Input, findings: &mut Vec<Finding>) {
    for drill in &input.scope.raw.drills {
        match drill {
            DrillDef::KanaWord { id, word, .. } if is_kana_surface(word) => {
                push_kana_findings(findings, id, word, false);
            }
            DrillDef::MinimalPair {
                id,
                a,
                b,
                a_kana,
                b_kana,
                a_tts_text,
                b_tts_text,
                ..
            } => check_pair_fields(
                findings,
                id,
                [a, b],
                [a_kana.as_deref(), b_kana.as_deref()],
                [a_tts_text.as_deref(), b_tts_text.as_deref()],
            ),
            _ => {}
        }
    }
}

fn check_kana_and_groups(input: &Input, findings: &mut Vec<Finding>) {
    for kana in &input.scope.raw.kana {
        for example in &kana.example_words {
            if is_kana_surface(&example.surface) {
                push_kana_findings(findings, &kana.id, &example.surface, false);
            }
        }
        // 單字元的 tts_text 就是字本身（ん、ゃ），和 `char` 一樣不適用。
        if let Some(tts) = kana.tts_text.as_ref().filter(|tts| **tts != kana.ch) {
            check_tts(findings, &kana.id, tts);
        }
    }
    for group in &input.scope.raw.sound_groups {
        for pair in &group.pairs {
            check_pair_fields(
                findings,
                &group.id,
                [&pair.a, &pair.b],
                [pair.a_kana.as_deref(), pair.b_kana.as_deref()],
                [pair.a_tts_text.as_deref(), pair.b_tts_text.as_deref()],
            );
        }
    }
}

pub fn j04(input: &Input) -> Vec<Finding> {
    let mut findings = Vec::new();
    check_vocab(input, &mut findings);
    check_morphs(input, &mut findings);
    check_drills(input, &mut findings);
    check_kana_and_groups(input, &mut findings);
    findings
}

pub fn j02(input: &Input) -> Vec<Finding> {
    let Some(joyo) = input.data.joyo.as_ref() else {
        return Vec::new();
    };
    let mut flagged: BTreeSet<(String, char)> = BTreeSet::new();
    let mut check = |owner: &str, text: &str| {
        for c in text.chars().filter(|c| is_kanji(*c) && !joyo.contains(c)) {
            flagged.insert((owner.to_owned(), c));
        }
    };
    input.scope.visit_ja_fields(|owner, key, text| {
        if key != "origin_kanji" {
            check(owner, text);
        }
    });
    for site in &input.scope.sites {
        for morph in site.morphs() {
            check(&site.owner, &morph.surface);
        }
    }
    input.scope.visit_zh_fields(|field| {
        for ja in &field.ja {
            check(field.owner, ja);
        }
    });
    flagged
        .into_iter()
        .map(|(owner, c)| {
            Finding::error(
                "J02",
                owner,
                c.to_string(),
                "不是常用漢字（可能混入繁中字形）；人名請登錄 verify_allow.toml",
            )
        })
        .collect()
}

const HA: &str = "は";
const HE: &str = "へ";

fn j08_expected(kana: &str) -> Option<(&'static str, &'static str)> {
    match kana {
        HA => Some(("ha", "wa")),
        HE => Some(("he", "e")),
        _ => None,
    }
}

pub fn j08(input: &Input) -> Vec<Finding> {
    let mut findings = Vec::new();
    for vocab in &input.scope.raw.vocab {
        let kana = vocab.kana.as_str();
        let mode = reading_mode_of(kana);
        if let Some((right, wrong)) = j08_expected(kana) {
            let romaji = to_romaji_reading(kana, mode).unwrap_or_default();
            if romaji != right
                || !typed_answer_matches(right, kana, mode)
                || typed_answer_matches(wrong, kana, mode)
            {
                findings.push(Finding::error(
                    "J08",
                    &vocab.id,
                    kana,
                    format!("單獨的 {kana} 應讀 {right}，實際 {romaji}（reading_mode_of／typed_answer_matches 異常）"),
                ));
            }
        } else if !kana.contains(' ') && (kana.ends_with(HA) || kana.ends_with(HE)) {
            findings.push(Finding::warning(
                "J08",
                &vocab.id,
                kana,
                "以 は／へ 結尾且無空白會讀 ha／he；若應讀 wa／e，請在 kana 助詞前加空白",
            ));
        }
    }
    findings
}

/// 擴充假名、長音符、波浪線等 wana_kana 已知不同的類別（§7.1）。
const J09_KNOWN_CHARS: &str = "ぁぃぅぇぉゎァィゥェォヮヵヶヴー〜";

fn is_known_wana_difference(kana: &str) -> bool {
    kana.chars().any(|c| J09_KNOWN_CHARS.contains(c))
        || (kana.contains(' ') && ["は", "へ", "を"].iter().any(|p| kana.contains(p)))
}

fn compare_with_wana(kana: &str, owner: &str, findings: &mut Vec<Finding>) {
    let Ok(ours) = to_romaji_reading(kana, reading_mode_of(kana)) else {
        return;
    };
    let ours = strip_spaces(&ours).to_lowercase();
    let theirs = strip_spaces(&kana.to_romaji()).to_lowercase();
    if ours != theirs && !is_known_wana_difference(kana) {
        findings.push(Finding::info(
            "J09",
            owner,
            kana,
            format!("羅馬字模組輸出 {ours}，wana_kana 輸出 {theirs}"),
        ));
    }
}

pub fn j09(input: &Input) -> Vec<Finding> {
    let mut seen: BTreeSet<String> = BTreeSet::new();
    let mut findings = Vec::new();
    for vocab in &input.scope.raw.vocab {
        let kana = strip_tilde(&vocab.kana);
        if seen.insert(kana.to_owned()) {
            compare_with_wana(kana, &vocab.id, &mut findings);
        }
    }
    for site in &input.scope.sites {
        for morph in site.morphs() {
            if seen.insert(morph.kana.clone()) {
                compare_with_wana(&morph.kana, &site.owner, &mut findings);
            }
        }
    }
    findings
}

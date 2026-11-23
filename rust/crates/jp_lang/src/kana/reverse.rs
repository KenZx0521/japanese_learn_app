//! 羅馬字→平假名（rust-core.md §4.5），用於打字判定與即時預覽。

use thiserror::Error;

use super::table::{is_romaji_vowel, is_word_separator, kana_of_romaji};

const MAX_SYLLABLE_LETTERS: usize = 3;
const NASAL_KANA: &str = "ん";
const SOKUON_KANA: &str = "っ";
const LONG_MARK_KANA: &str = "ー";
const SPACE: &str = " ";

/// `pos` 是輸入的字元索引。
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum RomajiError {
    #[error("無法解析的羅馬字（位置 {pos}）")]
    Unparsable { pos: usize },
}

/// 寬鬆轉換：大小寫不分，接受訓令式拼法。空白與句尾標點保留，讓整句的預覽不會中斷。
pub fn romaji_to_hiragana(input: &str) -> Result<String, RomajiError> {
    let chars: Vec<char> = input.chars().map(|c| c.to_ascii_lowercase()).collect();
    let mut out = String::with_capacity(input.len());
    let mut i = 0;
    while i < chars.len() {
        let (kana, consumed) = next_unit(&chars, i).ok_or(RomajiError::Unparsable { pos: i })?;
        out.push_str(kana);
        i += consumed;
    }
    Ok(out)
}

fn next_unit(chars: &[char], i: usize) -> Option<(&'static str, usize)> {
    let c = chars[i];
    if let Some(kana) = non_letter(c) {
        return Some((kana, 1));
    }
    if c == 'n' {
        if let Some(unit) = nasal(chars, i) {
            return Some(unit);
        }
    }
    if starts_sokuon(chars, i) {
        return Some((SOKUON_KANA, 1));
    }
    syllable(chars, i)
}

fn non_letter(c: char) -> Option<&'static str> {
    match c {
        '-' => Some(LONG_MARK_KANA),
        '.' => Some("。"),
        ',' => Some("、"),
        '!' => Some("！"),
        '?' => Some("？"),
        '~' => Some("〜"),
        _ if is_word_separator(c) => Some(SPACE),
        _ => None,
    }
}

/// §4.5 的 `n` 表；回傳 `None` 表示這個 n 是 な行、にゃ行的子音。
fn nasal(chars: &[char], i: usize) -> Option<(&'static str, usize)> {
    match chars.get(i + 1) {
        None => Some((NASAL_KANA, 1)),
        Some('\'') => Some((NASAL_KANA, 2)),
        Some('n') => {
            let starts_syllable = chars.get(i + 2).is_some_and(|&c| takes_syllable_after_n(c));
            Some((NASAL_KANA, if starts_syllable { 1 } else { 2 }))
        }
        Some(&next) if !takes_syllable_after_n(next) => Some((NASAL_KANA, 1)),
        Some(_) => None,
    }
}

fn takes_syllable_after_n(c: char) -> bool {
    is_romaji_vowel(c) || c == 'y'
}

/// 雙子音，或 `tch`。n 的重複由 `nasal` 處理，不算促音。
fn starts_sokuon(chars: &[char], i: usize) -> bool {
    let c = chars[i];
    if !c.is_ascii_alphabetic() || is_romaji_vowel(c) {
        return false;
    }
    let next = chars.get(i + 1).copied();
    next == Some(c) || (c == 't' && next == Some('c') && chars.get(i + 2) == Some(&'h'))
}

fn syllable(chars: &[char], i: usize) -> Option<(&'static str, usize)> {
    let longest = MAX_SYLLABLE_LETTERS.min(chars.len() - i);
    (1..=longest).rev().find_map(|len| {
        let key: String = chars[i..i + len].iter().collect();
        kana_of_romaji(&key).map(|kana| (kana, len))
    })
}

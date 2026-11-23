//! 打字判定（rust-core.md §4.5）。

use super::reverse::romaji_to_hiragana;
use super::romanize::{to_hiragana, to_romaji_reading, to_romaji_word, ReadingMode};
use super::table::{is_kana_char, is_romaji_vowel};

/// 期望讀音無法轉換時回傳 `false`；內容 lint（RC1）保證這不會發生在正式內容上。
pub fn typed_answer_matches(input: &str, expected_reading: &str, mode: ReadingMode) -> bool {
    if input.chars().any(is_kana_char) {
        return kana_key(input) == kana_key(expected_reading);
    }
    let Ok(expected) = to_romaji_reading(expected_reading, mode) else {
        return false;
    };
    let want = normalized(&expected);
    if want.is_empty() {
        return false;
    }
    let typed = letters_only(&expand_hyphens(&input.to_lowercase()));
    // 必須先直接比對：反向表的 ti 是 ち，轉回去 paatii 會變 paachii（F9）。
    fold_long_vowels(&typed) == want || matches_via_kana(&typed, &want)
}

fn matches_via_kana(typed: &str, want: &str) -> bool {
    romaji_to_hiragana(typed)
        .ok()
        .and_then(|kana| to_romaji_word(&kana).ok())
        .is_some_and(|romaji| normalized(&romaji) == want)
}

fn kana_key(text: &str) -> String {
    letters_only(&to_hiragana(text))
}

fn normalized(romaji: &str) -> String {
    fold_long_vowels(&letters_only(romaji))
}

fn letters_only(text: &str) -> String {
    text.chars().filter(|c| c.is_alphanumeric()).collect()
}

fn fold_long_vowels(text: &str) -> String {
    text.replace("oo", "ou").replace("ee", "ei")
}

fn expand_hyphens(text: &str) -> String {
    text.chars()
        .fold(String::with_capacity(text.len()), |mut out, c| {
            let previous_vowel = out.chars().last().filter(|&last| is_romaji_vowel(last));
            out.push(previous_vowel.filter(|_| c == '-').unwrap_or(c));
            out
        })
}

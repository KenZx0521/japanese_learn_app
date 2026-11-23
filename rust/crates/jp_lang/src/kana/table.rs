//! 假名↔羅馬字對照表（rust-core.md §4.2、§4.5）。
//!
//! 只有 `MONOGRAPHS`、`DIGRAPHS` 與 `LENIENT_ROMAJI` 進反向表；
//! 有損對應放在 `FORWARD_ONLY_*`，所以反向表不必靠覆寫順序決定結果。

use std::collections::HashMap;
use std::sync::LazyLock;

const HIRAGANA_START: char = '\u{3041}';
const HIRAGANA_END: char = '\u{3096}';
const KATAKANA_START: char = '\u{30A1}';
const KATAKANA_SHIFTABLE_END: char = '\u{30F6}';
const KATAKANA_END: char = '\u{30FA}';
const KATAKANA_TO_HIRAGANA_DISTANCE: u32 = 0x60;
pub(crate) const LONG_MARK: char = 'ー';

#[rustfmt::skip]
const MONOGRAPHS: &[(char, &str)] = &[
    ('あ', "a"), ('い', "i"), ('う', "u"), ('え', "e"), ('お', "o"),
    ('か', "ka"), ('き', "ki"), ('く', "ku"), ('け', "ke"), ('こ', "ko"),
    ('さ', "sa"), ('し', "shi"), ('す', "su"), ('せ', "se"), ('そ', "so"),
    ('た', "ta"), ('ち', "chi"), ('つ', "tsu"), ('て', "te"), ('と', "to"),
    ('な', "na"), ('に', "ni"), ('ぬ', "nu"), ('ね', "ne"), ('の', "no"),
    ('は', "ha"), ('ひ', "hi"), ('ふ', "fu"), ('へ', "he"), ('ほ', "ho"),
    ('ま', "ma"), ('み', "mi"), ('む', "mu"), ('め', "me"), ('も', "mo"),
    ('や', "ya"), ('ゆ', "yu"), ('よ', "yo"),
    ('ら', "ra"), ('り', "ri"), ('る', "ru"), ('れ', "re"), ('ろ', "ro"),
    ('わ', "wa"), ('を', "wo"),
    ('が', "ga"), ('ぎ', "gi"), ('ぐ', "gu"), ('げ', "ge"), ('ご', "go"),
    ('ざ', "za"), ('じ', "ji"), ('ず', "zu"), ('ぜ', "ze"), ('ぞ', "zo"),
    ('だ', "da"), ('で', "de"), ('ど', "do"),
    ('ば', "ba"), ('び', "bi"), ('ぶ', "bu"), ('べ', "be"), ('ぼ', "bo"),
    ('ぱ', "pa"), ('ぴ', "pi"), ('ぷ', "pu"), ('ぺ', "pe"), ('ぽ', "po"),
    ('ゔ', "vu"),
];

/// 舊假名、ぢ づ、單獨出現的小寫假名：羅馬字與其他假名相同，只能單向轉換。
#[rustfmt::skip]
const FORWARD_ONLY_MONOGRAPHS: &[(char, &str)] = &[
    ('ゐ', "i"), ('ゑ', "e"), ('ぢ', "ji"), ('づ', "zu"),
    ('ぁ', "a"), ('ぃ', "i"), ('ぅ', "u"), ('ぇ', "e"), ('ぉ', "o"),
    ('ゃ', "ya"), ('ゅ', "yu"), ('ょ', "yo"), ('ゎ', "wa"), ('ゕ', "ka"), ('ゖ', "ke"),
];

#[rustfmt::skip]
const DIGRAPHS: &[(char, char, &str)] = &[
    ('き', 'ゃ', "kya"), ('き', 'ゅ', "kyu"), ('き', 'ょ', "kyo"),
    ('し', 'ゃ', "sha"), ('し', 'ゅ', "shu"), ('し', 'ょ', "sho"),
    ('ち', 'ゃ', "cha"), ('ち', 'ゅ', "chu"), ('ち', 'ょ', "cho"),
    ('に', 'ゃ', "nya"), ('に', 'ゅ', "nyu"), ('に', 'ょ', "nyo"),
    ('ひ', 'ゃ', "hya"), ('ひ', 'ゅ', "hyu"), ('ひ', 'ょ', "hyo"),
    ('み', 'ゃ', "mya"), ('み', 'ゅ', "myu"), ('み', 'ょ', "myo"),
    ('り', 'ゃ', "rya"), ('り', 'ゅ', "ryu"), ('り', 'ょ', "ryo"),
    ('ぎ', 'ゃ', "gya"), ('ぎ', 'ゅ', "gyu"), ('ぎ', 'ょ', "gyo"),
    ('じ', 'ゃ', "ja"), ('じ', 'ゅ', "ju"), ('じ', 'ょ', "jo"),
    ('び', 'ゃ', "bya"), ('び', 'ゅ', "byu"), ('び', 'ょ', "byo"),
    ('ぴ', 'ゃ', "pya"), ('ぴ', 'ゅ', "pyu"), ('ぴ', 'ょ', "pyo"),
    ('い', 'ぇ', "ye"), ('う', 'ぃ', "wi"), ('う', 'ぇ', "we"),
    ('ゔ', 'ぁ', "va"), ('ゔ', 'ぃ', "vi"), ('ゔ', 'ぇ', "ve"), ('ゔ', 'ぉ', "vo"), ('ゔ', 'ゅ', "vyu"),
    ('く', 'ぁ', "kwa"), ('く', 'ぃ', "kwi"), ('く', 'ぇ', "kwe"), ('く', 'ぉ', "kwo"), ('ぐ', 'ぁ', "gwa"),
    ('し', 'ぇ', "she"), ('じ', 'ぇ', "je"), ('ち', 'ぇ', "che"),
    ('つ', 'ぁ', "tsa"), ('つ', 'ぃ', "tsi"), ('つ', 'ぇ', "tse"), ('つ', 'ぉ', "tso"),
    ('で', 'ぃ', "di"), ('ど', 'ぅ', "du"), ('で', 'ゅ', "dyu"),
    ('ふ', 'ぁ', "fa"), ('ふ', 'ぃ', "fi"), ('ふ', 'ぇ', "fe"), ('ふ', 'ぉ', "fo"), ('ふ', 'ゅ', "fyu"),
];

/// 反向時羅馬字被讓給常用假名的拼法（`ti` 是 ち、`wo` 是 を）。
#[rustfmt::skip]
const FORWARD_ONLY_DIGRAPHS: &[(char, char, &str)] = &[
    ('ぢ', 'ゃ', "ja"), ('ぢ', 'ゅ', "ju"), ('ぢ', 'ょ', "jo"),
    ('う', 'ぉ', "wo"), ('て', 'ぃ', "ti"), ('と', 'ぅ', "tu"), ('て', 'ゅ', "tyu"),
    ('す', 'ぃ', "si"), ('ず', 'ぃ', "zi"),
];

#[rustfmt::skip]
const LENIENT_ROMAJI: &[(&str, &str)] = &[
    ("si", "し"), ("ti", "ち"), ("tu", "つ"), ("hu", "ふ"), ("zi", "じ"),
    ("sya", "しゃ"), ("syu", "しゅ"), ("syo", "しょ"),
    ("tya", "ちゃ"), ("tyu", "ちゅ"), ("tyo", "ちょ"),
    ("cya", "ちゃ"), ("cyu", "ちゅ"), ("cyo", "ちょ"),
    ("zya", "じゃ"), ("zyu", "じゅ"), ("zyo", "じょ"),
    ("jya", "じゃ"), ("jyu", "じゅ"), ("jyo", "じょ"),
];

static MONOGRAPH_MAP: LazyLock<HashMap<char, &'static str>> = LazyLock::new(|| {
    MONOGRAPHS
        .iter()
        .chain(FORWARD_ONLY_MONOGRAPHS)
        .copied()
        .collect()
});

static DIGRAPH_MAP: LazyLock<HashMap<(char, char), &'static str>> = LazyLock::new(|| {
    DIGRAPHS
        .iter()
        .chain(FORWARD_ONLY_DIGRAPHS)
        .map(|&(first, second, romaji)| ((first, second), romaji))
        .collect()
});

/// 值是 `String`，因為 `MONOGRAPHS` 的鍵是 `char`；只建一次，查詢不配置記憶體。
static REVERSE_MAP: LazyLock<HashMap<&'static str, String>> = LazyLock::new(|| {
    let monographs = MONOGRAPHS
        .iter()
        .map(|&(kana, romaji)| (romaji, kana.to_string()));
    let digraphs = DIGRAPHS
        .iter()
        .map(|&(first, second, romaji)| (romaji, format!("{first}{second}")));
    let lenient = LENIENT_ROMAJI
        .iter()
        .map(|&(romaji, kana)| (romaji, kana.to_owned()));
    monographs.chain(digraphs).chain(lenient).collect()
});

pub(crate) fn monograph(kana: char) -> Option<&'static str> {
    MONOGRAPH_MAP.get(&kana).copied()
}

pub(crate) fn digraph(first: char, second: char) -> Option<&'static str> {
    DIGRAPH_MAP.get(&(first, second)).copied()
}

/// 反向表查詢：羅馬字音節 → 平假名。
pub(crate) fn kana_of_romaji(romaji: &str) -> Option<&'static str> {
    REVERSE_MAP.get(romaji).map(String::as_str)
}

pub(crate) fn hiragana_of(c: char) -> char {
    if (KATAKANA_START..=KATAKANA_SHIFTABLE_END).contains(&c) {
        char::from_u32(c as u32 - KATAKANA_TO_HIRAGANA_DISTANCE).unwrap_or(c)
    } else {
        c
    }
}

pub(crate) fn is_kana_char(c: char) -> bool {
    (HIRAGANA_START..=HIRAGANA_END).contains(&c)
        || (KATAKANA_START..=KATAKANA_END).contains(&c)
        || c == LONG_MARK
}

/// 非空且全為平假名、片假名或長音符。
pub fn is_kana_text(text: &str) -> bool {
    !text.is_empty() && text.chars().all(is_kana_char)
}

pub(crate) fn is_romaji_vowel(c: char) -> bool {
    matches!(c, 'a' | 'i' | 'u' | 'e' | 'o')
}

pub(crate) fn is_word_separator(c: char) -> bool {
    matches!(c, ' ' | '\u{3000}' | '\t')
}

/// §4.2 的標點表；ASCII 標點視同對應的全形標點。
pub(crate) fn punct_romaji(c: char) -> Option<&'static str> {
    Some(match c {
        '。' | '.' => ".",
        '、' | ',' => ",",
        '！' | '!' => "!",
        '？' | '?' => "?",
        '「' | '」' | '『' | '』' | '"' => "\"",
        '…' => "...",
        '〜' | '～' | '~' => "~",
        '（' | '(' => "(",
        '）' | ')' => ")",
        '・' => " ",
        _ => return None,
    })
}

/// 非空且全為 §4.2 標點表內的字元（`t` 的標點詞）。
pub fn is_punct_text(text: &str) -> bool {
    !text.is_empty() && text.chars().all(|c| punct_romaji(c).is_some())
}

pub(crate) fn is_opening_punct(c: char) -> bool {
    matches!(c, '「' | '『' | '（' | '(')
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    #[test]
    fn reversible_romaji_are_unique() {
        let romaji: Vec<&str> = MONOGRAPHS
            .iter()
            .map(|&(_, r)| r)
            .chain(DIGRAPHS.iter().map(|&(_, _, r)| r))
            .chain(LENIENT_ROMAJI.iter().map(|&(r, _)| r))
            .collect();
        let unique: HashSet<&str> = romaji.iter().copied().collect();
        assert_eq!(romaji.len(), unique.len());
    }

    #[test]
    fn forward_tables_do_not_shadow_each_other() {
        let monographs = MONOGRAPHS.iter().map(|&(k, _)| k);
        let forward = FORWARD_ONLY_MONOGRAPHS.iter().map(|&(k, _)| k);
        let kana: Vec<char> = monographs.chain(forward).collect();
        assert_eq!(kana.len(), kana.iter().collect::<HashSet<_>>().len());
    }

    #[test]
    fn hiragana_of_keeps_chars_outside_shiftable_range() {
        assert_eq!(hiragana_of('ア'), 'あ');
        assert_eq!(hiragana_of('ヶ'), 'ゖ');
        assert_eq!(hiragana_of('ヷ'), 'ヷ');
        assert_eq!(hiragana_of('ー'), 'ー');
    }
}

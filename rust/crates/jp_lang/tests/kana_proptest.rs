//! rust-core.md §11.1 的性質測試：不 panic、非有損集合來回一致。

use jp_lang::kana::{
    furigana, romaji_to_hiragana, to_romaji_sentence, to_romaji_word, typed_answer_matches,
    ReadingMode,
};
use proptest::prelude::*;

const NASAL: &str = "ん";
const SOKUON: &str = "っ";

/// 有損對應（§4.5）與小寫單字之外的音節。
const SYLLABLES: &[&str] = &[
    "あ", "い", "う", "え", "お", "か", "き", "く", "け", "こ", "さ", "し", "す", "せ", "そ", "た",
    "ち", "つ", "て", "と", "な", "に", "ぬ", "ね", "の", "は", "ひ", "ふ", "へ", "ほ", "ま", "み",
    "む", "め", "も", "や", "ゆ", "よ", "ら", "り", "る", "れ", "ろ", "わ", "を", "が", "ぎ", "ぐ",
    "げ", "ご", "ざ", "じ", "ず", "ぜ", "ぞ", "だ", "で", "ど", "ば", "び", "ぶ", "べ", "ぼ", "ぱ",
    "ぴ", "ぷ", "ぺ", "ぽ", "ゔ", "きゃ", "きゅ", "きょ", "しゃ", "しゅ", "しょ", "ちゃ", "ちゅ",
    "ちょ", "にゃ", "にゅ", "にょ", "ひゃ", "ひゅ", "ひょ", "みゃ", "みゅ", "みょ", "りゃ", "りゅ",
    "りょ", "ぎゃ", "ぎゅ", "ぎょ", "じゃ", "じゅ", "じょ", "びゃ", "びゅ", "びょ", "ぴゃ", "ぴゅ",
    "ぴょ", "いぇ", "うぃ", "うぇ", "ゔぁ", "ゔぃ", "ゔぇ", "ゔぉ", "ゔゅ", "くぁ", "くぃ", "くぇ",
    "くぉ", "ぐぁ", "しぇ", "じぇ", "ちぇ", "つぁ", "つぃ", "つぇ", "つぉ", "でぃ", "どぅ", "でゅ",
    "ふぁ", "ふぃ", "ふぇ", "ふぉ", "ふゅ",
];

fn is_doublable(syllable: &str) -> bool {
    let first = syllable.chars().next();
    let romaji_starts_consonant = to_romaji_word(syllable)
        .ok()
        .and_then(|r| r.chars().next())
        .is_some_and(|c| !"aiueon".contains(c));
    first.is_some() && romaji_starts_consonant
}

fn unit() -> impl Strategy<Value = String> {
    (prop::sample::select(SYLLABLES), 0..4u8).prop_map(|(syllable, kind)| match kind {
        0 => NASAL.to_owned(),
        1 if is_doublable(syllable) => format!("{SOKUON}{syllable}"),
        _ => syllable.to_owned(),
    })
}

/// んん 反向只得一個 ん；ん 後接促音違反 J04（ん 接小字）。兩者都不在來回一致的範圍內。
fn without_illegal_nasal_sequences(units: Vec<String>) -> Vec<String> {
    units.into_iter().fold(Vec::new(), |mut out, unit| {
        let after_nasal = out.last().is_some_and(|last: &String| last == NASAL);
        match (after_nasal, unit.as_str()) {
            (true, NASAL) => {}
            (true, text) => out.push(text.trim_start_matches(SOKUON).to_owned()),
            _ => out.push(unit),
        }
        out
    })
}

fn non_lossy_kana() -> impl Strategy<Value = String> {
    prop::collection::vec(unit(), 0..12)
        .prop_map(|units| without_illegal_nasal_sequences(units).concat())
}

fn any_kana_char() -> impl Strategy<Value = char> {
    prop_oneof![
        prop::char::range('\u{3041}', '\u{3096}'),
        prop::char::range('\u{30A1}', '\u{30F6}'),
        Just('ー'),
        Just('。'),
        Just('、'),
        Just('「'),
        Just('・'),
    ]
}

proptest! {
    // 不寫 regressions 檔，避免在工作目錄留下產物
    #![proptest_config(ProptestConfig { failure_persistence: None, ..ProptestConfig::default() })]

    #[test]
    fn non_lossy_kana_round_trips(kana in non_lossy_kana()) {
        let romaji = to_romaji_word(&kana).expect("生成的假名都合法");
        prop_assert_eq!(romaji_to_hiragana(&romaji), Ok(kana), "{}", romaji);
    }

    #[test]
    fn legal_kana_sequences_do_not_panic(chars in prop::collection::vec(any_kana_char(), 0..24)) {
        let kana: String = chars.into_iter().collect();
        let _ = to_romaji_word(&kana);
        let _ = to_romaji_sentence(&kana);
    }

    #[test]
    fn arbitrary_text_does_not_panic(text in ".{0,40}", other in ".{0,20}") {
        let _ = to_romaji_word(&text);
        let _ = to_romaji_sentence(&text);
        let _ = romaji_to_hiragana(&text);
        let _ = typed_answer_matches(&text, &other, ReadingMode::Word);
        let _ = typed_answer_matches(&text, &other, ReadingMode::Sentence);
    }

    #[test]
    fn furigana_does_not_panic(surface in ".{0,6}", kana in "[ぁ-ゖ]{0,10}") {
        let _ = furigana(&surface, &kana);
    }
}

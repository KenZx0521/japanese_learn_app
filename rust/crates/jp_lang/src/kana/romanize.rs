//! 假名→羅馬字（rust-core.md §4.2、§4.3）。

use thiserror::Error;

use super::table::{
    digraph, hiragana_of, is_kana_text, is_opening_punct, is_romaji_vowel, is_word_separator,
    monograph, punct_romaji, LONG_MARK,
};

const SOKUON: char = 'っ';
const NASAL: char = 'ん';

/// 尾端 は 讀 wa 的固定語。內容規範是切開寫，這裡只是防禦（lint RC4 會擋）。
pub const FIXED_WA_WORDS: [&str; 7] = [
    "こんにちは",
    "こんばんは",
    "では",
    "それでは",
    "または",
    "あるいは",
    "もしくは",
];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReadingMode {
    Word,
    Sentence,
}

/// `pos` 是整段輸入的字元索引（不是位元組）。
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum KanaError {
    #[error("無法轉換的字元 {ch:?}（位置 {pos}）")]
    InvalidChar { ch: char, pos: usize },
    #[error("長音符前沒有可延長的音（位置 {pos}）")]
    DanglingLongMark { pos: usize },
}

/// 已解析的語素。`parse_t` 在 jp_content，型別放這裡才能給 `romanize_words` 用。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Morph {
    pub surface: String,
    pub kana: String,
    pub r#ref: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Word {
    Punct(String),
    Morphs(Vec<Morph>),
}

pub fn reading_mode_of(reading: &str) -> ReadingMode {
    if reading.contains(is_word_separator) {
        ReadingMode::Sentence
    } else {
        ReadingMode::Word
    }
}

pub fn to_hiragana(s: &str) -> String {
    s.chars().map(hiragana_of).collect()
}

/// 單詞模式：は／へ／を 讀 ha／he／wo。
pub fn to_romaji_word(kana: &str) -> Result<String, KanaError> {
    romanize_at(kana, 0)
}

/// 句子模式：以空白切詞，獨立的 は／へ／を 讀 wa／e／o。
pub fn to_romaji_sentence(reading: &str) -> Result<String, KanaError> {
    let parts = reading
        .split(is_word_separator)
        .scan(0usize, |next_pos, token| {
            let at = *next_pos;
            *next_pos += token.chars().count() + 1;
            Some((at, token))
        })
        .filter(|(_, token)| !token.is_empty())
        .map(|(at, token)| romanize_token(token, at))
        .collect::<Result<Vec<_>, _>>()?;
    Ok(collapse_spaces(&parts.join(" ")))
}

pub fn to_romaji_reading(reading: &str, mode: ReadingMode) -> Result<String, KanaError> {
    match mode {
        ReadingMode::Word => to_romaji_word(reading),
        ReadingMode::Sentence => to_romaji_sentence(reading),
    }
}

/// `t` 模式：單一語素且 surface 為假名的詞才適用助詞規則，所以 `歯|は` 讀 ha。
/// 標點黏前一詞，開引號與開括號黏後一詞。
pub fn romanize_words(words: &[Word]) -> Result<String, KanaError> {
    let mut out = String::new();
    let mut glue_next = false;
    let mut at = 0;
    for word in words {
        let (text, opens, kana_len) = romanize_word(word, at)?;
        let needs_space = !out.is_empty() && !glue_next;
        if needs_space && (opens || matches!(word, Word::Morphs(_))) {
            out.push(' ');
        }
        out.push_str(&text);
        glue_next = opens;
        at += kana_len;
    }
    Ok(collapse_spaces(&out))
}

/// 回傳（羅馬字、是否為開引號或開括號、假名字元數）。
fn romanize_word(word: &Word, at: usize) -> Result<(String, bool, usize), KanaError> {
    match word {
        Word::Punct(punct) => {
            let opens = punct.chars().next().is_some_and(is_opening_punct);
            Ok((romanize_at(punct, at)?, opens, punct.chars().count()))
        }
        Word::Morphs(morphs) => {
            let kana: String = morphs.iter().map(|m| m.kana.as_str()).collect();
            let text = match morphs.as_slice() {
                [only] if is_kana_text(&only.surface) => romanize_lexeme(&kana, at)?,
                _ => romanize_at(&kana, at)?,
            };
            Ok((text, false, kana.chars().count()))
        }
    }
}

fn romanize_token(token: &str, at: usize) -> Result<String, KanaError> {
    let after_lead = token.trim_start_matches(is_punct);
    let core = after_lead.trim_end_matches(is_punct);
    let lead = &token[..token.len() - after_lead.len()];
    let trail = &after_lead[core.len()..];
    let body = romanize_lexeme(core, at + lead.chars().count())?;
    Ok(format!("{}{body}{}", punct_text(lead), punct_text(trail)))
}

fn romanize_lexeme(lexeme: &str, at: usize) -> Result<String, KanaError> {
    match lexeme {
        "は" => Ok("wa".to_owned()),
        "へ" => Ok("e".to_owned()),
        "を" => Ok("o".to_owned()),
        _ => match fixed_wa_stem(lexeme) {
            Some(stem) => Ok(format!("{}wa", romanize_at(stem, at)?)),
            None => romanize_at(lexeme, at),
        },
    }
}

fn fixed_wa_stem(lexeme: &str) -> Option<&str> {
    if FIXED_WA_WORDS.contains(&lexeme) {
        lexeme.strip_suffix('は')
    } else {
        None
    }
}

fn is_punct(c: char) -> bool {
    punct_romaji(c).is_some()
}

fn punct_text(punct: &str) -> String {
    punct.chars().filter_map(punct_romaji).collect()
}

/// `・` 會轉成空白，輸出前收斂成單一空白。
fn collapse_spaces(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// 單詞規則本體。`base` 是這段假名在整段輸入中的字元索引，只用於錯誤位置。
fn romanize_at(kana: &str, base: usize) -> Result<String, KanaError> {
    let chars: Vec<char> = kana.chars().map(hiragana_of).collect();
    let mut out = String::new();
    let mut i = 0;
    while i < chars.len() {
        i += append_unit(&chars, i, base, &mut out)?;
    }
    Ok(out)
}

/// 把 `chars[i]` 開始的一個單位轉成羅馬字接到 `out`，回傳吃掉的字元數。
fn append_unit(
    chars: &[char],
    i: usize,
    base: usize,
    out: &mut String,
) -> Result<usize, KanaError> {
    let c = chars[i];
    if c == SOKUON {
        out.extend(sokuon_letter(chars, i + 1));
        return Ok(1);
    }
    if c == NASAL {
        out.push_str(nasal_text(chars, i + 1));
        return Ok(1);
    }
    if c == LONG_MARK {
        let letter =
            long_mark_letter(chars, i, out).ok_or(KanaError::DanglingLongMark { pos: base + i })?;
        out.push(letter);
        return Ok(1);
    }
    if let Some(punct) = punct_romaji(c) {
        out.push_str(punct);
        return Ok(1);
    }
    let (romaji, consumed) = syllable(chars, i).ok_or(KanaError::InvalidChar {
        ch: c,
        pos: base + i,
    })?;
    out.push_str(romaji);
    Ok(consumed)
}

/// 雙字元（拗音、外來語）優先於單字元。
fn syllable(chars: &[char], i: usize) -> Option<(&'static str, usize)> {
    let first = *chars.get(i)?;
    chars
        .get(i + 1)
        .and_then(|&second| digraph(first, second))
        .map(|romaji| (romaji, 2))
        .or_else(|| monograph(first).map(|romaji| (romaji, 1)))
}

fn next_syllable_initial(chars: &[char], i: usize) -> Option<(&'static str, char)> {
    let (romaji, _) = syllable(chars, i)?;
    romaji.chars().next().map(|initial| (romaji, initial))
}

/// 促音重複下一音節的首子音，`ch` 前寫 `t`；後面沒有子音時省略。
fn sokuon_letter(chars: &[char], next: usize) -> Option<char> {
    let (romaji, initial) = next_syllable_initial(chars, next)?;
    if is_romaji_vowel(initial) {
        None
    } else if romaji.starts_with("ch") {
        Some('t')
    } else {
        Some(initial)
    }
}

fn nasal_text(chars: &[char], next: usize) -> &'static str {
    match next_syllable_initial(chars, next) {
        Some((_, initial)) if is_romaji_vowel(initial) || initial == 'y' => "n'",
        _ => "n",
    }
}

/// 重複前一母音，ん 後重複 n；句首、促音後、標點後沒有可延長的音。
fn long_mark_letter(chars: &[char], i: usize, out: &str) -> Option<char> {
    if i > 0 && chars[i - 1] == SOKUON {
        return None;
    }
    out.chars()
        .last()
        .filter(|&c| is_romaji_vowel(c) || c == 'n')
}

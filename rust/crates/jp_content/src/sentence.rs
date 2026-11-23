//! `t` 解析與衍生資料（rust-core.md §3.3）。

use jp_lang::kana::{
    furigana_or_whole, is_kana_text, is_punct_text, romanize_words, KanaError, Morph, Ruby, Word,
};
use thiserror::Error;

use crate::schema::TtsMode;

const NEW_PREFIX: &str = "@new:";
const NAME_REF: &str = "@name";
const CONTENT_REF_PREFIXES: [&str; 2] = ["vo.", "gr."];
const GRAMMAR_REF_PREFIX: &str = "gr.";
/// 排序題詞塊：這些助詞黏到前一詞。
const CHUNK_PARTICLES: [&str; 16] = [
    "は", "が", "を", "に", "で", "へ", "と", "も", "の", "から", "まで", "より", "か", "ね", "よ",
    "や",
];
/// (助詞 surface, TTS 讀音)。
const SPOKEN_PARTICLES: [(&str, &str); 2] = [("は", "わ"), ("へ", "え")];

#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum TParseError {
    #[error("空字串")]
    Empty,
    #[error("含漢字或數字卻省略讀音：{surface}")]
    MissingKana { surface: String },
    #[error("沒有 ref：{token}")]
    MissingRef { token: String },
    #[error("ref 不合法：{token}")]
    BadRef { token: String },
    #[error("讀音無法轉換：{0}")]
    Romaji(#[from] KanaError),
}

/// 語音送出內容（`SpeechDto` 的來源）。行動平台送 `text`，Linux 送 `kana`。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Speech {
    pub text: String,
    pub kana: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParsedWord {
    pub surface: String,
    pub kana: String,
    pub romaji: String,
    pub speech_kana: String,
    pub ruby: Vec<Ruby>,
    pub refs: Vec<String>,
    pub ref_id: Option<String>,
    pub gloss_zh: Option<String>,
    pub is_punct: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParsedSentence {
    pub words: Vec<ParsedWord>,
    pub display: String,
    pub romaji: String,
    pub spaced_kana: String,
    pub speech: Speech,
    pub has_name: bool,
}

/// 排序題的一個詞塊；`word_indices` 指向 `ParsedSentence::words`。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Chunk {
    pub surface: String,
    pub word_indices: Vec<usize>,
}

pub fn parse_t(t: &str) -> Result<Vec<Word>, TParseError> {
    let tokens: Vec<&str> = t.split_whitespace().collect();
    if tokens.is_empty() {
        return Err(TParseError::Empty);
    }
    tokens.into_iter().map(parse_word).collect()
}

fn parse_word(token: &str) -> Result<Word, TParseError> {
    if !token.contains('|') && is_punct_text(token) {
        return Ok(Word::Punct(token.to_owned()));
    }
    token
        .split('+')
        .map(parse_morph)
        .collect::<Result<Vec<_>, _>>()
        .map(Word::Morphs)
}

fn parse_morph(part: &str) -> Result<Morph, TParseError> {
    let fields: Vec<&str> = part.split('|').collect();
    match fields.as_slice() {
        [_] => Err(missing_ref(part)),
        [surface, second] => parse_two_field_morph(part, surface, second),
        [surface, kana, reference] if !surface.is_empty() && !kana.is_empty() => {
            ensure_valid_ref(reference, part)?;
            Ok(morph(surface, kana, reference))
        }
        _ => Err(bad_ref(part)),
    }
}

fn parse_two_field_morph(part: &str, surface: &str, second: &str) -> Result<Morph, TParseError> {
    if surface.is_empty() {
        return Err(bad_ref(part));
    }
    if is_kana_text(second) {
        return Err(missing_ref(part));
    }
    ensure_valid_ref(second, part)?;
    if !is_kana_text(surface) {
        return Err(TParseError::MissingKana {
            surface: surface.to_owned(),
        });
    }
    Ok(morph(surface, surface, second))
}

fn morph(surface: &str, kana: &str, reference: &str) -> Morph {
    Morph {
        surface: surface.to_owned(),
        kana: kana.to_owned(),
        r#ref: reference.to_owned(),
    }
}

fn missing_ref(token: &str) -> TParseError {
    TParseError::MissingRef {
        token: token.to_owned(),
    }
}

fn bad_ref(token: &str) -> TParseError {
    TParseError::BadRef {
        token: token.to_owned(),
    }
}

fn ensure_valid_ref(reference: &str, token: &str) -> Result<(), TParseError> {
    if is_valid_ref(reference) {
        Ok(())
    } else {
        Err(bad_ref(token))
    }
}

fn is_valid_ref(reference: &str) -> bool {
    reference == NAME_REF
        || reference
            .strip_prefix(NEW_PREFIX)
            .is_some_and(|gloss| !gloss.is_empty())
        || CONTENT_REF_PREFIXES
            .iter()
            .any(|prefix| reference.len() > prefix.len() && reference.starts_with(prefix))
}

/// 解析並算出全部衍生資料。`own`、`drill` 為 §12.2 解析順序的前兩項。
pub fn analyze_t(
    t: &str,
    own: Option<TtsMode>,
    drill: Option<TtsMode>,
) -> Result<ParsedSentence, TParseError> {
    analyze_words(&parse_t(t)?, own, drill)
}

pub fn analyze_words(
    words: &[Word],
    own: Option<TtsMode>,
    drill: Option<TtsMode>,
) -> Result<ParsedSentence, TParseError> {
    let parsed = words
        .iter()
        .map(parse_word_metadata)
        .collect::<Result<Vec<_>, _>>()?;
    let display: String = parsed.iter().map(|word| word.surface.as_str()).collect();
    let spaced_kana = join_words(
        parsed
            .iter()
            .map(|word| (word.kana.as_str(), word.is_punct)),
    );
    let kana = speech_kana(&parsed);
    let has_name = words.iter().any(word_has_name);
    let text = match resolve_tts(has_name, own, drill) {
        TtsMode::Auto => display.clone(),
        TtsMode::Kana => kana.clone(),
    };
    Ok(ParsedSentence {
        romaji: romanize_words(words)?,
        words: parsed,
        display,
        spaced_kana,
        speech: Speech { text, kana },
        has_name,
    })
}

pub fn resolve_tts(has_name: bool, own: Option<TtsMode>, drill: Option<TtsMode>) -> TtsMode {
    if has_name {
        return TtsMode::Kana;
    }
    own.or(drill).unwrap_or(TtsMode::Auto)
}

fn parse_word_metadata(word: &Word) -> Result<ParsedWord, TParseError> {
    match word {
        Word::Punct(punct) => Ok(ParsedWord {
            surface: punct.clone(),
            kana: punct.clone(),
            romaji: romanize_words(std::slice::from_ref(word))?,
            speech_kana: punct.clone(),
            ruby: vec![Ruby {
                base: punct.clone(),
                ruby: None,
            }],
            refs: Vec::new(),
            ref_id: None,
            gloss_zh: None,
            is_punct: true,
        }),
        Word::Morphs(morphs) => morph_word_metadata(word, morphs),
    }
}

fn morph_word_metadata(word: &Word, morphs: &[Morph]) -> Result<ParsedWord, TParseError> {
    let surface: String = morphs.iter().map(|m| m.surface.as_str()).collect();
    let kana: String = morphs.iter().map(|m| m.kana.as_str()).collect();
    let refs: Vec<String> = morphs.iter().map(|m| m.r#ref.clone()).collect();
    Ok(ParsedWord {
        romaji: romanize_words(std::slice::from_ref(word))?,
        speech_kana: spoken_word_kana(morphs, &kana),
        ruby: morphs
            .iter()
            .flat_map(|m| furigana_or_whole(&m.surface, &m.kana))
            .collect(),
        ref_id: refs.iter().find(|r| !r.starts_with('@')).cloned(),
        gloss_zh: morphs.iter().find_map(|m| new_gloss(&m.r#ref)),
        refs,
        surface,
        kana,
        is_punct: false,
    })
}

fn new_gloss(reference: &str) -> Option<String> {
    reference.strip_prefix(NEW_PREFIX).map(str::to_owned)
}

/// 單獨成詞且 surface 為假名的 は／へ 念 わ／え；`歯|は` 不換。
fn spoken_word_kana(morphs: &[Morph], kana: &str) -> String {
    let [only] = morphs else {
        return kana.to_owned();
    };
    SPOKEN_PARTICLES
        .iter()
        .find(|(particle, _)| only.surface == *particle && only.kana == *particle)
        .map_or_else(|| kana.to_owned(), |(_, spoken)| (*spoken).to_owned())
}

fn word_has_name(word: &Word) -> bool {
    matches!(word, Word::Morphs(morphs) if morphs.iter().any(|m| m.r#ref == NAME_REF))
}

/// kana 模式的語音文字。空白處理以實機試聽定案，集中在這裡。
pub fn speech_kana(words: &[ParsedWord]) -> String {
    join_words(
        words
            .iter()
            .map(|word| (word.speech_kana.as_str(), word.is_punct)),
    )
}

fn join_words<'a>(words: impl Iterator<Item = (&'a str, bool)>) -> String {
    words.fold(String::new(), |mut out, (text, is_punct)| {
        if !out.is_empty() && !is_punct {
            out.push(' ');
        }
        out.push_str(text);
        out
    })
}

fn is_particle_word(word: &ParsedWord) -> bool {
    matches!(word.refs.as_slice(), [only] if only.starts_with(GRAMMAR_REF_PREFIX))
        && CHUNK_PARTICLES.contains(&word.surface.as_str())
}

/// 排序題詞塊：標點不算，助詞黏到前一詞。`accept_orders` 的索引指向這裡的順序。
pub fn reorder_chunks(sentence: &ParsedSentence) -> Vec<Chunk> {
    let mut chunks: Vec<Chunk> = Vec::new();
    for (index, word) in sentence.words.iter().enumerate() {
        if word.is_punct {
            continue;
        }
        match chunks.last_mut() {
            Some(previous) if is_particle_word(word) => {
                previous.surface.push_str(&word.surface);
                previous.word_indices.push(index);
            }
            _ => chunks.push(Chunk {
                surface: word.surface.clone(),
                word_indices: vec![index],
            }),
        }
    }
    chunks
}

/// `answer` 欄位：含 `|` 或空白視為內嵌 `t`，否則為 `se.*` ID。
pub fn is_inline_t(text: &str) -> bool {
    text.contains('|') || text.contains(char::is_whitespace)
}

/// 句框展開：`{slot}` 代入每列的內容；未宣告或未使用的 slot 回傳說明文字。
pub fn expand_frame(
    frame: &str,
    slots: &std::collections::BTreeMap<String, String>,
) -> Result<String, String> {
    let mut used = std::collections::BTreeSet::new();
    let mut expanded = String::new();
    let mut rest = frame;
    while let Some(start) = rest.find('{') {
        expanded.push_str(&rest[..start]);
        let end = rest[start..]
            .find('}')
            .ok_or_else(|| format!("句框 {frame} 的 {{ 沒有對應的 }}"))?;
        let key = &rest[start + 1..start + end];
        let value = slots
            .get(key)
            .ok_or_else(|| format!("句框的 {{{key}}} 沒有對應的列欄位"))?;
        expanded.push_str(value);
        used.insert(key);
        rest = &rest[start + end + 1..];
    }
    expanded.push_str(rest);
    let unused: Vec<&str> = slots
        .keys()
        .map(String::as_str)
        .filter(|key| !used.contains(key))
        .collect();
    if unused.is_empty() {
        Ok(expanded)
    } else {
        Err(format!("列欄位 {unused:?} 未出現在句框"))
    }
}

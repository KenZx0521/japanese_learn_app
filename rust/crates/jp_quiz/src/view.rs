//! 由內容組出 `SentenceView`、語音與 MixedText 字串（§3.3、§8.3、§9.5）。

use jp_content::schema::{Style, TtsMode};
use jp_content::sentence::{
    analyze_t, is_inline_t, resolve_tts, ParsedSentence, ParsedWord, Speech,
};
use jp_content::store::{SentenceEntry, VocabEntry};
use jp_content::ContentStore;
use jp_lang::kana::{furigana_or_whole, is_kana_text, is_punct_text};

use crate::error::QuizError;
use crate::model::SentenceView;

const ZH_SEPARATOR: &str = "、";

pub(crate) fn join_zh(zh: &[String]) -> String {
    zh.join(ZH_SEPARATOR)
}

pub(crate) fn strip_spaces(text: &str) -> String {
    text.chars().filter(|c| !c.is_whitespace()).collect()
}

fn needs_reading(surface: &str) -> bool {
    surface.chars().any(|c| {
        let single = c.to_string();
        !is_kana_text(&single) && !is_punct_text(&single)
    })
}

/// 純日文包成 `{ja:…}`，含漢字時帶讀音（§9.5）。
pub(crate) fn mixed_ja(surface: &str, reading: &str) -> String {
    if needs_reading(surface) {
        format!("{{ja:{surface}|{reading}}}")
    } else {
        format!("{{ja:{surface}}}")
    }
}

pub(crate) fn mixed_sentence(parsed: &ParsedSentence) -> String {
    mixed_ja(&parsed.display, &strip_spaces(&parsed.spaced_kana))
}

pub(crate) fn mixed_word(entry: &VocabEntry) -> String {
    mixed_ja(&entry.def.surface, &strip_spaces(&entry.def.kana))
}

fn with_effective_tts(
    parsed: &ParsedSentence,
    own: Option<TtsMode>,
    drill: Option<TtsMode>,
) -> ParsedSentence {
    let text = match resolve_tts(parsed.has_name, own, drill) {
        TtsMode::Auto => parsed.display.clone(),
        TtsMode::Kana => parsed.speech.kana.clone(),
    };
    ParsedSentence {
        speech: Speech {
            text,
            kana: parsed.speech.kana.clone(),
        },
        ..parsed.clone()
    }
}

pub(crate) fn lookup_sentence<'c>(
    content: &'c ContentStore,
    id: &str,
) -> Result<&'c SentenceEntry, QuizError> {
    content
        .sentence_by_id(id)
        .ok_or_else(|| QuizError::not_found("sentence", id))
}

/// `drill_tts` 只在句子自身沒有 `tts` 時生效（§3.3 解析順序）。
pub(crate) fn sentence_view(entry: &SentenceEntry, drill_tts: Option<TtsMode>) -> SentenceView {
    let own = entry.def.tts;
    SentenceView {
        id: entry.def.id.clone(),
        zh: entry.def.zh.clone(),
        style: entry.def.style,
        parsed: with_effective_tts(&entry.parsed, own, drill_tts),
    }
}

/// 內嵌 `t` 的欄位，`own_tts` 來自 `rows[]`。
#[derive(Debug, Clone, Copy)]
pub(crate) struct InlineT<'a> {
    pub t: &'a str,
    pub id: &'a str,
    pub zh: &'a str,
    pub style: Style,
    pub own_tts: Option<TtsMode>,
    pub drill_tts: Option<TtsMode>,
}

pub(crate) fn inline_view(inline: InlineT<'_>) -> Result<SentenceView, QuizError> {
    let parsed = analyze_t(inline.t, inline.own_tts, inline.drill_tts)
        .map_err(|err| QuizError::content(inline.id, err))?;
    Ok(SentenceView {
        id: inline.id.to_owned(),
        zh: inline.zh.to_owned(),
        style: inline.style,
        parsed,
    })
}

/// `answer` 欄位：含 `|` 或空白視為內嵌 `t`，否則為 `se.*` ID（§3.2）。
pub(crate) fn answer_view(
    content: &ContentStore,
    answer: InlineT<'_>,
) -> Result<SentenceView, QuizError> {
    if is_inline_t(answer.t) {
        inline_view(answer)
    } else {
        Ok(sentence_view(
            lookup_sentence(content, answer.t)?,
            answer.drill_tts,
        ))
    }
}

/// 單字題的 `reveal` 由單字合成，不取 `examples`（§8.3）。
pub(crate) fn vocab_reveal(entry: &VocabEntry) -> SentenceView {
    let def = &entry.def;
    let word = ParsedWord {
        surface: def.surface.clone(),
        kana: def.kana.clone(),
        romaji: entry.romaji.clone(),
        speech_kana: entry.speech.kana.clone(),
        ruby: furigana_or_whole(&def.surface, &strip_spaces(&def.kana)),
        refs: vec![def.id.clone()],
        ref_id: Some(def.id.clone()),
        gloss_zh: None,
        is_punct: false,
    };
    SentenceView {
        id: def.id.clone(),
        zh: join_zh(&def.zh),
        style: Style::Neutral,
        parsed: ParsedSentence {
            words: vec![word],
            display: def.surface.clone(),
            romaji: entry.romaji.clone(),
            spaced_kana: def.kana.clone(),
            speech: entry.speech.clone(),
            has_name: false,
        },
    }
}

/// `use` 卡項目的標題（`gr.*`）。
pub(crate) fn use_item_title<'c>(content: &'c ContentStore, id: &str) -> Option<&'c str> {
    content.grammar_by_id(id).map(|item| item.title_zh.as_str())
}

/// 沒有例句的 `use` 卡退回時，只顯示標題，避免整個複習佇列卡住。
/// `words` 為空，Dart 依 `display` 走 MixedText，所以保留 `{ja:…}` 標記。
pub(crate) fn title_reveal(id: &str, title_zh: &str) -> SentenceView {
    SentenceView {
        id: id.to_owned(),
        zh: String::new(),
        style: Style::Neutral,
        parsed: ParsedSentence {
            words: Vec::new(),
            display: title_zh.to_owned(),
            romaji: String::new(),
            spaced_kana: String::new(),
            speech: Speech {
                text: String::new(),
                kana: String::new(),
            },
            has_name: false,
        },
    }
}

//! `search_vocab` 的比對與排序（§9.4 表）。

use jp_content::store::VocabEntry;
use jp_lang::kana::{is_kana_text, romaji_to_hiragana, to_hiragana};

use super::views::Views;
use super::vocab::{course_key, is_listable};
use crate::api::dto_content::VocabSummaryDto;
use crate::api::error::CoreError;

const LATIN_EXTRA_CHARS: [char; 3] = [' ', '\'', '-'];

/// 完全相等 < 前綴相符 < 包含。
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
enum MatchRank {
    Exact,
    Prefix,
    Contains,
}

fn rank_of(haystack: &str, needle: &str) -> Option<MatchRank> {
    if needle.is_empty() {
        None
    } else if haystack == needle {
        Some(MatchRank::Exact)
    } else if haystack.starts_with(needle) {
        Some(MatchRank::Prefix)
    } else if haystack.contains(needle) {
        Some(MatchRank::Contains)
    } else {
        None
    }
}

fn without_spaces(text: &str) -> String {
    text.chars().filter(|c| !c.is_whitespace()).collect()
}

fn normalized_kana(text: &str) -> String {
    without_spaces(&to_hiragana(text))
}

fn normalized_romaji(text: &str) -> String {
    text.chars()
        .filter(|c| !c.is_whitespace() && *c != '\'')
        .collect::<String>()
        .to_ascii_lowercase()
}

fn contains_kana(text: &str) -> bool {
    text.chars()
        .any(|c| is_kana_text(c.encode_utf8(&mut [0; 4])))
}

fn is_latin(text: &str) -> bool {
    text.chars()
        .all(|c| c.is_ascii_alphabetic() || LATIN_EXTRA_CHARS.contains(&c))
}

enum Query {
    Kana(String),
    Latin {
        hiragana: Option<String>,
        romaji: String,
    },
    Text(String),
}

fn classify(trimmed: &str) -> Query {
    if contains_kana(trimmed) {
        Query::Kana(normalized_kana(trimmed))
    } else if is_latin(trimmed) {
        Query::Latin {
            hiragana: romaji_to_hiragana(trimmed)
                .ok()
                .map(|kana| normalized_kana(&kana)),
            romaji: normalized_romaji(trimmed),
        }
    } else {
        Query::Text(trimmed.to_owned())
    }
}

fn rank_entry(entry: &VocabEntry, query: &Query) -> Option<MatchRank> {
    let def = &entry.def;
    match query {
        Query::Kana(kana) => rank_of(&normalized_kana(&def.kana), kana),
        Query::Latin { hiragana, romaji } => {
            let by_kana = hiragana
                .as_deref()
                .and_then(|kana| rank_of(&normalized_kana(&def.kana), kana));
            let by_romaji = rank_of(&normalized_romaji(&entry.romaji), romaji);
            by_kana.into_iter().chain(by_romaji).min()
        }
        Query::Text(text) => std::iter::once(def.surface.as_str())
            .chain(def.zh.iter().map(String::as_str))
            .filter_map(|field| rank_of(field, text))
            .min(),
    }
}

pub(super) fn search(
    views: &Views<'_>,
    query: &str,
    limit: usize,
) -> Result<Vec<VocabSummaryDto>, CoreError> {
    let trimmed = query.trim();
    if trimmed.is_empty() {
        return Ok(Vec::new());
    }
    let parsed = classify(trimmed);
    let mut ranked: Vec<(MatchRank, (u32, u32), &VocabEntry)> = views
        .content()
        .vocab()
        .iter()
        .filter(|entry| is_listable(entry))
        .filter_map(|entry| Some((rank_entry(entry, &parsed)?, course_key(entry, views), entry)))
        .collect();
    ranked.sort_by_key(|(rank, position, _)| (*rank, *position));
    ranked
        .iter()
        .take(limit)
        .map(|(_, _, entry)| views.vocab_summary(entry))
        .collect()
}

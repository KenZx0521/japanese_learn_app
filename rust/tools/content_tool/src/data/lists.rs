//! JLPT 清單、字幕詞頻、Kanjium 音調、JmdictFurigana。

use std::collections::{HashMap, HashSet};
use std::path::Path;

use serde::Deserialize;

use super::read_text;

/// `jmdict_seq,kana,kanji,waller_definition`（yomitan-jlpt-vocab 的 `original_data`）。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JlptRow {
    pub id: String,
    pub kana: String,
    pub kanji: String,
}

#[derive(Debug, Clone, Default)]
pub struct JlptLists {
    pub n5: Vec<JlptRow>,
    pub n4: Vec<JlptRow>,
}

const JLPT_HEADER_FIELD: &str = "jmdict_seq";
const CSV_FIELD_COUNT: usize = 4;

fn parse_csv(text: &str) -> Vec<JlptRow> {
    text.lines()
        .filter(|line| !line.starts_with(JLPT_HEADER_FIELD) && !line.trim().is_empty())
        .filter_map(|line| {
            let mut fields = line.splitn(CSV_FIELD_COUNT, ',');
            Some(JlptRow {
                id: fields.next()?.to_owned(),
                kana: fields.next()?.to_owned(),
                kanji: fields.next()?.to_owned(),
            })
        })
        .collect()
}

impl JlptLists {
    pub fn load(n5: &Path, n4: &Path) -> Result<Self, String> {
        Ok(Self {
            n5: parse_csv(&read_text(n5)?),
            n4: parse_csv(&read_text(n4)?),
        })
    }

    pub fn ids(&self) -> HashSet<String> {
        self.n5
            .iter()
            .chain(&self.n4)
            .map(|row| row.id.clone())
            .collect()
    }
}

#[derive(Deserialize)]
struct RawFreq {
    entries: Vec<FreqEntry>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct FreqEntry {
    pub text: String,
    pub reading: String,
    pub rank: u32,
}

pub fn load_freq(path: &Path) -> Result<Vec<FreqEntry>, String> {
    let raw: RawFreq = serde_json::from_str(&read_text(path)?)
        .map_err(|err| format!("字幕詞頻解析失敗：{err}"))?;
    let mut entries = raw.entries;
    entries.sort_by_key(|entry| entry.rank);
    Ok(entries)
}

/// `word\treading\taccent`，accent 可多值（`0,2`）。假名詞的 reading 為空。
#[derive(Debug, Clone, Default)]
pub struct AccentIndex {
    entries: HashMap<(String, String), Vec<u8>>,
}

fn parse_accents(field: &str) -> Vec<u8> {
    field
        .split(',')
        .filter_map(|part| {
            part.chars()
                .filter(char::is_ascii_digit)
                .collect::<String>()
                .parse()
                .ok()
        })
        .collect()
}

impl AccentIndex {
    pub fn from_entries(entries: HashMap<(String, String), Vec<u8>>) -> Self {
        Self { entries }
    }

    pub fn load(path: &Path) -> Result<Self, String> {
        let mut entries: HashMap<(String, String), Vec<u8>> = HashMap::new();
        for line in read_text(path)?.lines() {
            let mut fields = line.split('\t');
            let (Some(word), Some(reading), Some(accent)) =
                (fields.next(), fields.next(), fields.next())
            else {
                continue;
            };
            let reading = if reading.is_empty() { word } else { reading };
            entries
                .entry((word.to_owned(), reading.to_owned()))
                .or_default()
                .extend(parse_accents(accent));
        }
        Ok(Self { entries })
    }

    pub fn accents(&self, surface: &str, kana: &str) -> Option<&[u8]> {
        self.entries
            .get(&(surface.to_owned(), kana.to_owned()))
            .map(Vec::as_slice)
    }
}

/// 振假名的一段：本文與讀音；`None` 為送假名。
pub type FuriganaSegment = (String, Option<String>);

/// `(text, reading)` 對應的振假名切分；連續的 ruby／無 ruby 片段在比對時會先併段。
#[derive(Debug, Clone, Default)]
pub struct FuriganaIndex {
    entries: HashMap<(String, String), Vec<FuriganaSegment>>,
}

#[derive(Deserialize)]
struct RawFurigana {
    text: String,
    reading: String,
    furigana: Vec<RawFuriganaPart>,
}

#[derive(Deserialize)]
struct RawFuriganaPart {
    ruby: String,
    rt: Option<String>,
}

impl FuriganaIndex {
    pub fn from_entries(entries: HashMap<(String, String), Vec<FuriganaSegment>>) -> Self {
        Self { entries }
    }

    pub fn load(path: &Path) -> Result<Self, String> {
        let raw: Vec<RawFurigana> = serde_json::from_str(&read_text(path)?)
            .map_err(|err| format!("JmdictFurigana 解析失敗：{err}"))?;
        let entries = raw
            .into_iter()
            .map(|entry| {
                let parts = entry
                    .furigana
                    .into_iter()
                    .map(|part| (part.ruby, part.rt))
                    .collect();
                ((entry.text, entry.reading), parts)
            })
            .collect();
        Ok(Self { entries })
    }

    pub fn get(&self, surface: &str, kana: &str) -> Option<&[FuriganaSegment]> {
        self.entries
            .get(&(surface.to_owned(), kana.to_owned()))
            .map(Vec::as_slice)
    }
}

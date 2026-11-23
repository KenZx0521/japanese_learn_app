//! JMdict 的查詢索引（reuse-and-verification.md §2.2）。比對一律用 `(surface, kana)`，內容不存 JMdict ID。

use std::collections::{HashMap, HashSet};
use std::io::Read;
use std::rc::Rc;

use serde::Deserialize;

const ALL_KANJI: &str = "*";
const USUALLY_KANA: &str = "uk";
/// 只以這些形式存在的配對要警告（J03）。`gikun`、`ateji` 是正常用法，不算。
const IRREGULAR_TAGS: [&str; 9] = ["sK", "sk", "oK", "ok", "iK", "ik", "io", "rK", "rk"];

#[derive(Deserialize)]
struct RawJmdict {
    words: Vec<RawWord>,
}

#[derive(Deserialize)]
struct RawWord {
    id: String,
    kanji: Vec<RawKanji>,
    kana: Vec<RawKana>,
    sense: Vec<RawSense>,
}

#[derive(Deserialize)]
struct RawKanji {
    text: String,
    tags: Vec<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RawKana {
    text: String,
    tags: Vec<String>,
    applies_to_kanji: Vec<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RawSense {
    misc: Vec<String>,
    part_of_speech: Vec<String>,
}

/// 一個詞條在某配對或假名下的資訊。詞性跨義項取聯集。
#[derive(Debug, Clone)]
struct Hit {
    tags: Vec<String>,
    usually_kana: bool,
    pos: Rc<Vec<String>>,
}

/// JLPT 清單列要用的詞條展開（C06）。ID 只在記憶體內使用。
#[derive(Debug, Clone, Default)]
pub struct Expansion {
    pub pairs: Vec<(String, String)>,
    pub kana: Vec<String>,
}

#[derive(Debug, Default)]
pub struct JmdictIndex {
    pairs: HashMap<(String, String), Vec<Hit>>,
    kana: HashMap<String, Vec<Hit>>,
    kanji: HashSet<String>,
    expansions: HashMap<String, Expansion>,
}

fn applies_to(reading: &RawKana, kanji: &str) -> bool {
    reading
        .applies_to_kanji
        .iter()
        .any(|form| form == ALL_KANJI || form == kanji)
}

fn add_word(index: &mut JmdictIndex, word: RawWord, keep_ids: &HashSet<String>) {
    let usually_kana = word
        .sense
        .first()
        .is_some_and(|sense| sense.misc.iter().any(|m| m == USUALLY_KANA));
    let pos: Rc<Vec<String>> = Rc::new(
        word.sense
            .into_iter()
            .flat_map(|sense| sense.part_of_speech)
            .collect(),
    );
    let mut expansion = keep_ids.contains(&word.id).then(Expansion::default);
    for reading in &word.kana {
        index
            .kana
            .entry(reading.text.clone())
            .or_default()
            .push(Hit {
                tags: reading.tags.clone(),
                usually_kana,
                pos: Rc::clone(&pos),
            });
        if let Some(expansion) = expansion.as_mut() {
            expansion.kana.push(reading.text.clone());
        }
        for kanji in word.kanji.iter().filter(|k| applies_to(reading, &k.text)) {
            let tags = kanji.tags.iter().chain(&reading.tags).cloned().collect();
            index
                .pairs
                .entry((kanji.text.clone(), reading.text.clone()))
                .or_default()
                .push(Hit {
                    tags,
                    usually_kana,
                    pos: Rc::clone(&pos),
                });
            if let Some(expansion) = expansion.as_mut() {
                expansion
                    .pairs
                    .push((kanji.text.clone(), reading.text.clone()));
            }
        }
    }
    index.kanji.extend(word.kanji.into_iter().map(|k| k.text));
    if let Some(expansion) = expansion {
        index.expansions.insert(word.id, expansion);
    }
}

impl JmdictIndex {
    /// `keep_ids`：要保留詞條展開的 JMdict ID（JLPT 清單列）。
    pub fn parse(reader: impl Read, keep_ids: &HashSet<String>) -> Result<Self, String> {
        let raw: RawJmdict =
            serde_json::from_reader(reader).map_err(|err| format!("JMdict 解析失敗：{err}"))?;
        let mut index = Self::default();
        for word in raw.words {
            add_word(&mut index, word, keep_ids);
        }
        Ok(index)
    }

    pub fn has_pair(&self, kanji: &str, kana: &str) -> bool {
        self.pairs
            .contains_key(&(kanji.to_owned(), kana.to_owned()))
    }

    pub fn has_kana(&self, kana: &str) -> bool {
        self.kana.contains_key(kana)
    }

    pub fn has_kanji_form(&self, kanji: &str) -> bool {
        self.kanji.contains(kanji)
    }

    fn pair_hits(&self, kanji: &str, kana: &str) -> Option<&[Hit]> {
        self.pairs
            .get(&(kanji.to_owned(), kana.to_owned()))
            .map(Vec::as_slice)
    }

    /// `kana` 底下的所有詞條。
    fn kana_hits(&self, kana: &str) -> Option<&[Hit]> {
        self.kana.get(kana).map(Vec::as_slice)
    }

    pub fn pair_is_irregular(&self, kanji: &str, kana: &str) -> bool {
        self.pair_hits(kanji, kana).is_some_and(hits_irregular)
    }

    pub fn kana_is_irregular(&self, kana: &str) -> bool {
        self.kana_hits(kana).is_some_and(hits_irregular)
    }

    /// 漢字形標 `uk`（第一義項，§2.2-5）。
    pub fn pair_is_usually_kana(&self, kanji: &str, kana: &str) -> bool {
        self.pair_hits(kanji, kana)
            .is_some_and(|hits| hits.iter().all(|hit| hit.usually_kana))
    }

    /// `accept` 判斷一個 JMdict 詞性標籤是否相符；配對查不到時回 `None`。
    pub fn pair_pos_matches(
        &self,
        kanji: &str,
        kana: &str,
        accept: impl Fn(&str) -> bool,
    ) -> Option<bool> {
        self.pair_hits(kanji, kana)
            .map(|hits| any_pos(hits, accept))
    }

    pub fn kana_pos_matches(&self, kana: &str, accept: impl Fn(&str) -> bool) -> Option<bool> {
        self.kana_hits(kana).map(|hits| any_pos(hits, accept))
    }

    pub fn expansion(&self, id: &str) -> Option<&Expansion> {
        self.expansions.get(id)
    }
}

fn hits_irregular(hits: &[Hit]) -> bool {
    hits.iter().all(|hit| {
        hit.tags
            .iter()
            .any(|tag| IRREGULAR_TAGS.contains(&tag.as_str()))
    })
}

fn any_pos(hits: &[Hit], accept: impl Fn(&str) -> bool) -> bool {
    hits.iter().any(|hit| hit.pos.iter().any(|tag| accept(tag)))
}

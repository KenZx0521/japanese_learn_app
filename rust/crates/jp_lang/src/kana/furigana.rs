//! 振假名對齊（rust-core.md §4.6）。

use super::table::{hiragana_of, is_kana_char, punct_romaji};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Ruby {
    pub base: String,
    pub ruby: Option<String>,
}

struct Segment {
    chars: Vec<char>,
    is_kanji_class: bool,
}

/// 解不唯一時回傳 `Err(解的數量)`，lint R08 要求恰為 1。
pub fn furigana(surface: &str, kana: &str) -> Result<Vec<Ruby>, usize> {
    let reading: Vec<char> = kana.chars().collect();
    let mut solutions = align(&segments_of(surface), &reading);
    if solutions.len() == 1 {
        Ok(solutions.remove(0))
    } else {
        Err(solutions.len())
    }
}

/// 執行期用：拿不到唯一解時，整個語素當一段 ruby。
pub fn furigana_or_whole(surface: &str, kana: &str) -> Vec<Ruby> {
    furigana(surface, kana).unwrap_or_else(|_| {
        vec![Ruby {
            base: surface.to_owned(),
            ruby: Some(kana.to_owned()),
        }]
    })
}

/// 振假名只給漢字類；假名與 §4.2 標點表的字元（？、〜 等）是錨點，讀音裡要原樣出現。
fn is_anchor_char(c: char) -> bool {
    is_kana_char(c) || punct_romaji(c).is_some()
}

/// ASCII 的 `.`、`,` 接在 ASCII 英數字後面時是小數點、千分位或縮寫（3.5、1,000、Mr.），歸漢字類。
fn is_numeric_mark(previous: Option<char>, c: char) -> bool {
    matches!(c, '.' | ',') && previous.is_some_and(|p| p.is_ascii_alphanumeric())
}

/// 切成漢字類與錨點（假名、標點）交錯的段；數字與 ASCII 英數字歸漢字類。
fn segments_of(surface: &str) -> Vec<Segment> {
    let chars: Vec<char> = surface.chars().collect();
    chars
        .iter()
        .enumerate()
        .fold(Vec::new(), |mut segments: Vec<Segment>, (index, &c)| {
            let previous = index.checked_sub(1).map(|i| chars[i]);
            let is_kanji_class = !is_anchor_char(c) || is_numeric_mark(previous, c);
            match segments.last_mut() {
                Some(last) if last.is_kanji_class == is_kanji_class => last.chars.push(c),
                _ => segments.push(Segment {
                    chars: vec![c],
                    is_kanji_class,
                }),
            }
            segments
        })
}

/// 回傳所有對齊解。漢字類的段至少要對到一個假名。
fn align(segments: &[Segment], kana: &[char]) -> Vec<Vec<Ruby>> {
    let Some((segment, rest)) = segments.split_first() else {
        return if kana.is_empty() {
            vec![Vec::new()]
        } else {
            Vec::new()
        };
    };
    let base: String = segment.chars.iter().collect();
    if segment.is_kanji_class {
        (1..=kana.len())
            .flat_map(|len| {
                let reading: String = kana[..len].iter().collect();
                prepend(&base, Some(reading), align(rest, &kana[len..]))
            })
            .collect()
    } else if starts_with_anchors(kana, &segment.chars) {
        prepend(&base, None, align(rest, &kana[segment.chars.len()..]))
    } else {
        Vec::new()
    }
}

fn prepend(base: &str, reading: Option<String>, tails: Vec<Vec<Ruby>>) -> Vec<Vec<Ruby>> {
    tails
        .into_iter()
        .map(|tail| {
            let head = Ruby {
                base: base.to_owned(),
                ruby: reading.clone(),
            };
            std::iter::once(head).chain(tail).collect()
        })
        .collect()
}

/// 平假名與片假名視為相同（コーヒー 對 こーひー）；標點以 §4.2 表的同一組為相同（〜～~、？?）。
fn same_anchor(a: char, b: char) -> bool {
    hiragana_of(a) == hiragana_of(b) || punct_romaji(a).is_some_and(|p| punct_romaji(b) == Some(p))
}

fn starts_with_anchors(kana: &[char], prefix: &[char]) -> bool {
    kana.len() >= prefix.len() && kana.iter().zip(prefix).all(|(&a, &b)| same_anchor(a, b))
}

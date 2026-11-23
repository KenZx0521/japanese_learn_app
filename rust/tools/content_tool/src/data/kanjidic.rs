//! KANJIDIC2 的常用漢字集合（J02）。

use std::collections::HashSet;
use std::fs;
use std::path::Path;

use serde::Deserialize;

/// 常用漢字：教育漢字 1–6 級與中學 8 級（§5.3）。
const JOYO_GRADES: [u8; 7] = [1, 2, 3, 4, 5, 6, 8];

#[derive(Deserialize)]
struct RawKanjidic {
    characters: Vec<RawCharacter>,
}

#[derive(Deserialize)]
struct RawCharacter {
    literal: String,
    misc: RawMisc,
}

#[derive(Deserialize)]
struct RawMisc {
    grade: Option<u8>,
}

pub fn load_joyo(path: &Path) -> Result<HashSet<char>, String> {
    let text = fs::read_to_string(path).map_err(|err| format!("{}：{err}", path.display()))?;
    let raw: RawKanjidic =
        serde_json::from_str(&text).map_err(|err| format!("KANJIDIC2 解析失敗：{err}"))?;
    Ok(raw
        .characters
        .into_iter()
        .filter(|ch| {
            ch.misc
                .grade
                .is_some_and(|grade| JOYO_GRADES.contains(&grade))
        })
        .filter_map(|ch| ch.literal.chars().next())
        .collect())
}

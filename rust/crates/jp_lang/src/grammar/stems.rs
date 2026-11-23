//! R07 的合法變化語幹（rust-core.md §4.7、curriculum.md §13）。

use super::conjugate::{
    adj_i_stem, conjugate_kana, dan_kana, is_yoi_family, kuru_surface, onbin_of, rewrite_okurigana,
    split_last, yoi_surface, Dan, Form, KuruForm, Pos, ADJ_I_ENDING, ICHIDAN_IMPERATIVE, KURU,
    SURU,
};

/// `vo.suru` 的合法語幹。
const SURU_STEMS: [&str; 7] = ["し", "する", "すれ", "しろ", "しよ", "さ", "せ"];

/// R07 的合法語幹，回傳 (surface, kana)。`vs` 只有 `vo.suru` 本身有語幹，其他回傳空。
pub fn legal_stems(surface: &str, kana: &str, pos: Pos) -> Vec<(String, String)> {
    if pos == Pos::Vs {
        return suru_stems(kana);
    }
    if surface.chars().last() != kana.chars().last() {
        return Vec::new();
    }
    let pairs = match pos {
        Pos::V1 | Pos::V1S => surface_pairs(surface, kana, &ichidan_stems(kana, pos)),
        Pos::V5 => surface_pairs(surface, kana, &godan_stems(kana)),
        Pos::Vk => kuru_stems(surface, kana),
        Pos::AdjI => adj_i_stems(surface, kana),
        _ => Vec::new(),
    };
    without_duplicates(pairs)
}

fn surface_pairs(surface: &str, kana: &str, stems: &[String]) -> Vec<(String, String)> {
    stems
        .iter()
        .filter_map(|stem| rewrite_okurigana(surface, kana, stem).map(|text| (text, stem.clone())))
        .collect()
}

fn without_duplicates(pairs: Vec<(String, String)>) -> Vec<(String, String)> {
    pairs.into_iter().fold(Vec::new(), |mut unique, pair| {
        if !unique.contains(&pair) {
            unique.push(pair);
        }
        unique
    })
}

/// 語幹、る、れ（ば）、ろ（命令）、よ（意向）。特殊一段的命令形是語幹本身，沒有 ろ。
fn ichidan_stems(kana: &str, pos: Pos) -> Vec<String> {
    let Some(stem) = kana.strip_suffix('る') else {
        return Vec::new();
    };
    ["", "る", "れ", ICHIDAN_IMPERATIVE, "よ"]
        .iter()
        .filter(|&&ending| pos != Pos::V1S || ending != ICHIDAN_IMPERATIVE)
        .map(|ending| format!("{stem}{ending}"))
        .collect()
}

fn godan_stems(kana: &str) -> Vec<String> {
    let Some((stem, last)) = split_last(kana) else {
        return Vec::new();
    };
    let row_stem = |dan| dan_kana(last, dan).map(|c| format!("{stem}{c}"));
    let masu_stem = conjugate_kana(kana, Pos::V5, Form::Masu)
        .and_then(|masu| masu.strip_suffix("ます").map(str::to_owned));
    let onbin_stem = onbin_of(kana, last).map(|onbin| format!("{stem}{}", onbin.ending));
    [
        row_stem(Dan::A),
        masu_stem,
        row_stem(Dan::U),
        row_stem(Dan::E),
        row_stem(Dan::O),
        onbin_stem,
    ]
    .into_iter()
    .flatten()
    .collect()
}

fn suru_stems(kana: &str) -> Vec<(String, String)> {
    if kana != SURU {
        return Vec::new();
    }
    SURU_STEMS
        .iter()
        .map(|stem| ((*stem).to_owned(), (*stem).to_owned()))
        .collect()
}

fn kuru_stems(surface: &str, kana: &str) -> Vec<(String, String)> {
    let Some(prefix) = kana.strip_suffix(KURU) else {
        return Vec::new();
    };
    [
        ("き", ""),
        ("こ", ""),
        ("く", "る"),
        ("く", "れ"),
        ("こ", "い"),
        ("こ", "よ"),
    ]
    .into_iter()
    .filter_map(|(mora, tail)| {
        let text = kuru_surface(surface, KuruForm { mora, tail })?;
        Some((text, format!("{prefix}{mora}{tail}")))
    })
    .collect()
}

fn adj_i_stems(surface: &str, kana: &str) -> Vec<(String, String)> {
    let Some(plain_stem) = kana.strip_suffix(ADJ_I_ENDING) else {
        return Vec::new();
    };
    let plain = [plain_stem.to_owned(), kana.to_owned()];
    let plain_pairs = surface_pairs(surface, kana, &plain);
    let Some(stem) = adj_i_stem(kana) else {
        return plain_pairs;
    };
    let inflected: Vec<(String, String)> = ["", "く", "かっ", "けれ"]
        .iter()
        .filter_map(|ending| {
            let stem_kana = format!("{stem}{ending}");
            let text = if is_yoi_family(kana) {
                yoi_surface(surface, kana, &stem_kana)?
            } else {
                rewrite_okurigana(surface, kana, &stem_kana)?
            };
            Some((text, stem_kana))
        })
        .collect();
    plain_pairs.into_iter().chain(inflected).collect()
}

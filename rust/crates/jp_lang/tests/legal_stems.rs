//! rust-core.md §4.7、curriculum.md R07：`legal_stems`。

use jp_lang::grammar::conjugate::{
    legal_stems, Pos,
    Pos::{AdjI, AdjNa, Vk, Vs, N, V1, V1S, V5},
};

fn stems(surface: &str, kana: &str, pos: Pos) -> Vec<(String, String)> {
    legal_stems(surface, kana, pos)
}

fn pairs(rows: &[(&str, &str)]) -> Vec<(String, String)> {
    rows.iter()
        .map(|(s, k)| ((*s).to_owned(), (*k).to_owned()))
        .collect()
}

#[test]
fn legal_stems_of_vs_noun_is_empty() {
    assert!(stems("勉強", "べんきょう", Vs).is_empty());
}

#[test]
fn legal_stems_of_suru_is_fixed_list() {
    assert_eq!(
        stems("する", "する", Vs),
        pairs(&[
            ("し", "し"),
            ("する", "する"),
            ("すれ", "すれ"),
            ("しろ", "しろ"),
            ("しよ", "しよ"),
            ("さ", "さ"),
            ("せ", "せ")
        ])
    );
}

#[test]
fn legal_stems_of_v5_cover_every_row_and_onbin() {
    let got = stems("知る", "しる", V5);
    for pair in pairs(&[
        ("知ら", "しら"),
        ("知り", "しり"),
        ("知る", "しる"),
        ("知れ", "しれ"),
        ("知ろ", "しろ"),
        ("知っ", "しっ"),
    ]) {
        assert!(got.contains(&pair), "{pair:?}");
    }
    let got = stems("飲む", "のむ", V5);
    for pair in pairs(&[
        ("飲み", "のみ"),
        ("飲ん", "のん"),
        ("飲ま", "のま"),
        ("飲め", "のめ"),
        ("飲も", "のも"),
        ("飲む", "のむ"),
    ]) {
        assert!(got.contains(&pair), "{pair:?}");
    }
}

#[test]
fn legal_stems_have_no_duplicates() {
    let got = stems("話す", "はなす", V5);
    let unique: std::collections::HashSet<_> = got.iter().collect();
    assert_eq!(got.len(), unique.len(), "{got:?}");
    assert!(got.contains(&("話し".to_owned(), "はなし".to_owned())));
}

#[test]
fn legal_stems_of_honorific_use_i_stem() {
    let got = stems("いらっしゃる", "いらっしゃる", V5);
    assert!(got.contains(&("いらっしゃい".to_owned(), "いらっしゃい".to_owned())));
    assert!(!got.contains(&("いらっしゃり".to_owned(), "いらっしゃり".to_owned())));
}

#[test]
fn legal_stems_of_v1() {
    assert_eq!(
        stems("食べる", "たべる", V1),
        pairs(&[
            ("食べ", "たべ"),
            ("食べる", "たべる"),
            ("食べれ", "たべれ"),
            ("食べろ", "たべろ"),
            ("食べよ", "たべよ")
        ])
    );
}

/// 特殊一段的命令形是語幹（くれ），沒有 くれろ。
#[test]
fn legal_stems_of_v1_s_have_no_ro() {
    assert_eq!(
        stems("くれる", "くれる", V1S),
        pairs(&[
            ("くれ", "くれ"),
            ("くれる", "くれる"),
            ("くれれ", "くれれ"),
            ("くれよ", "くれよ")
        ])
    );
    assert!(stems("暮れる", "くれる", V1).contains(&("暮れろ".to_owned(), "くれろ".to_owned())));
}

#[test]
fn legal_stems_of_vk_keep_kanji_with_each_reading() {
    assert_eq!(
        stems("来る", "くる", Vk),
        pairs(&[
            ("来", "き"),
            ("来", "こ"),
            ("来る", "くる"),
            ("来れ", "くれ"),
            ("来い", "こい"),
            ("来よ", "こよ")
        ])
    );
    assert_eq!(
        stems("くる", "くる", Vk),
        pairs(&[
            ("き", "き"),
            ("こ", "こ"),
            ("くる", "くる"),
            ("くれ", "くれ"),
            ("こい", "こい"),
            ("こよ", "こよ")
        ])
    );
}

#[test]
fn legal_stems_of_adj_i() {
    assert_eq!(
        stems("高い", "たかい", AdjI),
        pairs(&[
            ("高", "たか"),
            ("高い", "たかい"),
            ("高く", "たかく"),
            ("高かっ", "たかかっ"),
            ("高けれ", "たかけれ")
        ])
    );
}

#[test]
fn legal_stems_of_ii_include_yo_family() {
    assert_eq!(
        stems("いい", "いい", AdjI),
        pairs(&[
            ("い", "い"),
            ("いい", "いい"),
            ("よ", "よ"),
            ("よく", "よく"),
            ("よかっ", "よかっ"),
            ("よけれ", "よけれ")
        ])
    );
    assert_eq!(
        stems("良い", "いい", AdjI),
        pairs(&[
            ("良", "い"),
            ("良い", "いい"),
            ("良", "よ"),
            ("良く", "よく"),
            ("良かっ", "よかっ"),
            ("良けれ", "よけれ")
        ])
    );
}

#[test]
fn legal_stems_of_non_inflecting_is_empty() {
    assert!(stems("本", "ほん", N).is_empty());
    assert!(stems("静か", "しずか", AdjNa).is_empty());
    assert!(stems("飲み", "のむ", V5).is_empty());
}

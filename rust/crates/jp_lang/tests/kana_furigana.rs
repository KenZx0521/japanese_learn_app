//! rust-core.md §4.6 的振假名對齊案例。

use jp_lang::kana::{furigana, furigana_or_whole, is_kana_text, Ruby};

fn r(base: &str, ruby: Option<&str>) -> Ruby {
    Ruby {
        base: base.to_owned(),
        ruby: ruby.map(str::to_owned),
    }
}

#[test]
fn aligns_spec_cases() {
    assert_eq!(
        furigana("食べ", "たべ"),
        Ok(vec![r("食", Some("た")), r("べ", None)])
    );
    assert_eq!(
        furigana("毎朝", "まいあさ"),
        Ok(vec![r("毎朝", Some("まいあさ"))])
    );
    assert_eq!(
        furigana("お願いします", "おねがいします"),
        Ok(vec![
            r("お", None),
            r("願", Some("ねが")),
            r("いします", None)
        ])
    );
    assert_eq!(
        furigana("3本", "さんぼん"),
        Ok(vec![r("3本", Some("さんぼん"))])
    );
    assert_eq!(
        furigana("行き来", "いきき"),
        Ok(vec![
            r("行", Some("い")),
            r("き", None),
            r("来", Some("き"))
        ])
    );
    assert_eq!(
        furigana("コーヒー", "こーひー"),
        Ok(vec![r("コーヒー", None)])
    );
    assert_eq!(furigana("食べ", "のむ"), Err(0));
}

#[test]
fn reports_number_of_solutions_when_ambiguous() {
    // 見の見／みののみ：前後兩個 見 都可吞下一個 の，共 2 解。
    assert_eq!(furigana("見の見", "みののみ"), Err(2));
}

#[test]
fn ascii_letters_count_as_kanji_class() {
    assert_eq!(
        furigana("Tシャツ", "てぃーしゃつ"),
        Ok(vec![r("T", Some("てぃー")), r("シャツ", None)])
    );
}

/// §4.2 標點表的字元和假名一樣是錨點：讀音裡原樣出現，不放進振假名。
#[test]
fn punctuation_is_an_anchor_without_ruby() {
    assert_eq!(
        furigana("大丈夫？", "だいじょうぶ？"),
        Ok(vec![r("大丈夫", Some("だいじょうぶ")), r("？", None)])
    );
    assert_eq!(
        furigana("〜人", "〜にん"),
        Ok(vec![r("〜", None), r("人", Some("にん"))])
    );
    assert_eq!(
        furigana("〜と思います", "〜とおもいます"),
        Ok(vec![
            r("〜と", None),
            r("思", Some("おも")),
            r("います", None)
        ])
    );
    assert_eq!(
        furigana("高いですが、おいしいです", "たかいですが、おいしいです"),
        Ok(vec![
            r("高", Some("たか")),
            r("いですが、おいしいです", None)
        ])
    );
}

/// 接在 ASCII 英數字後面的 `.`、`,` 是小數點、千分位或縮寫，歸漢字類（review_rust R2-L3）。
#[test]
fn ascii_dot_and_comma_after_an_ascii_alphanumeric_count_as_kanji_class() {
    assert_eq!(
        furigana("3.5キロ", "さんてんごきろ"),
        Ok(vec![r("3.5", Some("さんてんご")), r("キロ", None)])
    );
    assert_eq!(
        furigana("1,000円", "せんえん"),
        Ok(vec![r("1,000円", Some("せんえん"))])
    );
    assert_eq!(
        furigana("1.5倍", "いってんごばい"),
        Ok(vec![r("1.5倍", Some("いってんごばい"))])
    );
    assert_eq!(
        furigana("Mr.田中", "みすたーたなか"),
        Ok(vec![r("Mr.田中", Some("みすたーたなか"))])
    );
}

/// 同一組標點的異體（〜～~、？?、！!）在讀音裡互通（review_rust R2-L4）。
#[test]
fn punctuation_variants_match_each_other() {
    assert_eq!(
        furigana("〜人", "～にん"),
        Ok(vec![r("〜", None), r("人", Some("にん"))])
    );
    assert_eq!(
        furigana("〜人", "~にん"),
        Ok(vec![r("〜", None), r("人", Some("にん"))])
    );
    assert_eq!(
        furigana("大丈夫？", "だいじょうぶ?"),
        Ok(vec![r("大丈夫", Some("だいじょうぶ")), r("？", None)])
    );
    assert_eq!(furigana("大丈夫？", "だいじょうぶ！"), Err(0));
}

#[test]
fn punctuation_missing_from_the_reading_has_no_solution() {
    assert_eq!(furigana("元気？", "げんき"), Err(0));
    assert_eq!(
        furigana_or_whole("元気？", "げんき"),
        vec![r("元気？", Some("げんき"))]
    );
}

#[test]
fn ruby_keeps_reading_as_written() {
    assert_eq!(
        furigana("Tシャツ", "ティーシャツ"),
        Ok(vec![r("T", Some("ティー")), r("シャツ", None)])
    );
}

#[test]
fn kanji_segment_needs_at_least_one_kana() {
    assert_eq!(furigana("食", ""), Err(0));
    assert_eq!(furigana("食べ", "べ"), Err(0));
}

#[test]
fn empty_inputs() {
    assert_eq!(furigana("", ""), Ok(vec![]));
    assert_eq!(furigana("", "あ"), Err(0));
}

#[test]
fn lenient_variant_returns_whole_morpheme_without_unique_solution() {
    assert_eq!(
        furigana_or_whole("食べ", "のむ"),
        vec![r("食べ", Some("のむ"))]
    );
    assert_eq!(
        furigana_or_whole("見の見", "みののみ"),
        vec![r("見の見", Some("みののみ"))]
    );
    assert_eq!(
        furigana_or_whole("食べ", "たべ"),
        vec![r("食", Some("た")), r("べ", None)]
    );
}

#[test]
fn is_kana_text_covers_hiragana_katakana_and_long_mark() {
    assert!(is_kana_text("ひらがな"));
    assert!(is_kana_text("カタカナー"));
    assert!(!is_kana_text(""));
    assert!(!is_kana_text("食べ"));
    assert!(!is_kana_text("abc"));
}

//! curriculum.md §12.2 的 `{ja:…}` 混合文字標記。

use jp_content::mixed::{parse_mixed_text, validate_mixed, MixedError, MixedSpan};
use jp_lang::kana::Ruby;

fn ja(text: &str, ruby: Vec<Ruby>) -> MixedSpan {
    MixedSpan::Ja {
        text: text.to_owned(),
        ruby,
    }
}

fn zh(text: &str) -> MixedSpan {
    MixedSpan::Zh {
        text: text.to_owned(),
    }
}

fn ruby(base: &str, reading: Option<&str>) -> Ruby {
    Ruby {
        base: base.to_owned(),
        ruby: reading.map(str::to_owned),
    }
}

#[test]
fn plain_text_is_a_single_zh_span() {
    assert_eq!(parse_mixed_text("沒有標記"), vec![zh("沒有標記")]);
}

#[test]
fn splits_markup_without_reading() {
    assert_eq!(
        parse_mixed_text("和「{ja:め}」的差別"),
        vec![zh("和「"), ja("め", vec![ruby("め", None)]), zh("」的差別")]
    );
}

#[test]
fn reading_produces_aligned_ruby() {
    assert_eq!(
        parse_mixed_text("{ja:食べる|たべる}"),
        vec![ja(
            "食べる",
            vec![ruby("食", Some("た")), ruby("べる", None)]
        )]
    );
}

/// 文法標題常見 `{ja:大丈夫？|だいじょうぶ？}`、`{ja:〜と思います|〜とおもいます}`：
/// 符號不進振假名（rust-core §4.6）。
#[test]
fn punctuation_in_marked_text_gets_no_ruby() {
    assert_eq!(
        parse_mixed_text("{ja:大丈夫？|だいじょうぶ？}"),
        vec![ja(
            "大丈夫？",
            vec![ruby("大丈夫", Some("だいじょうぶ")), ruby("？", None)]
        )]
    );
    assert_eq!(
        parse_mixed_text("{ja:〜と思います|〜とおもいます}"),
        vec![ja(
            "〜と思います",
            vec![
                ruby("〜と", None),
                ruby("思", Some("おも")),
                ruby("います", None)
            ]
        )]
    );
}

#[test]
fn unaligned_reading_falls_back_to_whole_ruby() {
    assert_eq!(
        parse_mixed_text("{ja:今日|きょう}"),
        vec![ja("今日", vec![ruby("今日", Some("きょう"))])]
    );
}

#[test]
fn syntax_errors_return_whole_input_as_zh() {
    for bad in [
        "未結束 {ja:あ",
        "{ja:}",
        "{ja:あ|}",
        "{ja:あ|い|う}",
        "{ja:{ja:あ}}",
    ] {
        assert_eq!(parse_mixed_text(bad), vec![zh(bad)], "{bad}");
    }
}

#[test]
fn validate_reports_error_kinds() {
    assert_eq!(
        validate_mixed("未結束 {ja:あ"),
        Err(MixedError::Unterminated)
    );
    assert_eq!(validate_mixed("{ja:}"), Err(MixedError::Empty));
    assert_eq!(validate_mixed("{ja:あ|}"), Err(MixedError::Empty));
    assert_eq!(validate_mixed("{ja:あ|い|う}"), Err(MixedError::ExtraBar));
    assert_eq!(validate_mixed("{ja:{ja:あ}}"), Err(MixedError::Nested));
    assert!(validate_mixed("普通 {ja:あ} 文字").is_ok());
}

#[test]
fn literal_braces_outside_markup_are_kept() {
    assert_eq!(parse_mixed_text("{x} 與 }"), vec![zh("{x} 與 }")]);
}

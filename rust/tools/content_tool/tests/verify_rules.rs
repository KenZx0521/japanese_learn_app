//! B 層規則（reuse-and-verification.md §9.2）。用小型假資料，不依賴真實 JMdict。

mod common;

use std::collections::{HashMap, HashSet};

use common::*;
use content_tool::data::jmdict::JmdictIndex;
use content_tool::data::lists::{AccentIndex, FuriganaIndex, JlptLists, JlptRow};
use content_tool::data::Data;
use content_tool::rules::{self, kana, Level};

fn env() -> content_tool::rules::Env {
    env_for(std::path::Path::new("/nonexistent"))
}

// ---- J01 配對與假名存在 ----

#[test]
fn j01_accepts_fixture_words() {
    let findings = run_rule(
        rules::jmdict::j01,
        &scope(),
        &data_with_jmdict(fixture_jmdict()),
        &env(),
    );
    assert!(no_errors(&findings), "{findings:?}");
}

#[test]
fn j01_rejects_kanji_with_wrong_reading() {
    let scope = scope_with(&[(
        r#""surface": "学生", "kana": "がくせい""#,
        r#""surface": "学生", "kana": "がっせい""#,
    )]);
    let findings = run_rule(
        rules::jmdict::j01,
        &scope,
        &data_with_jmdict(fixture_jmdict()),
        &env(),
    );
    assert_level(&findings, "vo.gakusei", Level::Error);
    assert!(find(&findings, "vo.gakusei")
        .unwrap()
        .token
        .contains("学生"));
}

#[test]
fn j01_only_warns_for_phrases() {
    let findings = run_rule(
        rules::jmdict::j01,
        &scope(),
        &data_with_jmdict(jmdict(&[("私", "わたし", &["pn"])])),
        &env(),
    );
    assert_level(&findings, "vo.ii_desu_ne", Level::Warning);
    assert_level(&findings, "vo.hai", Level::Error);
}

#[test]
fn j01_finds_kana_under_kanji_headwords() {
    let index = jmdict(&[
        ("有難う", "ありがとう", &["int"]),
        ("先生", "せんせい", &["n"]),
    ]);
    assert!(index.has_kana("ありがとう"));
    assert!(index.has_pair("有難う", "ありがとう"));
    assert!(!index.has_pair("有難う", "ありがと"));
}

#[test]
fn j01_respects_applies_to_kanji() {
    let json = serde_json::json!({
        "words": [{
            "id": "1",
            "kanji": [{"text": "甲", "tags": []}, {"text": "乙", "tags": []}],
            "kana": [{"text": "かな", "tags": [], "appliesToKanji": ["甲"]}],
            "sense": [{"partOfSpeech": ["n"], "misc": []}],
        }]
    })
    .to_string();
    let index = JmdictIndex::parse(json.as_bytes(), &HashSet::new()).unwrap();
    assert!(index.has_pair("甲", "かな"));
    assert!(!index.has_pair("乙", "かな"));
}

#[test]
fn j01b_rejects_kana_surface_that_differs_from_kana() {
    let scope = scope_with(&[(
        r#""surface": "はい", "kana": "はい""#,
        r#""surface": "はい", "kana": "はぃ""#,
    )]);
    let findings = run_rule(rules::jmdict::j01b, &scope, &Data::default(), &env());
    assert_level(&findings, "vo.hai", Level::Error);
}

#[test]
fn j01b_ignores_spaces_in_kana() {
    let findings = run_rule(rules::jmdict::j01b, &scope(), &Data::default(), &env());
    assert!(find(&findings, "vo.konnichiwa").is_none(), "{findings:?}");
}

// ---- J02 常用漢字 ----

#[test]
fn j02_rejects_kanji_outside_joyo_and_skips_origin_kanji() {
    let scope = scope_with(&[(r#""surface": "学生""#, r#""surface": "學生""#)]);
    let joyo: HashSet<char> = "学生".chars().collect();
    let data = Data {
        joyo: Some(joyo),
        ..Data::default()
    };
    let findings = run_rule(rules::kana::j02, &scope, &data, &env());
    let hit = findings
        .iter()
        .find(|f| f.item == "vo.gakusei" && f.token == "學")
        .unwrap_or_else(|| panic!("{findings:?}"));
    assert_eq!(hit.level, Level::Error);
    assert!(findings
        .iter()
        .all(|f| f.message.find("origin_kanji").is_none()));
}

// ---- J03、J03b ----

#[test]
fn j03_warns_only_when_every_form_is_irregular() {
    let json = serde_json::json!({
        "words": [{
            "id": "1",
            "kanji": [{"text": "御茶", "tags": ["sK"]}],
            "kana": [{"text": "おちゃ", "tags": [], "appliesToKanji": ["*"]}],
            "sense": [{"partOfSpeech": ["n"], "misc": []}],
        }]
    })
    .to_string();
    let index = JmdictIndex::parse(json.as_bytes(), &HashSet::new()).unwrap();
    assert!(index.pair_is_irregular("御茶", "おちゃ"));
}

#[test]
fn j03b_warns_when_first_sense_is_usually_kana() {
    let json = serde_json::json!({
        "words": [{
            "id": "1",
            "kanji": [{"text": "有難う", "tags": []}],
            "kana": [{"text": "ありがとう", "tags": [], "appliesToKanji": ["*"]}],
            "sense": [{"partOfSpeech": ["int"], "misc": ["uk"]}],
        }]
    })
    .to_string();
    let index = JmdictIndex::parse(json.as_bytes(), &HashSet::new()).unwrap();
    assert!(index.pair_is_usually_kana("有難う", "ありがとう"));
}

// ---- J04 假名合法性 ----

#[test]
fn j04_flags_each_illegal_pattern() {
    let illegal = [
        "ゃま",
        "ーあ",
        "んま",
        "っま",
        "にゃぁ?", // ASCII
        "かゃ",
        "あっあ",
        "あっん",
        "あっー",
        "あんゃ",
        "あんー",
        "おゝ",
        "ヷイ",
        "あ～",
        "あ~",
        "ｺｰﾋｰ",
    ];
    for text in illegal {
        let issues = kana::kana_issues(text, false);
        assert!(
            issues.iter().any(|(level, _)| *level == Level::Error),
            "{text} 應為錯誤：{issues:?}"
        );
    }
}

#[test]
fn j04_allows_valid_kana() {
    for text in [
        "がっこう",
        "コーヒー",
        "ティー",
        "テュ",
        "ファン",
        "あっ",
        "おちゃ",
        "ちゃ",
        "にゃ",
        "ウィスキー",
        "ほんや",
        "〜さん",
        "こ・そ",
    ] {
        let issues = kana::kana_issues(text, false);
        assert!(
            issues.iter().all(|(level, _)| *level != Level::Error),
            "{text}：{issues:?}"
        );
    }
}

#[test]
fn j04_allows_grammar_morphs_to_start_with_n_or_sokuon() {
    for text in ["って", "んです", "っぽい", "ん"] {
        assert!(
            kana::kana_issues(text, true)
                .iter()
                .all(|(level, _)| *level != Level::Error),
            "{text}"
        );
        assert!(kana::kana_issues(text, false)
            .iter()
            .any(|(level, _)| *level == Level::Error));
    }
}

#[test]
fn j04_warns_on_colloquial_small_vowels_repeated_long_marks_and_old_kana() {
    for text in ["ねぇ", "へぇ", "コーーヒー", "ゐる", "ヱビ"] {
        let issues = kana::kana_issues(text, false);
        assert!(
            issues.iter().all(|(level, _)| *level != Level::Error)
                && issues.iter().any(|(level, _)| *level == Level::Warning),
            "{text}：{issues:?}"
        );
    }
}

#[test]
fn j04_rule_reports_vocab_kana_and_sentence_morphs() {
    let scope = scope_with(&[
        (r#""kana": "わたし""#, r#""kana": "ゃたし""#),
        (
            r#""surface": "はじめまして""#,
            r#""surface": "はじめ～して""#,
        ),
    ]);
    let findings = run_rule(rules::kana::j04, &scope, &Data::default(), &env());
    assert_level(&findings, "vo.watashi", Level::Error);
    assert_level(&findings, "vo.hajimemashite", Level::Error);
}

#[test]
fn j04_ignores_kana_chars_and_rule_beats() {
    let findings = run_rule(rules::kana::j04, &scope(), &Data::default(), &env());
    assert!(no_errors(&findings), "{findings:?}");
}

// ---- J05 詞性 ----

#[test]
fn j05_rejects_wrong_verb_class() {
    let scope = scope_with(&[(
        r#""surface": "飲む", "kana": "のむ", "zh": ["喝"], "pos": "v5""#,
        r#""surface": "飲む", "kana": "のむ", "zh": ["喝"], "pos": "v1""#,
    )]);
    let findings = run_rule(
        rules::jmdict::j05,
        &scope,
        &data_with_jmdict(fixture_jmdict()),
        &env(),
    );
    assert_level(&findings, "vo.nomu", Level::Error);
}

fn j05_on_taberu(pos: &str, jmdict_tags: &[&str]) -> Vec<content_tool::rules::Finding> {
    let replacement =
        format!(r#""surface": "食べる", "kana": "たべる", "zh": ["吃"], "pos": "{pos}""#);
    let scope = scope_with(&[(
        r#""surface": "食べる", "kana": "たべる", "zh": ["吃"], "pos": "v1""#,
        replacement.as_str(),
    )]);
    let index = jmdict(&[("食べる", "たべる", jmdict_tags)]);
    run_rule(rules::jmdict::j05, &scope, &data_with_jmdict(index), &env())
}

/// `v1_s` 只對應 JMdict 的 `v1-s`；`v1` 不再接受 `v1-s`（くれる 標 `v1` 會算出 くれろ）。
#[test]
fn j05_separates_v1_from_v1_s() {
    assert!(find(&j05_on_taberu("v1_s", &["v1-s"]), "vo.taberu").is_none());
    assert!(find(&j05_on_taberu("v1", &["v1"]), "vo.taberu").is_none());
    assert_level(&j05_on_taberu("v1_s", &["v1"]), "vo.taberu", Level::Error);
    assert_level(&j05_on_taberu("v1", &["v1-s"]), "vo.taberu", Level::Error);
}

#[test]
fn j05_accepts_fixture_and_does_not_treat_num_as_noun() {
    let findings = run_rule(
        rules::jmdict::j05,
        &scope(),
        &data_with_jmdict(fixture_jmdict()),
        &env(),
    );
    assert!(no_errors(&findings), "{findings:?}");
    let scope = scope_with(&[(
        r#""surface": "先生", "kana": "せんせい", "zh": ["老師"], "pos": "n""#,
        r#""surface": "先生", "kana": "せんせい", "zh": ["老師"], "pos": "num""#,
    )]);
    let index = jmdict(&[("先生", "せんせい", &["num-suf"])]);
    let findings = run_rule(rules::jmdict::j05, &scope, &data_with_jmdict(index), &env());
    assert!(find(&findings, "vo.sensei").is_none(), "{findings:?}");
}

// ---- J06、J07 ----

#[test]
fn j06_warns_on_unknown_at_new_kanji_pair() {
    let scope = scope_with(&[(
        "手紙|てがみ|vo.tegami です|gr.desu 。\", \"zh\": \"是信。\"",
        "猫|ねこ|@new:ねこ です|gr.desu 。\", \"zh\": \"是信。\"",
    )]);
    let findings = run_rule(
        rules::jmdict::j06,
        &scope,
        &data_with_jmdict(fixture_jmdict()),
        &env(),
    );
    assert_level(&findings, "se.l08.001", Level::Warning);
}

#[test]
fn j07_warns_when_furigana_differs_from_dataset() {
    let mut furigana = HashMap::new();
    furigana.insert(
        ("学生".to_owned(), "がくせい".to_owned()),
        vec![
            ("学".to_owned(), Some("が".to_owned())),
            ("生".to_owned(), Some("くせい".to_owned())),
        ],
    );
    furigana.insert(
        ("食べる".to_owned(), "たべる".to_owned()),
        vec![
            ("食".to_owned(), Some("たべ".to_owned())),
            ("べる".to_owned(), None),
        ],
    );
    let data = Data {
        furigana: Some(FuriganaIndex::from_entries(furigana)),
        ..Data::default()
    };
    let findings = run_rule(rules::jmdict::j07, &scope(), &data, &env());
    assert_level(&findings, "vo.taberu", Level::Warning);
    assert!(find(&findings, "vo.gakusei").is_none(), "{findings:?}");
}

// ---- J08、J09、J10 ----

#[test]
fn j08_accepts_tooth_like_kana() {
    let scope = scope_with(&[(
        r#""id": "vo.hai", "lesson": "le.l01", "lesson_order": 4, "surface": "はい", "kana": "はい""#,
        r#""id": "vo.hai", "lesson": "le.l01", "lesson_order": 4, "surface": "歯", "kana": "は""#,
    )]);
    let findings = run_rule(rules::kana::j08, &scope, &Data::default(), &env());
    assert!(no_errors(&findings), "{findings:?}");
    assert!(find(&findings, "vo.hai").is_none());
}

#[test]
fn j08_warns_on_words_ending_in_ha_without_space() {
    let scope = scope_with(&[(
        r#""surface": "はじめまして", "kana": "はじめまして""#,
        r#""surface": "では", "kana": "では""#,
    )]);
    let findings = run_rule(rules::kana::j08, &scope, &Data::default(), &env());
    assert_level(&findings, "vo.hajimemashite", Level::Warning);
}

#[test]
fn j09_reports_only_info_for_unknown_differences() {
    let findings = run_rule(rules::kana::j09, &scope(), &Data::default(), &env());
    assert!(findings.iter().all(|f| f.level == Level::Info));
}

#[test]
fn j10_warns_when_kana_word_missing_from_jmdict() {
    let findings = run_rule(
        rules::jmdict::j10,
        &scope(),
        &data_with_jmdict(jmdict(&[("", "あい", &["n"])])),
        &env(),
    );
    assert!(findings.iter().all(|f| f.level == Level::Warning));
    assert!(!findings.is_empty());
}

// ---- Z01、Z02 ----

#[test]
fn z01_warns_on_non_big5_han_outside_markup() {
    let scope = scope_with(&[(r#""zh": ["老師"]"#, r#""zh": ["学習老師"]"#)]);
    let findings = run_rule(rules::zh::z01, &scope, &Data::default(), &env());
    assert_level(&findings, "vo.sensei", Level::Warning);
    assert_eq!(find(&findings, "vo.sensei").unwrap().token, "学");
}

#[test]
fn z01_covers_japanese_shinjitai_and_ignores_markup() {
    for c in ["学", "気", "円", "図", "駅", "発", "説", "読", "楽", "国"] {
        assert!(rules::zh::is_non_big5_han(c.chars().next().unwrap()), "{c}");
    }
    assert!(!rules::zh::is_non_big5_han('學'));
    assert!(!rules::zh::is_non_big5_han('的'));
    let scope = scope_with(&[(
        r#""diff_zh": "{ja:か} 與 {ja:カ} 字形相近""#,
        r#""diff_zh": "{ja:学校} 與 {ja:カ} 字形相近""#,
    )]);
    let findings = run_rule(rules::zh::z01, &scope, &Data::default(), &env());
    assert!(findings.iter().all(|f| f.token != "学"), "{findings:?}");
}

#[test]
fn z02_rejects_kana_outside_markup_in_mixed_field() {
    let scope = scope_with(&[(
        r#""diff_zh": "{ja:ぬ} 收尾有圈，{ja:め} 沒有""#,
        r#""diff_zh": "ぬ 收尾有圈，{ja:め} 沒有""#,
    )]);
    let findings = run_rule(rules::zh::z02, &scope, &Data::default(), &env());
    assert_level(&findings, "ka.cf.nu_me", Level::Error);
}

#[test]
fn z02_rejects_markup_and_kana_in_plain_zh_fields() {
    let scope = scope_with(&[(r#""zh": ["老師"]"#, r#""zh": ["せんせい老師"]"#)]);
    let findings = run_rule(rules::zh::z02, &scope, &Data::default(), &env());
    assert_level(&findings, "vo.sensei", Level::Error);
    let scope = scope_with(&[(r#""zh": ["老師"]"#, r#""zh": ["{ja:先生}老師"]"#)]);
    let findings = run_rule(rules::zh::z02, &scope, &Data::default(), &env());
    assert_level(&findings, "vo.sensei", Level::Error);
}

// ---- C 涵蓋率 ----

fn jlpt_rows(rows: &[(&str, &str, &str)]) -> Vec<JlptRow> {
    rows.iter()
        .map(|(id, kana, kanji)| JlptRow {
            id: (*id).to_owned(),
            kana: (*kana).to_owned(),
            kanji: (*kanji).to_owned(),
        })
        .collect()
}

#[test]
fn c05_reports_incomplete_kana() {
    let findings = run_rule(rules::jlpt::c05, &scope(), &Data::default(), &env());
    assert!(findings
        .iter()
        .any(|f| f.level == Level::Error && f.item == "hira"));
    assert!(findings
        .iter()
        .any(|f| f.level == Level::Error && f.item == "kata"));
}

#[test]
fn c06_rejects_wrong_jlpt_and_accepts_right_one() {
    let keep: HashSet<String> = ["10", "11"].iter().map(|s| (*s).to_owned()).collect();
    let json = serde_json::json!({
        "words": [
            {"id": "10", "kanji": [{"text": "先生", "tags": []}], "kana": [{"text": "せんせい", "tags": [], "appliesToKanji": ["*"]}], "sense": [{"partOfSpeech": ["n"], "misc": []}]},
            {"id": "11", "kanji": [{"text": "私", "tags": []}], "kana": [{"text": "わたし", "tags": [], "appliesToKanji": ["*"]}], "sense": [{"partOfSpeech": ["pn"], "misc": []}]}
        ]
    })
    .to_string();
    let index = JmdictIndex::parse(json.as_bytes(), &keep).unwrap();
    let data = Data {
        jlpt: Some(JlptLists {
            n5: jlpt_rows(&[("10", "せんせい", "先生")]),
            n4: jlpt_rows(&[("11", "わたし", "私")]),
        }),
        jmdict: Some(index),
        ..Data::default()
    };
    let findings = run_rule(rules::jlpt::c06, &scope(), &data, &env());
    assert!(find(&findings, "vo.sensei").is_none(), "{findings:?}");
    assert_level(&findings, "vo.watashi", Level::Error);
    assert_level(&findings, "vo.nani", Level::Error);
}

#[test]
fn c01_reports_coverage_with_missing_sample() {
    let keep: HashSet<String> = ["10", "20"].iter().map(|s| (*s).to_owned()).collect();
    let json = serde_json::json!({
        "words": [
            {"id": "10", "kanji": [{"text": "先生", "tags": []}], "kana": [{"text": "せんせい", "tags": [], "appliesToKanji": ["*"]}], "sense": [{"partOfSpeech": ["n"], "misc": []}]},
            {"id": "20", "kanji": [{"text": "犬", "tags": []}], "kana": [{"text": "いぬ", "tags": [], "appliesToKanji": ["*"]}], "sense": [{"partOfSpeech": ["n"], "misc": []}]}
        ]
    })
    .to_string();
    let index = JmdictIndex::parse(json.as_bytes(), &keep).unwrap();
    let data = Data {
        jlpt: Some(JlptLists {
            n5: jlpt_rows(&[("10", "せんせい", "先生"), ("20", "いぬ", "犬")]),
            n4: Vec::new(),
        }),
        jmdict: Some(index),
        ..Data::default()
    };
    let findings = run_rule(rules::jlpt::c01, &scope(), &data, &env());
    let hit = find(&findings, "N5").unwrap_or_else(|| panic!("{findings:?}"));
    assert_eq!(hit.level, Level::Info);
    assert!(hit.message.contains("1/2"), "{hit:?}");
    assert!(hit.message.contains("犬/いぬ"), "{hit:?}");
}

#[test]
fn c03_reports_grammar_coverage_from_checklist() {
    let mut environment = env();
    environment.grammar_checklist = Some(vec![
        ("gr.desu".to_owned(), "n5".to_owned()),
        ("gr.not_written".to_owned(), "n5".to_owned()),
        ("gr.other".to_owned(), "n4".to_owned()),
    ]);
    let findings = run_rule(rules::jlpt::c03, &scope(), &Data::default(), &environment);
    let n5 = find(&findings, "N5").unwrap();
    assert!(n5.message.contains("1/2"), "{n5:?}");
}

// ---- L ----

#[test]
fn l01_rejects_forbidden_keys() {
    let files = vec![(
        "vocab/x.json".to_owned(),
        r#"{"items": [{"id": "vo.hai", "jmdict_id": "1"}, {"id": "vo.x", "note": {"tatoeba_id": 1}}]}"#
            .to_owned(),
    )];
    let findings = rules::license::forbidden_keys(&files);
    assert_level(&findings, "vo.hai", Level::Error);
    assert_eq!(find(&findings, "vo.hai").unwrap().token, "jmdict_id");
    assert_eq!(find(&findings, "vo.x").unwrap().token, "tatoeba_id");
}

#[test]
fn l01_passes_clean_content() {
    assert!(run_rule(rules::license::l01, &scope(), &Data::default(), &env()).is_empty());
}

#[test]
fn l02_requires_notice_for_jlpt_field_and_bundled_fonts() {
    let temp = tempfile::tempdir().unwrap();
    let environment = env_for(temp.path());
    let findings = run_rule(
        rules::license::l02,
        &scope(),
        &Data::default(),
        &environment,
    );
    assert!(findings
        .iter()
        .any(|f| f.level == Level::Error && f.token.contains("Waller")));

    std::fs::write(
        temp.path().join("THIRD_PARTY_NOTICES.md"),
        "Jonathan Waller's JLPT Resources\n",
    )
    .unwrap();
    let findings = run_rule(
        rules::license::l02,
        &scope(),
        &Data::default(),
        &environment,
    );
    assert!(findings.is_empty(), "{findings:?}");

    std::fs::write(
        temp.path().join("pubspec.yaml"),
        "flutter:\n  fonts:\n    - family: KleeOneJP\n      fonts:\n        - asset: assets/fonts/KleeOne-Regular.subset.ttf\n",
    )
    .unwrap();
    let findings = run_rule(
        rules::license::l02,
        &scope(),
        &Data::default(),
        &environment,
    );
    assert!(
        findings.iter().any(|f| f.token.contains("Klee One")),
        "{findings:?}"
    );
}

#[test]
fn l04_requires_ignored_paths() {
    let temp = tempfile::tempdir().unwrap();
    let environment = env_for(temp.path());
    std::fs::write(temp.path().join(".gitignore"), "/.verify-cache/\n").unwrap();
    let findings = run_rule(
        rules::license::l04,
        &scope(),
        &Data::default(),
        &environment,
    );
    assert_eq!(findings.len(), 2, "{findings:?}");
    assert!(findings.iter().all(|f| f.level == Level::Error));

    std::fs::write(
        temp.path().join(".gitignore"),
        "/.verify-cache/\n/build/verify/\n/build/fonts/\n",
    )
    .unwrap();
    let findings = run_rule(
        rules::license::l04,
        &scope(),
        &Data::default(),
        &environment,
    );
    assert!(findings.is_empty());
}

// ---- A01 ----

#[test]
fn a01_warns_when_accent_contradicts_data() {
    let mut accents = HashMap::new();
    accents.insert(("先生".to_owned(), "せんせい".to_owned()), vec![3]);
    let data = Data {
        accents: Some(AccentIndex::from_entries(accents)),
        ..Data::default()
    };
    let scope = scope_with(&[(
        r#""surface": "先生", "kana": "せんせい", "zh": ["老師"], "pos": "n", "accent": null"#,
        r#""surface": "先生", "kana": "せんせい", "zh": ["老師"], "pos": "n", "accent": 0"#,
    )]);
    let findings = run_rule(rules::accent::a01, &scope, &data, &env());
    assert_level(&findings, "vo.sensei", Level::Warning);

    let good = scope_with(&[(
        r#""surface": "先生", "kana": "せんせい", "zh": ["老師"], "pos": "n", "accent": null"#,
        r#""surface": "先生", "kana": "せんせい", "zh": ["老師"], "pos": "n", "accent": 3"#,
    )]);
    assert!(run_rule(rules::accent::a01, &good, &data, &env()).is_empty());
}

// ---- F 字型 ----

#[test]
fn f01_reports_missing_glyphs_and_marks_unrun_when_font_absent() {
    let mut environment = env();
    let mut klee: HashSet<char> = HashSet::new();
    klee.extend("あいうえお".chars());
    environment
        .fonts
        .insert("KleeOne-Regular.subset.ttf".to_owned(), klee.clone());
    environment
        .fonts
        .insert("KleeOne-SemiBold.subset.ttf".to_owned(), klee);
    let findings = run_rule(rules::font::f01, &scope(), &Data::default(), &environment);
    assert!(
        findings
            .iter()
            .any(|f| f.level == Level::Error && f.token == "私"),
        "{findings:?}"
    );

    let findings = run_rule(rules::font::f01, &scope(), &Data::default(), &env());
    assert_eq!(findings.len(), 1, "{findings:?}");
    assert_eq!(findings[0].level, Level::Warning);
    assert!(findings[0].message.contains("未執行"));
}

#[test]
fn f02_requires_ofl_for_each_referenced_font() {
    let temp = tempfile::tempdir().unwrap();
    std::fs::write(
        temp.path().join("pubspec.yaml"),
        "flutter:\n  fonts:\n    - family: KleeOneJP\n      fonts:\n        - asset: assets/fonts/KleeOne-Regular.subset.ttf\n",
    )
    .unwrap();
    let environment = env_for(temp.path());
    let findings = run_rule(rules::font::f02, &scope(), &Data::default(), &environment);
    assert_eq!(findings.len(), 1, "{findings:?}");
    assert_eq!(findings[0].level, Level::Error);

    std::fs::create_dir_all(temp.path().join("assets/fonts/licenses")).unwrap();
    std::fs::write(
        temp.path().join("assets/fonts/licenses/OFL-KleeOne.txt"),
        "OFL",
    )
    .unwrap();
    assert!(run_rule(rules::font::f02, &scope(), &Data::default(), &environment).is_empty());
}

// ---- F03 歸屬 ----

/// `lib` 的放行不可蓋掉內容的缺字：同一個字同時出現時要歸給內容項目。
#[test]
fn f03_attributes_a_shared_char_to_the_content_item_not_lib() {
    let repo = tempfile::tempdir().expect("暫存目錄");
    let lib = repo.path().join("lib");
    std::fs::create_dir_all(&lib).expect("建立 lib");
    std::fs::write(lib.join("glyph.dart"), "const glyph = '暦';\n").expect("寫入");
    let scope = scope_with(&[(r#""zh": ["學生"]"#, r#""zh": ["暦"]"#)]);
    let mut env = env_for(repo.path());
    for name in rules::font::NOTO_SANS_FONTS {
        env.fonts.insert(name.to_owned(), HashSet::new());
    }

    let findings = run_rule(rules::font::f03, &scope, &Data::default(), &env);

    let owners: HashSet<&str> = findings
        .iter()
        .filter(|f| f.token == "暦")
        .map(|f| f.item.as_str())
        .collect();
    assert_eq!(owners, HashSet::from(["vo.gakusei"]));
}

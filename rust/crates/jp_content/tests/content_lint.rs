//! curriculum.md §13（R01–R25）與 rust-core.md §11.3（RC1–RC11）。
//!
//! 每條規則都有專屬的負面夾具：`fixtures/lint_bad/<case>/` 疊加在完整夾具上。
//! 本檔放整體性的檢查與 R01–R12，R13 之後在 `content_lint_rules.rs`。

#[macro_use]
mod lint_support;

use lint_support::*;

#[test]
fn full_fixture_passes_at_every_stage() {
    let lists = LintLists::from_content_root(&full_fixture_dir()).expect("清單");
    for stage in [ContentStage::P0a, ContentStage::P0, ContentStage::Full] {
        let report = lint_of(&fixture_files(), stage, &lists);
        assert_no_errors(&report, stage.name());
    }
}

#[test]
fn real_content_passes_lint() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../content");
    let lists = LintLists::from_content_root(&root).expect("rust/content/lint 應可讀取");
    let stage = resolve_stage(None).expect("CONTENT_STAGE 值無效");
    let files = read_content_dir(&root).expect("rust/content 應可讀取");
    let report = lint_of(&files, stage, &lists);
    assert_no_errors(&report, "rust/content");
}

/// 第三輪裁決 C1、C2：發布階段的 R10、R19 必須全清（多解標記要拆開，例外要登錄）。
/// `full` 的 L31 之後還沒寫，L30 的字沒有重現的地方，不在此列。
#[test]
fn real_content_has_no_r10_or_r19_findings() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../content");
    let lists = LintLists::from_content_root(&root).expect("rust/content/lint 應可讀取");
    let files = read_content_dir(&root).expect("rust/content 應可讀取");
    for stage in [ContentStage::P0a, ContentStage::P0] {
        let report = lint_of(&files, stage, &lists);
        let found: Vec<String> = ["R10", "R19"]
            .iter()
            .flat_map(|rule| report.of_rule(rule))
            .map(Finding::to_string)
            .collect();
        assert!(found.is_empty(), "{}：{found:#?}", stage.name());
    }
}

negative!(
    rc11_rejects_l_lesson_without_dialogue,
    "rc11_lesson_without_dialogue",
    "RC11",
    "le.l03",
    "dialogue"
);

negative!(
    rc11_rejects_unreferenced_main_dialogue,
    "rc11_orphan_main_dialogue",
    "RC11",
    "di.orphan",
    "le.l02"
);

/// 種子夾具本來就沒有每課主對話，比照 R17 略過。
#[test]
fn rc11_is_skipped_for_seed_content() {
    let lists = LintLists::from_content_root(&full_fixture_dir()).expect("清單");
    let report = lint_of(&fixture_files(), ContentStage::Full, &lists);
    assert!(
        report.of_rule("RC11").next().is_none(),
        "{}",
        describe(&report)
    );
}

#[test]
fn kana_lessons_need_no_dialogue() {
    let report = lint_case("rc11_lesson_without_dialogue");
    let kana_lessons = report
        .of_rule("RC11")
        .filter(|f| f.item.starts_with("le.k"))
        .count();
    assert_eq!(kana_lessons, 0, "{}", describe(&report));
}

/// 主對話指向不存在的項目由 R03 把關（硬引用）。
#[test]
fn lesson_dialogue_pointing_nowhere_is_reported() {
    let lists = LintLists::from_content_root(&full_fixture_dir()).expect("清單");
    let files: ContentFiles = fixture_files()
        .into_iter()
        .map(|(path, text)| {
            let text = if path == "course.json" {
                text.replacen("\"dialogue\": \"di.meal\"", "\"dialogue\": \"di.none\"", 1)
            } else {
                text
            };
            (path, text)
        })
        .collect();
    let report = lint_of(&files, ContentStage::Full, &lists);
    assert!(
        report
            .of_rule("R03")
            .any(|f| f.item == "le.l02" && f.token == "di.none"),
        "{}",
        describe(&report)
    );
}

#[test]
fn findings_are_sorted_and_display_item_token_and_lesson() {
    let finding = assert_finding("r04_order", "R04", Level::Error, "se.bad.r04", "vo.taberu");
    assert_eq!(finding.first_taught.as_deref(), Some("le.l02"));
    let text = finding.to_string();
    assert!(
        text.contains("se.bad.r04") && text.contains("vo.taberu") && text.contains("le.l02"),
        "{text}"
    );
    assert!(text.contains("R04"), "{text}");
}

#[test]
fn unknown_field_reports_load_failure() {
    let report = lint_case("load_unknown_field");
    assert!(
        report.of_rule("LOAD").next().is_some(),
        "{}",
        describe(&report)
    );
}

#[test]
fn r06_reports_first_taught_lesson_for_later_kana_and_untaught_for_unknown() {
    let later = assert_finding("r06_kana_gate", "R06", Level::Error, "se.bad.r06", "ア");
    assert_eq!(later.first_taught.as_deref(), Some("le.kk01"));
    let unknown = assert_finding("r06_kana_word", "R06", Level::Error, "dr.bad.kwd.r06", "ぬ");
    assert_eq!(unknown.first_taught.as_deref(), Some("le.k05"));
}

#[test]
fn r17_counts_below_targets_only_when_policy_enforced() {
    assert_finding("r17_counts_below_target", "R17", Level::Error, "單字", "");
    let seed_lists = LintLists::from_content_root(&full_fixture_dir()).expect("清單");
    let report = lint_of(&fixture_files(), ContentStage::Full, &seed_lists);
    assert!(report.of_rule("R17").all(|f| f.level == Level::Warning));
}

negative!(
    r01_rejects_malformed_id,
    "r01_bad_id",
    "R01",
    "se.BAD.001",
    "se.BAD.001"
);
negative!(
    r01_rejects_duplicate_id,
    "r01_duplicate",
    "R01",
    "se.l01.001",
    "se.l01.001"
);
negative_warning!(
    r01_warns_when_slug_differs_from_romaji,
    "r01_slug_warning",
    "R01",
    "vo.wrong_slug",
    ""
);
negative!(
    r02_rejects_token_without_ref,
    "r02_missing_ref",
    "R02",
    "se.bad.r02",
    "はい"
);
negative!(
    r02_rejects_bad_ref_prefix,
    "r02_bad_prefix",
    "R02",
    "se.bad.r02b",
    "xx.hai"
);
negative!(
    r03_rejects_dangling_t_ref,
    "r03_missing_ref",
    "R03",
    "se.bad.r03",
    "vo.nope"
);
negative!(
    r03_rejects_retired_target,
    "r03_retired_ref",
    "R03",
    "se.bad.r03r",
    "vo.old"
);
negative!(
    r03_rejects_missing_soft_ref,
    "r03_missing_soft_examples",
    "R03",
    "vo.badsoft",
    "se.no_such"
);
negative!(
    r03_rejects_item_in_unknown_lesson,
    "r03_unknown_lesson",
    "R03",
    "vo.typo",
    "le.l99"
);
negative!(
    r04_rejects_future_ref,
    "r04_order",
    "R04",
    "se.bad.r04",
    "vo.taberu"
);
negative!(
    r04_rejects_later_requires,
    "r04_requires_later",
    "R04",
    "gr.needs_later",
    "gr.plain_style"
);
negative!(
    r04_rejects_cycle,
    "r04_requires_cycle",
    "R04",
    "gr.cycle",
    "gr.cycle"
);
negative!(
    r05_rejects_two_new_in_sentence,
    "r05_two_new",
    "R05",
    "se.bad.r05",
    "@new"
);
negative!(
    r05_rejects_new_in_drill,
    "r05_in_drill",
    "R05",
    "dr.bad.z2j.r05",
    "@new"
);
negative!(
    r05_rejects_new_in_s0_lesson,
    "r05_in_s0",
    "R05",
    "dr.bad.z2j.s0",
    "@new"
);
negative!(
    r05_rejects_ratio_over_ten_percent,
    "r05_ratio",
    "R05",
    "le.l03",
    "@new"
);
negative!(
    r06_rejects_untaught_katakana,
    "r06_kana_gate",
    "R06",
    "se.bad.r06",
    "ア"
);
negative!(
    r06_rejects_untaught_in_kana_word,
    "r06_kana_word",
    "R06",
    "dr.bad.kwd.r06",
    "ぬ"
);
negative!(
    r06_matches_yoon_as_one_unit,
    "r06_yoon_unit",
    "R06",
    "dr.bad.mpr.r06",
    "ちゃ"
);
negative!(
    r06_rejects_untaught_in_sound_group,
    "r06_sound_group",
    "R06",
    "ka.sg.bad_r06",
    "た"
);
negative!(
    r07_rejects_illegal_stem,
    "r07_stem",
    "R07",
    "se.bad.r07",
    "食べた"
);
negative!(
    r07_rejects_noninflecting_mismatch,
    "r07_noninflect",
    "R07",
    "se.bad.r07n",
    "学校"
);
negative!(
    r08_rejects_redundant_kana,
    "r08_redundant",
    "R08",
    "se.bad.r08",
    "はい|はい"
);
negative!(
    r08_rejects_missing_kana,
    "r08_missing",
    "R08",
    "se.bad.r08m",
    "先生"
);
negative!(
    r08_rejects_bad_alignment,
    "r08_alignment",
    "R08",
    "se.bad.r08a",
    "食べ|ちち"
);
negative!(
    r09_rejects_word_without_sentences,
    "r09_vocab_unused",
    "R09",
    "vo.neko",
    "ねこ"
);
negative!(
    r09_rejects_example_from_other_lesson,
    "r09_example_first",
    "R09",
    "vo.neko",
    "ねこ"
);
negative!(
    r09_rejects_thin_grammar,
    "r09_grammar_few",
    "R09",
    "gr.thin",
    ""
);
negative_warning!(
    r10_warns_without_spaced_repetition,
    "r10_no_repeat",
    "R10",
    "vo.neko",
    "ねこ"
);

fn r10_items(report: &LintReport) -> Vec<String> {
    report.of_rule("R10").map(|f| f.item.clone()).collect()
}

/// 夾具順序 L02、L03、KK07、KK08、L08：L08 是 L02 之後第 2 個主線課。
/// 假名課不介紹單字，不佔「3 課內」的時間窗（第三輪裁決 P9）。
#[test]
fn r10_window_counts_only_main_line_lessons() {
    let report = lint_case("r10_kana_lessons_between");
    assert!(
        !r10_items(&report).contains(&"vo.neko".to_owned()),
        "{}",
        describe(&report)
    );
}

/// 夾具順序 L01 之後的主線課是 L02、L03、L08、L21：L21 是第 4 個，仍要警告。
#[test]
fn r10_still_warns_when_reuse_is_past_three_main_line_lessons() {
    let report = r10_report_with_reuse_in("le.l21");
    assert!(
        r10_items(&report).contains(&"vo.neko".to_owned()),
        "{}",
        describe(&report)
    );
}

/// 把 `r10_no_repeat` 的第二句移到 [lesson]，其餘不變。
fn r10_report_with_reuse_in(lesson: &str) -> LintReport {
    let moved = format!("\"lesson\": \"{lesson}\"");
    let files: ContentFiles = fixture_files_with_overlay("r10_no_repeat")
        .into_iter()
        .map(|(path, text)| {
            let text = if path == "sentences/bad.json" {
                text.replacen("\"lesson\": \"le.l01\"", &moved, 2).replacen(
                    &moved,
                    "\"lesson\": \"le.l01\"",
                    1,
                )
            } else {
                text
            };
            (path, text)
        })
        .collect();
    lint_of(&files, ContentStage::Full, &lists_for_case("r10_no_repeat"))
}

/// 夾具順序 L01 之後的主線課是 L02、L03、L08：L08 剛好是第 3 個，算重現（時間窗含端點）。
#[test]
fn r10_reuse_on_the_third_main_line_lesson_counts() {
    let report = r10_report_with_reuse_in("le.l08");
    assert!(
        !r10_items(&report).contains(&"vo.neko".to_owned()),
        "{}",
        describe(&report)
    );
}

/// 已退役的單字不追蹤：不必再重現，也就不報 R10。
#[test]
fn r10_ignores_retired_vocab() {
    let files: ContentFiles = fixture_files_with_overlay("r10_no_repeat")
        .into_iter()
        .map(|(path, text)| {
            let text = if path == "vocab/bad.json" {
                text.replace(
                    "\"id\": \"vo.neko\",",
                    "\"id\": \"vo.neko\", \"retired\": true,",
                )
            } else {
                text
            };
            (path, text)
        })
        .collect();
    let report = lint_of(&files, ContentStage::Full, &lists_for_case("r10_no_repeat"));
    assert!(
        !r10_items(&report).contains(&"vo.neko".to_owned()),
        "{}",
        describe(&report)
    );
}

// 夾具把 L02 的字只在 KK07 再用一次：假名課的出現不算重現（第三輪裁決 P9）。
negative_warning!(
    r10_reuse_in_kana_lesson_does_not_count,
    "r10_reuse_only_in_kana_lesson",
    "R10",
    "vo.neko",
    "ねこ"
);

/// 刻意設計的例外登錄在 `lint/r10_allow.txt`（每行 ID 與理由），不再警告。
#[test]
fn r10_allow_list_with_reason_suppresses_warning() {
    let report = lint_case("r10_allowed");
    assert!(
        !r10_items(&report).contains(&"vo.neko".to_owned()),
        "{}",
        describe(&report)
    );
    assert_no_errors(&report, "r10_allowed");
}

#[test]
fn r10_allow_list_parses_id_and_reason() {
    let overlay = fixtures_dir().join("lint_bad").join("r10_allowed");
    let lists = LintLists::from_content_root(&overlay).expect("清單");
    assert_eq!(
        lists.r10_allow.get("vo.neko").map(String::as_str),
        Some("測試用：刻意只在教學課出現")
    );
}

negative!(
    r10_allow_entry_needs_reason,
    "r10_allow_no_reason",
    "R10",
    "vo.neko",
    "r10_allow.txt"
);
// 缺理由的登錄除了報錯，也不能把原本的警告消掉。
negative_warning!(
    r10_allow_entry_without_reason_keeps_warning,
    "r10_allow_no_reason",
    "R10",
    "vo.neko",
    "ねこ"
);
negative_warning!(
    r10_allow_entry_for_repeated_word_is_stale,
    "r10_allow_stale",
    "R10",
    "vo.watashi",
    "r10_allow.txt"
);

/// `p0a` 夾具到 L03 為止，後面只剩 KK07、KK08：L03 的字沒有可重現的主線課，不警告。
#[test]
fn r10_skips_last_main_line_lesson_even_when_kana_lessons_follow() {
    let lists = LintLists::from_content_root(&full_fixture_dir()).expect("清單");
    let report = lint_of(&fixture_files(), ContentStage::P0a, &lists);
    let l03_items: Vec<String> = report
        .of_rule("R10")
        .filter(|f| f.first_taught.as_deref() == Some("le.l03"))
        .map(|f| f.item.clone())
        .collect();
    assert!(l03_items.is_empty(), "{}", describe(&report));
}
negative!(
    r11_rejects_overloaded_sentence,
    "r11_sentence",
    "R11",
    "se.bad.r11",
    ""
);
negative!(
    r11_rejects_overloaded_turn,
    "r11_turn",
    "R11",
    "di.bad_r11",
    ""
);
negative!(
    r11_rejects_more_than_five_new_items_in_early_lessons,
    "r11_early_limit",
    "R11",
    "se.bad.r11_early",
    ""
);

#[test]
fn r11_allows_five_new_items_in_early_lesson_sentences() {
    let report = lint_case("r11_early_ok");
    let found: Vec<_> = report.of_rule("R11").collect();
    assert!(found.is_empty(), "L01–L03 上限應為 5：{found:?}");
}

negative!(
    r12_rejects_two_blanks,
    "r12_blanks",
    "R12",
    "dr.bad.par.r12",
    "blanks"
);
negative!(
    r12_rejects_too_few_rows,
    "r12_rows",
    "R12",
    "dr.bad.sub.r12",
    "rows"
);
negative!(
    r12_rejects_future_ref_in_options,
    "r12_option_order",
    "R12",
    "dr.bad.z2j.r12",
    "vo.taberu"
);
negative!(
    r12_rejects_slot_mismatch,
    "r12_slot_mismatch",
    "R12",
    "dr.bad.sub.slot",
    ""
);
negative!(
    r12_rejects_option_without_ref,
    "r12_choice_missing_ref",
    "R12",
    "dr.bad.par.ref",
    "は"
);

//! `content_lint*.rs` 共用：載入夾具、斷言 Finding、負面案例巨集。
#![allow(dead_code, unused_imports)]

pub use std::path::Path;

pub use jp_content::disk::{borrow_files, read_content_dir, resolve_stage, ContentFiles};
pub use jp_content::lint::{run_lint, Finding, Level, LintLists, LintReport};
pub use jp_content::schema::ContentStage;
pub use jp_content::test_support::{
    fixture_files, fixture_files_with_overlay, fixtures_dir, full_fixture_dir,
};

pub fn lint_of(files: &ContentFiles, stage: ContentStage, lists: &LintLists) -> LintReport {
    run_lint(&borrow_files(files), stage, lists)
}

pub fn lists_for_case(case: &str) -> LintLists {
    let mut lists =
        LintLists::from_content_root(&full_fixture_dir()).expect("夾具 lint 清單應可讀取");
    let overlay = fixtures_dir().join("lint_bad").join(case);
    if overlay.join("lint/count_policy.txt").exists() {
        lists.seed_content = LintLists::from_content_root(&overlay)
            .expect("overlay lint 清單應可讀取")
            .seed_content;
    }
    if overlay.join("lint/r10_allow.txt").exists() {
        lists.r10_allow = LintLists::from_content_root(&overlay)
            .expect("overlay lint 清單應可讀取")
            .r10_allow;
    }
    lists
}

pub fn lint_case(case: &str) -> LintReport {
    lint_of(
        &fixture_files_with_overlay(case),
        ContentStage::Full,
        &lists_for_case(case),
    )
}

pub fn describe(report: &LintReport) -> String {
    report
        .findings()
        .iter()
        .map(Finding::to_string)
        .collect::<Vec<_>>()
        .join("\n")
}

pub fn assert_finding(case: &str, rule: &str, level: Level, item: &str, token: &str) -> Finding {
    let report = lint_case(case);
    let found = report
        .of_rule(rule)
        .find(|f| f.level == level && f.item.contains(item) && f.token.contains(token));
    match found {
        Some(finding) => finding.clone(),
        None => panic!(
            "{case}：找不到 {rule} {item}/{token}，實際：\n{}",
            describe(&report)
        ),
    }
}

macro_rules! negative {
    ($name:ident, $case:literal, $rule:literal, $item:literal, $token:literal) => {
        #[test]
        fn $name() {
            assert_finding($case, $rule, Level::Error, $item, $token);
        }
    };
}

macro_rules! negative_warning {
    ($name:ident, $case:literal, $rule:literal, $item:literal, $token:literal) => {
        #[test]
        fn $name() {
            assert_finding($case, $rule, Level::Warning, $item, $token);
        }
    };
}

pub fn assert_no_errors(report: &LintReport, what: &str) {
    assert!(
        !report.has_errors(),
        "{what} 應通過 lint，實際：\n{}",
        describe(report)
    );
}

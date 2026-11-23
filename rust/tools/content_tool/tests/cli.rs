//! `content_tool available`、`lint`、`stats` 的命令列行為與結束代碼（reuse-and-verification.md §9.4）。

use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};

const EXIT_OK: i32 = 0;
const EXIT_CONTENT_ERROR: i32 = 1;
const EXIT_ENV_ERROR: i32 = 2;

fn fixture_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../crates/jp_content/tests/fixtures/full")
}

fn real_content_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../content")
}

fn run(args: &[&str], root: &Path) -> Output {
    Command::new(env!("CARGO_BIN_EXE_content_tool"))
        .args(["--content-root", root.to_str().expect("路徑應為 UTF-8")])
        .args(args)
        .env_remove("CONTENT_STAGE")
        .output()
        .expect("應可執行 content_tool")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).into_owned()
}

fn code(output: &Output) -> i32 {
    output.status.code().expect("應有結束代碼")
}

fn copy_dir(from: &Path, to: &Path) {
    fs::create_dir_all(to).expect("建立目錄");
    for entry in fs::read_dir(from).expect("讀取目錄") {
        let entry = entry.expect("目錄項目");
        let target = to.join(entry.file_name());
        if entry.path().is_dir() {
            copy_dir(&entry.path(), &target);
        } else {
            fs::copy(entry.path(), target).expect("複製檔案");
        }
    }
}

#[test]
fn available_lists_items_up_to_lesson_in_tsv() {
    let output = run(&["available", "le.l01", "--stage", "full"], &fixture_root());
    assert_eq!(code(&output), EXIT_OK, "{output:?}");
    let text = stdout(&output);
    let mut lines = text.lines();
    assert_eq!(lines.next(), Some("id\tsurface\tkana\tlesson"));
    assert!(
        text.lines().any(|l| l == "ka.hira.a\tあ\tあ\tle.k01"),
        "{text}"
    );
    assert!(
        text.lines().any(|l| l == "vo.watashi\t私\tわたし\tle.l01"),
        "{text}"
    );
    assert!(text.contains("gr.desu\t"), "{text}");
    assert!(text.contains("ka.rule.sokuon\t"), "{text}");
    assert!(text.contains("ka.cf.nu_me\t"), "{text}");
    assert!(text.contains("ka.sg.voicing_k\t"), "{text}");
    assert!(!text.contains("vo.taberu"), "{text}");
}

#[test]
fn available_excludes_items_after_the_lesson() {
    let output = run(&["available", "le.l21", "--stage", "full"], &fixture_root());
    assert_eq!(code(&output), EXIT_OK);
    let text = stdout(&output);
    assert!(text.contains("vo.suru\t"), "L21 的單字應列出：{text}");
    assert!(!text.contains("vo.miru"), "L31 內容不應出現：{text}");
}

#[test]
fn available_is_ordered_by_lesson_position_then_lesson_order() {
    let output = run(&["available", "le.l02", "--stage", "full"], &fixture_root());
    let text = stdout(&output);
    let ids: Vec<&str> = text
        .lines()
        .skip(1)
        .filter_map(|l| l.split('\t').next())
        .collect();
    let pos = |id: &str| {
        ids.iter()
            .position(|x| *x == id)
            .unwrap_or_else(|| panic!("缺 {id}"))
    };
    assert!(pos("ka.hira.a") < pos("vo.watashi"));
    assert!(pos("vo.watashi") < pos("vo.sensei"));
    assert!(pos("vo.gohan") < pos("vo.taberu"));
}

#[test]
fn available_uses_env_stage_by_default() {
    let output = Command::new(env!("CARGO_BIN_EXE_content_tool"))
        .args([
            "--content-root",
            fixture_root().to_str().expect("UTF-8"),
            "available",
            "le.l21",
        ])
        .env("CONTENT_STAGE", "p0")
        .output()
        .expect("應可執行");
    assert_eq!(code(&output), EXIT_OK, "{output:?}");
}

#[test]
fn available_unknown_lesson_is_environment_error() {
    let output = run(
        &["available", "le.nope", "--stage", "full"],
        &fixture_root(),
    );
    assert_eq!(code(&output), EXIT_ENV_ERROR);
}

#[test]
fn invalid_stage_exits_two() {
    let output = run(&["lint", "--stage", "bogus"], &fixture_root());
    assert_eq!(code(&output), EXIT_ENV_ERROR);
}

#[test]
fn missing_content_root_exits_two() {
    let output = run(&["lint"], Path::new("/nonexistent/content"));
    assert_eq!(code(&output), EXIT_ENV_ERROR);
}

#[test]
fn lint_passes_on_fixture_and_seed_content() {
    assert_eq!(
        code(&run(&["lint", "--stage", "full"], &fixture_root())),
        EXIT_OK
    );
    let output = run(&["lint"], &real_content_root());
    assert_eq!(code(&output), EXIT_OK, "{}", stdout(&output));
}

#[test]
fn lint_reports_findings_with_item_token_and_lesson_and_exits_one() {
    let temp = tempfile::tempdir().expect("暫存目錄");
    copy_dir(&fixture_root(), temp.path());
    fs::write(
        temp.path().join("sentences/bad.json"),
        r#"{"schema":1,"items":[{"id":"se.bad.cli","lesson":"le.l01","t":"食べ|たべ|vo.taberu+ます|gr.masu 。","zh":"測試。","style":"polite"}]}"#,
    )
    .expect("寫入");
    let output = run(&["lint", "--stage", "full"], temp.path());
    assert_eq!(code(&output), EXIT_CONTENT_ERROR, "{}", stdout(&output));
    let text = stdout(&output);
    assert!(text.contains("R04"), "{text}");
    assert!(text.contains("se.bad.cli"), "{text}");
    assert!(text.contains("vo.taberu"), "{text}");
    assert!(text.contains("le.l02"), "{text}");
}

#[test]
fn lint_reports_load_failure_as_content_error() {
    let temp = tempfile::tempdir().expect("暫存目錄");
    fs::write(temp.path().join("course.json"), "{ not json").expect("寫入");
    let output = run(&["lint"], temp.path());
    assert_eq!(code(&output), EXIT_CONTENT_ERROR, "{}", stdout(&output));
    assert!(stdout(&output).contains("LOAD"), "{}", stdout(&output));
}

#[test]
fn stats_prints_category_counts_against_stage_targets() {
    let output = run(&["stats"], &real_content_root());
    assert_eq!(code(&output), EXIT_OK, "{output:?}");
    let text = stdout(&output);
    assert!(text.contains("category\tcount\ttarget"), "{text}");
    assert!(text.lines().any(|l| l == "假名字元\t229\t229"), "{text}");
    assert!(text.lines().any(|l| l == "計畫預設\t4\t4"), "{text}");
    // 未指定階段時預設 p0（disk::DEFAULT_STAGE）：K19＋KK8＋L01–L30
    assert!(text.lines().any(|l| l == "課程\t57\t57"), "{text}");
}

#[test]
fn stats_respects_stage_override() {
    let output = run(&["stats", "--stage", "full"], &fixture_root());
    assert_eq!(code(&output), EXIT_OK, "{output:?}");
    assert!(stdout(&output)
        .lines()
        .any(|l| l.starts_with("單字\t") && l.ends_with("\t1400")));
}

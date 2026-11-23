//! `content_tool verify`、`coverage`、`charset` 的命令列行為（reuse-and-verification.md §9.4、§9.6）。

mod common;

use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};

use common::{fixture_jmdict_json, fixture_root};

const EXIT_OK: i32 = 0;
const EXIT_CONTENT_ERROR: i32 = 1;
const EXIT_ENV_ERROR: i32 = 2;
const NO_DATA_RULES: &str = "J01b,J04,J08,Z01,Z02,C05,L04";

struct Run {
    repo: tempfile::TempDir,
    content: PathBuf,
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

fn setup() -> Run {
    let repo = tempfile::tempdir().expect("暫存目錄");
    let content = repo.path().join("content");
    copy_dir(&fixture_root(), &content);
    let cache = repo.path().join(".verify-cache");
    fs::create_dir_all(&cache).expect("建立快取");
    fs::write(cache.join("jmdict-eng.json"), fixture_jmdict_json()).expect("寫入 JMdict");
    fs::write(
        repo.path().join(".gitignore"),
        "/.verify-cache/\n/build/verify/\n/build/fonts/\n",
    )
    .expect("寫入 .gitignore");
    Run { repo, content }
}

fn run(fixture: &Run, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_content_tool"))
        .args(["--content-root", fixture.content.to_str().expect("UTF-8")])
        .args(["--repo-root", fixture.repo.path().to_str().expect("UTF-8")])
        .args(args)
        .args(["--stage", "full"])
        .env_remove("CONTENT_STAGE")
        .output()
        .expect("應可執行")
}

fn cached(fixture: &Run, args: &[&str]) -> Output {
    let cache = fixture.repo.path().join(".verify-cache");
    let mut all = vec!["verify", "--cache-dir", cache.to_str().expect("UTF-8")];
    all.extend(args);
    run(fixture, &all)
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).into_owned()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).into_owned()
}

fn code(output: &Output) -> i32 {
    output.status.code().expect("應有結束代碼")
}

fn edit(fixture: &Run, file: &str, from: &str, to: &str) {
    let path = fixture.content.join(file);
    let text = fs::read_to_string(&path).expect("讀檔");
    assert!(text.contains(from), "{file} 缺 {from}");
    fs::write(path, text.replacen(from, to, 1)).expect("寫檔");
}

#[test]
fn verify_without_data_explains_how_to_get_it_and_exits_two() {
    let fixture = setup();
    fs::remove_file(fixture.repo.path().join(".verify-cache/jmdict-eng.json")).expect("刪除");

    let output = cached(&fixture, &["--only", "J01"]);

    assert_eq!(code(&output), EXIT_ENV_ERROR, "{output:?}");
    let message = stderr(&output);
    assert!(message.contains("fetch_data.sh"), "{message}");
    assert!(message.contains("jmdict-eng.json"), "{message}");
}

#[test]
fn verify_rejects_unknown_rule_id() {
    let fixture = setup();
    let output = cached(&fixture, &["--only", "Z99"]);
    assert_eq!(code(&output), EXIT_ENV_ERROR, "{output:?}");
}

#[test]
fn verify_rules_without_data_run_without_a_cache() {
    let fixture = setup();
    fs::remove_dir_all(fixture.repo.path().join(".verify-cache")).expect("刪除");

    let output = cached(&fixture, &["--only", NO_DATA_RULES]);

    assert_ne!(code(&output), EXIT_ENV_ERROR, "{}", stderr(&output));
}

#[test]
fn verify_passes_clean_fixture_and_writes_report() {
    let fixture = setup();

    let output = cached(&fixture, &["--only", "J01,J01b,J04,J05"]);

    assert_eq!(code(&output), EXIT_OK, "{}", stdout(&output));
    let report = fixture.repo.path().join("build/verify/report.json");
    let body: serde_json::Value =
        serde_json::from_str(&fs::read_to_string(report).expect("報告")).expect("JSON");
    assert_eq!(body["stage"], "full");
    assert_eq!(body["counts"]["errors"], 0);
}

#[test]
fn verify_catches_kanji_with_wrong_reading_and_exits_one() {
    let fixture = setup();
    edit(
        &fixture,
        "vocab/core.json",
        r#""surface": "学生", "kana": "がくせい""#,
        r#""surface": "学生", "kana": "がっせい""#,
    );

    let output = cached(&fixture, &["--only", "J01"]);

    assert_eq!(code(&output), EXIT_CONTENT_ERROR, "{}", stdout(&output));
    let text = stdout(&output);
    assert!(text.contains("J01 [error] vo.gakusei"), "{text}");
    assert!(text.contains("がっせい"), "{text}");
    let report =
        fs::read_to_string(fixture.repo.path().join("build/verify/report.json")).expect("報告");
    assert!(report.contains("vo.gakusei"));
}

#[test]
fn verify_catches_wrong_part_of_speech_and_exits_one() {
    let fixture = setup();
    edit(
        &fixture,
        "vocab/core.json",
        r#""surface": "飲む", "kana": "のむ", "zh": ["喝"], "pos": "v5""#,
        r#""surface": "飲む", "kana": "のむ", "zh": ["喝"], "pos": "v1""#,
    );

    let output = cached(&fixture, &["--only", "J05"]);

    assert_eq!(code(&output), EXIT_CONTENT_ERROR, "{}", stdout(&output));
    assert!(
        stdout(&output).contains("J05 [error] vo.nomu"),
        "{}",
        stdout(&output)
    );
}

#[test]
fn verify_reports_forbidden_keys_even_when_they_break_loading() {
    let fixture = setup();
    edit(
        &fixture,
        "vocab/core.json",
        r#""id": "vo.hai", "lesson": "le.l01""#,
        r#""id": "vo.hai", "jmdict_id": "1", "lesson": "le.l01""#,
    );

    let output = cached(&fixture, &["--only", "L01"]);

    assert_eq!(code(&output), EXIT_CONTENT_ERROR, "{}", stdout(&output));
    assert!(
        stdout(&output).contains("L01 [error] vo.hai"),
        "{}",
        stdout(&output)
    );
}

#[test]
fn verify_allow_list_suppresses_and_stale_entries_error() {
    let fixture = setup();
    edit(
        &fixture,
        "vocab/core.json",
        r#""surface": "学生", "kana": "がくせい""#,
        r#""surface": "学生", "kana": "がっせい""#,
    );
    let allow = fixture.content.join("lint/verify_allow.toml");
    fs::write(
        &allow,
        "[[allow]]\nrule = \"J01\"\nitem = \"vo.gakusei\"\nreason = \"測試用覆寫\"\n",
    )
    .expect("寫入");

    let suppressed = cached(&fixture, &["--only", "J01"]);
    assert_eq!(code(&suppressed), EXIT_OK, "{}", stdout(&suppressed));

    edit(
        &fixture,
        "vocab/core.json",
        r#""surface": "学生", "kana": "がっせい""#,
        r#""surface": "学生", "kana": "がくせい""#,
    );
    let stale = cached(&fixture, &["--only", "J01"]);
    assert_eq!(code(&stale), EXIT_CONTENT_ERROR, "{}", stdout(&stale));
    assert!(stdout(&stale).contains("ALLOW"), "{}", stdout(&stale));
}

fn write_allow(fixture: &Run, body: &str) {
    fs::write(fixture.content.join("lint/verify_allow.toml"), body).expect("寫入");
}

const WRONG_GAKUSEI: &str = r#""surface": "学生", "kana": "がっせい""#;
const RIGHT_GAKUSEI: &str = r#""surface": "学生", "kana": "がくせい""#;

#[test]
fn token_level_allow_covers_only_that_token() {
    let fixture = setup();
    edit(&fixture, "vocab/core.json", RIGHT_GAKUSEI, WRONG_GAKUSEI);

    write_allow(
        &fixture,
        "[[allow]]\nrule = \"J01\"\nitem = \"vo.gakusei\"\ntoken = \"学生/がっせい\"\nreason = \"測試\"\n",
    );
    let matched = cached(&fixture, &["--only", "J01"]);
    assert_eq!(code(&matched), EXIT_OK, "{}", stdout(&matched));

    write_allow(
        &fixture,
        "[[allow]]\nrule = \"J01\"\nitem = \"vo.gakusei\"\ntoken = \"学生/ほか\"\nreason = \"測試\"\n",
    );
    let other = cached(&fixture, &["--only", "J01"]);
    assert_eq!(code(&other), EXIT_CONTENT_ERROR, "{}", stdout(&other));
    assert!(
        stdout(&other).contains("J01 [error] vo.gakusei"),
        "{}",
        stdout(&other)
    );
    assert!(
        stdout(&other).contains("ALLOW"),
        "token 對不上應視為失效：{}",
        stdout(&other)
    );
}

#[test]
fn token_less_allow_keeps_covering_every_token_of_the_item() {
    let fixture = setup();
    edit(&fixture, "vocab/core.json", RIGHT_GAKUSEI, WRONG_GAKUSEI);
    write_allow(
        &fixture,
        "[[allow]]\nrule = \"J01\"\nitem = \"vo.gakusei\"\nreason = \"測試\"\n",
    );

    let output = cached(&fixture, &["--only", "J01"]);

    assert_eq!(code(&output), EXIT_OK, "{}", stdout(&output));
}

#[test]
fn lib_allow_must_name_a_token() {
    let fixture = setup();
    write_allow(
        &fixture,
        "[[allow]]\nrule = \"F03\"\nitem = \"lib\"\nreason = \"不該整包放行\"\n",
    );

    let output = cached(&fixture, &["--only", "F03"]);

    assert_eq!(code(&output), EXIT_CONTENT_ERROR, "{}", stdout(&output));
    assert!(stdout(&output).contains("token"), "{}", stdout(&output));
}

#[test]
fn lib_token_allow_is_not_stale_when_the_fonts_are_absent() {
    let fixture = setup();
    write_allow(
        &fixture,
        "[[allow]]\nrule = \"F03\"\nitem = \"lib\"\ntoken = \"暦\"\nreason = \"介面圖示字\"\n",
    );

    let output = cached(&fixture, &["--only", "F03"]);

    assert_eq!(code(&output), EXIT_OK, "{}", stdout(&output));
    assert!(stdout(&output).contains("未執行"), "{}", stdout(&output));
    assert!(!stdout(&output).contains("ALLOW"), "{}", stdout(&output));
}

/// 暦 不在 Noto TC 上游字形內；用打包的子集字型確認 F03 真的回報、token 真的放行。
#[test]
fn lib_token_allow_suppresses_the_glyph_and_goes_stale_with_it() {
    let fixture = setup();
    // 夾具自帶 lib 圖示字的覆寫；這個測試要從沒有覆寫開始
    write_allow(&fixture, "");
    let fonts = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../assets/fonts");
    let lib = fixture.repo.path().join("lib");
    fs::create_dir_all(&lib).expect("建立 lib");
    fs::write(lib.join("glyph.dart"), "const glyph = '暦';\n").expect("寫入");
    let args = [
        "--only",
        "F03",
        "--font-dir",
        fonts.to_str().expect("UTF-8"),
    ];

    let bare = cached(&fixture, &args);
    assert!(
        stdout(&bare).contains("F03 [error] lib token=暦"),
        "{}",
        stdout(&bare)
    );

    write_allow(
        &fixture,
        "[[allow]]\nrule = \"F03\"\nitem = \"lib\"\ntoken = \"暦\"\nreason = \"介面圖示字\"\n",
    );
    let allowed = cached(&fixture, &args);
    assert!(
        !stdout(&allowed).contains("token=暦"),
        "{}",
        stdout(&allowed)
    );
    assert!(!stdout(&allowed).contains("ALLOW"), "{}", stdout(&allowed));

    fs::write(lib.join("glyph.dart"), "const glyph = '';\n").expect("寫入");
    let stale = cached(&fixture, &args);
    assert!(stdout(&stale).contains("ALLOW"), "{}", stdout(&stale));
}

/// reuse §5.4、§9.8、§9.11 的夾具檢查：用打包的子集字型與專案真正的 `lib/`。
/// `lib/` 的圖示字（暦、済、聴）走 Klee，夾具要和 `rust/content/` 一樣帶這三字的覆寫。
#[test]
fn documented_fixture_verify_passes_with_the_bundled_fonts_and_lib() {
    let fixture = setup();
    let project = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..");
    copy_dir(&project.join("lib"), &fixture.repo.path().join("lib"));
    let fonts = project.join("assets/fonts");
    let args = [
        "--only",
        "J04,Z01,Z02,F01,F03,F04",
        "--font-dir",
        fonts.to_str().expect("UTF-8"),
    ];

    let output = cached(&fixture, &args);

    assert_eq!(code(&output), EXIT_OK, "{}", stdout(&output));
    assert!(!stdout(&output).contains("未執行"), "{}", stdout(&output));
}

#[test]
fn verify_requires_a_reason_in_allow_entries() {
    let fixture = setup();
    fs::write(
        fixture.content.join("lint/verify_allow.toml"),
        "[[allow]]\nrule = \"J01\"\nitem = \"vo.gakusei\"\nreason = \"\"\n",
    )
    .expect("寫入");

    let output = cached(&fixture, &["--only", "J01"]);

    assert_eq!(code(&output), EXIT_CONTENT_ERROR, "{}", stdout(&output));
    assert!(stdout(&output).contains("reason"), "{}", stdout(&output));
}

#[test]
fn strict_mode_fails_on_warnings() {
    let fixture = setup();

    let relaxed = cached(&fixture, &["--only", "F01"]);
    let strict = cached(&fixture, &["--only", "F01", "--strict"]);

    assert_eq!(code(&relaxed), EXIT_OK, "{}", stdout(&relaxed));
    assert!(stdout(&relaxed).contains("未執行"), "{}", stdout(&relaxed));
    assert_eq!(code(&strict), EXIT_CONTENT_ERROR, "{}", stdout(&strict));
}

#[test]
fn charset_writes_ja_and_zh_character_files() {
    let fixture = setup();

    let output = run(&fixture, &["charset"]);

    assert_eq!(code(&output), EXIT_OK, "{}", stderr(&output));
    let dir = fixture.repo.path().join("build/verify");
    let ja = fs::read_to_string(dir.join("chars_ja.txt")).expect("chars_ja");
    let zh = fs::read_to_string(dir.join("chars_zh.txt")).expect("chars_zh");
    assert!(ja.contains('私') && ja.contains('わ'), "{ja}");
    assert!(zh.contains('師'), "{zh}");
    assert!(!ja.contains(' '));
}

#[test]
fn coverage_command_reports_c_rules_only() {
    let fixture = setup();
    let cache = fixture.repo.path().join(".verify-cache");
    fs::write(cache.join("jlpt_n5.csv"), "jmdict_seq,kana,kanji\n").expect("寫入");
    fs::write(cache.join("jlpt_n4.csv"), "jmdict_seq,kana,kanji\n").expect("寫入");
    fs::write(cache.join("frequency-subtitles.json"), "{\"entries\": []}").expect("寫入");

    let output = run(
        &fixture,
        &["coverage", "--cache-dir", cache.to_str().expect("UTF-8")],
    );

    assert_eq!(code(&output), EXIT_OK, "{}", stderr(&output));
    assert!(stdout(&output).contains("C01"), "{}", stdout(&output));
    let body = fs::read_to_string(fixture.repo.path().join("build/verify/coverage.md"))
        .expect("coverage.md");
    assert!(body.contains("N5"), "{body}");
}

/// §9.9：真實 JMdict 的整合測試，需要 `tools/verify/fetch_data.sh`。
#[test]
#[ignore = "需要 .verify-cache/ 的真實資料"]
fn real_jmdict_catches_deliberate_mistakes() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..");
    let cache = repo_root.join(".verify-cache");
    assert!(
        cache.join("jmdict-eng.json").exists(),
        "先執行 fetch_data.sh"
    );
    let fixture = setup();
    edit(
        &fixture,
        "vocab/core.json",
        r#""surface": "学生", "kana": "がくせい""#,
        r#""surface": "学校", "kana": "がこう""#,
    );
    edit(
        &fixture,
        "vocab/core.json",
        r#""surface": "飲む", "kana": "のむ", "zh": ["喝"], "pos": "v5""#,
        r#""surface": "飲む", "kana": "のむ", "zh": ["喝"], "pos": "v1""#,
    );

    let output = run(
        &fixture,
        &[
            "verify",
            "--cache-dir",
            cache.to_str().expect("UTF-8"),
            "--only",
            "J01,J05",
        ],
    );

    let text = stdout(&output);
    assert_eq!(code(&output), EXIT_CONTENT_ERROR, "{text}");
    assert!(text.contains("J01 [error] vo.gakusei"), "{text}");
    assert!(text.contains("J05 [error] vo.nomu"), "{text}");
}

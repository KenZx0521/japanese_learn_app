//! `content_tool verify`：B 層流程（reuse-and-verification.md §9.4、§9.6、§9.7）。

use std::collections::{BTreeSet, HashSet};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

use chrono::{NaiveDate, Utc};
use jp_content::disk::read_content_dir;
use jp_content::schema::ContentStage;
use serde::Deserialize;

use crate::charset;
use crate::commands::{write_failed, ToolError};
use crate::data;
use crate::report::{self, count};
use crate::rules::font::{FONTS_OWNER, KLEE_FONTS, LIB_OWNER, NOTO_SANS_FONTS, NOTO_SERIF_FONTS};
use crate::rules::{jlpt, license};
use crate::rules::{Env, Finding, Input, RuleDef, RULES};
use crate::scope::Scope;

const ALLOW_FILE: &str = "lint/verify_allow.toml";
const COVERAGE_SKIP_FILE: &str = "lint/coverage_skip.toml";
const GRAMMAR_CHECKLIST: &str = "tools/verify/grammar_checklist.toml";
const DATA_LOCK: &str = "tools/verify/data.lock.toml";
const OUT_DIR: &str = "build/verify";
const STALE_DAYS: i64 = 90;
const ALLOW_RULE: &str = "ALLOW";
const L01_RULE: &str = "L01";
const DATA_RULE: &str = "DATA";

pub struct VerifyOptions {
    pub content_root: PathBuf,
    pub repo_root: PathBuf,
    pub cache_dir: PathBuf,
    pub font_dir: Option<PathBuf>,
    pub stage: ContentStage,
    pub only: Option<String>,
    pub strict: bool,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct AllowFile {
    #[serde(default)]
    allow: Vec<AllowEntry>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct AllowEntry {
    rule: String,
    item: String,
    /// 有填時只放行這個 token；省略時放行該項目在此規則下的所有 Finding。
    #[serde(default)]
    token: Option<String>,
    reason: String,
}

impl AllowEntry {
    fn covers(&self, finding: &Finding) -> bool {
        self.rule == finding.rule
            && self.item == finding.item
            && self
                .token
                .as_deref()
                .is_none_or(|token| token == finding.token)
    }

    /// 字型檔缺失時 F01／F03／F04 沒有真的比對（回報 `fonts` 警告），不能判為失效。
    fn rule_was_skipped(&self, findings: &[Finding]) -> bool {
        findings
            .iter()
            .any(|finding| finding.rule == self.rule && finding.item == FONTS_OWNER)
    }
}

#[derive(Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct SkipFile {
    #[serde(default)]
    skip: Vec<SkipEntry>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct SkipEntry {
    surface: String,
    kana: String,
    #[allow(dead_code)]
    reason: String,
}

#[derive(Deserialize)]
struct ChecklistFile {
    item: Vec<ChecklistItem>,
}

#[derive(Deserialize)]
struct ChecklistItem {
    id: String,
    level: String,
}

fn select_rules(only: Option<&str>) -> Result<Vec<&'static RuleDef>, ToolError> {
    let Some(only) = only else {
        return Ok(RULES.iter().collect());
    };
    only.split(',')
        .map(str::trim)
        .filter(|id| !id.is_empty())
        .map(|id| {
            RULES
                .iter()
                .find(|rule| rule.id.eq_ignore_ascii_case(id))
                .ok_or_else(|| ToolError::Env(format!("未知的規則：{id}")))
        })
        .collect()
}

fn load_toml<T: for<'de> Deserialize<'de>>(path: &Path) -> Result<Option<T>, ToolError> {
    let text = match fs::read_to_string(path) {
        Ok(text) => text,
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(err) => return Err(ToolError::Env(format!("{}：{err}", path.display()))),
    };
    toml::from_str(&text)
        .map(Some)
        .map_err(|err| ToolError::Env(format!("{} 格式錯誤：{err}", path.display())))
}

fn load_cmap(path: &Path) -> Result<HashSet<char>, ToolError> {
    let bytes =
        fs::read(path).map_err(|err| ToolError::Env(format!("{}：{err}", path.display())))?;
    let face = ttf_parser::Face::parse(&bytes, 0)
        .map_err(|err| ToolError::Env(format!("{} 不是有效字型：{err}", path.display())))?;
    let mut chars = HashSet::new();
    if let Some(cmap) = face.tables().cmap {
        for subtable in cmap.subtables.into_iter().filter(|s| s.is_unicode()) {
            subtable.codepoints(|code| {
                if let Some(ch) = char::from_u32(code) {
                    chars.insert(ch);
                }
            });
        }
    }
    Ok(chars)
}

fn load_fonts(
    font_dir: &Path,
) -> Result<std::collections::HashMap<String, HashSet<char>>, ToolError> {
    let names = KLEE_FONTS
        .iter()
        .chain(&NOTO_SANS_FONTS)
        .chain(&NOTO_SERIF_FONTS);
    let mut fonts = std::collections::HashMap::new();
    for name in names {
        let path = font_dir.join(name);
        if path.exists() {
            fonts.insert((*name).to_owned(), load_cmap(&path)?);
        }
    }
    Ok(fonts)
}

fn load_env(opts: &VerifyOptions) -> Result<Env, ToolError> {
    let font_dir = opts
        .font_dir
        .clone()
        .unwrap_or_else(|| opts.repo_root.join("assets/fonts"));
    let skip: Option<SkipFile> = load_toml(&opts.content_root.join(COVERAGE_SKIP_FILE))?;
    let checklist: Option<ChecklistFile> = load_toml(&opts.repo_root.join(GRAMMAR_CHECKLIST))?;
    Ok(Env {
        repo_root: opts.repo_root.clone(),
        strict: opts.strict,
        fonts: load_fonts(&font_dir)?,
        font_dir,
        coverage_skip: skip
            .unwrap_or_default()
            .skip
            .into_iter()
            .map(|entry| (entry.surface, entry.kana))
            .collect(),
        grammar_checklist: checklist.map(|file| {
            file.item
                .into_iter()
                .map(|item| (item.id, item.level))
                .collect()
        }),
    })
}

/// 單一條目的問題：缺理由、對 `lib` 整包放行、或已失效（§9.6）。
fn allow_entry_problems(
    entry: &AllowEntry,
    findings: &[Finding],
    executed: &HashSet<&str>,
    scope: &Scope,
) -> Vec<Finding> {
    let problem = |message: &str| Finding::error(ALLOW_RULE, &entry.item, &entry.rule, message);
    let mut problems = Vec::new();
    if entry.reason.trim().is_empty() {
        problems.push(problem("verify_allow.toml 必須寫明 reason"));
    }
    let is_lib = entry.item == LIB_OWNER;
    if is_lib && entry.token.is_none() {
        problems.push(problem("lib 的覆寫必須指定 token，不可整個 lib 放行"));
    }
    let in_scope = is_lib || scope.item_ids.contains(&entry.item);
    let ran = executed.contains(entry.rule.as_str()) && !entry.rule_was_skipped(findings);
    if ran && in_scope && !findings.iter().any(|finding| entry.covers(finding)) {
        problems.push(problem("該項目已不再觸發此規則，請刪除這筆覆寫"));
    }
    problems
}

/// 刪除被允許的 Finding；有問題的條目回報為錯誤（§9.6）。
fn apply_allow(
    findings: Vec<Finding>,
    entries: &[AllowEntry],
    executed: &HashSet<&str>,
    scope: &Scope,
) -> Vec<Finding> {
    let problems: Vec<Finding> = entries
        .iter()
        .flat_map(|entry| allow_entry_problems(entry, &findings, executed, scope))
        .collect();
    findings
        .into_iter()
        .filter(|finding| !entries.iter().any(|entry| entry.covers(finding)))
        .chain(problems)
        .collect()
}

/// 開發工具沒有注入時鐘的需要（`SystemClock` 同為 clippy 例外）。
#[allow(clippy::disallowed_methods)]
fn today() -> NaiveDate {
    Utc::now().date_naive()
}

fn lock_staleness(repo_root: &Path) -> Option<Finding> {
    let text = fs::read_to_string(repo_root.join(DATA_LOCK)).ok()?;
    let lock: toml::Table = toml::from_str(&text).ok()?;
    let fetched = lock
        .get("jmdict")?
        .get("fetched")?
        .as_str()?
        .parse::<NaiveDate>()
        .ok()?;
    let age = today().signed_duration_since(fetched).num_days();
    (age > STALE_DAYS).then(|| {
        Finding::warning(
            DATA_RULE,
            DATA_LOCK,
            fetched.to_string(),
            format!("資料鎖定檔已 {age} 天未更新，建議重新取得（§9.5）"),
        )
    })
}

fn coverage_markdown(input: &Input) -> String {
    let mut md = format!("# 涵蓋率報告（{}）\n\n", input.scope.stage.name());
    if let Some(lists) = input.data.jlpt.as_ref() {
        for (label, rows) in [("N5", &lists.n5), ("N4", &lists.n4)] {
            if let Some(cov) = jlpt::list_coverage(input, label, rows) {
                md.push_str(&format!("## {label}：{}/{}\n\n", cov.covered, cov.total));
                for missing in &cov.missing {
                    md.push_str(&format!("- {missing}\n"));
                }
                md.push('\n');
            }
        }
    }
    let subtitles = jlpt::subtitle_missing(input);
    if !subtitles.is_empty() {
        md.push_str(&format!("## 字幕前 500 未收錄（{}）\n\n", subtitles.len()));
        for word in &subtitles {
            md.push_str(&format!("- {word}\n"));
        }
    }
    md
}

/// 執行選中的規則，寫出報告，回傳未被覆寫的 Finding。
fn execute(opts: &VerifyOptions) -> Result<(Vec<Finding>, Vec<&'static str>), ToolError> {
    let rules = select_rules(opts.only.as_deref())?;
    let needs: BTreeSet<_> = crate::rules::needs_of(&rules);
    let missing = data::missing_files(&opts.cache_dir, &needs);
    if !missing.is_empty() {
        return Err(ToolError::Env(data::missing_data_help(
            &opts.cache_dir,
            &missing,
        )));
    }
    let files = read_content_dir(&opts.content_root).map_err(|err| {
        ToolError::Env(format!(
            "無法讀取內容目錄 {}：{err}",
            opts.content_root.display()
        ))
    })?;
    if rules.iter().any(|rule| rule.id == L01_RULE) {
        let forbidden = license::forbidden_keys(&files);
        if !forbidden.is_empty() {
            write_early_report(opts, &forbidden)?;
            return Ok((forbidden, vec![L01_RULE]));
        }
    }
    let scope = Scope::build(files, opts.stage).map_err(ToolError::Content)?;
    let data = data::load(&opts.cache_dir, &needs).map_err(ToolError::Env)?;
    let env = load_env(opts)?;
    let input = Input {
        scope: &scope,
        data: &data,
        env: &env,
    };
    let findings: Vec<Finding> = rules.iter().flat_map(|rule| (rule.run)(&input)).collect();
    let executed: HashSet<&str> = rules.iter().map(|rule| rule.id).collect();
    let allow: Option<AllowFile> = load_toml(&opts.content_root.join(ALLOW_FILE))?;
    let entries = allow.map(|file| file.allow).unwrap_or_default();
    let mut findings = apply_allow(findings, &entries, &executed, &scope);
    findings.extend(lock_staleness(&opts.repo_root));
    findings.sort_by(|a, b| {
        (a.level, a.rule, &a.item, &a.token).cmp(&(b.level, b.rule, &b.item, &b.token))
    });
    write_outputs(opts, &input, &rules, &findings)?;
    Ok((findings, rules.iter().map(|rule| rule.id).collect()))
}

/// `L01` 有違規時內容可能載入不了，只寫 `report.json`。
fn write_early_report(opts: &VerifyOptions, findings: &[Finding]) -> Result<(), ToolError> {
    let dir = opts.repo_root.join(OUT_DIR);
    fs::create_dir_all(&dir).map_err(write_failed)?;
    report::write_json(
        &dir.join(report::REPORT_FILE),
        opts.stage.name(),
        &[L01_RULE],
        findings,
    )
    .map_err(write_failed)
}

fn write_outputs(
    opts: &VerifyOptions,
    input: &Input,
    rules: &[&RuleDef],
    findings: &[Finding],
) -> Result<(), ToolError> {
    let dir = opts.repo_root.join(OUT_DIR);
    fs::create_dir_all(&dir).map_err(write_failed)?;
    let ids: Vec<&str> = rules.iter().map(|rule| rule.id).collect();
    report::write_json(
        &dir.join(report::REPORT_FILE),
        opts.stage.name(),
        &ids,
        findings,
    )
    .map_err(write_failed)?;
    report::write_coverage_md(&dir.join(report::COVERAGE_FILE), &coverage_markdown(input))
        .map_err(write_failed)
}

pub fn run_verify(opts: &VerifyOptions, out: &mut impl Write) -> Result<(), ToolError> {
    let (findings, rules) = execute(opts)?;
    for finding in &findings {
        writeln!(out, "{finding}").map_err(write_failed)?;
    }
    let counts = count(&findings);
    writeln!(
        out,
        "verify（{}）：規則 {} 條，{} 個錯誤、{} 個警告、{} 則報告",
        opts.stage.name(),
        rules.len(),
        counts.errors,
        counts.warnings,
        counts.infos
    )
    .map_err(write_failed)?;
    let failed = counts.errors > 0 || (opts.strict && counts.warnings > 0);
    if failed {
        return Err(ToolError::Content(format!(
            "{} 個錯誤、{} 個警告",
            counts.errors, counts.warnings
        )));
    }
    Ok(())
}

pub fn run_charset(
    content_root: &Path,
    repo_root: &Path,
    stage: ContentStage,
    out: &mut impl Write,
) -> Result<(), ToolError> {
    let files = read_content_dir(content_root).map_err(|err| {
        ToolError::Env(format!(
            "無法讀取內容目錄 {}：{err}",
            content_root.display()
        ))
    })?;
    let scope = Scope::build(files, stage).map_err(ToolError::Content)?;
    let dir = repo_root.join(OUT_DIR);
    let (ja, zh) = charset::write_charsets(&scope, &dir).map_err(write_failed)?;
    writeln!(
        out,
        "charset（{}）：{} 字（{}）、{} 字（{}）",
        stage.name(),
        ja,
        charset::JA_OUTPUT,
        zh,
        charset::ZH_OUTPUT
    )
    .map_err(write_failed)
}

/// C01–C04 的規則 ID（`coverage` 子指令）。
pub const COVERAGE_RULES: &str = "C01,C02,C03,C04";

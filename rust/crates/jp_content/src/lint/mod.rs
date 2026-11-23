//! 內容 lint：curriculum.md §13 的 R01–R25、rust-core.md §11.3 的 RC1–RC11。
//! R13、R14、R21、R22、R23 已停用，編號留空不重排。
//!
//! `run_lint` 由整合測試與 `content_tool lint` 共用，規則本身不依賴環境變數，
//! `LintLists` 由呼叫端從 `rust/content/lint/*.txt` 載入。

mod context;
mod counts;
mod coverage;
mod dialogues;
mod drills;
mod identity;
mod kana_gate;
mod keys;
mod lists;
mod morphs;
mod order;
mod simulate;
mod spaced;
mod text;

use std::fmt;

use crate::filter::filter_stage;
use crate::raw::{parse_files, RawContent};
use crate::schema::ContentStage;
use crate::validate::{validate, Issue};

pub use lists::LintLists;

use context::Ctx;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Level {
    Error,
    Warning,
}

/// 一筆違規。錯誤訊息須列出項目 ID、違規 token、首次教學課（curriculum.md §13）。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Finding {
    pub rule: &'static str,
    pub level: Level,
    pub item: String,
    pub token: String,
    /// token 首次教學的課；與課無關時為 `None`，尚未教過時為 `未教學`。
    pub first_taught: Option<String>,
    pub message: String,
}

impl Finding {
    pub(crate) fn error(
        rule: &'static str,
        item: impl Into<String>,
        token: impl Into<String>,
        message: impl Into<String>,
    ) -> Self {
        Self {
            rule,
            level: Level::Error,
            item: item.into(),
            token: token.into(),
            first_taught: None,
            message: message.into(),
        }
    }

    pub(crate) fn warning(
        rule: &'static str,
        item: impl Into<String>,
        token: impl Into<String>,
        message: impl Into<String>,
    ) -> Self {
        Self {
            level: Level::Warning,
            ..Self::error(rule, item, token, message)
        }
    }

    pub(crate) fn first_taught(mut self, lesson: impl Into<String>) -> Self {
        self.first_taught = Some(lesson.into());
        self
    }
}

impl fmt::Display for Finding {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let level = match self.level {
            Level::Error => "error",
            Level::Warning => "warning",
        };
        write!(f, "{} [{level}] {}", self.rule, self.item)?;
        if !self.token.is_empty() {
            write!(f, " token={}", self.token)?;
        }
        if let Some(lesson) = &self.first_taught {
            write!(f, " 首次教學={lesson}")?;
        }
        write!(f, "：{}", self.message)
    }
}

/// lint 結果，依規則與項目排序，輸出穩定。
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct LintReport {
    findings: Vec<Finding>,
}

impl LintReport {
    pub fn findings(&self) -> &[Finding] {
        &self.findings
    }

    pub fn errors(&self) -> impl Iterator<Item = &Finding> {
        self.findings.iter().filter(|f| f.level == Level::Error)
    }

    pub fn warnings(&self) -> impl Iterator<Item = &Finding> {
        self.findings.iter().filter(|f| f.level == Level::Warning)
    }

    pub fn has_errors(&self) -> bool {
        self.errors().next().is_some()
    }

    pub fn of_rule<'r>(&'r self, rule: &'r str) -> impl Iterator<Item = &'r Finding> {
        self.findings.iter().filter(move |f| f.rule == rule)
    }
}

fn issue_to_finding(issue: Issue) -> Finding {
    Finding::error(issue.rule, issue.item, issue.token, issue.detail)
}

/// 檢查 `files` 在 `stage` 範圍內的內容。
pub fn run_lint(files: &[(&str, &str)], stage: ContentStage, lists: &LintLists) -> LintReport {
    let forbidden = keys::forbidden_keys(files);
    if !forbidden.is_empty() {
        return finish(forbidden);
    }
    let raw = match parse_files(files) {
        Ok(raw) => raw,
        Err(err) => return finish(vec![Finding::error("LOAD", "-", "", err.to_string())]),
    };
    finish(lint_parsed(&raw, files, stage, lists))
}

fn lint_parsed(
    raw: &RawContent,
    files: &[(&str, &str)],
    stage: ContentStage,
    lists: &LintLists,
) -> Vec<Finding> {
    let filtered = filter_stage(raw.clone(), stage);
    let mut findings: Vec<Finding> = validate(&filtered, raw)
        .into_iter()
        .map(issue_to_finding)
        .collect();
    let ctx = Ctx::build(&filtered, raw, stage, lists);
    findings.extend(identity::check(&ctx));
    findings.extend(order::check(&ctx));
    findings.extend(spaced::check(&ctx));
    findings.extend(kana_gate::check(&ctx));
    findings.extend(morphs::check(&ctx));
    findings.extend(coverage::check(&ctx));
    findings.extend(simulate::check_r18(&ctx));
    findings.extend(drills::check(&ctx));
    findings.extend(text::check_structured(&ctx));
    findings.extend(text::check_fields(files, &ctx));
    findings.extend(counts::check_r17(&ctx));
    findings.extend(dialogues::check_rc11(&ctx));
    findings
}

fn finish(mut findings: Vec<Finding>) -> LintReport {
    findings.sort_by(|a, b| (a.rule, &a.item, &a.token).cmp(&(b.rule, &b.item, &b.token)));
    LintReport { findings }
}

/// `content_tool stats`：解析、過濾後回傳各類別的筆數與當前階段目標。
pub fn stage_stats(
    files: &[(&str, &str)],
    stage: ContentStage,
) -> Result<Vec<(&'static str, usize, usize)>, crate::ContentError> {
    let raw = parse_files(files)?;
    Ok(counts::stage_counts(&filter_stage(raw, stage), stage))
}

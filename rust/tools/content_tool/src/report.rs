//! 終端、`build/verify/report.json`、`coverage.md`（reuse-and-verification.md §9.7）。

use std::fs;
use std::path::Path;

use serde_json::json;

use crate::rules::{Finding, Level};

pub const REPORT_FILE: &str = "report.json";
pub const COVERAGE_FILE: &str = "coverage.md";

pub struct Counts {
    pub errors: usize,
    pub warnings: usize,
    pub infos: usize,
}

pub fn count(findings: &[Finding]) -> Counts {
    let of = |level: Level| findings.iter().filter(|f| f.level == level).count();
    Counts {
        errors: of(Level::Error),
        warnings: of(Level::Warning),
        infos: of(Level::Info),
    }
}

pub fn write_json(
    path: &Path,
    stage: &str,
    rules: &[&str],
    findings: &[Finding],
) -> std::io::Result<()> {
    let counts = count(findings);
    let body = json!({
        "stage": stage,
        "rules": rules,
        "counts": {
            "errors": counts.errors,
            "warnings": counts.warnings,
            "infos": counts.infos,
        },
        "findings": findings
            .iter()
            .map(|finding| json!({
                "rule": finding.rule,
                "level": finding.level.name(),
                "item": finding.item,
                "token": finding.token,
                "message": finding.message,
            }))
            .collect::<Vec<_>>(),
    });
    let pretty = serde_json::to_string_pretty(&body).expect("Finding 只含字串與數字");
    fs::write(path, pretty)
}

/// `coverage.md` 含 JLPT 清單內容，只放 `build/verify/`（gitignore），不得公開。
pub fn write_coverage_md(path: &Path, body: &str) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, body)
}

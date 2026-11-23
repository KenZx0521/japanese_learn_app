//! 各子指令的實作。

use std::io::Write;
use std::path::Path;

use jp_content::disk::{borrow_files, read_content_dir, ContentFiles};
use jp_content::lint::{stage_stats, LintLists};
use jp_content::load_content;
use jp_content::schema::ContentStage;

use crate::available::{rows_up_to, HEADER};

#[derive(Debug)]
pub enum ToolError {
    /// 結束代碼 1。
    Content(String),
    /// 結束代碼 2。
    Env(String),
}

fn read_files(root: &Path) -> Result<ContentFiles, ToolError> {
    read_content_dir(root)
        .map_err(|err| ToolError::Env(format!("無法讀取內容目錄 {}：{err}", root.display())))
}

pub fn write_failed(err: std::io::Error) -> ToolError {
    ToolError::Env(format!("無法寫入輸出：{err}"))
}

pub fn run_available(
    root: &Path,
    stage: ContentStage,
    lesson: &str,
    out: &mut impl Write,
) -> Result<(), ToolError> {
    let files = read_files(root)?;
    let store = load_content(&borrow_files(&files), stage)
        .map_err(|err| ToolError::Content(err.to_string()))?;
    let position = store
        .lesson_pos(lesson)
        .ok_or_else(|| ToolError::Env(format!("找不到課 {lesson}（階段 {}）", stage.name())))?;
    writeln!(out, "{HEADER}").map_err(write_failed)?;
    for row in rows_up_to(&store, position) {
        writeln!(out, "{}", row.tsv()).map_err(write_failed)?;
    }
    Ok(())
}

pub fn run_lint(root: &Path, stage: ContentStage, out: &mut impl Write) -> Result<(), ToolError> {
    let files = read_files(root)?;
    let lists = LintLists::from_content_root(root)
        .map_err(|err| ToolError::Env(format!("無法讀取 lint 清單：{err}")))?;
    let report = jp_content::lint::run_lint(&borrow_files(&files), stage, &lists);
    for finding in report.findings() {
        writeln!(out, "{finding}").map_err(write_failed)?;
    }
    let errors = report.errors().count();
    let warnings = report.warnings().count();
    writeln!(
        out,
        "lint（{}）：{errors} 個錯誤、{warnings} 個警告",
        stage.name()
    )
    .map_err(write_failed)?;
    if errors > 0 {
        return Err(ToolError::Content(format!("{errors} 個內容錯誤")));
    }
    Ok(())
}

pub fn run_stats(root: &Path, stage: ContentStage, out: &mut impl Write) -> Result<(), ToolError> {
    let files = read_files(root)?;
    let rows = stage_stats(&borrow_files(&files), stage)
        .map_err(|err| ToolError::Content(err.to_string()))?;
    writeln!(out, "category\tcount\ttarget").map_err(write_failed)?;
    for (label, count, target) in rows {
        writeln!(out, "{label}\t{count}\t{target}").map_err(write_failed)?;
    }
    Ok(())
}

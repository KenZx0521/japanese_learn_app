//! 啟動流程（rust-core.md §3.4）。

use crate::error::ContentError;
use crate::filter::{filter_stage, prune_soft_refs};
use crate::manifest::{CONTENT_FILES, CONTENT_STAGE_NAME};
use crate::raw::parse_files;
use crate::schema::ContentStage;
use crate::store::ContentStore;
use crate::validate::validate;

/// 解析、過濾、驗證後建立索引。階段過濾在驗證前，軟引用修剪在驗證後。
pub fn load_content(
    files: &[(&str, &str)],
    stage: ContentStage,
) -> Result<ContentStore, ContentError> {
    let raw = parse_files(files)?;
    let filtered = filter_stage(raw.clone(), stage);
    if let Some(issue) = validate(&filtered, &raw).into_iter().next() {
        return Err(ContentError::corrupt(
            issue.item,
            format!("{} {}（{}）", issue.rule, issue.detail, issue.token),
        ));
    }
    ContentStore::build(prune_soft_refs(filtered), stage)
}

/// 嵌入的內容與建置時的 `CONTENT_STAGE`。
pub fn load_embedded() -> Result<ContentStore, ContentError> {
    let stage = ContentStage::parse(CONTENT_STAGE_NAME).expect("build.rs 已驗證 CONTENT_STAGE");
    load_content(CONTENT_FILES, stage)
}

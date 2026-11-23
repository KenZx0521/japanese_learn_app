//! 從磁碟讀內容（工具與測試用，不進 App）。

use std::fs;
use std::path::{Path, PathBuf};

use crate::schema::ContentStage;

/// 相對路徑與檔案內容。
pub type ContentFiles = Vec<(String, String)>;

fn collect_json(dir: &Path, out: &mut Vec<PathBuf>) -> std::io::Result<()> {
    for entry in fs::read_dir(dir)? {
        let path = entry?.path();
        if path.is_dir() {
            collect_json(&path, out)?;
        } else if path.extension().is_some_and(|ext| ext == "json") {
            out.push(path);
        }
    }
    Ok(())
}

/// 讀 `root` 下全部 `.json`；路徑分隔符統一為 `/`。
pub fn read_content_dir(root: &Path) -> std::io::Result<ContentFiles> {
    let mut paths = Vec::new();
    collect_json(root, &mut paths)?;
    paths.sort();
    paths
        .into_iter()
        .map(|path| {
            let relative = path
                .strip_prefix(root)
                .map_err(|err| std::io::Error::other(err.to_string()))?
                .to_string_lossy()
                .replace('\\', "/");
            Ok((relative, fs::read_to_string(&path)?))
        })
        .collect()
}

pub fn borrow_files(files: &ContentFiles) -> Vec<(&str, &str)> {
    files
        .iter()
        .map(|(path, text)| (path.as_str(), text.as_str()))
        .collect()
}

/// 未指定階段時的預設值；`build.rs` 的 `DEFAULT_STAGE` 必須一致。
pub const DEFAULT_STAGE: ContentStage = ContentStage::P0;

/// `explicit` 優先，否則取環境變數 `CONTENT_STAGE`，預設 [`DEFAULT_STAGE`]。無效值回 `Err(該值)`。
pub fn resolve_stage(explicit: Option<&str>) -> Result<ContentStage, String> {
    resolve_stage_with(explicit, std::env::var("CONTENT_STAGE").ok())
}

fn resolve_stage_with(explicit: Option<&str>, env: Option<String>) -> Result<ContentStage, String> {
    match explicit.map(str::to_owned).or(env) {
        Some(name) => ContentStage::parse(&name).ok_or(name),
        None => Ok(DEFAULT_STAGE),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn explicit_stage_wins_over_environment() {
        assert_eq!(
            resolve_stage_with(Some("full"), Some("p0a".to_owned())),
            Ok(ContentStage::Full)
        );
    }

    #[test]
    fn environment_stage_used_when_not_explicit() {
        assert_eq!(
            resolve_stage_with(None, Some("p0a".to_owned())),
            Ok(ContentStage::P0a)
        );
    }

    #[test]
    fn default_stage_is_p0() {
        assert_eq!(resolve_stage_with(None, None), Ok(ContentStage::P0));
        assert_eq!(DEFAULT_STAGE, ContentStage::P0);
    }

    #[test]
    fn invalid_stage_returns_the_value() {
        assert_eq!(
            resolve_stage_with(None, Some("bogus".to_owned())),
            Err("bogus".to_owned())
        );
    }

    #[test]
    fn build_default_matches_runtime_default() {
        // build.rs 在沒有 CONTENT_STAGE 時嵌入的階段必須和執行期預設一致。
        if std::env::var("CONTENT_STAGE").is_err() {
            assert_eq!(crate::manifest::CONTENT_STAGE_NAME, DEFAULT_STAGE.name());
        }
    }
}

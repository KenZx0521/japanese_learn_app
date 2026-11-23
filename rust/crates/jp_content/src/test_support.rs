//! 共用測試夾具。下游 crate 在 dev-dependencies 開啟 `features = ["test-support"]`。
//!
//! 涵蓋全部內容類別（含對話、12 種演練變體、筆記），課序為
//! K01–K19 → L01 → KK01 → L02 → L03 → KK07 → KK08 → L08（p0）→ L21（p0）→ L31（full）。

use std::path::{Path, PathBuf};

use crate::disk::{borrow_files, read_content_dir, ContentFiles};
use crate::load::load_content;
use crate::schema::ContentStage;
use crate::store::ContentStore;

/// 與 `load_content` 參數相同的擁有權版本。
pub type FixtureFiles = ContentFiles;

/// `crates/jp_content/tests/fixtures/`。
pub fn fixtures_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

/// 完整夾具的根目錄，亦可傳給 `LintLists::from_content_root`。
pub fn full_fixture_dir() -> PathBuf {
    fixtures_dir().join("full")
}

/// 完整夾具的檔案清單（不含 `lint/*.txt`）。
pub fn fixture_files() -> FixtureFiles {
    read_content_dir(&full_fixture_dir()).expect("夾具目錄應可讀取")
}

/// 完整夾具疊加 `lint_bad/<case>/`：同路徑取代，新路徑新增。
pub fn fixture_files_with_overlay(case: &str) -> FixtureFiles {
    let overlay = read_content_dir(&fixtures_dir().join("lint_bad").join(case))
        .expect("overlay 目錄應可讀取");
    let mut merged: FixtureFiles = fixture_files()
        .into_iter()
        .filter(|(path, _)| overlay.iter().all(|(over, _)| over != path))
        .collect();
    merged.extend(overlay);
    merged
}

/// 載入完整夾具；失敗代表夾具本身有問題。
pub fn load_full_fixture(stage: ContentStage) -> ContentStore {
    let files = fixture_files();
    load_content(&borrow_files(&files), stage).expect("完整夾具應可載入")
}

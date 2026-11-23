//! 走訪 `rust/content/**/*.json` 生成內容清單，並把 `CONTENT_STAGE` 寫成常數（rust-core.md §3.1）。

use std::{
    env,
    fmt::Write as _,
    fs,
    path::{Path, PathBuf},
};

const CONTENT_DIR: &str = "../../content";
const STAGE_ENV: &str = "CONTENT_STAGE";
/// 必須和 `jp_content::disk::DEFAULT_STAGE` 一致（disk.rs 有測試）。
const DEFAULT_STAGE: &str = "p0";
const VALID_STAGES: [&str; 3] = ["p0a", "p0", "full"];

fn collect(dir: &Path, out: &mut Vec<PathBuf>) -> std::io::Result<()> {
    for entry in fs::read_dir(dir)? {
        let path = entry?.path();
        if path.is_dir() {
            collect(&path, out)?;
        } else if path.extension().is_some_and(|e| e == "json") {
            out.push(path);
        }
    }
    Ok(())
}

fn render_manifest(
    stage: &str,
    root: &Path,
    files: &[PathBuf],
) -> Result<String, Box<dyn std::error::Error>> {
    let mut src = format!("pub const CONTENT_STAGE_NAME: &str = {stage:?};\n");
    src.push_str("pub const CONTENT_FILES: &[(&str, &str)] = &[\n");
    for file in files {
        let rel = file
            .strip_prefix(root)?
            .to_string_lossy()
            .replace('\\', "/");
        writeln!(
            src,
            "    ({rel:?}, include_str!({:?})),",
            file.to_string_lossy()
        )?;
    }
    src.push_str("];\n");
    Ok(src)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed={CONTENT_DIR}");
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-env-changed={STAGE_ENV}");

    let stage = env::var(STAGE_ENV).unwrap_or_else(|_| DEFAULT_STAGE.to_string());
    if !VALID_STAGES.contains(&stage.as_str()) {
        return Err(format!("{STAGE_ENV} must be p0a, p0 or full, got {stage}").into());
    }

    let root = PathBuf::from(env::var("CARGO_MANIFEST_DIR")?)
        .join(CONTENT_DIR)
        .canonicalize()?;
    let mut files = vec![];
    collect(&root, &mut files)?;
    files.sort();

    let src = render_manifest(&stage, &root, &files)?;
    fs::write(
        PathBuf::from(env::var("OUT_DIR")?).join("content_manifest.rs"),
        src,
    )?;
    Ok(())
}

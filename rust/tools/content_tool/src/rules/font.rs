//! 字型：F01–F05（reuse-and-verification.md §9.2）。

use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::fs;
use std::path::Path;

use crate::charset;

use super::{Finding, Input};

pub const KLEE_FONTS: [&str; 2] = ["KleeOne-Regular.subset.ttf", "KleeOne-SemiBold.subset.ttf"];
pub const NOTO_SANS_FONTS: [&str; 2] = [
    "NotoSansTC-Regular.subset.ttf",
    "NotoSansTC-Bold.subset.ttf",
];
pub const NOTO_SERIF_FONTS: [&str; 1] = ["NotoSerifTC-ExtraBold.subset.ttf"];

/// Finding 的 `item`：`lib/` 介面用字。
pub const LIB_OWNER: &str = "lib";
/// Finding 的 `item`：字型檔缺失，規則沒有真的比對。
pub const FONTS_OWNER: &str = "fonts";

const ASCII_START: u8 = 0x20;
const ASCII_END: u8 = 0x7E;
const MB: u64 = 1024 * 1024;
const FONT_BUDGET_MB: u64 = 12;
const SUBSET_SUFFIX: &str = ".subset.ttf";

/// `(字型檔名前綴, OFL 檔名, 授權頁家族名)`。
pub const FONT_FAMILIES: [(&str, &str, &str); 3] = [
    ("KleeOne", "OFL-KleeOne.txt", "Klee One"),
    ("NotoSansTC", "OFL-NotoSansTC.txt", "Noto Sans TC"),
    ("NotoSerifTC", "OFL-NotoSerifTC.txt", "Noto Serif TC"),
];

/// 單一 cmap 集合是否涵蓋；缺字型回 `None`（呼叫端標未執行）。
fn check_cmaps(
    rule: &'static str,
    input: &Input,
    required: &[&str],
    chars: &BTreeMap<char, String>,
) -> Vec<Finding> {
    let missing: Vec<&str> = required
        .iter()
        .copied()
        .filter(|name| !input.env.fonts.contains_key(*name))
        .collect();
    let mut findings = Vec::new();
    if !missing.is_empty() {
        findings.push(Finding::warning(
            rule,
            FONTS_OWNER,
            missing.join(","),
            format!(
                "{rule} 未執行：{} 尚無這些字型檔，打包字型後會自動檢查",
                input.env.font_dir.display()
            ),
        ));
    }
    let loaded: Vec<(&str, &HashSet<char>)> = required
        .iter()
        .filter_map(|name| input.env.fonts.get(*name).map(|cmap| (*name, cmap)))
        .collect();
    for (ch, owner) in chars {
        for (name, cmap) in &loaded {
            if !cmap.contains(ch) {
                findings.push(Finding::error(
                    rule,
                    owner,
                    ch.to_string(),
                    format!("{name} 缺字；改寫內容，不得 fallback"),
                ));
            }
        }
    }
    findings
}

pub fn f01(input: &Input) -> Vec<Finding> {
    check_cmaps("F01", input, &KLEE_FONTS, &charset::ja_chars(input.scope))
}

fn ascii_chars() -> BTreeMap<char, String> {
    (ASCII_START..=ASCII_END)
        .map(|byte| (byte as char, "ASCII".to_owned()))
        .collect()
}

fn lib_chars(input: &Input) -> BTreeMap<char, String> {
    charset::lib_chars(&input.env.repo_root)
        .into_iter()
        .map(|ch| (ch, LIB_OWNER.to_owned()))
        .collect()
}

pub fn f03(input: &Input) -> Vec<Finding> {
    // 內容最後寫入：同一個字兩邊都有時歸給內容項目，`lib` 的 token 放行才蓋不到內容缺字
    let mut chars = lib_chars(input);
    chars.extend(ascii_chars());
    chars.extend(charset::zh_chars(input.scope));
    check_cmaps("F03", input, &NOTO_SANS_FONTS, &chars)
}

pub fn f04(input: &Input) -> Vec<Finding> {
    let mut chars = lib_chars(input);
    chars.extend(ascii_chars());
    check_cmaps("F04", input, &NOTO_SERIF_FONTS, &chars)
}

/// `pubspec.yaml` 引用的字型檔名（已略過註解行）。
pub fn bundled_font_assets(repo_root: &Path) -> Vec<String> {
    let Ok(pubspec) = fs::read_to_string(repo_root.join("pubspec.yaml")) else {
        return Vec::new();
    };
    pubspec
        .lines()
        .map(str::trim)
        .filter(|line| !line.starts_with('#'))
        .filter_map(|line| line.strip_prefix("- asset:"))
        .map(str::trim)
        .filter(|path| path.ends_with(".ttf"))
        .map(|path| path.rsplit('/').next().unwrap_or(path).to_owned())
        .collect()
}

pub fn f02(input: &Input) -> Vec<Finding> {
    let licenses = input.env.font_dir.join("licenses");
    let mut required: BTreeSet<(&str, &str)> = BTreeSet::new();
    for asset in bundled_font_assets(&input.env.repo_root) {
        if let Some((_, ofl, _)) = FONT_FAMILIES
            .iter()
            .find(|(prefix, ..)| asset.starts_with(prefix))
        {
            required.insert((ofl, "assets/fonts/licenses"));
        }
    }
    required
        .into_iter()
        .filter(|(ofl, _)| !licenses.join(ofl).exists())
        .map(|(ofl, dir)| {
            Finding::error(
                "F02",
                "pubspec.yaml",
                ofl,
                format!("{dir}/{ofl} 不存在；打包字型必須附上 OFL 全文"),
            )
        })
        .collect()
}

pub fn f05(input: &Input) -> Vec<Finding> {
    let Ok(entries) = fs::read_dir(&input.env.font_dir) else {
        return Vec::new();
    };
    let total: u64 = entries
        .flatten()
        .filter(|entry| entry.file_name().to_string_lossy().ends_with(SUBSET_SUFFIX))
        .filter_map(|entry| entry.metadata().ok())
        .map(|meta| meta.len())
        .sum();
    if total > FONT_BUDGET_MB * MB {
        vec![Finding::warning(
            "F05",
            "assets/fonts",
            format!("{} MB", total / MB),
            format!("字型子集合計超過 {FONT_BUDGET_MB} MB 預算"),
        )]
    } else {
        Vec::new()
    }
}

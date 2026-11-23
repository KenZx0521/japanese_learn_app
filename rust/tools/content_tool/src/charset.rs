//! `content_tool charset`：輸出字型子集用的字元集（reuse-and-verification.md §5.3）。

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;

use jp_lang::kana::Word;

use crate::scope::Scope;

pub const JA_OUTPUT: &str = "chars_ja.txt";
pub const ZH_OUTPUT: &str = "chars_zh.txt";

const LIB_DIR: &str = "lib";
const GENERATED_DIR: &str = "src/rust";
const DART_EXTENSION: &str = "dart";

fn add_chars(chars: &mut BTreeMap<char, String>, owner: &str, text: &str) {
    for ch in text.chars().filter(|c| !c.is_whitespace()) {
        chars.entry(ch).or_insert_with(|| owner.to_owned());
    }
}

/// F01 定義的日文內容（字元 → 首次出現的項目）。
pub fn ja_chars(scope: &Scope) -> BTreeMap<char, String> {
    let mut chars = BTreeMap::new();
    scope.visit_ja_fields(|owner, _key, text| add_chars(&mut chars, owner, text));
    for site in &scope.sites {
        for word in &site.words {
            match word {
                Word::Punct(punct) => add_chars(&mut chars, &site.owner, punct),
                Word::Morphs(morphs) => {
                    for morph in morphs {
                        add_chars(&mut chars, &site.owner, &morph.surface);
                        add_chars(&mut chars, &site.owner, &morph.kana);
                    }
                }
            }
        }
    }
    scope.visit_zh_fields(|field| {
        for ja in &field.ja {
            add_chars(&mut chars, field.owner, ja);
        }
    });
    chars
}

/// 中文欄位 `{ja:…}` 以外的字元。
pub fn zh_chars(scope: &Scope) -> BTreeMap<char, String> {
    let mut chars = BTreeMap::new();
    scope.visit_zh_fields(|field| add_chars(&mut chars, field.owner, &field.zh));
    chars
}

fn is_lib_char(c: char) -> bool {
    matches!(c,
        '\u{3000}'..='\u{303F}' | '\u{3400}'..='\u{4DBF}' | '\u{4E00}'..='\u{9FFF}' | '\u{FF00}'..='\u{FFEF}')
}

fn collect_dart_files(dir: &Path, out: &mut Vec<std::path::PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for path in entries.flatten().map(|entry| entry.path()) {
        if path.is_dir() {
            if !path.to_string_lossy().ends_with(GENERATED_DIR) {
                collect_dart_files(&path, out);
            }
        } else if path.extension().is_some_and(|ext| ext == DART_EXTENSION) {
            out.push(path);
        }
    }
}

/// `lib/**/*.dart` 去掉 `//` 註解後的 CJK 漢字與全形標點，排除生成碼（§5.3）。
pub fn lib_chars(repo_root: &Path) -> BTreeSet<char> {
    let mut files = Vec::new();
    collect_dart_files(&repo_root.join(LIB_DIR), &mut files);
    let mut chars = BTreeSet::new();
    for file in files {
        let Ok(text) = fs::read_to_string(&file) else {
            continue;
        };
        for line in text.lines() {
            let code = line.split("//").next().unwrap_or_default();
            chars.extend(code.chars().filter(|c| is_lib_char(*c)));
        }
    }
    chars
}

fn write_chars(path: &Path, chars: impl Iterator<Item = char>) -> std::io::Result<()> {
    let text: String = chars.collect();
    fs::write(path, text)
}

/// 寫入 `<out_dir>/chars_ja.txt`、`chars_zh.txt`，回傳字元數。
pub fn write_charsets(scope: &Scope, out_dir: &Path) -> std::io::Result<(usize, usize)> {
    fs::create_dir_all(out_dir)?;
    let ja = ja_chars(scope);
    let zh = zh_chars(scope);
    write_chars(&out_dir.join(JA_OUTPUT), ja.keys().copied())?;
    write_chars(&out_dir.join(ZH_OUTPUT), zh.keys().copied())?;
    Ok((ja.len(), zh.len()))
}

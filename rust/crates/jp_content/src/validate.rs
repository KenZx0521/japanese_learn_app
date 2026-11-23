//! 啟動驗證：防止執行期 panic 的存在性檢查（R01、R02、R03）。其他 lint 由 `cargo test` 負責。

use std::collections::HashSet;

use jp_lang::kana::{reading_mode_of, to_romaji_reading, Word};

use crate::raw::{item_ids, RawContent};
use crate::refs::{reference_sites, t_sites, Strength};
use crate::sentence::{parse_t, TParseError};
use crate::store::ItemKind;

const REF_PREFIXES: [&str; 2] = ["vo.", "gr."];

/// 一筆檢查結果。`rule` 為 curriculum.md §13 的規則代碼。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Issue {
    pub rule: &'static str,
    pub item: String,
    pub token: String,
    pub detail: String,
}

/// `[a-z]{2}\.[a-z0-9_]+(\.[a-z0-9_]+)*`（curriculum.md §12.1）。
pub fn is_valid_id(id: &str) -> bool {
    let Some((prefix, rest)) = id.split_once('.') else {
        return false;
    };
    let is_prefix = prefix.len() == 2 && prefix.bytes().all(|b| b.is_ascii_lowercase());
    is_prefix
        && rest.split('.').all(|segment| {
            !segment.is_empty()
                && segment
                    .bytes()
                    .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_')
        })
}

fn id_issues(ids: &[(&str, ItemKind)]) -> Vec<Issue> {
    let mut seen: HashSet<&str> = HashSet::new();
    let mut issues = Vec::new();
    for (id, _) in ids {
        if !is_valid_id(id) {
            issues.push(Issue {
                rule: "R01",
                item: (*id).to_owned(),
                token: (*id).to_owned(),
                detail: "ID 不符合命名規則".to_owned(),
            });
        }
        if !seen.insert(id) {
            issues.push(Issue {
                rule: "R01",
                item: (*id).to_owned(),
                token: (*id).to_owned(),
                detail: "ID 重複".to_owned(),
            });
        }
    }
    issues
}

fn reference_issues(raw: &RawContent, all: &HashSet<&str>, present: &HashSet<&str>) -> Vec<Issue> {
    reference_sites(raw)
        .into_iter()
        .filter(|site| match site.strength {
            Strength::Hard => !present.contains(site.target),
            Strength::Soft => !all.contains(site.target),
        })
        .map(|site| Issue {
            rule: "R03",
            item: site.owner.to_owned(),
            token: site.target.to_owned(),
            detail: format!("{} 指向不存在的項目", site.field),
        })
        .collect()
}

fn parse_issue(item: &str, error: &TParseError) -> Issue {
    let (rule, token) = match error {
        TParseError::MissingKana { surface } => ("R08", surface.clone()),
        TParseError::MissingRef { token } | TParseError::BadRef { token } => ("R02", token.clone()),
        TParseError::Empty => ("R02", String::new()),
        TParseError::Romaji(err) => ("R02", err.to_string()),
    };
    Issue {
        rule,
        item: item.to_owned(),
        token,
        detail: error.to_string(),
    }
}

fn t_ref_issues(item: &str, words: &[Word], present: &HashSet<&str>) -> Vec<Issue> {
    words
        .iter()
        .filter_map(|word| match word {
            Word::Morphs(morphs) => Some(morphs),
            Word::Punct(_) => None,
        })
        .flatten()
        .filter(|m| {
            REF_PREFIXES.iter().any(|p| m.r#ref.starts_with(p))
                && !present.contains(m.r#ref.as_str())
        })
        .map(|m| Issue {
            rule: "R03",
            item: item.to_owned(),
            token: m.r#ref.clone(),
            detail: format!("t 內的 ref {} 不存在", m.r#ref),
        })
        .collect()
}

fn t_issues(raw: &RawContent, present: &HashSet<&str>) -> Vec<Issue> {
    let (sites, frame_issues) = t_sites(raw);
    let mut issues: Vec<Issue> = frame_issues
        .into_iter()
        .map(|issue| Issue {
            rule: "R12",
            item: issue.owner.to_owned(),
            token: String::new(),
            detail: issue.detail,
        })
        .collect();
    for site in &sites {
        match parse_t(&site.text) {
            Err(error) => issues.push(parse_issue(site.owner, &error)),
            Ok(words) => {
                issues.extend(t_ref_issues(site.owner, &words, present));
                let derived = crate::sentence::analyze_words(&words, site.own_tts, site.drill_tts);
                if let Err(error) = derived {
                    issues.push(parse_issue(site.owner, &error));
                }
            }
        }
    }
    issues
}

/// 單字讀音也要能轉羅馬字，否則 `VocabEntry::romaji` 無法建立。
fn vocab_reading_issues(raw: &RawContent) -> Vec<Issue> {
    raw.vocab
        .iter()
        .filter_map(|vocab| {
            to_romaji_reading(&vocab.kana, reading_mode_of(&vocab.kana))
                .err()
                .map(|err| Issue {
                    rule: "R02",
                    item: vocab.id.clone(),
                    token: vocab.kana.clone(),
                    detail: format!("讀音無法轉換：{err}"),
                })
        })
        .collect()
}

/// 課程結構：`order` 與 `lessons` 必須一一對應，`order` 不得重複。
fn course_issues(raw: &RawContent) -> Vec<Issue> {
    let mut seen: HashSet<&str> = HashSet::new();
    let mut issues = Vec::new();
    for id in &raw.course.order {
        if !seen.insert(id) {
            issues.push(Issue {
                rule: "R01",
                item: id.clone(),
                token: id.clone(),
                detail: "course.order 重複".to_owned(),
            });
        }
    }
    for lesson in raw
        .course
        .lessons
        .iter()
        .filter(|l| !seen.contains(l.id.as_str()))
    {
        issues.push(Issue {
            rule: "R03",
            item: lesson.id.clone(),
            token: lesson.id.clone(),
            detail: "課程未列入 course.order".to_owned(),
        });
    }
    issues
}

/// 過濾會丟棄課不在範圍內的項目，所以 `lesson` 打錯要在過濾前檢查。
fn lesson_ref_issues(unfiltered: &RawContent) -> Vec<Issue> {
    let lessons: HashSet<&str> = unfiltered
        .course
        .lessons
        .iter()
        .map(|l| l.id.as_str())
        .collect();
    reference_sites(unfiltered)
        .into_iter()
        .filter(|site| site.field == "lesson" && !lessons.contains(site.target))
        .map(|site| Issue {
            rule: "R03",
            item: site.owner.to_owned(),
            token: site.target.to_owned(),
            detail: "lesson 指向不存在的課".to_owned(),
        })
        .collect()
}

/// `raw` 為當前階段的內容；`unfiltered` 用來查重與判定軟引用。
pub fn validate(raw: &RawContent, unfiltered: &RawContent) -> Vec<Issue> {
    let all_ids = item_ids(unfiltered);
    let present_ids = item_ids(raw);
    let present: HashSet<&str> = present_ids.iter().map(|(id, _)| *id).collect();
    let all: HashSet<&str> = all_ids.iter().map(|(id, _)| *id).collect();
    let mut issues = id_issues(&all_ids);
    issues.extend(course_issues(raw));
    issues.extend(lesson_ref_issues(unfiltered));
    issues.extend(reference_issues(raw, &all, &present));
    issues.extend(t_issues(raw, &present));
    issues.extend(vocab_reading_issues(raw));
    issues
}

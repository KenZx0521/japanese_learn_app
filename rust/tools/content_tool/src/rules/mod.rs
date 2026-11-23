//! B 層規則（reuse-and-verification.md §9.2）。每條規則一個函式，簽章相同，便於單獨測試。

use std::collections::{BTreeSet, HashMap, HashSet};
use std::fmt;
use std::path::PathBuf;

use crate::data::{Data, Need};
use crate::scope::Scope;

pub mod accent;
pub mod font;
pub mod jlpt;
pub mod jmdict;
pub mod kana;
pub mod license;
pub mod zh;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Level {
    Error,
    Warning,
    Info,
}

impl Level {
    pub fn name(self) -> &'static str {
        match self {
            Self::Error => "error",
            Self::Warning => "warning",
            Self::Info => "info",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Finding {
    pub rule: &'static str,
    pub level: Level,
    pub item: String,
    pub token: String,
    pub message: String,
}

impl Finding {
    pub fn new(
        rule: &'static str,
        level: Level,
        item: impl Into<String>,
        token: impl Into<String>,
        message: impl Into<String>,
    ) -> Self {
        Self {
            rule,
            level,
            item: item.into(),
            token: token.into(),
            message: message.into(),
        }
    }

    pub fn error(
        rule: &'static str,
        item: impl Into<String>,
        token: impl Into<String>,
        message: impl Into<String>,
    ) -> Self {
        Self::new(rule, Level::Error, item, token, message)
    }

    pub fn warning(
        rule: &'static str,
        item: impl Into<String>,
        token: impl Into<String>,
        message: impl Into<String>,
    ) -> Self {
        Self::new(rule, Level::Warning, item, token, message)
    }

    pub fn info(
        rule: &'static str,
        item: impl Into<String>,
        token: impl Into<String>,
        message: impl Into<String>,
    ) -> Self {
        Self::new(rule, Level::Info, item, token, message)
    }
}

impl fmt::Display for Finding {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} [{}] {}", self.rule, self.level.name(), self.item)?;
        if !self.token.is_empty() {
            write!(f, " token={}", self.token)?;
        }
        write!(f, "：{}", self.message)
    }
}

/// 規則需要的環境：repo 路徑、已載入的字型、清單。
#[derive(Debug, Clone, Default)]
pub struct Env {
    pub repo_root: PathBuf,
    pub font_dir: PathBuf,
    /// `verify --strict`：C01–C03 依階段門檻判錯（§9.2）。
    pub strict: bool,
    /// 字型檔名 → cmap；檔案不存在者不列入。
    pub fonts: HashMap<String, HashSet<char>>,
    pub coverage_skip: Vec<(String, String)>,
    /// `(gr.* ID, n5|n4)`；清單不存在時為 `None`。
    pub grammar_checklist: Option<Vec<(String, String)>>,
}

pub struct Input<'a> {
    pub scope: &'a Scope,
    pub data: &'a Data,
    pub env: &'a Env,
}

pub type RuleFn = fn(&Input) -> Vec<Finding>;

pub struct RuleDef {
    pub id: &'static str,
    pub needs: &'static [Need],
    pub run: RuleFn,
}

const JM: &[Need] = &[Need::Jmdict];

pub const RULES: &[RuleDef] = &[
    RuleDef {
        id: "J01",
        needs: JM,
        run: jmdict::j01,
    },
    RuleDef {
        id: "J01b",
        needs: &[],
        run: jmdict::j01b,
    },
    RuleDef {
        id: "J02",
        needs: &[Need::Kanjidic],
        run: kana::j02,
    },
    RuleDef {
        id: "J03",
        needs: JM,
        run: jmdict::j03,
    },
    RuleDef {
        id: "J03b",
        needs: JM,
        run: jmdict::j03b,
    },
    RuleDef {
        id: "J04",
        needs: &[],
        run: kana::j04,
    },
    RuleDef {
        id: "J05",
        needs: JM,
        run: jmdict::j05,
    },
    RuleDef {
        id: "J06",
        needs: JM,
        run: jmdict::j06,
    },
    RuleDef {
        id: "J07",
        needs: &[Need::Furigana],
        run: jmdict::j07,
    },
    RuleDef {
        id: "J08",
        needs: &[],
        run: kana::j08,
    },
    RuleDef {
        id: "J09",
        needs: &[],
        run: kana::j09,
    },
    RuleDef {
        id: "J10",
        needs: JM,
        run: jmdict::j10,
    },
    RuleDef {
        id: "F01",
        needs: &[],
        run: font::f01,
    },
    RuleDef {
        id: "F02",
        needs: &[],
        run: font::f02,
    },
    RuleDef {
        id: "F03",
        needs: &[],
        run: font::f03,
    },
    RuleDef {
        id: "F04",
        needs: &[],
        run: font::f04,
    },
    RuleDef {
        id: "F05",
        needs: &[],
        run: font::f05,
    },
    RuleDef {
        id: "C01",
        needs: &[Need::Jmdict, Need::Jlpt],
        run: jlpt::c01,
    },
    RuleDef {
        id: "C02",
        needs: &[Need::Jmdict, Need::Jlpt],
        run: jlpt::c02,
    },
    RuleDef {
        id: "C03",
        needs: &[],
        run: jlpt::c03,
    },
    RuleDef {
        id: "C04",
        needs: &[Need::Freq],
        run: jlpt::c04,
    },
    RuleDef {
        id: "C05",
        needs: &[],
        run: jlpt::c05,
    },
    RuleDef {
        id: "C06",
        needs: &[Need::Jmdict, Need::Jlpt],
        run: jlpt::c06,
    },
    RuleDef {
        id: "Z01",
        needs: &[],
        run: zh::z01,
    },
    RuleDef {
        id: "Z02",
        needs: &[],
        run: zh::z02,
    },
    RuleDef {
        id: "A01",
        needs: &[Need::Accents],
        run: accent::a01,
    },
    RuleDef {
        id: "L01",
        needs: &[],
        run: license::l01,
    },
    RuleDef {
        id: "L02",
        needs: &[],
        run: license::l02,
    },
    RuleDef {
        id: "L04",
        needs: &[],
        run: license::l04,
    },
];

/// 被選中的規則合併後需要的資料。
pub fn needs_of(rules: &[&RuleDef]) -> BTreeSet<Need> {
    rules
        .iter()
        .flat_map(|rule| rule.needs.iter().copied())
        .collect()
}

/// 判斷漢字（含 々 以外的擴充區）。
pub fn is_kanji(c: char) -> bool {
    matches!(c,
        '\u{3400}'..='\u{4DBF}' | '\u{4E00}'..='\u{9FFF}' | '\u{F900}'..='\u{FAFF}'
        | '\u{20000}'..='\u{3FFFF}')
}

pub fn has_kanji(text: &str) -> bool {
    text.chars().any(is_kanji)
}

/// `〜` 依 §2.2-3 不參與比對。
pub fn strip_tilde(surface: &str) -> &str {
    surface.trim_matches('\u{301C}')
}

pub fn strip_spaces(kana: &str) -> String {
    kana.chars().filter(|c| !c.is_whitespace()).collect()
}

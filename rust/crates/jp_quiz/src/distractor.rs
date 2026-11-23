//! 程式產生的干擾項（§8.2、§8.3）。

use std::collections::HashSet;

use jp_content::schema::{ConfusableDef, ConfusableKind, KanaKind, Script};
use jp_content::store::{KanaEntry, VocabEntry};
use jp_content::ContentStore;
use jp_lang::quiz::rng::{shuffled, ChaCha8Rng};

use crate::view::strip_spaces;

/// 假名題最多四選一。
const MAX_KANA_DISTRACTORS: usize = 3;
const MAX_VOCAB_DISTRACTORS: usize = 3;

/// を 與 お 發音相同，放在一起會有兩個正解（§8.2）。
const WO_ROMAJI: &str = "wo";
const O_ROMAJI: &str = "o";
const EXTENDED_SLUG_PREFIX: &str = "x_";
const VOWELS: [char; 5] = ['a', 'i', 'u', 'e', 'o'];
/// 赫本式拼法不規則的字，對回所屬的行。
const ROW_ALIASES: [(&str, &str); 5] = [
    ("sh", "s"),
    ("ch", "t"),
    ("ts", "t"),
    ("f", "h"),
    ("j", "z"),
];

/// 已教字，依內容順序排列，出題結果因此不受 `HashSet` 走訪順序影響。
#[derive(Debug, Clone)]
pub struct KanaPool<'c> {
    entries: Vec<&'c KanaEntry>,
}

fn is_quizzable(entry: &KanaEntry) -> bool {
    !entry.def.retired && entry.def.kind != KanaKind::Mark
}

impl<'c> KanaPool<'c> {
    /// `known` 加上目前這一批的字（§8.2）。
    pub fn taught(content: &'c ContentStore, known: &HashSet<String>, batch: &[&str]) -> Self {
        let entries = content
            .kana()
            .iter()
            .filter(|entry| is_quizzable(entry))
            .filter(|entry| known.contains(&entry.def.id) || batch.contains(&entry.def.id.as_str()))
            .collect();
        Self { entries }
    }

    /// 檢定 K19／KK08 的範圍（§8.5）：`pos ≤ max_pos` 的該文字系統全部字，不看 `item_intro`。
    pub fn whole_script(content: &'c ContentStore, script: Script, max_pos: u32) -> Self {
        let entries = content
            .kana()
            .iter()
            .filter(|entry| is_quizzable(entry) && entry.def.script == script)
            .filter(|entry| {
                content
                    .lesson_pos(&entry.def.lesson)
                    .is_some_and(|pos| pos <= max_pos)
            })
            .collect();
        Self { entries }
    }

    pub fn entries(&self) -> &[&'c KanaEntry] {
        &self.entries
    }

    /// 只留同一文字系統的字。
    pub(crate) fn of_script(&self, script: Script) -> Self {
        let entries = self
            .entries
            .iter()
            .copied()
            .filter(|entry| entry.def.script == script)
            .collect();
        Self { entries }
    }

    pub(crate) fn contains(&self, kana_id: &str) -> bool {
        self.entries.iter().any(|entry| entry.def.id == kana_id)
    }
}

pub(crate) fn sound_key(entry: &KanaEntry) -> &str {
    if entry.romaji == WO_ROMAJI {
        O_ROMAJI
    } else {
        &entry.romaji
    }
}

/// `kana_confuse` 與干擾項第一層只用字形、跨文字的字組（§8.2）。
pub(crate) fn confusable_groups<'c>(
    kana_id: &str,
    content: &'c ContentStore,
) -> Vec<&'c ConfusableDef> {
    content
        .confusables()
        .iter()
        .filter(|group| !group.retired && is_confuse_kind(group.kind))
        .filter(|group| group.members.iter().any(|member| member == kana_id))
        .collect()
}

pub(crate) fn is_confuse_kind(kind: ConfusableKind) -> bool {
    matches!(kind, ConfusableKind::Shape | ConfusableKind::CrossScript)
}

struct GridPos {
    row: String,
    column: Option<char>,
    is_yoon: bool,
}

fn grid_pos(entry: &KanaEntry) -> GridPos {
    let id = entry.def.id.as_str();
    let slug = id.rsplit('.').next().unwrap_or(id);
    let slug = slug.strip_prefix(EXTENDED_SLUG_PREFIX).unwrap_or(slug);
    let column = slug.chars().last().filter(|c| VOWELS.contains(c));
    let consonant = slug.strip_suffix(VOWELS).unwrap_or(slug);
    let row = entry.def.row.clone().unwrap_or_else(|| {
        ROW_ALIASES
            .iter()
            .find(|(alias, _)| *alias == consonant)
            .map_or(consonant, |(_, row)| row)
            .to_owned()
    });
    GridPos {
        row,
        column,
        is_yoon: entry.def.kind == KanaKind::Yoon,
    }
}

/// ん 不在五十音的格線上，不算同行同段；拗音是另一張表，段不與直音共用。
fn shares_row_or_column(a: &GridPos, b: &GridPos) -> bool {
    let on_grid = a.column.is_some() && b.column.is_some();
    on_grid && (a.row == b.row || (a.column == b.column && a.is_yoon == b.is_yoon))
}

const TIER_CONFUSABLE: u8 = 0;
const TIER_GRID: u8 = 1;
const TIER_OTHER: u8 = 2;

/// 同層內同文字系統優先：別的文字系統一眼就能排除，起不了干擾作用。
fn rank(
    entry: &KanaEntry,
    target: &KanaEntry,
    target_grid: &GridPos,
    groups: &[&ConfusableDef],
) -> (u8, bool) {
    let in_group = groups
        .iter()
        .any(|group| group.members.contains(&entry.def.id));
    let tier = if in_group {
        TIER_CONFUSABLE
    } else if shares_row_or_column(&grid_pos(entry), target_grid) {
        TIER_GRID
    } else {
        TIER_OTHER
    };
    (tier, entry.def.script != target.def.script)
}

/// 依 §8.2 三層取字，排除讀音相同者；選項羅馬字不重複。
pub fn kana_distractors<'c>(
    target: &KanaEntry,
    pool: &KanaPool<'c>,
    content: &ContentStore,
    rng: &mut ChaCha8Rng,
) -> Vec<&'c KanaEntry> {
    let groups = confusable_groups(&target.def.id, content);
    let target_grid = grid_pos(target);
    let target_sound = sound_key(target);
    let candidates: Vec<&'c KanaEntry> = pool
        .entries
        .iter()
        .copied()
        .filter(|entry| entry.def.id != target.def.id && sound_key(entry) != target_sound)
        .collect();
    // 先洗牌再穩定排序：同層內的順序由種子決定
    let mut ordered = shuffled(rng, candidates);
    ordered.sort_by_key(|entry| rank(entry, target, &target_grid, &groups));
    let mut seen = HashSet::new();
    ordered
        .into_iter()
        .filter(|entry| seen.insert(sound_key(entry).to_owned()))
        .take(MAX_KANA_DISTRACTORS)
        .collect()
}

fn shares_zh(a: &VocabEntry, b: &VocabEntry) -> bool {
    a.def.zh.iter().any(|zh| b.def.zh.contains(zh))
}

fn same_kana(a: &VocabEntry, b: &VocabEntry) -> bool {
    strip_spaces(&a.def.kana) == strip_spaces(&b.def.kana)
}

fn conflicts(a: &VocabEntry, b: &VocabEntry) -> bool {
    a.def.id == b.def.id || same_kana(a, b) || shares_zh(a, b)
}

fn is_vocab_candidate(entry: &VocabEntry, known: &HashSet<String>) -> bool {
    !entry.def.retired && known.contains(&entry.def.id)
}

/// 同 `pos` 且同 `topics[0]`，再放寬到同 `pos`，每層內以種子洗牌（§8.3）。
pub fn vocab_distractors<'c>(
    target: &VocabEntry,
    known: &HashSet<String>,
    content: &'c ContentStore,
    rng: &mut ChaCha8Rng,
) -> Vec<&'c VocabEntry> {
    let same_pos: Vec<&'c VocabEntry> = content
        .vocab_with_pos(target.def.pos)
        .iter()
        .map(|&index| &content.vocab()[index as usize])
        .filter(|entry| is_vocab_candidate(entry, known) && !conflicts(entry, target))
        .collect();
    let (same_topic, rest): (Vec<_>, Vec<_>) = same_pos
        .into_iter()
        .partition(|entry| entry.def.topics.first() == target.def.topics.first());
    let tier_one = shuffled(rng, same_topic);
    let tier_two = shuffled(rng, rest);
    let mut chosen: Vec<&'c VocabEntry> = Vec::new();
    for entry in tier_one.into_iter().chain(tier_two) {
        if chosen.len() < MAX_VOCAB_DISTRACTORS && !chosen.iter().any(|c| conflicts(c, entry)) {
            chosen.push(entry);
        }
    }
    chosen
}

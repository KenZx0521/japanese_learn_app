//! 五十音表、單字查詢、規則卡（§9.4，flutter-app §3.3）。

use jp_content::schema::{KanaKind, Script};
use jp_content::store::KanaEntry;

use super::deps::Deps;
use super::mapping::enums::script_of;
use super::views::Views;
use crate::api::dto_content::{
    KanaCellDto, KanaDetailDto, KanaGroupDto, KanaRowDto, KanaScript, RuleCardDto, SoundGroupDto,
};
use crate::api::error::CoreError;

const GOJUON_VOWELS: [char; 5] = ['a', 'i', 'u', 'e', 'o'];
const YOON_VOWELS: [char; 3] = ['a', 'u', 'o'];
const GOJUON_COLUMNS: usize = 5;
const YOON_COLUMNS: usize = 3;

struct GroupSpec {
    kind: KanaKind,
    title_zh: &'static str,
    vowels: &'static [char],
    columns: usize,
}

const GROUPS: [GroupSpec; 5] = [
    GroupSpec {
        kind: KanaKind::Basic,
        title_zh: "清音",
        vowels: &GOJUON_VOWELS,
        columns: GOJUON_COLUMNS,
    },
    GroupSpec {
        kind: KanaKind::Dakuten,
        title_zh: "濁音與半濁音",
        vowels: &GOJUON_VOWELS,
        columns: GOJUON_COLUMNS,
    },
    GroupSpec {
        kind: KanaKind::Yoon,
        title_zh: "拗音",
        vowels: &YOON_VOWELS,
        columns: YOON_COLUMNS,
    },
    GroupSpec {
        kind: KanaKind::Extended,
        title_zh: "外來音",
        vowels: &GOJUON_VOWELS,
        columns: GOJUON_COLUMNS,
    },
    GroupSpec {
        kind: KanaKind::Mark,
        title_zh: "符號",
        vowels: &[],
        columns: GOJUON_COLUMNS,
    },
];

/// 依 ID 尾端的母音對位。沒有母音的字（ん、符號）放在新一列開頭。
fn column_of(id: &str, vowels: &[char]) -> Option<usize> {
    let last = id.chars().next_back()?;
    vowels.iter().position(|vowel| *vowel == last)
}

fn first_empty_column(row: &[Option<KanaCellDto>]) -> usize {
    row.iter().take_while(|cell| cell.is_some()).count()
}

fn needs_new_row(
    rows: &[Vec<Option<KanaCellDto>>],
    column: Option<usize>,
    previous: Option<usize>,
    spec: &GroupSpec,
) -> bool {
    let Some(current) = rows.last() else {
        return true;
    };
    if spec.vowels.is_empty() {
        return first_empty_column(current) == spec.columns;
    }
    !matches!((column, previous), (Some(c), Some(p)) if c > p)
}

/// 字序本身就是五十音順：欄位沒有往右走就換列，や行、わ行 的空格因此自然保留。
fn layout_rows(entries: &[&KanaEntry], spec: &GroupSpec, views: &Views<'_>) -> Vec<KanaRowDto> {
    let mut rows: Vec<Vec<Option<KanaCellDto>>> = Vec::new();
    let mut previous: Option<usize> = None;
    for entry in entries {
        let column = column_of(&entry.def.id, spec.vowels);
        if needs_new_row(&rows, column, previous, spec) {
            rows.push(vec![None; spec.columns]);
        }
        let row = rows.last_mut().expect("上方已確保至少一列");
        let index = column.unwrap_or_else(|| first_empty_column(row));
        row[index] = Some(views.kana_cell(entry));
        previous = column;
    }
    rows.into_iter().map(|cells| KanaRowDto { cells }).collect()
}

fn group_of(script: Script, spec: &GroupSpec, views: &Views<'_>) -> Option<KanaGroupDto> {
    let entries: Vec<&KanaEntry> = views
        .content()
        .kana()
        .iter()
        .filter(|entry| entry.def.script == script && entry.def.kind == spec.kind)
        .filter(|entry| !entry.def.retired)
        .collect();
    (!entries.is_empty()).then(|| KanaGroupDto {
        title_zh: spec.title_zh.to_owned(),
        columns: u32::try_from(spec.columns).expect("欄數是小常數"),
        rows: layout_rows(&entries, spec, views),
    })
}

pub(crate) fn kana_chart(deps: &Deps, script: KanaScript) -> Result<Vec<KanaGroupDto>, CoreError> {
    let views = Views::load(deps)?;
    let script = script_of(script);
    Ok(GROUPS
        .iter()
        .filter_map(|spec| group_of(script, spec, &views))
        .collect())
}

pub(crate) fn kana_detail(deps: &Deps, kana_id: &str) -> Result<KanaDetailDto, CoreError> {
    let views = Views::load(deps)?;
    let entry = views
        .content()
        .kana_by_id(kana_id)
        .ok_or_else(|| CoreError::not_found("kana", kana_id))?;
    Ok(views.kana_detail(entry))
}

pub(crate) fn rule_card(deps: &Deps, rule_id: &str) -> Result<RuleCardDto, CoreError> {
    let views = Views::load(deps)?;
    let def = views
        .content()
        .rule_card_by_id(rule_id)
        .ok_or_else(|| CoreError::not_found("rule_card", rule_id))?;
    Ok(views.rule_card(def))
}

pub(crate) fn sound_groups(deps: &Deps) -> Result<Vec<SoundGroupDto>, CoreError> {
    let views = Views::load(deps)?;
    Ok(views
        .content()
        .sound_groups()
        .iter()
        .filter(|group| !group.retired)
        .map(|group| views.sound_group(group))
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    const ONE_ROW: [Vec<Option<KanaCellDto>>; 1] = [Vec::new()];

    #[test]
    fn column_comes_from_the_trailing_vowel() {
        assert_eq!(column_of("ka.hira.shi", &GOJUON_VOWELS), Some(1));
        assert_eq!(column_of("ka.hira.kyo", &YOON_VOWELS), Some(2));
        assert_eq!(column_of("ka.hira.n", &GOJUON_VOWELS), None);
    }

    /// ティ、ディ 同在 i 段，不換列就會互相覆蓋。
    #[test]
    fn a_repeated_column_starts_a_new_row() {
        let spec = &GROUPS[3];
        assert!(needs_new_row(&ONE_ROW, Some(1), Some(1), spec));
        assert!(!needs_new_row(&ONE_ROW, Some(2), Some(1), spec));
        assert!(needs_new_row(&ONE_ROW, None, Some(1), spec));
    }
}

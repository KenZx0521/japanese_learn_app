//! `available`：列出到某課為止可用的項目（reuse-and-verification.md §9.4）。

use jp_content::store::ContentStore;

pub const HEADER: &str = "id\tsurface\tkana\tlesson";

const NO_READING: &str = "-";

/// 同課內的類別順序：假名、假名群組（規則卡、易混字組、語音示範組）、單字、文法。
const RANK_KANA: u8 = 0;
const RANK_KANA_GROUP: u8 = 1;
const RANK_VOCAB: u8 = 2;
const RANK_GRAMMAR: u8 = 3;

pub struct Row {
    position: u32,
    rank: u8,
    order: u32,
    id: String,
    surface: String,
    kana: String,
    lesson: String,
}

impl Row {
    pub fn tsv(&self) -> String {
        format!(
            "{}\t{}\t{}\t{}",
            self.id, self.surface, self.kana, self.lesson
        )
    }
}

struct RowInput<'a> {
    rank: u8,
    order: u32,
    id: &'a str,
    surface: &'a str,
    kana: &'a str,
    lesson: &'a str,
}

fn row(store: &ContentStore, limit: u32, input: RowInput) -> Option<Row> {
    let position = store.lesson_pos(input.lesson)?;
    (position <= limit).then(|| Row {
        position,
        rank: input.rank,
        order: input.order,
        id: input.id.to_owned(),
        surface: input.surface.to_owned(),
        kana: input.kana.to_owned(),
        lesson: input.lesson.to_owned(),
    })
}

fn kana_rows(store: &ContentStore, limit: u32) -> Vec<Row> {
    store
        .kana()
        .iter()
        .filter(|entry| !entry.def.retired)
        .enumerate()
        .filter_map(|(order, entry)| {
            row(
                store,
                limit,
                RowInput {
                    rank: RANK_KANA,
                    order: order as u32,
                    id: &entry.def.id,
                    surface: &entry.def.ch,
                    kana: &entry.def.ch,
                    lesson: &entry.def.lesson,
                },
            )
        })
        .collect()
}

/// 規則卡、易混字組、語音示範組：`surface` 取標題或差異說明。
fn kana_group_rows(store: &ContentStore, limit: u32) -> Vec<Row> {
    let rules = store
        .rule_cards()
        .iter()
        .filter(|c| !c.retired)
        .map(|c| (&c.id, &c.title_zh, &c.lesson));
    let confusables = store
        .confusables()
        .iter()
        .filter(|c| !c.retired)
        .map(|c| (&c.id, &c.diff_zh, &c.lesson));
    let sound_groups = store
        .sound_groups()
        .iter()
        .filter(|s| !s.retired)
        .map(|s| (&s.id, &s.title_zh, &s.lesson));
    rules
        .chain(confusables)
        .chain(sound_groups)
        .filter_map(|(id, surface, lesson)| {
            row(
                store,
                limit,
                RowInput {
                    rank: RANK_KANA_GROUP,
                    order: 0,
                    id,
                    surface,
                    kana: NO_READING,
                    lesson,
                },
            )
        })
        .collect()
}

fn vocab_rows(store: &ContentStore, limit: u32) -> Vec<Row> {
    store
        .vocab()
        .iter()
        .filter(|entry| !entry.def.retired)
        .filter_map(|entry| {
            let def = &entry.def;
            row(
                store,
                limit,
                RowInput {
                    rank: RANK_VOCAB,
                    order: def.lesson_order,
                    id: &def.id,
                    surface: &def.surface,
                    kana: &def.kana,
                    lesson: &def.lesson,
                },
            )
        })
        .collect()
}

fn grammar_rows(store: &ContentStore, limit: u32) -> Vec<Row> {
    store
        .grammar()
        .iter()
        .filter(|def| !def.retired)
        .filter_map(|def| {
            row(
                store,
                limit,
                RowInput {
                    rank: RANK_GRAMMAR,
                    order: def.lesson_order,
                    id: &def.id,
                    surface: &def.pattern,
                    kana: NO_READING,
                    lesson: &def.lesson,
                },
            )
        })
        .collect()
}

/// 依 `pos(lesson)`、類別、`lesson_order` 排序。
pub fn rows_up_to(store: &ContentStore, limit: u32) -> Vec<Row> {
    let mut rows = kana_rows(store, limit);
    rows.extend(kana_group_rows(store, limit));
    rows.extend(vocab_rows(store, limit));
    rows.extend(grammar_rows(store, limit));
    rows.sort_by_key(|row| (row.position, row.rank, row.order, row.id.clone()));
    rows
}

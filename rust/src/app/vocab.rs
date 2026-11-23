//! 單字列表、詳情、旗標、主題（§9.4）。

use jp_content::store::VocabEntry;
use jp_lang::clock::DayContext;
use jp_plan::state::cursor_pos;
use jp_srs::facets::cards_for_content;
use jp_srs::{CardId, Facet};
use jp_store::{
    CardRow, ItemIntroRow, PlanRepo, SrsRepo, VocabFlagRow, VocabFlagsWrite, STATE_NEW,
};

use super::deps::Deps;
use super::mapping::enums::{jlpt_name, pos_name};
use super::views::Views;
use crate::api::dto_content::{
    TopicDto, VocabDetailDto, VocabFilterDto, VocabFlagsDto, VocabPageDto, VocabSummaryDto,
};
use crate::api::error::CoreError;

pub(super) const MAX_PAGE_SIZE: u32 = 200;

/// curriculum §4.2 的「內容」欄，查無時回 slug 本身。
const TOPIC_TITLES: [(&str, &str); 26] = [
    ("greet", "問候與固定用語"),
    ("people", "人稱、家人、人物關係"),
    ("job", "職業與身分"),
    ("number", "數字與量詞"),
    ("time", "時間、日期、星期、頻率"),
    ("food", "食物、飲料、餐廳"),
    ("shop", "購物、金錢、衣物"),
    ("place", "場所與建築"),
    ("direction", "方位與問路"),
    ("transport", "交通與車站"),
    ("home", "住家、家具、日用品"),
    ("body", "身體、健康、看病"),
    ("nature", "天氣、季節、自然"),
    ("animal", "動植物"),
    ("school", "學校與學習"),
    ("work", "工作與職場"),
    ("hobby", "興趣、娛樂、運動"),
    ("travel", "旅行與住宿"),
    ("device", "手機、網路、3C"),
    ("emotion", "情感與個性"),
    ("adj", "基本形容詞"),
    ("verb", "基本動詞"),
    ("adverb", "副詞與程度詞"),
    ("connector", "接續詞與功能詞"),
    ("question", "疑問詞"),
    ("demonstrative", "{ja:こそあど}與指示"),
];

pub(super) fn validate_limit(limit: u32) -> Result<(), CoreError> {
    if (1..=MAX_PAGE_SIZE).contains(&limit) {
        Ok(())
    } else {
        Err(CoreError::invalid(
            "limit",
            format!("須為 1–{MAX_PAGE_SIZE}：{limit}"),
        ))
    }
}

/// 淘汰的字不列出（§9.4）。
pub(super) fn is_listable(entry: &VocabEntry) -> bool {
    !entry.def.retired
}

/// `(pos(lesson), lesson_order)`。不在課序內的字排最後。
pub(super) fn course_key(entry: &VocabEntry, views: &Views<'_>) -> (u32, u32) {
    let pos = views
        .content()
        .lesson_pos(&entry.def.lesson)
        .unwrap_or(u32::MAX);
    (pos, entry.def.lesson_order)
}

fn matches_static_filter(entry: &VocabEntry, filter: &VocabFilterDto, views: &Views<'_>) -> bool {
    let def = &entry.def;
    let id = &def.id;
    filter
        .topic
        .as_ref()
        .is_none_or(|t| def.topics.first() == Some(t))
        // `v1` 也篩出同 family 的 `v1_s`（くれる），與干擾項分組一致；`v1_s` 仍可精確篩選。
        && filter
            .pos
            .as_deref()
            .is_none_or(|p| pos_name(def.pos) == p || pos_name(def.pos.family()) == p)
        && filter
            .jlpt
            .as_deref()
            .is_none_or(|j| jlpt_name(def.jlpt) == j)
        && filter.lesson_id.as_ref().is_none_or(|l| def.lesson == *l)
        && (!filter.only_introduced || views.state.introduced.contains(id))
        && (!filter.only_starred || views.flags.get(id).is_some_and(|row| row.starred))
}

fn matches_srs_filter(
    entry: &VocabEntry,
    filter: &VocabFilterDto,
    views: &Views<'_>,
) -> Result<bool, CoreError> {
    match filter.srs_state {
        None => Ok(true),
        Some(wanted) => Ok(views.vocab_state(&entry.def.id)? == wanted),
    }
}

pub(crate) fn vocab_page(
    deps: &Deps,
    filter: &VocabFilterDto,
    offset: u32,
    limit: u32,
) -> Result<VocabPageDto, CoreError> {
    validate_limit(limit)?;
    let views = Views::load(deps)?;
    let mut matched: Vec<&VocabEntry> = Vec::new();
    for entry in views.content().vocab() {
        if is_listable(entry)
            && matches_static_filter(entry, filter, &views)
            && matches_srs_filter(entry, filter, &views)?
        {
            matched.push(entry);
        }
    }
    matched.sort_by_key(|entry| course_key(entry, &views));
    Ok(VocabPageDto {
        total: u32::try_from(matched.len()).expect("單字數不可能超過 u32"),
        items: matched
            .iter()
            .skip(offset as usize)
            .take(limit as usize)
            .map(|entry| views.vocab_summary(entry))
            .collect::<Result<_, _>>()?,
    })
}

pub(crate) fn vocab_detail(deps: &Deps, vocab_id: &str) -> Result<VocabDetailDto, CoreError> {
    let views = Views::load(deps)?;
    let entry = views
        .content()
        .vocab_by_id(vocab_id)
        .ok_or_else(|| CoreError::not_found("vocab", vocab_id))?;
    views.vocab_detail(entry, None)
}

pub(crate) fn search_vocab(
    deps: &Deps,
    query: &str,
    limit: u32,
) -> Result<Vec<VocabSummaryDto>, CoreError> {
    validate_limit(limit)?;
    let views = Views::load(deps)?;
    super::vocab_search::search(&views, query, limit as usize)
}

fn word_cards(deps: &Deps, vocab_id: &str) -> Result<Vec<CardRow>, CoreError> {
    let mut cards = Vec::new();
    for facet in [Facet::Recog, Facet::Listen, Facet::Produce] {
        let card_id = CardId::new(vocab_id, facet).to_string();
        cards.extend(deps.repo.card(&card_id)?);
    }
    Ok(cards)
}

/// 字所在的課還沒完成。走完全部課（`cursor_pos` 為 `None`）時都算完成。
fn lesson_is_pending(deps: &Deps, entry: &VocabEntry, ctx: &DayContext) -> Result<bool, CoreError> {
    let state = deps.cursor_state(ctx.today())?;
    let lesson = deps.content.lesson_pos(&entry.def.lesson);
    Ok(match (lesson, cursor_pos(&state, &deps.content)) {
        (Some(lesson), Some(cursor)) => lesson >= cursor,
        _ => false,
    })
}

fn mark_known_write(entry: &VocabEntry, flag: VocabFlagRow, ctx: &DayContext) -> VocabFlagsWrite {
    VocabFlagsWrite {
        flag,
        suspended: Some(true),
        add_intro: Some(ItemIntroRow {
            item_id: entry.def.id.clone(),
            lesson_id: entry.def.lesson.clone(),
            logical_date: ctx.today(),
            introduced_at: ctx.now,
        }),
        remove_intro: false,
        new_cards: Vec::new(),
    }
}

/// 課還沒教到、卡也沒作答過的字，`item_intro` 只是標已會留下的，要讓字回到切片，
/// 否則之後會在沒教過的情況下進複習。其餘情況沿用原有的卡，沒有卡才建立。
fn unmark_known_write(
    deps: &Deps,
    entry: &VocabEntry,
    flag: VocabFlagRow,
    ctx: &DayContext,
) -> Result<VocabFlagsWrite, CoreError> {
    let cards = word_cards(deps, &entry.def.id)?;
    let untaught =
        lesson_is_pending(deps, entry, ctx)? && cards.iter().all(|card| card.state == STATE_NEW);
    let new_cards = if cards.is_empty() && !untaught {
        cards_for_content(&entry.def.id, &deps.content, ctx.now)
    } else {
        Vec::new()
    };
    Ok(VocabFlagsWrite {
        flag,
        suspended: Some(false),
        add_intro: None,
        remove_intro: untaught,
        new_cards,
    })
}

pub(crate) fn set_vocab_flags(
    deps: &Deps,
    vocab_id: &str,
    flags: VocabFlagsDto,
) -> Result<VocabSummaryDto, CoreError> {
    let entry = deps
        .content
        .vocab_by_id(vocab_id)
        .ok_or_else(|| CoreError::not_found("vocab", vocab_id))?;
    let was_known = deps
        .repo
        .vocab_flags()?
        .get(vocab_id)
        .is_some_and(|row| row.known);
    let ctx = deps.day_ctx()?;
    let flag = VocabFlagRow {
        vocab_id: vocab_id.to_owned(),
        known: flags.known,
        starred: flags.starred,
        updated_at: ctx.now,
    };
    let write = if flags.known {
        mark_known_write(entry, flag, &ctx)
    } else if was_known {
        unmark_known_write(deps, entry, flag, &ctx)?
    } else {
        // 單純收藏尚未介紹的字不動卡片
        VocabFlagsWrite {
            flag,
            suspended: None,
            add_intro: None,
            remove_intro: false,
            new_cards: Vec::new(),
        }
    };
    deps.repo.apply_vocab_flags(&write)?;
    Views::load(deps)?.vocab_summary(entry)
}

fn topic_title(slug: &str) -> String {
    TOPIC_TITLES
        .iter()
        .find(|(id, _)| *id == slug)
        .map_or_else(|| slug.to_owned(), |(_, title)| (*title).to_owned())
}

/// `count` 依 `topics[0]`，排除 `retired`；0 字的主題不列出。
pub(crate) fn vocab_topics(deps: &Deps) -> Result<Vec<TopicDto>, CoreError> {
    let counted = || {
        deps.content
            .vocab()
            .iter()
            .filter(|e| !e.def.retired)
            .filter_map(|e| e.def.topics.first())
    };
    let mut slugs: Vec<&String> = Vec::new();
    for topic in counted() {
        if !slugs.contains(&topic) {
            slugs.push(topic);
        }
    }
    Ok(slugs
        .into_iter()
        .map(|slug| TopicDto {
            id: slug.clone(),
            title_zh: topic_title(slug),
            count: u32::try_from(counted().filter(|topic| *topic == slug).count())
                .expect("單字數不可能超過 u32"),
        })
        .collect())
}

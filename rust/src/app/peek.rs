//! `peek`：點字查詢的摘要（§9.4 表）。

use jp_content::ContentStore;

use super::deps::Deps;
use crate::api::dto_content::PeekDto;
use crate::api::error::CoreError;

const ZH_SEPARATOR: &str = "、";
const TITLE_SEPARATOR: &str = "／";

fn peek_dto(ref_id: &str, title: String, summary_zh: String, lesson_id: &str) -> PeekDto {
    PeekDto {
        ref_id: ref_id.to_owned(),
        title,
        kana: None,
        romaji: None,
        summary_zh,
        lesson_id: Some(lesson_id.to_owned()),
    }
}

fn vocab_peek(content: &ContentStore, id: &str) -> Option<PeekDto> {
    let entry = content.vocab_by_id(id)?;
    let def = &entry.def;
    Some(PeekDto {
        kana: Some(def.kana.clone()),
        romaji: Some(entry.romaji.clone()),
        ..peek_dto(
            id,
            def.surface.clone(),
            def.zh.join(ZH_SEPARATOR),
            &def.lesson,
        )
    })
}

fn kana_peek(content: &ContentStore, id: &str) -> Option<PeekDto> {
    let entry = content.kana_by_id(id)?;
    let def = &entry.def;
    Some(PeekDto {
        romaji: Some(entry.romaji.clone()),
        ..peek_dto(id, def.ch.clone(), def.hint_zh.clone(), &def.lesson)
    })
}

fn confusable_peek(content: &ContentStore, id: &str) -> Option<PeekDto> {
    let def = content.confusable_by_id(id)?;
    let members = def
        .members
        .iter()
        .filter_map(|member| content.kana_by_id(member))
        .map(|entry| entry.def.ch.clone());
    let literals = def.literals.iter().map(|literal| literal.text.clone());
    let title = members
        .chain(literals)
        .collect::<Vec<_>>()
        .join(TITLE_SEPARATOR);
    Some(peek_dto(id, title, def.diff_zh.clone(), &def.lesson))
}

fn rule_peek(content: &ContentStore, id: &str) -> Option<PeekDto> {
    let def = content.rule_card_by_id(id)?;
    let title = def
        .examples
        .first()
        .map_or_else(String::new, |example| example.text.clone());
    Some(peek_dto(id, title, def.title_zh.clone(), &def.lesson))
}

fn sound_group_peek(content: &ContentStore, id: &str) -> Option<PeekDto> {
    let def = content.sound_group_by_id(id)?;
    let title = def.pairs.first().map_or_else(String::new, |pair| {
        format!("{}{TITLE_SEPARATOR}{}", pair.a, pair.b)
    });
    Some(peek_dto(id, title, def.title_zh.clone(), &def.lesson))
}

fn grammar_peek(content: &ContentStore, id: &str) -> Option<PeekDto> {
    let def = content.grammar_by_id(id)?;
    Some(peek_dto(
        id,
        def.title_zh.clone(),
        def.meaning_zh.clone(),
        &def.lesson,
    ))
}

type PeekFn = fn(&ContentStore, &str) -> Option<PeekDto>;

const PEEKS: [PeekFn; 6] = [
    vocab_peek,
    kana_peek,
    confusable_peek,
    rule_peek,
    sound_group_peek,
    grammar_peek,
];

pub(crate) fn peek(deps: &Deps, ref_id: &str) -> Result<PeekDto, CoreError> {
    PEEKS
        .iter()
        .find_map(|lookup| lookup(&deps.content, ref_id))
        .ok_or_else(|| CoreError::not_found("ref", ref_id))
}

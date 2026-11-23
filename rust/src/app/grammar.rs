//! 文法列表、詳情、筆記（§9.4）。

use jp_content::mixed::{parse_mixed_text, MixedSpan};
use jp_content::schema::{GrammarDef, NoteDef};
use jp_lang::kana::romaji_to_hiragana;

use super::deps::Deps;
use super::mapping::grammar::note_dto;
use super::views::Views;
use crate::api::dto_content::{GrammarDetailDto, GrammarSummaryDto, NoteDto, NoteKind};
use crate::api::error::CoreError;

/// 去掉 `{ja:}` 標記後的純文字。
fn plain_text(mixed: &str) -> String {
    parse_mixed_text(mixed)
        .into_iter()
        .map(|span| match span {
            MixedSpan::Zh { text } | MixedSpan::Ja { text, .. } => text,
        })
        .collect()
}

/// 拉丁字母先轉假名（比照 `search_vocab`），原字串也比對，`pattern` 內可能有 V、N。
fn query_forms(query: &str) -> Vec<String> {
    let lowered = query.to_lowercase();
    let is_latin = lowered.chars().all(|c| c.is_ascii_alphabetic() || c == ' ');
    let hiragana = is_latin
        .then(|| romaji_to_hiragana(&lowered).ok())
        .flatten();
    std::iter::once(lowered).chain(hiragana).collect()
}

fn matches_query(def: &GrammarDef, forms: &[String]) -> bool {
    [&def.title_zh, &def.pattern, &def.meaning_zh]
        .iter()
        .map(|field| plain_text(field).to_lowercase())
        .any(|field| forms.iter().any(|form| field.contains(form.as_str())))
}

fn in_stage(def: &GrammarDef, stage: Option<&str>, views: &Views<'_>) -> bool {
    stage.is_none_or(|wanted| {
        views
            .content()
            .lesson(&def.lesson)
            .is_some_and(|lesson| lesson.stage == wanted)
    })
}

pub(crate) fn grammar_list(
    deps: &Deps,
    stage: Option<&str>,
    query: Option<&str>,
) -> Result<Vec<GrammarSummaryDto>, CoreError> {
    let views = Views::load(deps)?;
    let content = views.content();
    let forms = query
        .map(str::trim)
        .filter(|text| !text.is_empty())
        .map(query_forms);
    let mut matched: Vec<&GrammarDef> = content
        .grammar()
        .iter()
        .filter(|def| !def.retired && in_stage(def, stage, &views))
        .filter(|def| {
            forms
                .as_deref()
                .is_none_or(|forms| matches_query(def, forms))
        })
        .collect();
    matched.sort_by_key(|def| {
        (
            content.lesson_pos(&def.lesson).unwrap_or(u32::MAX),
            def.lesson_order,
        )
    });
    matched
        .into_iter()
        .map(|def| views.grammar_summary(def))
        .collect()
}

pub(crate) fn grammar_detail(deps: &Deps, grammar_id: &str) -> Result<GrammarDetailDto, CoreError> {
    let views = Views::load(deps)?;
    let def = views
        .content()
        .grammar_by_id(grammar_id)
        .ok_or_else(|| CoreError::not_found("grammar", grammar_id))?;
    views.grammar_detail(def, None)
}

fn is_kind(note: &NoteDef, kind: NoteKind) -> bool {
    matches!(
        (note, kind),
        (NoteDef::FalseFriend(_), NoteKind::FalseFriend)
            | (NoteDef::Shinjitai(_), NoteKind::Shinjitai)
            | (NoteDef::Reading(_), NoteKind::Reading)
            | (NoteDef::Transfer(_), NoteKind::Transfer)
            | (NoteDef::Term(_), NoteKind::Term)
    )
}

pub(crate) fn note_list(deps: &Deps, kind: NoteKind) -> Result<Vec<NoteDto>, CoreError> {
    Ok(deps
        .content
        .notes()
        .iter()
        .filter(|note| !note.retired() && is_kind(note, kind))
        .map(note_dto)
        .collect())
}

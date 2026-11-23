//! 句子與對話（§9.4）。

use super::deps::Deps;
use super::mapping::sentence::KnownCards;
use super::views::Views;
use crate::api::dto_content::{DialogueDto, DialogueSummaryDto, SentenceDto};
use crate::api::error::CoreError;

pub(crate) fn sentence(deps: &Deps, sentence_id: &str) -> Result<SentenceDto, CoreError> {
    let entry = deps
        .content
        .sentence_by_id(sentence_id)
        .ok_or_else(|| CoreError::not_found("sentence", sentence_id))?;
    KnownCards::new(&deps.repo).entry(entry)
}

pub(crate) fn dialogues(deps: &Deps) -> Result<Vec<DialogueSummaryDto>, CoreError> {
    let views = Views::load(deps)?;
    Ok(views
        .content()
        .dialogues()
        .iter()
        .filter(|entry| !entry.def.retired)
        .map(|entry| views.dialogue_summary(entry))
        .collect())
}

pub(crate) fn dialogue_detail(deps: &Deps, dialogue_id: &str) -> Result<DialogueDto, CoreError> {
    let views = Views::load(deps)?;
    let entry = views
        .content()
        .dialogue_by_id(dialogue_id)
        .ok_or_else(|| CoreError::not_found("dialogue", dialogue_id))?;
    views.dialogue(entry)
}

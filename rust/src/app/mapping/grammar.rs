//! 文法與筆記（§9.5）。

use std::collections::HashSet;

use jp_content::schema::{GrammarDef, NoteDef};
use jp_srs::{CardId, Facet};
use jp_store::SrsRepo;

use super::enums::{jlpt_level, register_name};
use crate::api::dto_content::{
    FormationRowDto, GrammarDetailDto, GrammarRefDto, GrammarStatus, GrammarSummaryDto, NoteDto,
    ReadingExampleDto,
};
use crate::api::error::CoreError;
use crate::app::views::Views;

pub(crate) fn note_dto(note: &NoteDef) -> NoteDto {
    match note {
        NoteDef::FalseFriend(n) => NoteDto::FalseFriend {
            id: n.id.clone(),
            surface: n.surface.clone(),
            ja_zh: n.ja_zh.clone(),
            misread_zh: n.misread_zh.clone(),
            vocab_id: n.vocab.clone(),
        },
        NoteDef::Shinjitai(n) => NoteDto::Shinjitai {
            id: n.id.clone(),
            ja: n.ja.clone(),
            zh_tw: n.zh_tw.clone(),
            kind: n.kind.clone(),
            vocab_ids: n.vocab.clone(),
        },
        NoteDef::Reading(n) => NoteDto::Reading {
            id: n.id.clone(),
            title_zh: n.title_zh.clone(),
            body_zh: n.body_zh.clone(),
            examples: n
                .examples
                .iter()
                .map(|example| ReadingExampleDto {
                    hanzi: example.hanzi.clone(),
                    tai: example.tai.clone(),
                    ja: example.ja.clone(),
                })
                .collect(),
            caveat_zh: n.caveat_zh.clone(),
        },
        NoteDef::Transfer(n) => NoteDto::Transfer {
            id: n.id.clone(),
            title_zh: n.title_zh.clone(),
            zh_pattern: n.zh_pattern.clone(),
            wrong: n.wrong.clone(),
            right: n.right.clone(),
            explain_zh: n.explain_zh.clone(),
        },
        NoteDef::Term(n) => NoteDto::Term {
            id: n.id.clone(),
            term: n.term.clone(),
            aka_zh: n.aka_zh.clone(),
            body_zh: n.body_zh.clone(),
            grammar_ids: n.grammar.clone(),
        },
    }
}

impl Views<'_> {
    /// 由 `item_intro` 與 `use` 卡狀態推導，不存蓋章狀態（§9.4）。
    fn grammar_status(&self, id: &str) -> Result<GrammarStatus, CoreError> {
        let card_id = CardId::new(id, Facet::Use).to_string();
        let practiced = self.deps.repo.card(&card_id)?.is_some_and(|c| c.reps >= 1);
        Ok(if practiced {
            GrammarStatus::Practiced
        } else if self.state.introduced.contains(id) {
            GrammarStatus::Introduced
        } else {
            GrammarStatus::NotStarted
        })
    }

    pub(crate) fn grammar_summary(&self, def: &GrammarDef) -> Result<GrammarSummaryDto, CoreError> {
        let stage_id = self
            .content()
            .lesson(&def.lesson)
            .map_or_else(String::new, |lesson| lesson.stage.clone());
        Ok(GrammarSummaryDto {
            id: def.id.clone(),
            title_zh: def.title_zh.clone(),
            pattern: def.pattern.clone(),
            meaning_zh: def.meaning_zh.clone(),
            lesson_id: def.lesson.clone(),
            stage_id,
            jlpt: jlpt_level(def.jlpt),
            status: self.grammar_status(&def.id)?,
        })
    }

    fn grammar_refs(&self, ids: &[String]) -> Vec<GrammarRefDto> {
        ids.iter()
            .filter_map(|id| self.content().grammar_by_id(id))
            .map(|def| GrammarRefDto {
                id: def.id.clone(),
                title_zh: def.title_zh.clone(),
            })
            .collect()
    }

    pub(crate) fn grammar_detail(
        &self,
        def: &GrammarDef,
        usable: Option<&HashSet<String>>,
    ) -> Result<GrammarDetailDto, CoreError> {
        Ok(GrammarDetailDto {
            summary: self.grammar_summary(def)?,
            explain_zh: def.explain_zh.clone(),
            compare_zh: def.compare_zh.clone(),
            trap_zh: def.trap_zh.clone(),
            formation: def
                .formation
                .iter()
                .map(|row| FormationRowDto {
                    from: row.from.clone(),
                    to: row.to.clone(),
                })
                .collect(),
            register: register_name(def.register).to_owned(),
            requires: self.grammar_refs(&def.requires),
            examples: self.examples(&def.examples, usable)?,
            contrast: self.grammar_refs(&def.contrast),
            terms: def
                .terms
                .iter()
                .filter_map(|id| self.content().note_by_id(id))
                .map(note_dto)
                .collect(),
        })
    }
}

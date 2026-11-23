//! 單字（§9.5）。

use std::collections::HashSet;

use jp_content::store::VocabEntry;
use jp_lang::grammar::conjugate::{conjugate_kana, conjugate_surface};
use jp_quiz::drill::conj_form_label;
use jp_srs::{CardId, Facet};
use jp_store::{SrsRepo, STATE_LEARNING, STATE_NEW, STATE_RELEARNING};

use super::enums::{jlpt_level, pos_name, transitivity, use_level, CONJUGATION_FORMS};
use super::sentence::{is_mastered, speech_dto};
use crate::api::dto_content::{
    ConjugationDto, SentenceDto, SrsStateLabel, UseLevelDto, VocabDetailDto, VocabRefDto,
    VocabSummaryDto,
};
use crate::api::error::CoreError;
use crate::app::views::Views;

/// 單字詳情的活用表：引擎算得出、且不在 `conj_omit` 的形。
fn conjugations(entry: &VocabEntry) -> Vec<ConjugationDto> {
    let def = &entry.def;
    CONJUGATION_FORMS
        .iter()
        .filter(|form| !def.conj_omit.contains(form))
        .filter_map(|&form| {
            Some(ConjugationDto {
                form: conj_form_label(form).to_owned(),
                surface: conjugate_surface(&def.surface, &def.kana, def.pos, form)?,
                kana: conjugate_kana(&def.kana, def.pos, form)?,
            })
        })
        .collect()
}

impl Views<'_> {
    /// 單字的進度看主卡片 `recog`。
    pub(crate) fn vocab_state(&self, id: &str) -> Result<SrsStateLabel, CoreError> {
        let card_id = CardId::new(id, Facet::Recog).to_string();
        let Some(card) = self.deps.repo.card(&card_id)? else {
            return Ok(SrsStateLabel::NotStarted);
        };
        Ok(match card.state {
            STATE_NEW => SrsStateLabel::NotStarted,
            STATE_LEARNING | STATE_RELEARNING => SrsStateLabel::Learning,
            _ if is_mastered(&card) => SrsStateLabel::Mastered,
            _ => SrsStateLabel::Review,
        })
    }

    pub(crate) fn vocab_summary(&self, entry: &VocabEntry) -> Result<VocabSummaryDto, CoreError> {
        let def = &entry.def;
        let flag = self.flags.get(&def.id);
        Ok(VocabSummaryDto {
            id: def.id.clone(),
            surface: def.surface.clone(),
            kana: def.kana.clone(),
            romaji: entry.romaji.clone(),
            zh: def.zh.clone(),
            pos: pos_name(def.pos).to_owned(),
            lesson_id: def.lesson.clone(),
            srs_state: self.vocab_state(&def.id)?,
            speech: speech_dto(&entry.speech),
            known: flag.is_some_and(|row| row.known),
            starred: flag.is_some_and(|row| row.starred),
        })
    }

    fn vocab_ref(&self, id: &str) -> Option<VocabRefDto> {
        self.content().vocab_by_id(id).map(|entry| VocabRefDto {
            id: entry.def.id.clone(),
            surface: entry.def.surface.clone(),
            kana: entry.def.kana.clone(),
            zh: entry.def.zh.clone(),
        })
    }

    /// `usable` 給定時只留可用句子（`new_content_session`，§7.3）。
    pub(crate) fn examples(
        &self,
        ids: &[String],
        usable: Option<&HashSet<String>>,
    ) -> Result<Vec<SentenceDto>, CoreError> {
        let content = self.content();
        ids.iter()
            .filter_map(|id| content.sentence_index(id))
            .filter(|&index| usable.is_none_or(|known| content.sentence_is_usable(index, known)))
            .map(|index| &content.sentences()[index as usize])
            .filter(|entry| !entry.def.retired)
            .map(|entry| self.known_cards().entry(entry))
            .collect()
    }

    pub(crate) fn vocab_detail(
        &self,
        entry: &VocabEntry,
        usable: Option<&HashSet<String>>,
    ) -> Result<VocabDetailDto, CoreError> {
        let def = &entry.def;
        Ok(VocabDetailDto {
            summary: self.vocab_summary(entry)?,
            accent: def.accent,
            jlpt: jlpt_level(def.jlpt),
            use_level: def.use_level.map_or(UseLevelDto::Safe, use_level),
            trans: def.trans.map(transitivity),
            same_form_zh: def.same_form_zh,
            hook_zh: def.hook_zh.clone(),
            trap_zh: def.trap_zh.clone(),
            pair: def.pair.as_deref().and_then(|id| self.vocab_ref(id)),
            reading_family: def
                .reading_family
                .iter()
                .filter_map(|id| self.vocab_ref(id))
                .collect(),
            examples: self.examples(&def.examples, usable)?,
            notes: def
                .notes
                .iter()
                .filter_map(|id| self.content().note_by_id(id))
                .map(super::grammar::note_dto)
                .collect(),
            conjugations: conjugations(entry),
        })
    }
}

#[cfg(test)]
mod tests {
    use jp_content::schema::{ConjForm, ContentStage, Pos, VocabDef};
    use jp_content::store::VocabEntry;
    use jp_content::test_support::load_full_fixture;

    use super::conjugations;

    fn fixture_entry(id: &str) -> VocabEntry {
        load_full_fixture(ContentStage::Full)
            .vocab_by_id(id)
            .expect("夾具應有此字")
            .clone()
    }

    fn with_def(entry: &VocabEntry, def: VocabDef) -> VocabEntry {
        VocabEntry {
            def,
            ..entry.clone()
        }
    }

    fn forms(entry: &VocabEntry) -> Vec<String> {
        conjugations(entry).into_iter().map(|c| c.form).collect()
    }

    #[test]
    fn conjugations_skip_conj_omit_forms() {
        let taberu = fixture_entry("vo.taberu");
        assert_eq!(forms(&taberu).len(), 10);
        let omitted = with_def(
            &taberu,
            VocabDef {
                conj_omit: vec![ConjForm::Potential, ConjForm::Imperative],
                ..taberu.def.clone()
            },
        );
        let left = forms(&omitted);
        assert_eq!(left.len(), 8);
        assert!(!left.iter().any(|form| form == "可能形" || form == "命令形"));
        assert!(left.iter().any(|form| form == "{ja:て}形"));
    }

    #[test]
    fn conjugations_of_v1_s_use_bare_imperative() {
        let taberu = fixture_entry("vo.taberu");
        let kureru = with_def(
            &taberu,
            VocabDef {
                surface: "くれる".to_owned(),
                kana: "くれる".to_owned(),
                pos: Pos::V1S,
                ..taberu.def.clone()
            },
        );
        let imperative = conjugations(&kureru)
            .into_iter()
            .find(|c| c.form == "命令形")
            .expect("有命令形");
        assert_eq!(imperative.surface, "くれ");
        assert_eq!(imperative.kana, "くれ");
    }
}

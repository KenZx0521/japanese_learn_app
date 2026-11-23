//! `impl AppCore`：查詢內容、單字旗標、筆記（rust-core.md §9.4）。

use super::core::AppCore;
use super::dto_content::{
    CourseOverviewDto, DialogueDto, DialogueSummaryDto, GrammarDetailDto, GrammarSummaryDto,
    KanaDetailDto, KanaGroupDto, KanaScript, LessonDetailDto, NoteDto, NoteKind, PeekDto,
    RuleCardDto, SentenceDto, SoundGroupDto, TopicDto, VocabDetailDto, VocabFilterDto,
    VocabFlagsDto, VocabPageDto, VocabSummaryDto,
};
use super::error::CoreError;
use crate::app::{course, dialogue, grammar, kana, peek, vocab};

impl AppCore {
    pub fn course_overview(&self) -> Result<CourseOverviewDto, CoreError> {
        course::course_overview(&self.deps)
    }

    pub fn lesson_detail(&self, lesson_id: String) -> Result<LessonDetailDto, CoreError> {
        course::lesson_detail(&self.deps, &lesson_id)
    }

    pub fn kana_chart(&self, script: KanaScript) -> Result<Vec<KanaGroupDto>, CoreError> {
        kana::kana_chart(&self.deps, script)
    }

    pub fn kana_detail(&self, kana_id: String) -> Result<KanaDetailDto, CoreError> {
        kana::kana_detail(&self.deps, &kana_id)
    }

    pub fn rule_card(&self, rule_id: String) -> Result<RuleCardDto, CoreError> {
        kana::rule_card(&self.deps, &rule_id)
    }

    pub fn sound_groups(&self) -> Result<Vec<SoundGroupDto>, CoreError> {
        kana::sound_groups(&self.deps)
    }

    pub fn vocab_page(
        &self,
        filter: VocabFilterDto,
        offset: u32,
        limit: u32,
    ) -> Result<VocabPageDto, CoreError> {
        vocab::vocab_page(&self.deps, &filter, offset, limit)
    }

    pub fn vocab_detail(&self, vocab_id: String) -> Result<VocabDetailDto, CoreError> {
        vocab::vocab_detail(&self.deps, &vocab_id)
    }

    pub fn search_vocab(
        &self,
        query: String,
        limit: u32,
    ) -> Result<Vec<VocabSummaryDto>, CoreError> {
        vocab::search_vocab(&self.deps, &query, limit)
    }

    pub fn set_vocab_flags(
        &self,
        vocab_id: String,
        flags: VocabFlagsDto,
    ) -> Result<VocabSummaryDto, CoreError> {
        vocab::set_vocab_flags(&self.deps, &vocab_id, flags)
    }

    pub fn vocab_topics(&self) -> Result<Vec<TopicDto>, CoreError> {
        vocab::vocab_topics(&self.deps)
    }

    pub fn grammar_list(
        &self,
        stage: Option<String>,
        query: Option<String>,
    ) -> Result<Vec<GrammarSummaryDto>, CoreError> {
        grammar::grammar_list(&self.deps, stage.as_deref(), query.as_deref())
    }

    pub fn grammar_detail(&self, grammar_id: String) -> Result<GrammarDetailDto, CoreError> {
        grammar::grammar_detail(&self.deps, &grammar_id)
    }

    pub fn note_list(&self, kind: NoteKind) -> Result<Vec<NoteDto>, CoreError> {
        grammar::note_list(&self.deps, kind)
    }

    pub fn sentence(&self, sentence_id: String) -> Result<SentenceDto, CoreError> {
        dialogue::sentence(&self.deps, &sentence_id)
    }

    pub fn dialogues(&self) -> Result<Vec<DialogueSummaryDto>, CoreError> {
        dialogue::dialogues(&self.deps)
    }

    pub fn dialogue_detail(&self, dialogue_id: String) -> Result<DialogueDto, CoreError> {
        dialogue::dialogue_detail(&self.deps, &dialogue_id)
    }

    pub fn peek(&self, ref_id: String) -> Result<PeekDto, CoreError> {
        peek::peek(&self.deps, &ref_id)
    }
}

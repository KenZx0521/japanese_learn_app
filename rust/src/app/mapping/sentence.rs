//! 句子、語音、振假名與 `is_known`（§3.3、§9.4、§9.5）。

use jp_content::mixed::MixedSpan;
use jp_content::schema::Style;
use jp_content::sentence::{ParsedSentence, ParsedWord, Speech};
use jp_content::store::{DialogueEntry, SentenceEntry};
use jp_lang::kana::Ruby;
use jp_quiz::model::SentenceView;
use jp_srs::{CardId, Facet};
use jp_store::{CardRow, SqliteRepository, SrsRepo, MASTERED_MIN_SCHEDULED_DAYS, STATE_REVIEW};

use super::enums::style_name;
use crate::api::dto_content::{MixedSpanDto, RubyPartDto, SentenceDto, SpeechDto, WordDto};
use crate::api::error::CoreError;

const VOCAB_PREFIX: &str = "vo.";
const DIALOGUE_TURN_SEPARATOR: char = '#';

pub(crate) fn speech_dto(speech: &Speech) -> SpeechDto {
    SpeechDto {
        text: speech.text.clone(),
        kana: speech.kana.clone(),
    }
}

pub(crate) fn ruby_dto(part: &Ruby) -> RubyPartDto {
    RubyPartDto {
        base: part.base.clone(),
        ruby: part.ruby.clone(),
    }
}

pub(crate) fn mixed_span_dto(span: &MixedSpan) -> MixedSpanDto {
    match span {
        MixedSpan::Zh { text } => MixedSpanDto::Zh { text: text.clone() },
        MixedSpan::Ja { text, ruby } => MixedSpanDto::Ja {
            text: text.clone(),
            ruby: ruby.iter().map(ruby_dto).collect(),
        },
    }
}

pub(crate) fn is_mastered(card: &CardRow) -> bool {
    card.state == STATE_REVIEW && card.scheduled_days >= MASTERED_MIN_SCHEDULED_DAYS
}

/// `WordDto.is_known`：`ref_id` 的主卡片已熟（§9.4）。
#[derive(Clone, Copy)]
pub(crate) struct KnownCards<'a> {
    repo: &'a SqliteRepository,
}

impl<'a> KnownCards<'a> {
    pub(crate) fn new(repo: &'a SqliteRepository) -> Self {
        Self { repo }
    }

    fn is_known(&self, ref_id: &str) -> Result<bool, CoreError> {
        let facet = if ref_id.starts_with(VOCAB_PREFIX) {
            Facet::Recog
        } else {
            Facet::Use
        };
        let card = self.repo.card(&CardId::new(ref_id, facet).to_string())?;
        Ok(card.is_some_and(|card| is_mastered(&card)))
    }

    fn word(&self, word: &ParsedWord) -> Result<WordDto, CoreError> {
        let is_known = match &word.ref_id {
            Some(ref_id) => self.is_known(ref_id)?,
            None => false,
        };
        Ok(WordDto {
            surface: word.surface.clone(),
            kana: word.kana.clone(),
            romaji: word.romaji.clone(),
            speech_kana: word.speech_kana.clone(),
            ruby: word.ruby.iter().map(ruby_dto).collect(),
            refs: word.refs.clone(),
            ref_id: word.ref_id.clone(),
            gloss_zh: word.gloss_zh.clone(),
            is_punct: word.is_punct,
            is_known,
        })
    }

    fn words(&self, parsed: &ParsedSentence) -> Result<Vec<WordDto>, CoreError> {
        parsed.words.iter().map(|word| self.word(word)).collect()
    }

    fn sentence(
        &self,
        id: &str,
        zh: &str,
        style: Style,
        parsed: &ParsedSentence,
    ) -> Result<SentenceDto, CoreError> {
        Ok(SentenceDto {
            id: id.to_owned(),
            display: parsed.display.clone(),
            romaji: parsed.romaji.clone(),
            zh: zh.to_owned(),
            style: style_name(style).to_owned(),
            words: self.words(parsed)?,
            speech: speech_dto(&parsed.speech),
        })
    }

    pub(crate) fn entry(&self, entry: &SentenceEntry) -> Result<SentenceDto, CoreError> {
        self.sentence(&entry.def.id, &entry.def.zh, entry.def.style, &entry.parsed)
    }

    pub(crate) fn view(&self, view: &SentenceView) -> Result<SentenceDto, CoreError> {
        self.sentence(&view.id, &view.zh, view.style, &view.parsed)
    }

    /// 對話逐句，ID 以 `<對話>#<第幾句>` 組成。
    pub(crate) fn turn(
        &self,
        dialogue: &DialogueEntry,
        index: usize,
    ) -> Result<SentenceDto, CoreError> {
        let turn = &dialogue.def.turns[index];
        let id = format!("{}{DIALOGUE_TURN_SEPARATOR}{index}", dialogue.def.id);
        self.sentence(&id, &turn.zh, dialogue.def.style, &dialogue.turns[index])
    }
}

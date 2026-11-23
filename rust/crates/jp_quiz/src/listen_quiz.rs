//! 聽力 session 與自動補的 `listen_meaning`（§8.4、§9.4）。

use std::collections::HashSet;

use jp_content::store::SentenceEntry;
use jp_lang::quiz::rng::{rng_from_seed, seed_for, shuffled, ChaCha8Rng};
use jp_srs::use_cards::{sentence_is_usable_now, UseQuery};

use crate::context::{QuestionKey, QuizContext};
use crate::error::QuizError;
use crate::model::{ChoiceOption, Prompt, Question, QuestionBody, QuestionRef};
use crate::question_type::QuestionType;
use crate::view::sentence_view;

const MAX_DISTRACTORS: usize = 3;
const SENTENCE_OPTION_PREFIX: &str = "s:";
const FOCUS_REF_PREFIX: &str = "gr.";
/// 每 3 題的第 3 題是跟讀（§9.4）。
const SHADOW_EVERY: usize = 3;
const LISTEN_SESSION_SEED_KEY: &str = "listen_session";

const LISTEN_INSTRUCTION: &str = "聽句子，選出意思";
const SHADOW_INSTRUCTION: &str = "跟著念一次";

pub(crate) fn sentence_option_id(sentence_id: &str) -> String {
    format!("{SENTENCE_OPTION_PREFIX}{sentence_id}")
}

/// 句子 `t` 內的 `gr.*`，依出現順序去重（§8.4）。
fn focus_ids(entry: &SentenceEntry) -> Vec<String> {
    let mut seen = HashSet::new();
    entry
        .parsed
        .words
        .iter()
        .flat_map(|word| word.refs.iter())
        .filter(|reference| reference.starts_with(FOCUS_REF_PREFIX))
        .filter(|reference| seen.insert(reference.as_str()))
        .cloned()
        .collect()
}

fn reference(
    question_type: QuestionType,
    entry: &SentenceEntry,
    key: QuestionKey<'_>,
) -> QuestionRef {
    QuestionRef {
        question_type,
        card_id: key.card_id.map(str::to_owned),
        drill_id: None,
        content_id: entry.def.id.clone(),
        variant: None,
    }
}

fn zh_option(entry: &SentenceEntry) -> ChoiceOption {
    ChoiceOption {
        id: sentence_option_id(&entry.def.id),
        text: entry.def.zh.clone(),
        ..ChoiceOption::default()
    }
}

/// 同課優先，排除中文相同者；同層內以種子洗牌。
fn distractors<'c>(
    ctx: &QuizContext<'c>,
    index: u32,
    rng: &mut ChaCha8Rng,
) -> Vec<&'c SentenceEntry> {
    let sentences = ctx.content.sentences();
    let target = &sentences[index as usize];
    let query = UseQuery {
        content_id: &target.def.id,
        cursor_pos: ctx.cursor_pos,
        known: ctx.known,
        audio_available: ctx.audio_available,
    };
    let (same_lesson, others): (Vec<_>, Vec<_>) = sentences
        .iter()
        .zip(0u32..)
        .filter(|(other, other_index)| {
            *other_index != index
                && other.def.zh != target.def.zh
                && sentence_is_usable_now(*other_index, &query, ctx.content)
        })
        .map(|(other, _)| other)
        .partition(|other| other.def.lesson == target.def.lesson);
    let first = shuffled(rng, same_lesson);
    let second = shuffled(rng, others);
    let mut seen = HashSet::new();
    first
        .into_iter()
        .chain(second)
        .filter(|other| seen.insert(other.def.zh.as_str()))
        .take(MAX_DISTRACTORS)
        .collect()
}

/// 少於 1 個干擾項時回 `None`（§8.4）。
pub fn auto_listen_meaning(
    ctx: &QuizContext<'_>,
    sentence_index: u32,
    key: QuestionKey<'_>,
) -> Result<Option<Question>, QuizError> {
    let target = &ctx.content.sentences()[sentence_index as usize];
    let mut rng = key.rng(ctx.session_seed);
    let picked = distractors(ctx, sentence_index, &mut rng);
    if picked.is_empty() {
        return Ok(None);
    }
    let view = sentence_view(target, None);
    let options = std::iter::once(target)
        .chain(picked)
        .map(zh_option)
        .collect();
    let prompt = Prompt {
        instruction_zh: LISTEN_INSTRUCTION.to_owned(),
        speech: Some(view.parsed.speech.clone()),
        text: Some(view),
        autoplay: true,
        hide_text_until_answered: true,
        ..Prompt::default()
    };
    let body = QuestionBody::Choice {
        options: shuffled(&mut rng, options),
        correct_option_id: sentence_option_id(&target.def.id),
        blank_word_index: None,
    };
    let question = Question::new(
        reference(QuestionType::ListenMeaning, target, key),
        prompt,
        body,
    );
    Ok(Some(question.with_focus(focus_ids(target))))
}

fn shadowing_question(ctx: &QuizContext<'_>, index: u32, key: QuestionKey<'_>) -> Question {
    let target = &ctx.content.sentences()[index as usize];
    let view = sentence_view(target, None);
    let prompt = Prompt {
        instruction_zh: SHADOW_INSTRUCTION.to_owned(),
        speech: Some(view.parsed.speech.clone()),
        text: Some(view.clone()),
        autoplay: true,
        ..Prompt::default()
    };
    let body = QuestionBody::Shadow {
        reveal: Box::new(view),
    };
    Question::new(
        reference(QuestionType::Shadowing, target, key),
        prompt,
        body,
    )
    .with_focus(focus_ids(target))
}

/// 今日 `Listen` 任務（§9.4）。快照可能早於內容更新，已不存在的句子直接略過。
pub fn listen_session(
    ctx: &QuizContext<'_>,
    sentence_ids: &[String],
) -> Result<Vec<Question>, QuizError> {
    if !ctx.audio_available {
        return Ok(Vec::new());
    }
    let existing: Vec<(&str, u32)> = sentence_ids
        .iter()
        .filter_map(|id| {
            ctx.content
                .sentence_index(id)
                .map(|index| (id.as_str(), index))
        })
        .collect();
    let mut rng = rng_from_seed(seed_for(ctx.session_seed, LISTEN_SESSION_SEED_KEY));
    let mut questions: Vec<Question> = Vec::with_capacity(existing.len());
    for (id, index) in shuffled(&mut rng, existing) {
        let key = QuestionKey::plain(id);
        let next = if questions.len() % SHADOW_EVERY == SHADOW_EVERY - 1 {
            Some(shadowing_question(ctx, index, key))
        } else {
            auto_listen_meaning(ctx, index, key)?
        };
        questions.extend(next);
    }
    Ok(questions)
}

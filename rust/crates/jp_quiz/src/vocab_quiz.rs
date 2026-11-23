//! 單字題（§8.3）。

use jp_content::store::VocabEntry;
use jp_lang::quiz::rng::{shuffled, ChaCha8Rng};

use crate::context::{QuestionKey, QuizContext};
use crate::distractor::vocab_distractors;
use crate::error::QuizError;
use crate::model::{ChoiceOption, Prompt, Question, QuestionBody, QuestionRef};
use crate::question_type::QuestionType;
use crate::view::{join_zh, mixed_ja, mixed_word, strip_spaces, vocab_reveal};

const MIN_DISTRACTORS: usize = 2;

const RECOG_INSTRUCTION: &str = "選出這個字的意思";
const LISTEN_INSTRUCTION: &str = "聽聲音，選出意思";
const PRODUCE_INSTRUCTION: &str = "想想日文怎麼說";

fn vocab_entry<'c>(ctx: &QuizContext<'c>, vocab_id: &str) -> Result<&'c VocabEntry, QuizError> {
    ctx.content
        .vocab_by_id(vocab_id)
        .ok_or_else(|| QuizError::not_found("vocab", vocab_id))
}

fn zh_option(entry: &VocabEntry) -> ChoiceOption {
    ChoiceOption {
        id: entry.def.id.clone(),
        text: join_zh(&entry.def.zh),
        ..ChoiceOption::default()
    }
}

/// 少於 2 個干擾項時退回 `SelfGrade`，`question_type` 不變（§8.3、§8.6）。
fn choice_or_self_grade(
    ctx: &QuizContext<'_>,
    target: &VocabEntry,
    rng: &mut ChaCha8Rng,
) -> QuestionBody {
    let distractors = vocab_distractors(target, ctx.known, ctx.content, rng);
    if distractors.len() < MIN_DISTRACTORS {
        return QuestionBody::SelfGrade {
            reveal: Box::new(vocab_reveal(target)),
        };
    }
    let options = std::iter::once(target)
        .chain(distractors)
        .map(zh_option)
        .collect();
    QuestionBody::Choice {
        options: shuffled(rng, options),
        correct_option_id: target.def.id.clone(),
        blank_word_index: None,
    }
}

fn build(
    question_type: QuestionType,
    target: &VocabEntry,
    key: QuestionKey<'_>,
    prompt: Prompt,
    body: QuestionBody,
) -> Question {
    let reference = QuestionRef {
        question_type,
        card_id: key.card_id.map(str::to_owned),
        drill_id: None,
        content_id: target.def.id.clone(),
        variant: None,
    };
    Question::new(reference, prompt, body).with_focus(vec![target.def.id.clone()])
}

/// 與中文同形的字：有語音時先播音再選意思，否則只顯示假名（§6.1）。
fn recog_prompt(ctx: &QuizContext<'_>, target: &VocabEntry) -> Prompt {
    let base = Prompt {
        instruction_zh: RECOG_INSTRUCTION.to_owned(),
        plain_text: Some(mixed_word(target)),
        speech: Some(target.speech.clone()),
        ..Prompt::default()
    };
    match (target.def.same_form_zh, ctx.audio_available) {
        (true, true) => Prompt {
            autoplay: true,
            hide_text_until_answered: true,
            ..base
        },
        (true, false) => {
            let kana = strip_spaces(&target.def.kana);
            Prompt {
                plain_text: Some(mixed_ja(&kana, &kana)),
                speech: None,
                ..base
            }
        }
        (false, _) => base,
    }
}

pub fn recog_question(
    ctx: &QuizContext<'_>,
    vocab_id: &str,
    key: QuestionKey<'_>,
) -> Result<Question, QuizError> {
    let target = vocab_entry(ctx, vocab_id)?;
    let mut rng = key.rng(ctx.session_seed);
    let body = choice_or_self_grade(ctx, target, &mut rng);
    Ok(build(
        QuestionType::Recog,
        target,
        key,
        recog_prompt(ctx, target),
        body,
    ))
}

pub fn vocab_listen_question(
    ctx: &QuizContext<'_>,
    vocab_id: &str,
    key: QuestionKey<'_>,
) -> Result<Question, QuizError> {
    let target = vocab_entry(ctx, vocab_id)?;
    let mut rng = key.rng(ctx.session_seed);
    let body = choice_or_self_grade(ctx, target, &mut rng);
    let prompt = Prompt {
        instruction_zh: LISTEN_INSTRUCTION.to_owned(),
        plain_text: Some(mixed_word(target)),
        speech: Some(target.speech.clone()),
        autoplay: true,
        hide_text_until_answered: true,
        ..Prompt::default()
    };
    Ok(build(QuestionType::VocabListen, target, key, prompt, body))
}

/// 中→日回想，一律自評（§6.1）。
pub fn produce_question(
    ctx: &QuizContext<'_>,
    vocab_id: &str,
    key: QuestionKey<'_>,
) -> Result<Question, QuizError> {
    let target = vocab_entry(ctx, vocab_id)?;
    let prompt = Prompt {
        instruction_zh: PRODUCE_INSTRUCTION.to_owned(),
        plain_text: Some(join_zh(&target.def.zh)),
        ..Prompt::default()
    };
    let body = QuestionBody::SelfGrade {
        reveal: Box::new(vocab_reveal(target)),
    };
    Ok(build(QuestionType::Produce, target, key, prompt, body))
}

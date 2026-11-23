//! `Choice` 類手寫題：`particle_fill`、`zh_to_ja_choice`、`situation_response`、
//! `listen_meaning`、`false_friend`。

use jp_content::schema::{BlankDef, DistractorDef, DrillDef, NoteDef, Style, TtsMode};
use jp_content::sentence::{analyze_t, ParsedSentence};
use jp_content::ContentStore;
use jp_lang::quiz::rng::{shuffled, ChaCha8Rng};

use crate::drill::{wrong_kind, Draft};
use crate::error::QuizError;
use crate::model::{ChoiceOption, Prompt, QuestionBody, SentenceView};
use crate::view::{answer_view, inline_view, lookup_sentence, sentence_view, InlineT};

const ANSWER_OPTION_ID: &str = "a";

const PARTICLE_INSTRUCTION: &str = "選出正確的助詞";
const ZH_TO_JA_INSTRUCTION: &str = "選出正確的日文";
const SITUATION_INSTRUCTION: &str = "依情境選出合適的回應";
const LISTEN_INSTRUCTION: &str = "聽句子，選出意思";
const FALSE_FRIEND_INSTRUCTION: &str = "選出正確的意思";

pub(super) fn choice_id(index: usize) -> String {
    format!("c{index}")
}

fn distractor_id(index: usize) -> String {
    format!("d{index}")
}

pub(super) fn answer_option_id() -> &'static str {
    ANSWER_OPTION_ID
}

fn choice_body(
    options: Vec<ChoiceOption>,
    correct_id: String,
    blank_word_index: Option<u32>,
    rng: &mut ChaCha8Rng,
) -> QuestionBody {
    QuestionBody::Choice {
        options: shuffled(rng, options),
        correct_option_id: correct_id,
        blank_word_index,
    }
}

pub(super) fn single_blank<'d>(
    id: &str,
    blanks: &'d [BlankDef],
) -> Result<&'d BlankDef, QuizError> {
    blanks
        .first()
        .ok_or_else(|| QuizError::content(id, "particle_fill 沒有 blanks"))
}

pub(super) fn analyze_fragment(id: &str, t: &str) -> Result<ParsedSentence, QuizError> {
    analyze_t(t, None, None).map_err(|err| QuizError::content(id, err))
}

/// 正解是與句中該詞 surface 相同的選項。
pub(super) fn correct_blank_index(
    id: &str,
    sentence: &ParsedSentence,
    blank: &BlankDef,
) -> Result<usize, QuizError> {
    let word = sentence
        .words
        .get(blank.word_index as usize)
        .ok_or_else(|| QuizError::content(id, "word_index 超出範圍"))?;
    let parsed = blank
        .choices
        .iter()
        .map(|choice| analyze_fragment(id, choice))
        .collect::<Result<Vec<_>, _>>()?;
    parsed
        .iter()
        .position(|choice| choice.display == word.surface)
        .ok_or_else(|| QuizError::content(id, "選項沒有句中的詞"))
}

pub(super) fn particle_fill(
    content: &ContentStore,
    drill: &DrillDef,
    rng: &mut ChaCha8Rng,
) -> Result<Draft, QuizError> {
    let DrillDef::ParticleFill {
        sentence,
        blanks,
        explain_zh,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let id = drill.id();
    let view = sentence_view(lookup_sentence(content, sentence)?, None);
    let blank = single_blank(id, blanks)?;
    let correct = correct_blank_index(id, &view.parsed, blank)?;
    let options = blank
        .choices
        .iter()
        .enumerate()
        .map(|(index, choice)| {
            Ok(ChoiceOption {
                id: choice_id(index),
                text: analyze_fragment(id, choice)?.display,
                ..ChoiceOption::default()
            })
        })
        .collect::<Result<Vec<_>, QuizError>>()?;
    // 正解常靠語境決定（は／も、ね／よ），作答時要看得到中文
    let prompt = Prompt {
        instruction_zh: PARTICLE_INSTRUCTION.to_owned(),
        plain_text: Some(view.zh.clone()),
        text: Some(view),
        ..Prompt::default()
    };
    let body = choice_body(options, choice_id(correct), Some(blank.word_index), rng);
    Ok(Draft {
        explain_zh: explain_zh.clone(),
        ..Draft::new(prompt, body)
    })
}

fn view_option(option_id: String, view: SentenceView, why_zh: Option<String>) -> ChoiceOption {
    ChoiceOption {
        id: option_id,
        text: view.parsed.display.clone(),
        speech: Some(view.parsed.speech.clone()),
        sentence: Some(view),
        why_zh,
    }
}

/// `answer` 的 `SentenceView`；內嵌 `t` 沒有自己的中文，由呼叫端傳入。
#[derive(Debug, Clone, Copy)]
pub(super) struct AnswerFields<'a> {
    pub drill_id: &'a str,
    pub answer: &'a str,
    pub zh: &'a str,
    pub style: Style,
    pub tts: Option<TtsMode>,
}

pub(super) fn answer_sentence(
    content: &ContentStore,
    fields: AnswerFields<'_>,
) -> Result<SentenceView, QuizError> {
    let id = format!("{}:{ANSWER_OPTION_ID}", fields.drill_id);
    answer_view(
        content,
        InlineT {
            t: fields.answer,
            id: &id,
            zh: fields.zh,
            style: fields.style,
            own_tts: None,
            drill_tts: fields.tts,
        },
    )
}

fn answer_options(
    content: &ContentStore,
    fields: AnswerFields<'_>,
    distractors: &[DistractorDef],
) -> Result<Vec<ChoiceOption>, QuizError> {
    let answer = answer_sentence(content, fields)?;
    let first = view_option(ANSWER_OPTION_ID.to_owned(), answer, None);
    let rest = distractors.iter().enumerate().map(|(index, distractor)| {
        let option_id = distractor_id(index);
        let view_id = format!("{}:{option_id}", fields.drill_id);
        let view = inline_view(InlineT {
            t: &distractor.t,
            id: &view_id,
            zh: "",
            style: fields.style,
            own_tts: None,
            drill_tts: fields.tts,
        })?;
        Ok(view_option(
            option_id,
            view,
            Some(distractor.why_zh.clone()),
        ))
    });
    std::iter::once(Ok(first)).chain(rest).collect()
}

pub(super) fn zh_to_ja(
    content: &ContentStore,
    drill: &DrillDef,
    rng: &mut ChaCha8Rng,
) -> Result<Draft, QuizError> {
    let DrillDef::ZhToJaChoice {
        prompt_zh,
        answer,
        distractors,
        tts,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let fields = AnswerFields {
        drill_id: drill.id(),
        answer,
        zh: prompt_zh,
        style: Style::Neutral,
        tts: *tts,
    };
    let options = answer_options(content, fields, distractors)?;
    let prompt = Prompt {
        instruction_zh: ZH_TO_JA_INSTRUCTION.to_owned(),
        plain_text: Some(prompt_zh.clone()),
        ..Prompt::default()
    };
    let body = choice_body(options, ANSWER_OPTION_ID.to_owned(), None, rng);
    Ok(Draft::new(prompt, body))
}

fn situation_prompt(
    id: &str,
    situation_zh: &str,
    line: Option<&String>,
    style: Style,
    tts: Option<TtsMode>,
) -> Result<Prompt, QuizError> {
    let view_id = format!("{id}:prompt");
    let text = line
        .map(|t| {
            inline_view(InlineT {
                t,
                id: &view_id,
                zh: "",
                style,
                own_tts: None,
                drill_tts: tts,
            })
        })
        .transpose()?;
    Ok(Prompt {
        instruction_zh: SITUATION_INSTRUCTION.to_owned(),
        plain_text: Some(situation_zh.to_owned()),
        speech: text.as_ref().map(|view| view.parsed.speech.clone()),
        text,
        ..Prompt::default()
    })
}

fn zh_choice_options(choices: &[String]) -> Vec<ChoiceOption> {
    choices
        .iter()
        .enumerate()
        .map(|(index, text)| ChoiceOption {
            id: choice_id(index),
            text: text.clone(),
            ..ChoiceOption::default()
        })
        .collect()
}

fn listen_prompt(instruction: &str, view: SentenceView) -> Prompt {
    Prompt {
        instruction_zh: instruction.to_owned(),
        speech: Some(view.parsed.speech.clone()),
        text: Some(view),
        autoplay: true,
        hide_text_until_answered: true,
        ..Prompt::default()
    }
}

/// `false_friend` 的筆記內容，答後顯示（flutter-app §3.6）。
pub(super) fn false_friend_explain(
    content: &ContentStore,
    id: &str,
    note: &str,
) -> Result<String, QuizError> {
    match content.note_by_id(note) {
        Some(NoteDef::FalseFriend(def)) => Ok(format!("{}；{}", def.ja_zh, def.misread_zh)),
        _ => Err(QuizError::content(id, format!("找不到筆記 {note}"))),
    }
}

pub(super) fn situation_response(
    content: &ContentStore,
    drill: &DrillDef,
    rng: &mut ChaCha8Rng,
) -> Result<Draft, QuizError> {
    let DrillDef::SituationResponse {
        situation_zh,
        style,
        prompt,
        answer,
        distractors,
        tts,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let id = drill.id();
    let style = style.unwrap_or(Style::Neutral);
    let fields = AnswerFields {
        drill_id: id,
        answer,
        zh: "",
        style,
        tts: *tts,
    };
    let options = answer_options(content, fields, distractors)?;
    let question_prompt = situation_prompt(id, situation_zh, prompt.as_ref(), style, *tts)?;
    let body = choice_body(options, ANSWER_OPTION_ID.to_owned(), None, rng);
    Ok(Draft::new(question_prompt, body))
}

pub(super) fn listen_meaning(
    content: &ContentStore,
    drill: &DrillDef,
    rng: &mut ChaCha8Rng,
) -> Result<Draft, QuizError> {
    let DrillDef::ListenMeaning {
        sentence,
        choices_zh,
        answer_index,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let view = sentence_view(lookup_sentence(content, sentence)?, None);
    let prompt = listen_prompt(LISTEN_INSTRUCTION, view);
    let correct = choice_id(*answer_index as usize);
    let body = choice_body(zh_choice_options(choices_zh), correct, None, rng);
    Ok(Draft::new(prompt, body))
}

pub(super) fn false_friend(
    content: &ContentStore,
    drill: &DrillDef,
    rng: &mut ChaCha8Rng,
) -> Result<Draft, QuizError> {
    let DrillDef::FalseFriend {
        note,
        prompt_zh,
        choices_zh,
        answer_index,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let prompt = Prompt {
        instruction_zh: FALSE_FRIEND_INSTRUCTION.to_owned(),
        plain_text: Some(prompt_zh.clone()),
        ..Prompt::default()
    };
    let correct = choice_id(*answer_index as usize);
    let body = choice_body(zh_choice_options(choices_zh), correct, None, rng);
    Ok(Draft {
        explain_zh: Some(false_friend_explain(content, drill.id(), note)?),
        ..Draft::new(prompt, body)
    })
}

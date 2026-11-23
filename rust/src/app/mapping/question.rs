//! 題目與作答（§9.5）：領域型別↔DTO。

use jp_quiz::model::{
    Answer, AnswerPayload as QuizPayload, ChoiceOption, GradeResult, MatchPair, Prompt, Question,
    QuestionBody, QuestionRef, ReorderChunk,
};
use jp_srs::Outcome;

use super::enums::{
    question_type_domain, question_type_dto, rating_domain, rating_dto, shadow_domain,
};
use super::sentence::{speech_dto, KnownCards};
use crate::api::dto_study::{
    AnswerDto, AnswerPayload, ChunkDto, DrillResultDto, MatchPairDto, OptionDto, PromptDto,
    QuestionBodyDto, QuestionDto, QuestionRefDto, RatingPreviewDto,
};
use crate::api::error::CoreError;

pub(crate) fn reference_dto(reference: &QuestionRef) -> QuestionRefDto {
    QuestionRefDto {
        question_type: question_type_dto(reference.question_type),
        card_id: reference.card_id.clone(),
        drill_id: reference.drill_id.clone(),
        content_id: reference.content_id.clone(),
        variant: reference.variant,
    }
}

pub(crate) fn reference_domain(dto: &QuestionRefDto) -> QuestionRef {
    QuestionRef {
        question_type: question_type_domain(dto.question_type),
        card_id: dto.card_id.clone(),
        drill_id: dto.drill_id.clone(),
        content_id: dto.content_id.clone(),
        variant: dto.variant,
    }
}

pub(crate) fn payload_domain(payload: &AnswerPayload) -> QuizPayload {
    match payload {
        AnswerPayload::Choice { option_id } => QuizPayload::Choice {
            option_id: option_id.clone(),
        },
        AnswerPayload::Reorder { order } => QuizPayload::Reorder {
            order: order.clone(),
        },
        AnswerPayload::Typing { input } => QuizPayload::Typing {
            input: input.clone(),
        },
        AnswerPayload::Match { all_correct } => QuizPayload::Match {
            all_correct: *all_correct,
        },
        AnswerPayload::SelfGrade { rating } => QuizPayload::SelfGrade {
            rating: rating_domain(*rating),
        },
        AnswerPayload::Shadow { level } => QuizPayload::Shadow {
            level: shadow_domain(*level),
        },
    }
}

pub(crate) fn answer_domain(answer: &AnswerDto) -> Answer {
    Answer {
        reference: reference_domain(&answer.reference),
        expected_reps: answer.expected_reps,
        response: payload_domain(&answer.response),
        hint_used: answer.hint_used,
        attempts: answer.attempts,
        duration_ms: answer.duration_ms,
    }
}

pub(crate) fn rating_preview(outcome: &Outcome) -> RatingPreviewDto {
    RatingPreviewDto {
        rating: rating_dto(outcome.rating),
        interval_minutes: outcome.interval_minutes(),
    }
}

fn option_dto(option: &ChoiceOption, known: KnownCards<'_>) -> Result<OptionDto, CoreError> {
    Ok(OptionDto {
        id: option.id.clone(),
        text: option.text.clone(),
        sentence: option
            .sentence
            .as_ref()
            .map(|sentence| known.view(sentence))
            .transpose()?,
        speech: option.speech.as_ref().map(speech_dto),
        why_zh: option.why_zh.clone(),
    })
}

fn chunk_dto(chunk: &ReorderChunk) -> ChunkDto {
    ChunkDto {
        index: chunk.index,
        text: chunk.text.clone(),
    }
}

fn match_pair_dto(pair: &MatchPair) -> MatchPairDto {
    MatchPairDto {
        left_id: pair.left_id.clone(),
        left: pair.left.clone(),
        right_id: pair.right_id.clone(),
        right: pair.right.clone(),
    }
}

fn prompt_dto(prompt: &Prompt, known: KnownCards<'_>) -> Result<PromptDto, CoreError> {
    Ok(PromptDto {
        instruction_zh: prompt.instruction_zh.clone(),
        text: prompt
            .text
            .as_ref()
            .map(|text| known.view(text))
            .transpose()?,
        plain_text: prompt.plain_text.clone(),
        speech: prompt.speech.as_ref().map(speech_dto),
        autoplay: prompt.autoplay,
        hide_text_until_answered: prompt.hide_text_until_answered,
    })
}

fn body_dto(body: &QuestionBody, known: KnownCards<'_>) -> Result<QuestionBodyDto, CoreError> {
    Ok(match body {
        QuestionBody::Choice {
            options,
            correct_option_id,
            blank_word_index,
        } => QuestionBodyDto::Choice {
            options: options
                .iter()
                .map(|option| option_dto(option, known))
                .collect::<Result<_, _>>()?,
            correct_option_id: correct_option_id.clone(),
            blank_word_index: *blank_word_index,
        },
        QuestionBody::Reorder {
            chunks,
            accept_orders,
        } => QuestionBodyDto::Reorder {
            chunks: chunks.iter().map(chunk_dto).collect(),
            accept_orders: accept_orders.clone(),
        },
        QuestionBody::Typing {
            expected_reading,
            placeholder_zh,
        } => QuestionBodyDto::Typing {
            expected_reading: expected_reading.clone(),
            placeholder_zh: placeholder_zh.clone(),
        },
        QuestionBody::Match { pairs } => QuestionBodyDto::Match {
            pairs: pairs.iter().map(match_pair_dto).collect(),
        },
        QuestionBody::SelfGrade { reveal } => QuestionBodyDto::SelfGrade {
            reveal: known.view(reveal)?,
        },
        QuestionBody::Shadow { reveal } => QuestionBodyDto::Shadow {
            reveal: known.view(reveal)?,
        },
    })
}

pub(crate) fn question_dto(
    question: &Question,
    known: KnownCards<'_>,
) -> Result<QuestionDto, CoreError> {
    Ok(QuestionDto {
        question_type: question_type_dto(question.question_type),
        reference: reference_dto(&question.reference),
        prompt: prompt_dto(&question.prompt, known)?,
        body: body_dto(&question.body, known)?,
        explain_zh: question.explain_zh.clone(),
        focus_ids: question.focus_ids.clone(),
    })
}

pub(crate) fn questions_dto(
    questions: &[Question],
    known: KnownCards<'_>,
) -> Result<Vec<QuestionDto>, CoreError> {
    questions
        .iter()
        .map(|question| question_dto(question, known))
        .collect()
}

pub(crate) fn drill_result_dto(
    result: &GradeResult,
    known: KnownCards<'_>,
) -> Result<DrillResultDto, CoreError> {
    Ok(DrillResultDto {
        is_correct: result.is_correct,
        correct_display: result.correct_display.clone(),
        explain_zh: result.explain_zh.clone(),
        why_zh: result.why_zh.clone(),
        reveal: result
            .reveal
            .as_ref()
            .map(|reveal| known.view(reveal))
            .transpose()?,
    })
}

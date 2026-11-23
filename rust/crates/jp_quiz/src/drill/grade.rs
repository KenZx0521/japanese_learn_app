//! 手寫演練的判定（§8.4）。依 `reference` 從內容重算正解，不重新產生題目。

use jp_content::schema::{DrillDef, KanaWordMode, Style};
use jp_content::sentence::reorder_chunks;
use jp_content::ContentStore;
use jp_lang::kana::{reading_mode_of, typed_answer_matches};

use crate::drill::choice::{
    analyze_fragment, answer_option_id, answer_sentence, choice_id, correct_blank_index,
    false_friend_explain, single_blank, AnswerFields,
};
use crate::drill::order::{identity_order, order_is_accepted};
use crate::drill::simple::{conjugated, lemma_entry, OPTION_A, OPTION_B};
use crate::drill::{substitution, wrong_kind};
use crate::error::QuizError;
use crate::model::{AnswerPayload, GradeResult, QuestionRef, SentenceView};
use crate::view::{lookup_sentence, mixed_ja, mixed_sentence, sentence_view};

const PAIR_SIDES: usize = 2;
const DISTRACTOR_OPTION_PREFIX: char = 'd';

pub(super) fn wrong_payload(expected: &str) -> QuizError {
    QuizError::invalid("response", format!("作答型別與題目不符：{expected}"))
}

fn choice_of<'a>(response: &'a AnswerPayload, expected: &str) -> Result<&'a str, QuizError> {
    match response {
        AnswerPayload::Choice { option_id } => Ok(option_id),
        _ => Err(wrong_payload(expected)),
    }
}

fn order_of<'a>(response: &'a AnswerPayload, expected: &str) -> Result<&'a [u32], QuizError> {
    match response {
        AnswerPayload::Reorder { order } => Ok(order),
        _ => Err(wrong_payload(expected)),
    }
}

fn typed_of<'a>(response: &'a AnswerPayload, expected: &str) -> Result<&'a str, QuizError> {
    match response {
        AnswerPayload::Typing { input } => Ok(input),
        _ => Err(wrong_payload(expected)),
    }
}

/// `variant` 缺少或超出範圍回 `InvalidInput`（§8.4）。
fn variant_index(reference: &QuestionRef, len: usize) -> Result<usize, QuizError> {
    let variant = reference
        .variant
        .ok_or_else(|| QuizError::invalid("variant", "缺少 variant"))?;
    let index = variant as usize;
    if index < len {
        Ok(index)
    } else {
        Err(QuizError::invalid(
            "variant",
            format!("{variant} 超出範圍（共 {len} 個）"),
        ))
    }
}

pub(crate) fn plain(is_correct: bool, correct_display: String) -> GradeResult {
    GradeResult {
        is_correct,
        correct_display,
        explain_zh: None,
        why_zh: None,
        reveal: None,
    }
}

pub(super) fn revealed(is_correct: bool, view: SentenceView) -> GradeResult {
    GradeResult {
        reveal: Some(view.clone()),
        ..plain(is_correct, mixed_sentence(&view.parsed))
    }
}

fn indexed_text<'a>(id: &str, texts: &'a [String], index: u32) -> Result<&'a str, QuizError> {
    texts
        .get(index as usize)
        .map(String::as_str)
        .ok_or_else(|| QuizError::content(id, "answer_index 超出範圍"))
}

fn grade_answer_choice(
    content: &ContentStore,
    fields: AnswerFields<'_>,
    distractors: &[jp_content::schema::DistractorDef],
    response: &AnswerPayload,
    type_name: &str,
) -> Result<GradeResult, QuizError> {
    let option_id = choice_of(response, type_name)?;
    let why_zh = option_id
        .strip_prefix(DISTRACTOR_OPTION_PREFIX)
        .and_then(|index| index.parse::<usize>().ok())
        .and_then(|index| distractors.get(index))
        .map(|distractor| distractor.why_zh.clone());
    let answer = answer_sentence(content, fields)?;
    Ok(GradeResult {
        why_zh,
        ..revealed(option_id == answer_option_id(), answer)
    })
}

fn grade_zh_to_ja(
    content: &ContentStore,
    drill: &DrillDef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
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
    grade_answer_choice(content, fields, distractors, response, drill.type_name())
}

fn grade_situation(
    content: &ContentStore,
    drill: &DrillDef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let DrillDef::SituationResponse {
        style,
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
        zh: "",
        style: style.unwrap_or(Style::Neutral),
        tts: *tts,
    };
    grade_answer_choice(content, fields, distractors, response, drill.type_name())
}

fn grade_particle(
    content: &ContentStore,
    drill: &DrillDef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
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
    let option_id = choice_of(response, drill.type_name())?;
    let view = sentence_view(lookup_sentence(content, sentence)?, None);
    let blank = single_blank(id, blanks)?;
    let correct = correct_blank_index(id, &view.parsed, blank)?;
    let answer = analyze_fragment(id, &blank.choices[correct])?;
    Ok(GradeResult {
        explain_zh: explain_zh.clone(),
        reveal: Some(view),
        ..plain(option_id == choice_id(correct), mixed_sentence(&answer))
    })
}

fn grade_conjugate(
    content: &ContentStore,
    drill: &DrillDef,
    reference: &QuestionRef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let DrillDef::Conjugate { form, lemmas, .. } = drill else {
        return Err(wrong_kind(drill));
    };
    let index = variant_index(reference, lemmas.len())?;
    let input = typed_of(response, drill.type_name())?;
    let entry = lemma_entry(content, &lemmas[index])?;
    let answer = conjugated(drill.id(), entry, *form)?;
    let mode = reading_mode_of(&answer.reading);
    Ok(plain(
        typed_answer_matches(input, &answer.reading, mode),
        mixed_ja(&answer.surface, &answer.reading),
    ))
}

fn grade_pair(
    drill: &DrillDef,
    reference: &QuestionRef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let DrillDef::MinimalPair {
        a,
        a_zh,
        b,
        b_zh,
        a_kana,
        b_kana,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let index = variant_index(reference, PAIR_SIDES)?;
    let (expected, text, kana, zh) = if index == 0 {
        (OPTION_A, a, a_kana, a_zh)
    } else {
        (OPTION_B, b, b_kana, b_zh)
    };
    let option_id = choice_of(response, drill.type_name())?;
    let reading = kana.as_deref().unwrap_or(text);
    let display = format!("{} {zh}", mixed_ja(text, reading));
    Ok(plain(option_id == expected, display))
}

fn grade_kana_word(drill: &DrillDef, response: &AnswerPayload) -> Result<GradeResult, QuizError> {
    let DrillDef::KanaWord {
        word,
        zh,
        mode,
        choices_zh,
        answer_index,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    match mode {
        KanaWordMode::Choice => {
            let answer =
                answer_index.ok_or_else(|| QuizError::content(drill.id(), "缺 answer_index"))?;
            let display = indexed_text(drill.id(), choices_zh, answer)?;
            let option_id = choice_of(response, drill.type_name())?;
            Ok(plain(
                option_id == choice_id(answer as usize),
                display.to_owned(),
            ))
        }
        KanaWordMode::Typing => {
            let input = typed_of(response, drill.type_name())?;
            let is_correct = typed_answer_matches(input, word, reading_mode_of(word));
            Ok(plain(is_correct, format!("{} {zh}", mixed_ja(word, word))))
        }
    }
}

fn grade_reorder(
    content: &ContentStore,
    drill: &DrillDef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let DrillDef::Reorder {
        sentence,
        accept_orders,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let order = order_of(response, drill.type_name())?;
    let view = sentence_view(lookup_sentence(content, sentence)?, None);
    let chunks = reorder_chunks(&view.parsed);
    let is_correct = order_is_accepted(&chunks, order, accept_orders);
    Ok(revealed(is_correct, view))
}

fn grade_register(
    content: &ContentStore,
    drill: &DrillDef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let DrillDef::RegisterConvert { to, .. } = drill else {
        return Err(wrong_kind(drill));
    };
    let order = order_of(response, drill.type_name())?;
    let view = sentence_view(lookup_sentence(content, to)?, None);
    let chunks = reorder_chunks(&view.parsed);
    let is_correct = order_is_accepted(&chunks, order, &[identity_order(chunks.len())]);
    Ok(revealed(is_correct, view))
}

fn indexed_choice(
    drill: &DrillDef,
    choices_zh: &[String],
    answer_index: u32,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let option_id = choice_of(response, drill.type_name())?;
    let display = indexed_text(drill.id(), choices_zh, answer_index)?;
    Ok(plain(
        option_id == choice_id(answer_index as usize),
        display.to_owned(),
    ))
}

fn grade_listen(
    content: &ContentStore,
    drill: &DrillDef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let DrillDef::ListenMeaning {
        sentence,
        choices_zh,
        answer_index,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let result = indexed_choice(drill, choices_zh, *answer_index, response)?;
    Ok(GradeResult {
        reveal: Some(sentence_view(lookup_sentence(content, sentence)?, None)),
        ..result
    })
}

fn grade_false_friend(
    content: &ContentStore,
    drill: &DrillDef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let DrillDef::FalseFriend {
        note,
        choices_zh,
        answer_index,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let result = indexed_choice(drill, choices_zh, *answer_index, response)?;
    Ok(GradeResult {
        explain_zh: Some(false_friend_explain(content, drill.id(), note)?),
        ..result
    })
}

fn grade_shadowing(
    content: &ContentStore,
    drill: &DrillDef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let DrillDef::Shadowing { sentence, .. } = drill else {
        return Err(wrong_kind(drill));
    };
    if !matches!(response, AnswerPayload::Shadow { .. }) {
        return Err(wrong_payload(drill.type_name()));
    }
    // 跟讀不判定，三級自評只累計練習統計（§6.1）
    let view = sentence_view(lookup_sentence(content, sentence)?, None);
    Ok(revealed(true, view))
}

pub(crate) fn grade_drill(
    content: &ContentStore,
    drill: &DrillDef,
    reference: &QuestionRef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    match drill {
        DrillDef::Substitution { rows, .. } => {
            substitution::grade(drill, variant_index(reference, rows.len())?, response)
        }
        DrillDef::Reorder { .. } => grade_reorder(content, drill, response),
        DrillDef::RegisterConvert { .. } => grade_register(content, drill, response),
        DrillDef::ParticleFill { .. } => grade_particle(content, drill, response),
        DrillDef::ZhToJaChoice { .. } => grade_zh_to_ja(content, drill, response),
        DrillDef::SituationResponse { .. } => grade_situation(content, drill, response),
        DrillDef::ListenMeaning { .. } => grade_listen(content, drill, response),
        DrillDef::FalseFriend { .. } => grade_false_friend(content, drill, response),
        DrillDef::Conjugate { .. } => grade_conjugate(content, drill, reference, response),
        DrillDef::MinimalPair { .. } => grade_pair(drill, reference, response),
        DrillDef::KanaWord { .. } => grade_kana_word(drill, response),
        DrillDef::Shadowing { .. } => grade_shadowing(content, drill, response),
    }
}

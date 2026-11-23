//! 作答判定（§8.4、§9.6）。判定以 Rust 為準，不重新產生題目。

use jp_content::store::{KanaEntry, VocabEntry};
use jp_content::ContentStore;
use jp_srs::review::Grade;
use jp_srs::Rating;

use crate::drill::grade::{grade_drill, plain};
use crate::error::QuizError;
use crate::listen_quiz::sentence_option_id;
use crate::model::{AnswerPayload, GradeResult, QuestionRef};
use crate::question_type::QuestionType;
use crate::view::{
    join_zh, lookup_sentence, mixed_ja, mixed_sentence, mixed_word, sentence_view, use_item_title,
    vocab_reveal,
};

fn mismatch(reference: &QuestionRef) -> QuizError {
    QuizError::invalid(
        "response",
        format!("作答型別與 {} 不符", reference.question_type.as_str()),
    )
}

fn chosen_id<'a>(
    reference: &QuestionRef,
    response: &'a AnswerPayload,
) -> Result<&'a str, QuizError> {
    match response {
        AnswerPayload::Choice { option_id } => Ok(option_id),
        _ => Err(mismatch(reference)),
    }
}

fn kana_display(question_type: QuestionType, entry: &KanaEntry) -> String {
    let char_text = mixed_ja(&entry.def.ch, &entry.def.ch);
    match question_type {
        QuestionType::KanaRead => entry.romaji.clone(),
        // 答後要顯示讀音（flutter-app §3.3）
        QuestionType::KanaListen => format!("{char_text} {}", entry.romaji),
        _ => char_text,
    }
}

fn grade_kana(
    content: &ContentStore,
    reference: &QuestionRef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let id = reference.content_id.as_str();
    let entry = content
        .kana_by_id(id)
        .ok_or_else(|| QuizError::not_found("kana", id))?;
    let option_id = chosen_id(reference, response)?;
    Ok(plain(
        option_id == id,
        kana_display(reference.question_type, entry),
    ))
}

fn self_rated_correct(rating: Rating) -> bool {
    rating != Rating::Again
}

fn vocab_result(is_correct: bool, display: String, entry: &VocabEntry) -> GradeResult {
    GradeResult {
        reveal: Some(vocab_reveal(entry)),
        ..plain(is_correct, display)
    }
}

/// `Recog`、`VocabListen`：答案是中文；`Produce`：答案是日文。
fn grade_vocab(
    content: &ContentStore,
    reference: &QuestionRef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let id = reference.content_id.as_str();
    let Some(entry) = content.vocab_by_id(id) else {
        return grade_use_example(content, reference, response);
    };
    let is_produce = reference.question_type == QuestionType::Produce;
    let is_correct = match response {
        AnswerPayload::Choice { option_id } if !is_produce => option_id == id,
        AnswerPayload::SelfGrade { rating } => self_rated_correct(*rating),
        _ => return Err(mismatch(reference)),
    };
    let display = if is_produce {
        mixed_word(entry)
    } else {
        join_zh(&entry.def.zh)
    };
    Ok(vocab_result(is_correct, display, entry))
}

/// `use` 卡候選為空時的例句自評，`question_type` 記為 `Recog`（§6.1）。
fn grade_use_example(
    content: &ContentStore,
    reference: &QuestionRef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let id = reference.content_id.as_str();
    match (use_item_title(content, id), response) {
        (Some(title), AnswerPayload::SelfGrade { rating }) => {
            Ok(plain(self_rated_correct(*rating), title.to_owned()))
        }
        (Some(_), _) => Err(mismatch(reference)),
        (None, _) => Err(QuizError::not_found("vocab", id)),
    }
}

fn grade_auto_listen(
    content: &ContentStore,
    reference: &QuestionRef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let entry = lookup_sentence(content, &reference.content_id)?;
    let option_id = chosen_id(reference, response)?;
    Ok(GradeResult {
        reveal: Some(sentence_view(entry, None)),
        ..plain(
            option_id == sentence_option_id(&entry.def.id),
            entry.def.zh.clone(),
        )
    })
}

fn grade_auto_shadowing(
    content: &ContentStore,
    reference: &QuestionRef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let entry = lookup_sentence(content, &reference.content_id)?;
    if !matches!(response, AnswerPayload::Shadow { .. }) {
        return Err(mismatch(reference));
    }
    let view = sentence_view(entry, None);
    Ok(GradeResult {
        reveal: Some(view.clone()),
        ..plain(true, mixed_sentence(&view.parsed))
    })
}

fn grade_match(
    reference: &QuestionRef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    match response {
        // Match 是唯一由 Dart 判定的題型（§8.4）
        AnswerPayload::Match { all_correct } => Ok(plain(*all_correct, String::new())),
        _ => Err(mismatch(reference)),
    }
}

/// 依 `reference` 從內容算出正解並判定（§9.6 第 2 步）。
pub fn grade_answer(
    content: &ContentStore,
    reference: &QuestionRef,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    if let Some(drill_id) = &reference.drill_id {
        let drill = content
            .drill_by_id(drill_id)
            .ok_or_else(|| QuizError::not_found("drill", drill_id))?;
        return grade_drill(content, drill, reference, response);
    }
    match reference.question_type {
        QuestionType::KanaRead | QuestionType::KanaListen | QuestionType::KanaConfuse => {
            grade_kana(content, reference, response)
        }
        QuestionType::KanaMatch => grade_match(reference, response),
        QuestionType::Recog | QuestionType::VocabListen | QuestionType::Produce => {
            grade_vocab(content, reference, response)
        }
        QuestionType::ListenMeaning => grade_auto_listen(content, reference, response),
        QuestionType::Shadowing => grade_auto_shadowing(content, reference, response),
        other => Err(QuizError::invalid(
            "reference",
            format!("{} 必須帶 drill_id", other.as_str()),
        )),
    }
}

/// `submit_answer` 的第 3 步輸入（§6.2）：自評題用自評結果，其他題自動判定。
pub fn review_grade(
    response: &AnswerPayload,
    is_correct: bool,
    hint_used: bool,
    attempts: u32,
) -> Grade {
    match response {
        AnswerPayload::SelfGrade { rating } => Grade::SelfRated(*rating),
        _ => Grade::Auto {
            is_correct,
            hint_used,
            attempts,
        },
    }
}

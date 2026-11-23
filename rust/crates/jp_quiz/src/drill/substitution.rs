//! `substitution`（§8.4）：依種子選列，同一 slot 其他列的值作選項。

use std::collections::BTreeSet;

use jp_content::schema::{DrillDef, Style, SubRowDef};
use jp_content::sentence::{expand_frame, reorder_chunks};
use jp_lang::quiz::rng::{index_below, shuffled, ChaCha8Rng};

use crate::drill::choice::analyze_fragment;
use crate::drill::order::{identity_order, reorder_body};
use crate::drill::Draft;
use crate::error::QuizError;
use crate::model::{AnswerPayload, ChoiceOption, GradeResult, Prompt, QuestionBody, SentenceView};
use crate::view::{inline_view, InlineT};

const MIN_DISTINCT_OPTIONS: usize = 2;
const ROW_OPTION_PREFIX: char = 'r';

const CHOICE_INSTRUCTION: &str = "選出符合中文的詞";
const REORDER_INSTRUCTION: &str = "把詞塊排成符合中文的句子";

/// 相異值最多的 slot，同數取鍵名最後者；`max_by_key` 同值時回傳最後一個。
fn choose_slot(rows: &[SubRowDef]) -> Option<&str> {
    let first = rows.first()?;
    first
        .slots
        .keys()
        .max_by_key(|key| {
            rows.iter()
                .filter_map(|row| row.slots.get(*key))
                .collect::<BTreeSet<_>>()
                .len()
        })
        .map(String::as_str)
}

/// 值相同的列保留第一列。
fn distinct_rows(rows: &[SubRowDef], slot: &str) -> Vec<usize> {
    let mut seen = BTreeSet::new();
    rows.iter()
        .enumerate()
        .filter(|(_, row)| seen.insert(row.slots.get(slot)))
        .map(|(index, _)| index)
        .collect()
}

fn expanded_view(
    id: &str,
    frame: &str,
    rows: &[SubRowDef],
    row_index: usize,
) -> Result<SentenceView, QuizError> {
    let row = &rows[row_index];
    let t = expand_frame(frame, &row.slots).map_err(|err| QuizError::content(id, err))?;
    let view_id = format!("{id}:r{row_index}");
    inline_view(InlineT {
        t: &t,
        id: &view_id,
        zh: &row.zh,
        style: Style::Neutral,
        own_tts: row.tts,
        drill_tts: None,
    })
}

/// slot 在展開後的詞索引。slot 值可能含多個詞，所以先展開前綴再計數。
fn blank_word_index(frame: &str, slot: &str, row: &SubRowDef) -> u32 {
    let marker = format!("{{{slot}}}");
    let before = frame.split_once(&marker).map_or(frame, |(head, _)| head);
    let expanded = row
        .slots
        .iter()
        .fold(before.to_owned(), |text, (key, value)| {
            text.replace(&format!("{{{key}}}"), value)
        });
    let tokens = expanded.split_whitespace().count();
    // 前綴不是以空白結尾時，slot 與前一段同屬一個詞
    let index = if expanded.is_empty() || expanded.ends_with(char::is_whitespace) {
        tokens
    } else {
        tokens.saturating_sub(1)
    };
    u32::try_from(index).unwrap_or(u32::MAX)
}

fn row_id(index: usize) -> String {
    format!("{ROW_OPTION_PREFIX}{index}")
}

fn row_options(
    id: &str,
    rows: &[SubRowDef],
    slot: &str,
    distinct: &[usize],
) -> Result<Vec<ChoiceOption>, QuizError> {
    distinct
        .iter()
        .map(|&index| {
            let value = rows[index]
                .slots
                .get(slot)
                .ok_or_else(|| QuizError::content(id, format!("第 {index} 列缺 {slot}")))?;
            Ok(ChoiceOption {
                id: row_id(index),
                text: analyze_fragment(id, value)?.display,
                ..ChoiceOption::default()
            })
        })
        .collect()
}

fn fields(drill: &DrillDef) -> Result<(&str, &[SubRowDef]), QuizError> {
    match drill {
        DrillDef::Substitution { frame, rows, .. } => Ok((frame, rows)),
        other => Err(QuizError::content(other.id(), "不是 substitution")),
    }
}

pub(super) fn draft(drill: &DrillDef, rng: &mut ChaCha8Rng) -> Result<Draft, QuizError> {
    let id = drill.id();
    let (frame, rows) = fields(drill)?;
    let variant = index_below(rng, rows.len())
        .ok_or_else(|| QuizError::content(id, "substitution 沒有 rows"))?;
    let slot = choose_slot(rows).ok_or_else(|| QuizError::content(id, "沒有 slot"))?;
    let distinct = distinct_rows(rows, slot);
    let view = expanded_view(id, frame, rows, variant)?;
    let (prompt, body) = if distinct.len() < MIN_DISTINCT_OPTIONS {
        reorder_fallback(view, rng)
    } else {
        let chosen_value = rows[variant].slots.get(slot);
        let correct_row = distinct
            .iter()
            .copied()
            .find(|&index| rows[index].slots.get(slot) == chosen_value)
            .unwrap_or(variant);
        let body = QuestionBody::Choice {
            options: shuffled(rng, row_options(id, rows, slot, &distinct)?),
            correct_option_id: row_id(correct_row),
            blank_word_index: Some(blank_word_index(frame, slot, &rows[variant])),
        };
        let prompt = Prompt {
            instruction_zh: CHOICE_INSTRUCTION.to_owned(),
            plain_text: Some(view.zh.clone()),
            text: Some(view),
            ..Prompt::default()
        };
        (prompt, body)
    };
    Ok(Draft {
        variant: u32::try_from(variant).ok(),
        ..Draft::new(prompt, body)
    })
}

fn reorder_fallback(view: SentenceView, rng: &mut ChaCha8Rng) -> (Prompt, QuestionBody) {
    let count = reorder_chunks(&view.parsed).len();
    let body = reorder_body(&view.parsed, vec![identity_order(count)], rng);
    let prompt = Prompt {
        instruction_zh: REORDER_INSTRUCTION.to_owned(),
        plain_text: Some(view.zh),
        ..Prompt::default()
    };
    (prompt, body)
}

/// 判定時比對 slot 的值，選項 id 指向哪一列不重要（§8.4）。
pub(super) fn grade(
    drill: &DrillDef,
    variant: usize,
    response: &AnswerPayload,
) -> Result<GradeResult, QuizError> {
    let id = drill.id();
    let (frame, rows) = fields(drill)?;
    let view = expanded_view(id, frame, rows, variant)?;
    let is_correct = match response {
        AnswerPayload::Choice { option_id } => {
            let slot = choose_slot(rows).ok_or_else(|| QuizError::content(id, "沒有 slot"))?;
            let chosen = option_id
                .strip_prefix(ROW_OPTION_PREFIX)
                .and_then(|index| index.parse::<usize>().ok())
                .and_then(|index| rows.get(index));
            chosen.is_some_and(|row| row.slots.get(slot) == rows[variant].slots.get(slot))
        }
        AnswerPayload::Reorder { order } => {
            let count = reorder_chunks(&view.parsed).len();
            *order == identity_order(count)
        }
        _ => return Err(super::grade::wrong_payload("substitution")),
    };
    Ok(super::grade::revealed(is_correct, view))
}

//! `{ja:…}` 混合文字標記（curriculum.md §12.2）。

use jp_lang::kana::{furigana_or_whole, Ruby};
use thiserror::Error;

const OPEN: &str = "{ja:";
const CLOSE: char = '}';
const READING_BAR: char = '|';

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MixedSpan {
    Zh { text: String },
    Ja { text: String, ruby: Vec<Ruby> },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
pub enum MixedError {
    #[error("標記沒有結束的 }}")]
    Unterminated,
    #[error("標記內容或讀音為空")]
    Empty,
    #[error("標記內 | 超過一個")]
    ExtraBar,
    #[error("標記不可巢狀")]
    Nested,
}

/// 語法錯誤時整段回 `Zh`。
pub fn parse_mixed_text(input: &str) -> Vec<MixedSpan> {
    validate_mixed(input).unwrap_or_else(|_| {
        vec![MixedSpan::Zh {
            text: input.to_owned(),
        }]
    })
}

/// 嚴格解析，lint R19 用。
pub fn validate_mixed(input: &str) -> Result<Vec<MixedSpan>, MixedError> {
    let mut spans = Vec::new();
    let mut rest = input;
    while let Some(start) = rest.find(OPEN) {
        push_zh(&mut spans, &rest[..start]);
        let body_start = start + OPEN.len();
        let end = rest[body_start..]
            .find(CLOSE)
            .ok_or(MixedError::Unterminated)?;
        spans.push(ja_span(&rest[body_start..body_start + end])?);
        rest = &rest[body_start + end + CLOSE.len_utf8()..];
    }
    push_zh(&mut spans, rest);
    Ok(spans)
}

fn push_zh(spans: &mut Vec<MixedSpan>, text: &str) {
    if !text.is_empty() {
        spans.push(MixedSpan::Zh {
            text: text.to_owned(),
        });
    }
}

fn ja_span(body: &str) -> Result<MixedSpan, MixedError> {
    if body.contains(OPEN) {
        return Err(MixedError::Nested);
    }
    let mut parts = body.split(READING_BAR);
    let text = parts.next().unwrap_or_default();
    let reading = parts.next();
    if parts.next().is_some() {
        return Err(MixedError::ExtraBar);
    }
    if text.is_empty() || reading.is_some_and(str::is_empty) {
        return Err(MixedError::Empty);
    }
    let ruby = reading.map_or_else(
        || {
            vec![Ruby {
                base: text.to_owned(),
                ruby: None,
            }]
        },
        |reading| furigana_or_whole(text, reading),
    );
    Ok(MixedSpan::Ja {
        text: text.to_owned(),
        ruby,
    })
}

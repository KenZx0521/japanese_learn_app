//! `Reorder` 類手寫題：`reorder`、`register_convert`（§8.4）。

use jp_content::schema::{DrillDef, Style};
use jp_content::sentence::{reorder_chunks, Chunk, ParsedSentence};
use jp_content::ContentStore;
use jp_lang::quiz::rng::{shuffled, ChaCha8Rng};

use crate::drill::{wrong_kind, Draft};
use crate::error::QuizError;
use crate::model::{Prompt, QuestionBody, ReorderChunk};
use crate::view::{lookup_sentence, sentence_view};

const REORDER_INSTRUCTION: &str = "把詞塊排成正確的句子";
const CONVERT_INSTRUCTION: &str = "把詞塊排成另一種語體的句子";
const TO_PLAIN: &str = "改成常體";
const TO_POLITE: &str = "改成敬體";
const TO_OTHER: &str = "改成另一種語體";

pub(super) fn identity_order(count: usize) -> Vec<u32> {
    (0u32..).take(count).collect()
}

fn is_permutation(order: &[u32], count: usize) -> bool {
    let mut sorted = order.to_vec();
    sorted.sort_unstable();
    sorted == identity_order(count)
}

/// 外觀相同的詞塊互換後句子不變，畫面上也分不出來，所以比對排出的文字而不是索引。
pub(super) fn order_is_accepted(
    chunks: &[Chunk],
    order: &[u32],
    accept_orders: &[Vec<u32>],
) -> bool {
    let texts = |indices: &[u32]| -> Vec<Option<&str>> {
        indices
            .iter()
            .map(|&index| chunks.get(index as usize).map(|c| c.surface.as_str()))
            .collect()
    };
    is_permutation(order, chunks.len())
        && accept_orders
            .iter()
            .any(|accepted| texts(accepted) == texts(order))
}

fn rotated(order: &[u32], by: usize) -> Vec<u32> {
    order
        .iter()
        .cycle()
        .skip(by)
        .take(order.len())
        .copied()
        .collect()
}

fn swapped_front(order: &[u32]) -> Vec<u32> {
    match order {
        [first, second, rest @ ..] => [&[*second, *first], rest].concat(),
        _ => order.to_vec(),
    }
}

/// 洗牌後已是合法答案就循環位移；全部位移都合法時再換前兩塊試一輪，
/// 所有排列都合法時直接回傳（§8.4）。
fn presented_order(
    count: usize,
    is_accepted: impl Fn(&[u32]) -> bool,
    rng: &mut ChaCha8Rng,
) -> Vec<u32> {
    let order = shuffled(rng, identity_order(count));
    let swapped = swapped_front(&order);
    let rotations = |base: &[u32]| (0..count).map(|by| rotated(base, by)).collect::<Vec<_>>();
    let found = rotations(&order)
        .into_iter()
        .chain(rotations(&swapped))
        .find(|candidate| !is_accepted(candidate));
    found.unwrap_or(order)
}

pub(super) fn reorder_body(
    parsed: &ParsedSentence,
    accept_orders: Vec<Vec<u32>>,
    rng: &mut ChaCha8Rng,
) -> QuestionBody {
    let chunks = reorder_chunks(parsed);
    let accepted = |order: &[u32]| order_is_accepted(&chunks, order, &accept_orders);
    let presented = presented_order(chunks.len(), accepted, rng);
    QuestionBody::Reorder {
        chunks: presented
            .into_iter()
            .map(|index| ReorderChunk {
                index,
                text: chunks[index as usize].surface.clone(),
            })
            .collect(),
        accept_orders,
    }
}

fn target_register(style: Style) -> &'static str {
    match style {
        Style::Plain => TO_PLAIN,
        Style::Polite => TO_POLITE,
        Style::Mixed | Style::Neutral => TO_OTHER,
    }
}

pub(super) fn reorder(
    content: &ContentStore,
    drill: &DrillDef,
    rng: &mut ChaCha8Rng,
) -> Result<Draft, QuizError> {
    let DrillDef::Reorder {
        sentence,
        accept_orders,
        audio_first,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let view = sentence_view(lookup_sentence(content, sentence)?, None);
    let body = reorder_body(&view.parsed, accept_orders.clone(), rng);
    let prompt = if *audio_first {
        Prompt {
            instruction_zh: REORDER_INSTRUCTION.to_owned(),
            speech: Some(view.parsed.speech.clone()),
            text: Some(view),
            autoplay: true,
            hide_text_until_answered: true,
            ..Prompt::default()
        }
    } else {
        Prompt {
            instruction_zh: REORDER_INSTRUCTION.to_owned(),
            plain_text: Some(view.zh),
            ..Prompt::default()
        }
    };
    Ok(Draft::new(prompt, body))
}

pub(super) fn register_convert(
    content: &ContentStore,
    drill: &DrillDef,
    rng: &mut ChaCha8Rng,
) -> Result<Draft, QuizError> {
    let DrillDef::RegisterConvert { from, to, .. } = drill else {
        return Err(wrong_kind(drill));
    };
    let source = sentence_view(lookup_sentence(content, from)?, None);
    let target = sentence_view(lookup_sentence(content, to)?, None);
    let chunk_count = reorder_chunks(&target.parsed).len();
    let body = reorder_body(&target.parsed, vec![identity_order(chunk_count)], rng);
    let prompt = Prompt {
        instruction_zh: CONVERT_INSTRUCTION.to_owned(),
        text: Some(source),
        plain_text: Some(target_register(target.style).to_owned()),
        ..Prompt::default()
    };
    Ok(Draft::new(prompt, body))
}

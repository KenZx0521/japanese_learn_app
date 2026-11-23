//! 題目「可作答」的共用斷言（rust-core §8.4、§8.6）：選項 id 有效且正解唯一、詞塊排列合法、
//! 打字題的羅馬字判得對、需要語音的題可播放、無聲模式不出需要語音的題。

use std::collections::{BTreeMap, BTreeSet};

use jp_core::api::core::AppCore;
use jp_core::api::dto_content::{ReadingMode, SentenceDto, SpeechDto};
use jp_core::api::dto_study::{
    AnswerPayload, ChunkDto, OptionDto, QuestionBodyDto, QuestionDto, QuestionType,
};
use jp_core::api::tools_api::romanize_reading;

use super::correct_payload;

/// §8.6「需要語音」欄。
const AUDIO_TYPES: [QuestionType; 5] = [
    QuestionType::VocabListen,
    QuestionType::KanaListen,
    QuestionType::MinimalPair,
    QuestionType::ListenMeaning,
    QuestionType::Shadowing,
];
const MIN_OPTIONS: usize = 2;
const MIN_CHUNKS: usize = 2;

pub fn label(question: &QuestionDto) -> String {
    let reference = &question.reference;
    reference
        .drill_id
        .clone()
        .unwrap_or_else(|| reference.content_id.clone())
}

/// §8.6「需要語音」，加上 `audio_first` 的 Reorder（先只顯示播放鈕）。
pub fn needs_audio(question: &QuestionDto) -> bool {
    AUDIO_TYPES.contains(&question.question_type) || question.prompt.hide_text_until_answered
}

pub fn assert_playable(speech: &SpeechDto, what: &str) {
    assert!(
        !speech.text.trim().is_empty() && !speech.kana.trim().is_empty(),
        "{what}：語音文字為空 {speech:?}"
    );
}

/// 句子能顯示也能播放。
pub fn assert_sentence_playable(sentence: &SentenceDto) {
    assert!(
        !sentence.display.trim().is_empty(),
        "{}：顯示文字為空",
        sentence.id
    );
    assert_playable(&sentence.speech, &sentence.id);
}

pub fn assert_answerable(core: &AppCore, question: &QuestionDto, audio_available: bool) {
    assert_audio_fits(question, audio_available);
    match &question.body {
        QuestionBodyDto::Choice {
            options,
            correct_option_id,
            blank_word_index,
        } => {
            assert_unique_choice(core, question, options, correct_option_id);
            let correct = options.iter().find(|o| &o.id == correct_option_id);
            assert_blank_in_sentence(question, *blank_word_index, correct);
        }
        QuestionBodyDto::Reorder {
            chunks,
            accept_orders,
        } => assert_reorder(core, question, chunks, accept_orders),
        QuestionBodyDto::Typing {
            expected_reading, ..
        } => assert_typing(core, question, expected_reading),
        QuestionBodyDto::SelfGrade { reveal } | QuestionBodyDto::Shadow { reveal } => {
            assert_sentence_playable(reveal);
            assert!(is_correct(core, question, correct_payload(question)));
        }
        QuestionBodyDto::Match { .. } => panic!("{}：手寫演練不會出 Match", label(question)),
    }
}

fn is_correct(core: &AppCore, question: &QuestionDto, response: AnswerPayload) -> bool {
    core.grade_drill(question.reference.clone(), response)
        .unwrap_or_else(|err| panic!("{}：判定失敗 {err:?}", label(question)))
        .is_correct
}

fn assert_audio_fits(question: &QuestionDto, audio_available: bool) {
    if !needs_audio(question) {
        return;
    }
    let id = label(question);
    assert!(
        audio_available,
        "{id}：無聲模式不該出需要語音的 {:?}",
        question.question_type
    );
    let speech = question
        .prompt
        .speech
        .as_ref()
        .unwrap_or_else(|| panic!("{id}：需要語音卻沒有 prompt.speech"));
    assert_playable(speech, &id);
}

/// 選項 id 與文字都不重複、正解在選項內，逐一作答時只有正解判對。
fn assert_unique_choice(
    core: &AppCore,
    question: &QuestionDto,
    options: &[OptionDto],
    correct_option_id: &str,
) {
    let id = label(question);
    assert!(options.len() >= MIN_OPTIONS, "{id}：選項不足 {options:?}");
    let ids: BTreeSet<&str> = options.iter().map(|o| o.id.as_str()).collect();
    let texts: BTreeSet<&str> = options.iter().map(|o| o.text.as_str()).collect();
    assert_eq!(ids.len(), options.len(), "{id}：選項 id 重複 {options:?}");
    assert_eq!(texts.len(), options.len(), "{id}：選項文字重複 {options:?}");
    assert!(ids.contains(correct_option_id), "{id}：正解不在選項內");
    let judged_right: Vec<&str> = options
        .iter()
        .filter(|option| {
            let response = AnswerPayload::Choice {
                option_id: option.id.clone(),
            };
            is_correct(core, question, response)
        })
        .map(|option| option.id.as_str())
        .collect();
    assert_eq!(judged_right, [correct_option_id], "{id}：判對的選項不唯一");
}

/// 有空格就要有句子：`blank_word_index` 為 `Some` 時 `prompt.text` 必須存在，索引在句內，而且挖掉的
/// 正是正解那個詞。助詞填空的正解與該詞的表層相同（jp_quiz `correct_blank_index`）；代換題的 slot 值
/// 可能與前後黏成一個詞，或跨好幾個詞，所以只要求兩者互相包含。
fn assert_blank_in_sentence(
    question: &QuestionDto,
    blank_word_index: Option<u32>,
    correct: Option<&OptionDto>,
) {
    let Some(index) = blank_word_index else {
        return;
    };
    let id = label(question);
    let text = question
        .prompt
        .text
        .as_ref()
        .unwrap_or_else(|| panic!("{id}：有 blank_word_index {index} 卻沒有 prompt.text"));
    let word = text
        .words
        .get(index as usize)
        .unwrap_or_else(|| panic!("{id}：blank_word_index {index} 超出句子"));
    let answer = correct.map_or("", |o| o.text.as_str());
    let matches = if question.question_type == QuestionType::ParticleFill {
        word.surface == answer
    } else {
        word.surface.contains(answer) || answer.contains(word.surface.as_str())
    };
    assert!(
        !answer.is_empty() && matches,
        "{id}：空格挖的是「{}」（第 {index} 詞），正解是「{answer}」",
        word.surface
    );
}

/// 依 `order` 排出的詞塊文字序列；判定（jp_quiz `order_is_accepted`）比的就是它。
fn order_texts<'c>(chunks: &'c [ChunkDto], order: &[u32]) -> Vec<&'c str> {
    order
        .iter()
        .map(|index| {
            chunks
                .iter()
                .find(|chunk| chunk.index == *index)
                .map_or("", |chunk| chunk.text.as_str())
        })
        .collect()
}

fn order_text(chunks: &[ChunkDto], order: &[u32]) -> String {
    order_texts(chunks, order).concat()
}

fn is_permutation(order: &[u32], size: usize) -> bool {
    let distinct: BTreeSet<u32> = order.iter().copied().collect();
    order.len() == size && distinct.len() == size && distinct.iter().all(|&i| (i as usize) < size)
}

fn factorial(n: usize) -> usize {
    (1..=n).product()
}

/// 詞塊文字的相異排列數：n! ÷ Π(同文字塊數)!。
fn distinct_arrangements(chunks: &[ChunkDto]) -> usize {
    let counts = chunks.iter().fold(BTreeMap::new(), |mut counts, chunk| {
        *counts.entry(chunk.text.as_str()).or_insert(0usize) += 1;
        counts
    });
    counts
        .values()
        .fold(factorial(chunks.len()), |total, &same| {
            total / factorial(same)
        })
}

/// §8.4：洗牌後與正解相同就位移，所有排列都合法時才直接回傳。判定比的是排出的文字，
/// 外觀相同的詞塊互換後仍是正解，所以初始順序用判分 API 檢查，「所有排列」也以文字計。
fn assert_shown_order_not_accepted(
    core: &AppCore,
    question: &QuestionDto,
    chunks: &[ChunkDto],
    accept_orders: &[Vec<u32>],
) {
    let shown: Vec<u32> = chunks.iter().map(|chunk| chunk.index).collect();
    let accepted: BTreeSet<Vec<&str>> = accept_orders
        .iter()
        .map(|order| order_texts(chunks, order))
        .collect();
    let every_arrangement_legal = accepted.len() >= distinct_arrangements(chunks);
    let response = AnswerPayload::Reorder {
        order: shown.clone(),
    };
    assert!(
        every_arrangement_legal || !is_correct(core, question, response),
        "{}：初始順序已是正解 {shown:?}「{}」",
        label(question),
        order_text(chunks, &shown)
    );
}

/// 每個 `accept_orders` 都是完整排列且判對；初始順序不是正解（§8.4）；拼出別的文字判錯。
fn assert_reorder(
    core: &AppCore,
    question: &QuestionDto,
    chunks: &[ChunkDto],
    accept_orders: &[Vec<u32>],
) {
    let id = label(question);
    let size = chunks.len();
    let shown: Vec<u32> = chunks.iter().map(|chunk| chunk.index).collect();
    assert!(size >= MIN_CHUNKS, "{id}：詞塊不足 {chunks:?}");
    assert!(is_permutation(&shown, size), "{id}：詞塊索引 {shown:?}");
    assert!(!accept_orders.is_empty(), "{id}：沒有 accept_orders");
    for order in accept_orders {
        assert!(is_permutation(order, size), "{id}：{order:?} 不是排列");
        let response = AnswerPayload::Reorder {
            order: order.clone(),
        };
        assert!(is_correct(core, question, response), "{id}：{order:?} 判錯");
    }
    assert_shown_order_not_accepted(core, question, chunks, accept_orders);
    assert_other_text_rejected(core, question, chunks, accept_orders);
}

fn assert_other_text_rejected(
    core: &AppCore,
    question: &QuestionDto,
    chunks: &[ChunkDto],
    accept_orders: &[Vec<u32>],
) {
    let accepted: BTreeSet<String> = accept_orders
        .iter()
        .map(|order| order_text(chunks, order))
        .collect();
    let first = &accept_orders[0];
    let wrong = (1..first.len())
        .map(|shift| {
            let mut rotated = first.clone();
            rotated.rotate_left(shift);
            rotated
        })
        .find(|order| !accepted.contains(&order_text(chunks, order)));
    if let Some(order) = wrong {
        let response = AnswerPayload::Reorder {
            order: order.clone(),
        };
        assert!(
            !is_correct(core, question, response),
            "{}：拼成別的句子 {order:?} 卻判對",
            label(question)
        );
    }
}

/// 標準答案判對；UI 由 `romanize_reading` 產生的羅馬字同樣判對。
fn assert_typing(core: &AppCore, question: &QuestionDto, expected_reading: &str) {
    let id = label(question);
    assert!(!expected_reading.trim().is_empty(), "{id}：答案為空");
    assert!(
        is_correct(core, question, correct_payload(question)),
        "{id}：標準答案判錯"
    );
    let romaji = romanize_reading(expected_reading.to_owned(), ReadingMode::Word)
        .unwrap_or_else(|| panic!("{id}：{expected_reading} 應可轉羅馬字"));
    let response = AnswerPayload::Typing {
        input: romaji.clone(),
    };
    assert!(
        is_correct(core, question, response),
        "{id}：打羅馬字 {romaji} 被判錯（標準答案 {expected_reading}）"
    );
}

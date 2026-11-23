//! FSRS 卡片對應的題目（§6.1）。

use jp_content::store::KanaEntry;
use jp_lang::quiz::rng::fnv1a;
use jp_srs::use_cards::{select_use_question, UseCandidate, UseQuery, UseSelection};
use jp_srs::{CardId, Facet};

use crate::context::{QuestionKey, QuizContext};
use crate::distractor::KanaPool;
use crate::drill::drill_question;
use crate::error::QuizError;
use crate::kana_quiz::{kana_confuse_question, kana_listen_question, kana_read_question};
use crate::listen_quiz::auto_listen_meaning;
use crate::model::{Prompt, Question, QuestionBody, QuestionRef, SentenceView};
use crate::question_type::QuestionType;
use crate::view::{sentence_view, title_reveal, use_item_title};
use crate::vocab_quiz::{produce_question, recog_question, vocab_listen_question};

const FALLBACK_INSTRUCTION: &str = "看例句，回想這個句型";
/// 沒有可用例句時只顯示標題（§6.1）。
const FALLBACK_TITLE_INSTRUCTION: &str = "回想這個句型的意思和用法";

/// 靠 `reps` 自然輪替，不需題目歷史（§6.1）。
fn rotation_index(reps: i32, card_id: &str, len: usize) -> usize {
    // 餘數小於 len，轉回 usize 不會截斷
    let hash_turn = (fnv1a(card_id) % len as u64) as usize;
    let reps_turn = usize::try_from(reps).unwrap_or(0);
    (reps_turn + hash_turn) % len
}

fn kana_entry<'c>(ctx: &QuizContext<'c>, id: &str) -> Result<&'c KanaEntry, QuizError> {
    ctx.content
        .kana_by_id(id)
        .ok_or_else(|| QuizError::not_found("kana", id))
}

/// 已教字太少時改用該文字系統全部字，卡片不能因此卡住佇列。
fn with_script_fallback<'c, F>(
    ctx: &QuizContext<'c>,
    entry: &KanaEntry,
    build: F,
) -> Result<Question, QuizError>
where
    F: Fn(&KanaPool<'c>) -> Result<Option<Question>, QuizError>,
{
    let id = entry.def.id.as_str();
    let taught = KanaPool::taught(ctx.content, ctx.known, &[id]);
    if let Some(question) = build(&taught)? {
        return Ok(question);
    }
    let whole = KanaPool::whole_script(ctx.content, entry.def.script, u32::MAX);
    build(&whole)?.ok_or_else(|| QuizError::content(id, "沒有可用的干擾項"))
}

/// `read` 卡在有字組時輪流考 `KanaRead`、`KanaConfuse`（§6.1）。
fn kana_read_card(
    ctx: &QuizContext<'_>,
    card: &CardId,
    card_id: &str,
    reps: i32,
) -> Result<Question, QuizError> {
    let id = card.content_id();
    let entry = kana_entry(ctx, id)?;
    let key = QuestionKey::card(card_id);
    let taught = KanaPool::taught(ctx.content, ctx.known, &[id]);
    let confuse = kana_confuse_question(ctx, id, &taught, key)?;
    let turn_count = 1 + usize::from(confuse.is_some());
    match confuse {
        Some(question) if rotation_index(reps, card_id, turn_count) == 1 => Ok(question),
        _ => with_script_fallback(ctx, entry, |pool| kana_read_question(ctx, id, pool, key)),
    }
}

fn kana_listen_card(
    ctx: &QuizContext<'_>,
    card: &CardId,
    card_id: &str,
) -> Result<Question, QuizError> {
    let id = card.content_id();
    let entry = kana_entry(ctx, id)?;
    let key = QuestionKey::card(card_id);
    with_script_fallback(ctx, entry, |pool| kana_listen_question(ctx, id, pool, key))
}

fn use_card(
    ctx: &QuizContext<'_>,
    card: &CardId,
    card_id: &str,
    reps: i32,
) -> Result<Question, QuizError> {
    let content_id = card.content_id();
    let title = use_item_title(ctx.content, content_id)
        .ok_or_else(|| QuizError::not_found("use item", content_id))?;
    let query = UseQuery {
        content_id,
        cursor_pos: ctx.cursor_pos,
        known: ctx.known,
        audio_available: ctx.audio_available,
    };
    let key = QuestionKey::card(card_id);
    match select_use_question(&query, reps, card_id, ctx.content) {
        UseSelection::Question(UseCandidate::Drill(index)) => {
            let drill = &ctx.content.drills()[index as usize];
            drill_question(ctx, drill, key, Some(content_id))
        }
        UseSelection::Question(UseCandidate::AutoListenMeaning(index)) => {
            auto_listen_meaning(ctx, index, key)?
                .ok_or_else(|| QuizError::content(card_id, "自動補題沒有干擾項"))
        }
        UseSelection::SelfGradeExample(example) => {
            let instruction = match example {
                Some(_) => FALLBACK_INSTRUCTION,
                None => FALLBACK_TITLE_INSTRUCTION,
            };
            let reveal = example.map_or_else(
                || title_reveal(content_id, title),
                |index| sentence_view(&ctx.content.sentences()[index as usize], None),
            );
            Ok(self_grade_example(card_id, content_id, reveal, instruction))
        }
    }
}

/// 候選為空時退回例句自評，`question_type` 記為 `Recog`（§6.1）。
fn self_grade_example(
    card_id: &str,
    content_id: &str,
    reveal: SentenceView,
    instruction_zh: &str,
) -> Question {
    let reference = QuestionRef {
        question_type: QuestionType::Recog,
        card_id: Some(card_id.to_owned()),
        drill_id: None,
        content_id: content_id.to_owned(),
        variant: None,
    };
    let prompt = Prompt {
        instruction_zh: instruction_zh.to_owned(),
        ..Prompt::default()
    };
    let body = QuestionBody::SelfGrade {
        reveal: Box::new(reveal),
    };
    Question::new(reference, prompt, body).with_focus(vec![content_id.to_owned()])
}

pub fn question_for_card(
    ctx: &QuizContext<'_>,
    card: &CardId,
    reps: i32,
) -> Result<Question, QuizError> {
    let card_id = card.to_string();
    let key = QuestionKey::card(&card_id);
    match card.facet() {
        Facet::Read => kana_read_card(ctx, card, &card_id, reps),
        Facet::Listen if ctx.content.kana_by_id(card.content_id()).is_some() => {
            kana_listen_card(ctx, card, &card_id)
        }
        Facet::Listen => vocab_listen_question(ctx, card.content_id(), key),
        Facet::Recog => recog_question(ctx, card.content_id(), key),
        Facet::Produce => produce_question(ctx, card.content_id(), key),
        Facet::Use => use_card(ctx, card, &card_id, reps),
    }
}

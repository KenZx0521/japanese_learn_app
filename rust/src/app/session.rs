//! 複習佇列、作答、假名熟練（§6.4、§9.6）。

use std::collections::HashSet;

use chrono::NaiveDate;
use jp_content::ContentStore;
use jp_lang::clock::DayContext;
use jp_plan::state::cursor_pos;
use jp_plan::tasks::DailyTask;
use jp_plan::today::session_limits;
use jp_plan::{DaySnapshot, Slice};
use jp_quiz::context::QuizContext;
use jp_quiz::grade::{grade_answer, review_grade};
use jp_srs::kana_mastery::{record_kana_answer, KanaAnswer, KanaMasteryStatus};
use jp_srs::queue::{next_card, queue_summary, NextCard};
use jp_srs::review::{submit_review, ReviewRequest};
use jp_srs::{CardId, CardState, SrsScheduler};
use jp_store::{ActivityDelta, ActivityRepo, CardRow, PlanRepo, QueueFilter};

use super::deps::Deps;
use super::mapping::enums::rating_dto;
use super::mapping::question::{
    answer_domain, payload_domain, question_dto, questions_dto, rating_preview, reference_domain,
};
use super::mapping::sentence::KnownCards;
use crate::api::dto_study::{
    AnswerDto, AnswerPayload, AnswerResultDto, KanaMasteryDto, KanaSubmitResultDto, QuestionDto,
    QuestionRefDto, SessionCardDto, SessionNextDto, SessionSummaryDto,
};
use crate::api::error::CoreError;

/// `QuizContext` 需要的擁有權資料。`session_next` 的 `use` 卡只看 `item_intro`（§7.3）。
pub(crate) struct QuizInputs {
    pub known: HashSet<String>,
    pub cursor_pos: Option<u32>,
}

impl QuizInputs {
    pub(crate) fn load(deps: &Deps, today: NaiveDate) -> Result<Self, CoreError> {
        let state = deps.cursor_state(today)?;
        Ok(Self {
            cursor_pos: cursor_pos(&state, &deps.content),
            known: state.introduced,
        })
    }

    pub(crate) fn ctx<'a>(
        &'a self,
        deps: &'a Deps,
        session_seed: u32,
        audio_available: bool,
    ) -> QuizContext<'a> {
        let content: &'a ContentStore = &deps.content;
        QuizContext {
            content,
            known: &self.known,
            cursor_pos: self.cursor_pos,
            session_seed,
            audio_available,
        }
    }
}

pub(crate) fn session_summary(
    deps: &Deps,
    audio_available: bool,
) -> Result<SessionSummaryDto, CoreError> {
    let ctx = deps.day_ctx()?;
    let limits = session_limits(&deps.repo, &deps.content, &ctx, audio_available)?;
    let filter = QueueFilter { audio_available };
    let summary = queue_summary(&deps.repo, &ctx, limits, filter)?;
    Ok(SessionSummaryDto {
        due_reviews: summary.due_reviews,
        learning: summary.learning,
        new_cards: summary.new_cards,
        reviews_done_today: summary.reviews_done_today,
        review_cap: summary.review_cap,
    })
}

/// 題目與四個評分的預覽；`new_content_session` 的 `first_card` 共用。
pub(crate) fn card_dto(
    deps: &Deps,
    ctx: &DayContext,
    quiz: &QuizContext<'_>,
    card: &CardRow,
    remaining_estimate: u32,
) -> Result<SessionCardDto, CoreError> {
    let id = CardId::parse(&card.card_id)?;
    let question = jp_quiz::card::question_for_card(quiz, &id, card.reps)?;
    let previews = deps.scheduler.preview(&CardState::from_row(card)?, ctx)?;
    Ok(SessionCardDto {
        card_id: card.card_id.clone(),
        expected_reps: card.reps,
        facet: card.facet.clone(),
        question: question_dto(&question, KnownCards::new(&deps.repo))?,
        rating_previews: previews.iter().map(rating_preview).collect(),
        remaining_estimate,
    })
}

pub(crate) fn session_next(
    deps: &Deps,
    session_seed: u32,
    audio_available: bool,
) -> Result<SessionNextDto, CoreError> {
    let ctx = deps.day_ctx()?;
    let limits = session_limits(&deps.repo, &deps.content, &ctx, audio_available)?;
    let filter = QueueFilter { audio_available };
    match next_card(&deps.repo, &ctx, limits, filter)? {
        NextCard::Done { next_due_at } => Ok(SessionNextDto::Done { next_due_at }),
        NextCard::Card { card, .. } => {
            let inputs = QuizInputs::load(deps, ctx.today())?;
            let quiz = inputs.ctx(deps, session_seed, audio_available);
            let remaining = queue_summary(&deps.repo, &ctx, limits, filter)?.remaining_estimate();
            Ok(SessionNextDto::Card {
                card: card_dto(deps, &ctx, &quiz, &card, remaining)?,
            })
        }
    }
}

pub(crate) fn submit_answer(deps: &Deps, answer: &AnswerDto) -> Result<AnswerResultDto, CoreError> {
    let ctx = deps.day_ctx()?;
    let card_id = answer
        .reference
        .card_id
        .as_deref()
        .ok_or_else(|| CoreError::invalid("reference.card_id", "字卡作答必須帶 card_id"))?;
    let domain = answer_domain(answer);
    let graded = grade_answer(&deps.content, &domain.reference, &domain.response)?;
    let grade = review_grade(
        &domain.response,
        graded.is_correct,
        answer.hint_used,
        answer.attempts,
    );
    let reviewed = submit_review(
        &deps.repo,
        &deps.content,
        &deps.scheduler,
        &ctx,
        &ReviewRequest {
            card_id,
            expected_reps: answer.expected_reps,
            grade,
            question_type: domain.reference.question_type.as_str(),
            duration_ms: answer.duration_ms,
        },
    )?;
    Ok(AnswerResultDto {
        is_correct: graded.is_correct,
        rating: rating_dto(reviewed.outcome.rating),
        next_due_in_minutes: reviewed.outcome.interval_minutes(),
        correct_display: graded.correct_display,
        reveal: graded
            .reveal
            .as_ref()
            .map(|reveal| KnownCards::new(&deps.repo).view(reveal))
            .transpose()?,
        unlocked_cards: reviewed.unlocked_cards,
    })
}

pub(crate) fn kana_session(
    deps: &Deps,
    lesson_id: &str,
    session_seed: u32,
    audio_available: bool,
) -> Result<Vec<QuestionDto>, CoreError> {
    let today = deps.day_ctx()?.today();
    let inputs = QuizInputs::load(deps, today)?;
    let quiz = inputs.ctx(deps, session_seed, audio_available);
    let questions = jp_quiz::kana_quiz::kana_session(&quiz, lesson_id)?;
    questions_dto(&questions, KnownCards::new(&deps.repo))
}

/// 只讀現有快照：K1 自由練習可能還沒有計畫，也不該因此建快照。
fn today_slices(deps: &Deps, today: NaiveDate) -> Result<Vec<Slice>, CoreError> {
    let Some(row) = deps.repo.snapshot(today)? else {
        return Ok(Vec::new());
    };
    let Ok(snapshot) = DaySnapshot::from_json(&row.payload_json) else {
        return Ok(Vec::new());
    };
    Ok(snapshot
        .tasks
        .into_iter()
        .filter_map(|task| match task {
            DailyTask::NewContent { slice, .. } => Some(slice),
            _ => None,
        })
        .collect())
}

fn is_kana_of_slice(slice: &Slice, kana_id: &str) -> bool {
    matches!(slice, Slice::Kana { kana, .. } if kana.iter().any(|id| id == kana_id))
}

fn mastery_dto(status: KanaMasteryStatus) -> KanaMasteryDto {
    KanaMasteryDto {
        kana_id: status.kana_id,
        run: status.run,
        required: status.required,
        mastered: status.mastered,
        fast_badge: status.fast_badge,
    }
}

pub(crate) fn kana_submit(
    deps: &Deps,
    reference: &QuestionRefDto,
    response: &AnswerPayload,
    duration_ms: u32,
) -> Result<KanaSubmitResultDto, CoreError> {
    let ctx = deps.day_ctx()?;
    let domain = reference_domain(reference);
    let graded = grade_answer(&deps.content, &domain, &payload_domain(response))?;
    let slices = today_slices(deps, ctx.today())?;
    let mastery = record_kana_answer(
        &deps.repo,
        &deps.content,
        &KanaAnswer {
            kana_id: &domain.content_id,
            question_type: domain.question_type.as_str(),
            is_correct: graded.is_correct,
            duration_ms,
        },
        slices
            .iter()
            .any(|slice| is_kana_of_slice(slice, &domain.content_id)),
        ctx.now,
    )?;
    // 切片內外的作答都計入：K1 自由練習不推進計畫（C06），但作答的日子是活躍日（RULINGS O12）
    let answered = ActivityDelta {
        drills_done: 1,
        ..ActivityDelta::default()
    };
    deps.repo.add_activity(ctx.today(), answered)?;
    Ok(KanaSubmitResultDto {
        is_correct: graded.is_correct,
        correct_display: graded.correct_display,
        mastery: mastery.map(mastery_dto),
    })
}

//! `new_content_session`（§9.4、§7.3）：呈現、播音、立即一題。

use std::collections::HashSet;

use jp_lang::clock::DayContext;
use jp_plan::tasks::DailyTask;
use jp_plan::today::ensure_snapshot;
use jp_plan::Slice;
use jp_quiz::context::QuizContext;
use jp_quiz::distractor::KanaPool;
use jp_quiz::kana_quiz::{confuse_quiz, kana_batch_quiz, rule_quiz};
use jp_quiz::slice_drill::slice_drill_quiz;
use jp_quiz::Question;
use jp_srs::facets::cards_for_content;
use jp_srs::{CardId, Facet};
use jp_store::{PlanRepo, SrsRepo, STATE_NEW};

use super::deps::Deps;
use super::mapping::question::questions_dto;
use super::session::{card_dto, QuizInputs};
use super::views::Views;
use crate::api::dto_study::{NewContentSessionDto, NewContentStepDto, SessionCardDto};
use crate::api::error::CoreError;

const TASK_ENTITY: &str = "task";
const KANA_BATCH_SIZE: usize = 3;
/// `first_card` 不是佇列的一部分，沒有剩餘張數可估。
const FIRST_CARD_REMAINING: u32 = 0;

/// 這次 session 共用的輸入。
struct Session<'a> {
    deps: &'a Deps,
    views: Views<'a>,
    ctx: DayContext,
}

impl Session<'_> {
    fn quiz_step(&self, questions: &[Question]) -> Result<Option<NewContentStepDto>, CoreError> {
        if questions.is_empty() {
            return Ok(None);
        }
        Ok(Some(NewContentStepDto::KanaQuiz {
            questions: questions_dto(questions, self.views.known_cards())?,
        }))
    }

    fn rule_steps(
        &self,
        rule_ids: &[String],
        quiz: &QuizContext<'_>,
    ) -> Result<Vec<NewContentStepDto>, CoreError> {
        let mut steps = Vec::new();
        for id in rule_ids {
            let def = self
                .views
                .content()
                .rule_card_by_id(id)
                .ok_or_else(|| CoreError::not_found("rule_card", id))?;
            steps.push(NewContentStepDto::Rule {
                card: self.views.rule_card(def),
            });
            steps.extend(self.quiz_step(&rule_quiz(quiz, id)?)?);
        }
        Ok(steps)
    }

    fn confusable_steps(
        &self,
        group_ids: &[String],
        quiz: &QuizContext<'_>,
    ) -> Result<Vec<NewContentStepDto>, CoreError> {
        let pool = KanaPool::taught(self.views.content(), quiz.known, &[]);
        let mut steps = Vec::new();
        for id in group_ids {
            let def = self
                .views
                .content()
                .confusable_by_id(id)
                .ok_or_else(|| CoreError::not_found("confusable", id))?;
            steps.push(NewContentStepDto::Confusable {
                group: self.views.confusable(def),
            });
            steps.extend(self.quiz_step(&confuse_quiz(quiz, id, &pool)?)?);
        }
        Ok(steps)
    }

    /// 同一 `row` 的拗音一起教，其他字每 3 字一批（§9.4）。
    fn kana_batches<'k>(&self, ids: &'k [String]) -> Vec<Vec<&'k str>> {
        let mut units: Vec<Vec<&'k str>> = Vec::new();
        let mut previous_row: Option<&str> = None;
        for id in ids {
            let row = self
                .views
                .content()
                .kana_by_id(id)
                .and_then(|entry| entry.def.row.as_deref());
            match units.last_mut() {
                Some(unit) if row.is_some() && row == previous_row => unit.push(id),
                _ => units.push(vec![id]),
            }
            previous_row = row;
        }
        let mut batches: Vec<Vec<&'k str>> = Vec::new();
        for unit in units {
            match batches.last_mut() {
                Some(batch) if batch.len() + unit.len() <= KANA_BATCH_SIZE => batch.extend(unit),
                _ => batches.push(unit),
            }
        }
        batches
    }

    fn kana_steps(
        &self,
        ids: &[String],
        quiz: &QuizContext<'_>,
    ) -> Result<Vec<NewContentStepDto>, CoreError> {
        let content = self.views.content();
        let mut steps = Vec::new();
        let mut presented: Vec<&str> = Vec::new();
        for batch in self.kana_batches(ids) {
            for id in &batch {
                let entry = content
                    .kana_by_id(id)
                    .ok_or_else(|| CoreError::not_found("kana", id))?;
                steps.push(NewContentStepDto::Kana {
                    detail: self.views.kana_detail(entry),
                });
            }
            presented.extend(&batch);
            let pool = KanaPool::taught(content, quiz.known, &presented);
            steps.extend(self.quiz_step(&kana_batch_quiz(quiz, &batch, &pool)?)?);
        }
        Ok(steps)
    }

    /// K11–K15 的切片在所有假名題之後接一個 `KanaQuiz`（§9.4）。
    fn slice_drill_steps(
        &self,
        lesson_ids: &[String],
        kana: &[String],
        quiz: &QuizContext<'_>,
    ) -> Result<Option<NewContentStepDto>, CoreError> {
        let mut questions = Vec::new();
        for lesson in lesson_ids {
            questions.extend(slice_drill_quiz(quiz, lesson, kana)?);
        }
        self.quiz_step(&questions)
    }

    /// 只有 state=0、未暫停的卡才是「第一次接觸」，所以中途離開能從斷點繼續。
    fn first_card(
        &self,
        content_id: &str,
        facet: Facet,
        quiz: &QuizContext<'_>,
    ) -> Result<Option<SessionCardDto>, CoreError> {
        let card_id = CardId::new(content_id, facet).to_string();
        let Some(card) = self.deps.repo.card(&card_id)? else {
            return Ok(None);
        };
        if card.state != STATE_NEW || card.suspended {
            return Ok(None);
        }
        card_dto(self.deps, &self.ctx, quiz, &card, FIRST_CARD_REMAINING).map(Some)
    }

    fn vocab_steps(
        &self,
        words: &[String],
        grammar: &[String],
        quiz: &QuizContext<'_>,
    ) -> Result<Vec<NewContentStepDto>, CoreError> {
        let content = self.views.content();
        let mut steps = Vec::with_capacity(words.len() + grammar.len());
        for id in words {
            let entry = content
                .vocab_by_id(id)
                .ok_or_else(|| CoreError::not_found("vocab", id))?;
            steps.push(NewContentStepDto::Vocab {
                detail: self.views.vocab_detail(entry, Some(quiz.known))?,
                first_card: self.first_card(id, Facet::Recog, quiz)?,
            });
        }
        for id in grammar {
            let def = content
                .grammar_by_id(id)
                .ok_or_else(|| CoreError::not_found("grammar", id))?;
            steps.push(NewContentStepDto::Grammar {
                detail: self.views.grammar_detail(def, Some(quiz.known))?,
                first_card: self.first_card(id, Facet::Use, quiz)?,
            });
        }
        Ok(steps)
    }
}

fn create_slice_cards(deps: &Deps, ids: &[String], ctx: &DayContext) -> Result<(), CoreError> {
    let cards: Vec<_> = ids
        .iter()
        .flat_map(|id| cards_for_content(id, &deps.content, ctx.now))
        .collect();
    deps.repo.insert_cards(&cards)?;
    // 今日切片在標記前就凍結了，標「已會」當下還沒有卡可暫停（§9.4）
    let flags = deps.repo.vocab_flags()?;
    for id in ids
        .iter()
        .filter(|id| flags.get(*id).is_some_and(|f| f.known))
    {
        deps.repo.set_content_suspended(id, true)?;
    }
    Ok(())
}

/// 已知集合包含本切片（§7.3），例句與 `use` 候選才能用到今天教的字。
fn with_slice_known(inputs: QuizInputs, extra: &[String]) -> QuizInputs {
    let known: HashSet<String> = inputs
        .known
        .into_iter()
        .chain(extra.iter().cloned())
        .collect();
    QuizInputs { known, ..inputs }
}

fn steps_of(
    session: &Session<'_>,
    slice: &Slice,
    seed: u32,
    audio: bool,
) -> Result<Vec<NewContentStepDto>, CoreError> {
    let (deps, today) = (session.deps, session.ctx.today());
    let inputs = QuizInputs::load(deps, today)?;
    match slice {
        Slice::Kana {
            lesson_ids,
            kana,
            rules,
        } => {
            let quiz = inputs.ctx(deps, seed, audio);
            let mut steps = session.rule_steps(rules, &quiz)?;
            steps.extend(session.kana_steps(kana, &quiz)?);
            steps.extend(session.slice_drill_steps(lesson_ids, kana, &quiz)?);
            Ok(steps)
        }
        Slice::KanaRule {
            rules, confusables, ..
        } => {
            let quiz = inputs.ctx(deps, seed, audio);
            let mut steps = session.rule_steps(rules, &quiz)?;
            steps.extend(session.confusable_steps(confusables, &quiz)?);
            Ok(steps)
        }
        Slice::Vocab { words, grammar, .. } => {
            let slice_items: Vec<String> = words.iter().chain(grammar).cloned().collect();
            create_slice_cards(deps, &slice_items, &session.ctx)?;
            let inputs = with_slice_known(inputs, &slice_items);
            let quiz = inputs.ctx(deps, seed, audio);
            session.vocab_steps(words, grammar, &quiz)
        }
        Slice::Integration { .. } => Ok(Vec::new()),
    }
}

pub(crate) fn new_content_session(
    deps: &Deps,
    task_key: &str,
    session_seed: u32,
    audio_available: bool,
) -> Result<NewContentSessionDto, CoreError> {
    let ctx = deps.day_ctx()?;
    let snapshot = ensure_snapshot(&deps.repo, &deps.content, &ctx, audio_available)?;
    let (lesson_id, slice) = snapshot
        .tasks
        .iter()
        .find_map(|task| match task {
            DailyTask::NewContent {
                key,
                lesson_id,
                slice,
                ..
            } if key == task_key => Some((lesson_id, slice)),
            _ => None,
        })
        .ok_or_else(|| CoreError::not_found(TASK_ENTITY, task_key))?;
    let session = Session {
        deps,
        views: Views::load(deps)?,
        ctx,
    };
    let steps = steps_of(&session, slice, session_seed, audio_available)?;
    Ok(NewContentSessionDto {
        task_key: task_key.to_owned(),
        lesson_id: lesson_id.clone(),
        title_zh: deps
            .content
            .lesson(lesson_id)
            .map_or_else(String::new, |lesson| lesson.title_zh.clone()),
        steps,
    })
}

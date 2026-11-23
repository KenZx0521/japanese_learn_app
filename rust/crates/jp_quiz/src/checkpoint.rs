//! 檢定（§8.5）。

use std::collections::HashSet;

use jp_content::schema::{DrillDef, GrammarDef, MilestoneDef, Script, VocabDef};
use jp_content::ContentStore;
use jp_lang::clock::DayContext;
use jp_lang::kana::to_hiragana;
use jp_lang::quiz::rng::{rng_from_seed, seed_for, shuffled, ChaCha8Rng};
use jp_srs::use_cards::drill_is_usable;
use jp_store::{MilestoneResultRow, PlanRepo};

use crate::context::{QuestionKey, QuizContext};
use crate::distractor::KanaPool;
use crate::drill::{drill_question, is_offered, round_robin};
use crate::error::QuizError;
use crate::grade::grade_answer;
use crate::kana_quiz::{kana_listen_question, kana_read_question};
use crate::model::{Answer, Question, QuestionBody};
use crate::vocab_quiz::recog_question;

const MILESTONE_HIRA: &str = "ms.hira";
const MILESTONE_KATA: &str = "ms.kata";
/// 假名檢定最多四分之一是手寫題（`kana_word`、`minimal_pair`），其餘是單字元題。
const KANA_DRILL_DIVISOR: usize = 4;
const RECENT_LESSON_COUNT: usize = 3;
const LISTEN_EVERY: usize = 2;
/// 「各半」的份數。
const HALVES: usize = 2;
const PERCENT: u32 = 100;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CheckpointResult {
    pub milestone_id: String,
    pub correct: u32,
    pub total: u32,
    pub score_percent: u32,
    pub passed: bool,
    pub weak_ids: Vec<String>,
}

fn find_milestone<'c>(
    content: &'c ContentStore,
    milestone_id: &str,
) -> Result<&'c MilestoneDef, QuizError> {
    content
        .milestones()
        .iter()
        .find(|milestone| milestone.id == milestone_id)
        .ok_or_else(|| QuizError::not_found("milestone", milestone_id))
}

fn kana_script(milestone_id: &str) -> Option<Script> {
    match milestone_id {
        MILESTONE_HIRA => Some(Script::Hira),
        MILESTONE_KATA => Some(Script::Kata),
        _ => None,
    }
}

fn pos_at_most(content: &ContentStore, lesson: &str, max_pos: u32) -> bool {
    content.lesson_pos(lesson).is_some_and(|pos| pos <= max_pos)
}

fn matches_script(drill: &DrillDef, script: Script) -> bool {
    let text = match drill {
        DrillDef::KanaWord { word, .. } => word,
        DrillDef::MinimalPair { a, .. } => a,
        _ => return false,
    };
    (to_hiragana(text) != *text) == (script == Script::Kata)
}

fn kana_exam_drills<'c>(ctx: &QuizContext<'c>, script: Script, max_pos: u32) -> Vec<&'c DrillDef> {
    ctx.content
        .drills()
        .iter()
        .filter(|drill| matches_script(drill, script))
        .filter(|drill| is_offered(drill, ctx.audio_available))
        .filter(|drill| pos_at_most(ctx.content, drill.lesson(), max_pos))
        .collect()
}

fn exam_key(milestone_id: &str, item_id: &str) -> String {
    format!("{milestone_id}:{item_id}")
}

/// K19、KK08：範圍是該文字系統全部字，不看 `item_intro`，引導時也能考（§8.5）。
fn kana_exam(
    ctx: &QuizContext<'_>,
    milestone: &MilestoneDef,
    script: Script,
    max_pos: u32,
    rng: &mut ChaCha8Rng,
) -> Result<Vec<Question>, QuizError> {
    let wanted = milestone.questions as usize;
    let pool = KanaPool::whole_script(ctx.content, script, max_pos);
    let drills = shuffled(rng, kana_exam_drills(ctx, script, max_pos));
    let chars = shuffled(rng, pool.entries().to_vec());
    let drill_quota = (wanted / KANA_DRILL_DIVISOR).min(drills.len());
    let char_count = (wanted - drill_quota).min(chars.len());
    let drill_count = (wanted - char_count).min(drills.len());

    let mut questions = Vec::with_capacity(char_count + drill_count);
    for (index, entry) in chars.iter().take(char_count).enumerate() {
        let seed_key = exam_key(&milestone.id, &entry.def.id);
        let key = QuestionKey::plain(&seed_key);
        let question = if index % LISTEN_EVERY == 0 {
            kana_listen_question(ctx, &entry.def.id, &pool, key)?
        } else {
            kana_read_question(ctx, &entry.def.id, &pool, key)?
        };
        questions.extend(question);
    }
    for drill in drills.into_iter().take(drill_count) {
        let seed_key = exam_key(&milestone.id, drill.id());
        questions.push(drill_question(
            ctx,
            drill,
            QuestionKey::plain(&seed_key),
            None,
        )?);
    }
    Ok(shuffled(rng, questions))
}

/// 由課序末端往回，取最後幾個有單字或文法的課。
fn recent_lessons(content: &ContentStore, max_pos: u32) -> HashSet<String> {
    content
        .course()
        .order
        .iter()
        .take(max_pos as usize + 1)
        .rev()
        .filter(|lesson| {
            content
                .lesson_items(lesson)
                .is_some_and(|items| !items.words.is_empty() || !items.grammar.is_empty())
        })
        .take(RECENT_LESSON_COUNT)
        .cloned()
        .collect()
}

/// 待抽的項目，分成新近與較舊。逐筆轉成題目，轉不出來的跳過。
struct Draw<T> {
    recent: std::vec::IntoIter<T>,
    older: std::vec::IntoIter<T>,
}

type BuildQuestion<'b, T> = dyn Fn(&T) -> Result<Option<Question>, QuizError> + 'b;

impl<T> Draw<T> {
    fn new(recent: Vec<T>, older: Vec<T>) -> Self {
        Self {
            recent: recent.into_iter(),
            older: older.into_iter(),
        }
    }

    /// 新近、較舊各半；一邊不足時由另一邊補。
    fn take(
        &mut self,
        wanted: usize,
        build: &BuildQuestion<'_, T>,
    ) -> Result<Vec<Question>, QuizError> {
        let mut out = take_from(&mut self.recent, wanted.div_ceil(HALVES), build)?;
        out.extend(take_from(&mut self.older, wanted - out.len(), build)?);
        out.extend(take_from(&mut self.recent, wanted - out.len(), build)?);
        Ok(out)
    }
}

fn take_from<T>(
    items: &mut std::vec::IntoIter<T>,
    wanted: usize,
    build: &BuildQuestion<'_, T>,
) -> Result<Vec<Question>, QuizError> {
    let mut out = Vec::with_capacity(wanted);
    while out.len() < wanted {
        let Some(item) = items.next() else {
            break;
        };
        out.extend(build(&item)?);
    }
    Ok(out)
}

fn exam_vocab_ids<'c>(
    ctx: &QuizContext<'c>,
    max_pos: u32,
    recent: &HashSet<String>,
    rng: &mut ChaCha8Rng,
) -> Draw<&'c str> {
    let content = ctx.content;
    let (new, old): (Vec<_>, Vec<_>) = content
        .course()
        .order
        .iter()
        .take(max_pos as usize + 1)
        .filter_map(|lesson| content.lesson_items(lesson))
        .flat_map(|items| items.words.iter())
        .map(|&index| &content.vocab()[index as usize].def)
        .filter(|vocab| ctx.known.contains(&vocab.id))
        .partition(|vocab| recent.contains(&vocab.lesson));
    let ids = |list: Vec<&'c VocabDef>| list.into_iter().map(|v| v.id.as_str()).collect::<Vec<_>>();
    Draw::new(shuffled(rng, ids(new)), shuffled(rng, ids(old)))
}

fn grammar_drills<'c>(
    ctx: &QuizContext<'c>,
    grammar: &GrammarDef,
    max_pos: u32,
    rng: &mut ChaCha8Rng,
) -> Vec<&'c DrillDef> {
    let content = ctx.content;
    let drills = content
        .drills_for_target(&grammar.id)
        .iter()
        .map(|&index| &content.drills()[index as usize])
        .filter(|drill| !matches!(drill, DrillDef::Shadowing { .. }))
        .filter(|drill| is_offered(drill, ctx.audio_available))
        .filter(|drill| pos_at_most(content, drill.lesson(), max_pos))
        .filter(|drill| drill_is_usable(drill, ctx.known, content))
        .collect();
    shuffled(rng, drills)
}

/// 每個文法點輪流取題，同一題只出現一次。
fn flatten_unique(groups: Vec<Vec<&DrillDef>>) -> Vec<&DrillDef> {
    let mut seen = HashSet::new();
    round_robin(groups)
        .into_iter()
        .filter(|drill| seen.insert(drill.id()))
        .collect()
}

fn exam_grammar_drills<'c>(
    ctx: &QuizContext<'c>,
    max_pos: u32,
    recent: &HashSet<String>,
    rng: &mut ChaCha8Rng,
) -> Draw<&'c DrillDef> {
    let content = ctx.content;
    let (new, old): (Vec<_>, Vec<_>) = content
        .course()
        .order
        .iter()
        .take(max_pos as usize + 1)
        .filter_map(|lesson| content.lesson_items(lesson))
        .flat_map(|items| items.grammar.iter())
        .map(|&index| &content.grammar()[index as usize])
        .filter(|grammar| ctx.known.contains(&grammar.id))
        .partition(|grammar| recent.contains(&grammar.lesson));
    let new_groups = shuffled(rng, new)
        .into_iter()
        .map(|grammar| grammar_drills(ctx, grammar, max_pos, rng))
        .collect();
    let old_groups = shuffled(rng, old)
        .into_iter()
        .map(|grammar| grammar_drills(ctx, grammar, max_pos, rng))
        .collect();
    Draw::new(flatten_unique(new_groups), flatten_unique(old_groups))
}

/// L 課：文法與單字各半，新近與較舊各半，不足時互補（§8.5）。
fn lesson_exam(
    ctx: &QuizContext<'_>,
    milestone: &MilestoneDef,
    max_pos: u32,
    rng: &mut ChaCha8Rng,
) -> Result<Vec<Question>, QuizError> {
    let wanted = milestone.questions as usize;
    let recent = recent_lessons(ctx.content, max_pos);
    let mut vocab = exam_vocab_ids(ctx, max_pos, &recent, rng);
    let mut grammar = exam_grammar_drills(ctx, max_pos, &recent, rng);

    let id = milestone.id.as_str();
    let build_vocab = |vocab_id: &&str| -> Result<Option<Question>, QuizError> {
        let seed_key = exam_key(id, vocab_id);
        let question = recog_question(ctx, vocab_id, QuestionKey::plain(&seed_key))?;
        // 檢定每題都由 Rust 判定，退回自評的題目跳過
        Ok(matches!(question.body, QuestionBody::Choice { .. }).then_some(question))
    };
    let build_drill = |drill: &&DrillDef| -> Result<Option<Question>, QuizError> {
        let seed_key = exam_key(id, drill.id());
        drill_question(ctx, drill, QuestionKey::plain(&seed_key), None).map(Some)
    };

    let mut questions = grammar.take(wanted / HALVES, &build_drill)?;
    questions.extend(vocab.take(wanted - questions.len(), &build_vocab)?);
    questions.extend(grammar.take(wanted - questions.len(), &build_drill)?);
    Ok(shuffled(rng, questions))
}

pub fn checkpoint_start(
    ctx: &QuizContext<'_>,
    milestone_id: &str,
) -> Result<Vec<Question>, QuizError> {
    let milestone = find_milestone(ctx.content, milestone_id)?;
    let max_pos = ctx
        .content
        .lesson_pos(&milestone.lesson)
        .ok_or_else(|| QuizError::content(milestone_id, "里程碑的課不在課程內"))?;
    let mut rng = rng_from_seed(seed_for(ctx.session_seed, milestone_id));
    match kana_script(milestone_id) {
        Some(script) => kana_exam(ctx, milestone, script, max_pos, &mut rng),
        None => lesson_exam(ctx, milestone, max_pos, &mut rng),
    }
}

/// 逐筆由 Rust 判定，寫 `milestone_result`，不寫 FSRS（§8.5）。
pub fn checkpoint_finish<R>(
    repo: &R,
    content: &ContentStore,
    ctx: &DayContext,
    milestone_id: &str,
    answers: &[Answer],
) -> Result<CheckpointResult, QuizError>
where
    R: PlanRepo + ?Sized,
{
    let milestone = find_milestone(content, milestone_id)?;
    if answers.is_empty() {
        return Err(QuizError::invalid("answers", "沒有作答"));
    }
    let mut seen = HashSet::new();
    let unique: Vec<&Answer> = answers
        .iter()
        .filter(|answer| seen.insert(&answer.reference))
        .collect();
    let mut correct = 0u32;
    let mut weak_ids: Vec<String> = Vec::new();
    for answer in &unique {
        if grade_answer(content, &answer.reference, &answer.response)?.is_correct {
            correct += 1;
        } else if !weak_ids.contains(&answer.reference.content_id) {
            weak_ids.push(answer.reference.content_id.clone());
        }
    }
    let total =
        u32::try_from(unique.len()).map_err(|_| QuizError::invalid("answers", "作答數量過多"))?;
    let passed = f64::from(correct) / f64::from(total) >= milestone.pass_ratio;
    repo.insert_milestone_result(&MilestoneResultRow {
        milestone_id: milestone_id.to_owned(),
        correct,
        total,
        passed,
        logical_date: ctx.today(),
        taken_at: ctx.now,
    })?;
    Ok(CheckpointResult {
        milestone_id: milestone_id.to_owned(),
        correct,
        total,
        score_percent: correct * PERCENT / total,
        passed,
        weak_ids,
    })
}

/// 寫 `milestone_dismissed`，之後仍可從計畫頁手動開始（§8.5）。
pub fn checkpoint_dismiss<R>(
    repo: &R,
    content: &ContentStore,
    ctx: &DayContext,
    milestone_id: &str,
) -> Result<(), QuizError>
where
    R: PlanRepo + ?Sized,
{
    find_milestone(content, milestone_id)?;
    repo.dismiss_milestone(milestone_id, ctx.today(), ctx.now)?;
    Ok(())
}

//! 手寫演練轉題目（§8.4）。

mod choice;
pub(crate) mod grade;
mod order;
mod simple;
mod substitution;

pub use simple::conj_form_label;

use std::collections::VecDeque;

use jp_content::schema::DrillDef;
use jp_content::ContentStore;
use jp_lang::quiz::rng::{rng_from_seed, seed_for, shuffled, ChaCha8Rng};
use jp_srs::use_cards::{drill_is_usable, drill_needs_audio, is_listen_disabled};

use crate::context::{QuestionKey, QuizContext};
use crate::error::QuizError;
use crate::model::{Prompt, Question, QuestionBody, QuestionRef};
use crate::question_type::QuestionType;

const DRILL_SESSION_SEED_KEY: &str = "drill_session";

/// 各題型算好的內容，由 `drill_question` 補上共同欄位。
pub(crate) struct Draft {
    pub prompt: Prompt,
    pub body: QuestionBody,
    pub explain_zh: Option<String>,
    pub variant: Option<u32>,
}

impl Draft {
    fn new(prompt: Prompt, body: QuestionBody) -> Self {
        Self {
            prompt,
            body,
            explain_zh: None,
            variant: None,
        }
    }
}

fn question_type_of(drill: &DrillDef) -> QuestionType {
    match drill {
        DrillDef::Substitution { .. } => QuestionType::Substitution,
        DrillDef::Reorder { .. } => QuestionType::Reorder,
        DrillDef::ParticleFill { .. } => QuestionType::ParticleFill,
        DrillDef::ZhToJaChoice { .. } => QuestionType::ZhToJaChoice,
        DrillDef::ListenMeaning { .. } => QuestionType::ListenMeaning,
        DrillDef::SituationResponse { .. } => QuestionType::SituationResponse,
        DrillDef::Conjugate { .. } => QuestionType::Conjugate,
        DrillDef::RegisterConvert { .. } => QuestionType::RegisterConvert,
        DrillDef::Shadowing { .. } => QuestionType::Shadowing,
        DrillDef::FalseFriend { .. } => QuestionType::FalseFriend,
        DrillDef::MinimalPair { .. } => QuestionType::MinimalPair,
        DrillDef::KanaWord { .. } => QuestionType::KanaWord,
    }
}

fn draft_for(
    content: &ContentStore,
    drill: &DrillDef,
    rng: &mut ChaCha8Rng,
) -> Result<Draft, QuizError> {
    match drill {
        DrillDef::Substitution { .. } => substitution::draft(drill, rng),
        DrillDef::Reorder { .. } => order::reorder(content, drill, rng),
        DrillDef::RegisterConvert { .. } => order::register_convert(content, drill, rng),
        DrillDef::ParticleFill { .. } => choice::particle_fill(content, drill, rng),
        DrillDef::ZhToJaChoice { .. } => choice::zh_to_ja(content, drill, rng),
        DrillDef::SituationResponse { .. } => choice::situation_response(content, drill, rng),
        DrillDef::ListenMeaning { .. } => choice::listen_meaning(content, drill, rng),
        DrillDef::FalseFriend { .. } => choice::false_friend(content, drill, rng),
        DrillDef::Conjugate { .. } => simple::conjugate(content, drill, rng),
        DrillDef::MinimalPair { .. } => simple::minimal_pair(drill, rng),
        DrillDef::KanaWord { .. } => simple::kana_word(drill, rng),
        DrillDef::Shadowing { .. } => simple::shadowing(content, drill),
    }
}

/// 分派與變體不符；`draft_for`、`grade_drill` 依變體呼叫，走到這裡代表程式錯誤。
pub(crate) fn wrong_kind(drill: &DrillDef) -> QuizError {
    QuizError::content(drill.id(), format!("題型分派錯誤：{}", drill.type_name()))
}

/// `content_id` 為 `None` 時用 `targets[0]`；`use` 卡傳卡片的 `content_id`（§8.4）。
pub fn drill_question(
    ctx: &QuizContext<'_>,
    drill: &DrillDef,
    key: QuestionKey<'_>,
    content_id: Option<&str>,
) -> Result<Question, QuizError> {
    let mut rng = key.rng(ctx.session_seed);
    let draft = draft_for(ctx.content, drill, &mut rng)?;
    let targets = drill.targets();
    let content_id = content_id
        .or_else(|| targets.first().map(String::as_str))
        .unwrap_or(drill.id());
    let reference = QuestionRef {
        question_type: question_type_of(drill),
        card_id: key.card_id.map(str::to_owned),
        drill_id: Some(drill.id().to_owned()),
        content_id: content_id.to_owned(),
        variant: draft.variant,
    };
    Ok(Question::new(reference, draft.prompt, draft.body)
        .with_explain(draft.explain_zh)
        .with_focus(targets.to_vec()))
}

/// 這題此刻能不能出：淘汰、`listen_disabled`、沒有語音時需要語音的題都不出（§8.4、§9.4）。
pub(crate) fn is_offered(drill: &DrillDef, audio_available: bool) -> bool {
    !drill.retired() && !is_listen_disabled(drill) && (audio_available || !drill_needs_audio(drill))
}

/// `drill_session` 的條件，`task_key` 由根 crate 先解成 `lesson_ids`（§7.4）。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DrillSelection<'a> {
    pub lesson_ids: &'a [String],
    pub target: Option<&'a str>,
    /// 非空時只取這些題，不看 `item_intro`（對話、規則卡的固定題組）。
    pub drill_ids: &'a [String],
    /// 0 表示不限。
    pub count: u32,
}

fn explicit_drills<'c>(
    ctx: &QuizContext<'c>,
    ids: &[String],
) -> Result<Vec<&'c DrillDef>, QuizError> {
    let drills = ids
        .iter()
        .map(|id| {
            ctx.content
                .drill_by_id(id)
                .ok_or_else(|| QuizError::not_found("drill", id))
        })
        .collect::<Result<Vec<_>, _>>()?;
    Ok(drills
        .into_iter()
        .filter(|drill| is_offered(drill, ctx.audio_available))
        .collect())
}

fn scoped_drills<'c>(ctx: &QuizContext<'c>, selection: &DrillSelection<'_>) -> Vec<&'c DrillDef> {
    let content = ctx.content;
    let by_index = |index: &u32| &content.drills()[*index as usize];
    let lessons = selection.lesson_ids;
    let scoped: Vec<&DrillDef> = match selection.target {
        Some(target) => content
            .drills_for_target(target)
            .iter()
            .map(by_index)
            .filter(|drill| lessons.is_empty() || lessons.iter().any(|l| l == drill.lesson()))
            .collect(),
        None => lessons
            .iter()
            .filter_map(|lesson| content.lesson_items(lesson))
            .flat_map(|items| items.drills.iter().map(by_index))
            .collect(),
    };
    scoped
        .into_iter()
        .filter(|drill| is_offered(drill, ctx.audio_available))
        .filter(|drill| drill_is_usable(drill, ctx.known, content))
        .collect()
}

/// 每組輪流取一個，各組內順序不變。
pub(crate) fn round_robin<T>(groups: Vec<Vec<T>>) -> Vec<T> {
    let mut queues: Vec<VecDeque<T>> = groups.into_iter().map(VecDeque::from).collect();
    let total = queues.iter().map(VecDeque::len).sum();
    let mut out = Vec::with_capacity(total);
    while out.len() < total {
        out.extend(queues.iter_mut().filter_map(VecDeque::pop_front));
    }
    out
}

/// 依題型分組，組序由第一次出現決定。
fn rotate_by_type(drills: Vec<&DrillDef>) -> Vec<&DrillDef> {
    let mut groups: Vec<(&str, Vec<&DrillDef>)> = Vec::new();
    for drill in drills {
        let type_name = drill.type_name();
        match groups.iter_mut().find(|(name, _)| *name == type_name) {
            Some((_, group)) => group.push(drill),
            None => groups.push((type_name, vec![drill])),
        }
    }
    round_robin(groups.into_iter().map(|(_, group)| group).collect())
}

/// 以種子洗牌後依題型輪流取（§7.4）。
pub fn drill_session(
    ctx: &QuizContext<'_>,
    selection: &DrillSelection<'_>,
) -> Result<Vec<Question>, QuizError> {
    let candidates = if selection.drill_ids.is_empty() {
        scoped_drills(ctx, selection)
    } else {
        explicit_drills(ctx, selection.drill_ids)?
    };
    let mut rng = rng_from_seed(seed_for(ctx.session_seed, DRILL_SESSION_SEED_KEY));
    let ordered = rotate_by_type(shuffled(&mut rng, candidates));
    let limit = match selection.count {
        0 => ordered.len(),
        count => count as usize,
    };
    ordered
        .into_iter()
        .take(limit)
        .map(|drill| drill_question(ctx, drill, QuestionKey::plain(drill.id()), None))
        .collect()
}

/// `RuleCardDto.drill_ids`、`SoundGroupDto.test_drill_ids` 用：濾掉不出題的 `minimal_pair`（§8.4）。
pub fn quizzable_drill_ids(content: &ContentStore, ids: &[String]) -> Vec<String> {
    ids.iter()
        .filter(|id| {
            content
                .drill_by_id(id)
                .is_some_and(|drill| !drill.retired() && !is_listen_disabled(drill))
        })
        .cloned()
        .collect()
}

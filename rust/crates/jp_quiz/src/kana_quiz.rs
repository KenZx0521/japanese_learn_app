//! 假名題（§8.2、§8.4）。

use std::collections::HashSet;

use jp_content::schema::{ConfusableDef, ConfusableKind, DrillDef, KanaKind, Script};
use jp_content::speech::kana_speech;
use jp_content::store::KanaEntry;
use jp_content::ContentStore;
use jp_lang::quiz::rng::{index_below, rng_from_seed, seed_for, shuffled, ChaCha8Rng};

use crate::context::{QuestionKey, QuizContext};
use crate::distractor::{
    confusable_groups, is_confuse_kind, kana_distractors, sound_key, KanaPool,
};
use crate::drill::{drill_question, is_offered};
use crate::error::QuizError;
use crate::model::{ChoiceOption, MatchPair, Prompt, Question, QuestionBody, QuestionRef};
use crate::question_type::QuestionType;
use crate::view::mixed_ja;

const MATCH_PAIR_COUNT: usize = 5;
const MIN_MATCH_PAIRS: usize = 2;
const MIN_CONFUSE_OPTIONS: usize = 2;

const READ_INSTRUCTION: &str = "選出這個字的讀音";
const LISTEN_INSTRUCTION: &str = "聽聲音，選出聽到的字";
const CONFUSE_SHAPE_INSTRUCTION: &str = "看讀音，選出正確的字";
const CONFUSE_TO_KATAKANA_INSTRUCTION: &str = "選出對應的片假名";
const CONFUSE_TO_HIRAGANA_INSTRUCTION: &str = "選出對應的平假名";
const MATCH_INSTRUCTION: &str = "把假名和讀音配成一對";

fn kana_entry<'c>(content: &'c ContentStore, id: &str) -> Result<&'c KanaEntry, QuizError> {
    content
        .kana_by_id(id)
        .ok_or_else(|| QuizError::not_found("kana", id))
}

fn reference(question_type: QuestionType, kana_id: &str, key: QuestionKey<'_>) -> QuestionRef {
    QuestionRef {
        question_type,
        card_id: key.card_id.map(str::to_owned),
        drill_id: None,
        content_id: kana_id.to_owned(),
        variant: None,
    }
}

fn choice_body(options: Vec<ChoiceOption>, correct_id: &str, rng: &mut ChaCha8Rng) -> QuestionBody {
    QuestionBody::Choice {
        options: shuffled(rng, options),
        correct_option_id: correct_id.to_owned(),
        blank_word_index: None,
    }
}

fn read_option(entry: &KanaEntry) -> ChoiceOption {
    ChoiceOption {
        id: entry.def.id.clone(),
        text: entry.romaji.clone(),
        ..ChoiceOption::default()
    }
}

fn char_option(entry: &KanaEntry) -> ChoiceOption {
    ChoiceOption {
        id: entry.def.id.clone(),
        text: entry.def.ch.clone(),
        ..ChoiceOption::default()
    }
}

/// 回傳 `None` 表示沒有干擾項，選項數下限是 2（§8.2）。
pub fn kana_read_question(
    ctx: &QuizContext<'_>,
    kana_id: &str,
    pool: &KanaPool<'_>,
    key: QuestionKey<'_>,
) -> Result<Option<Question>, QuizError> {
    let target = kana_entry(ctx.content, kana_id)?;
    let mut rng = key.rng(ctx.session_seed);
    let distractors = kana_distractors(target, pool, ctx.content, &mut rng);
    if distractors.is_empty() {
        return Ok(None);
    }
    let options = std::iter::once(target)
        .chain(distractors)
        .map(read_option)
        .collect();
    let prompt = Prompt {
        instruction_zh: READ_INSTRUCTION.to_owned(),
        plain_text: Some(mixed_ja(&target.def.ch, &target.def.ch)),
        speech: (!target.def.listen_disabled).then(|| kana_speech(&target.def)),
        ..Prompt::default()
    };
    let body = choice_body(options, kana_id, &mut rng);
    let question = Question::new(
        reference(QuestionType::KanaRead, kana_id, key),
        prompt,
        body,
    );
    Ok(Some(question.with_focus(vec![kana_id.to_owned()])))
}

/// `listen_disabled` 或沒有語音時改出 `kana_read`（§8.2）。
pub fn kana_listen_question(
    ctx: &QuizContext<'_>,
    kana_id: &str,
    pool: &KanaPool<'_>,
    key: QuestionKey<'_>,
) -> Result<Option<Question>, QuizError> {
    let target = kana_entry(ctx.content, kana_id)?;
    if target.def.listen_disabled || !ctx.audio_available {
        return kana_read_question(ctx, kana_id, pool, key);
    }
    let mut rng = key.rng(ctx.session_seed);
    let distractors = kana_distractors(target, pool, ctx.content, &mut rng);
    if distractors.is_empty() {
        return Ok(None);
    }
    let options = std::iter::once(target)
        .chain(distractors)
        .map(char_option)
        .collect();
    let prompt = Prompt {
        instruction_zh: LISTEN_INSTRUCTION.to_owned(),
        speech: Some(kana_speech(&target.def)),
        autoplay: true,
        hide_text_until_answered: true,
        ..Prompt::default()
    };
    let body = choice_body(options, kana_id, &mut rng);
    let question = Question::new(
        reference(QuestionType::KanaListen, kana_id, key),
        prompt,
        body,
    );
    Ok(Some(question.with_focus(vec![kana_id.to_owned()])))
}

fn taught_members<'c>(
    ctx: &QuizContext<'c>,
    group: &'c ConfusableDef,
    target_id: &str,
    pool: &KanaPool<'_>,
) -> Vec<&'c KanaEntry> {
    group
        .members
        .iter()
        .filter(|member| *member == target_id || pool.contains(member))
        .filter_map(|member| ctx.content.kana_by_id(member))
        .collect()
}

/// 題幹與選項（尚未洗牌）；`None` 表示湊不出至少兩個選項。
struct ConfuseParts<'c> {
    prompt: Prompt,
    options: Vec<&'c KanaEntry>,
}

/// `shape`：看讀音選字，選項只有同組字形。同讀音的字（お／を）不能同時出現，否則有兩個正解。
fn shape_parts<'c>(
    ctx: &QuizContext<'c>,
    target: &'c KanaEntry,
    group: &'c ConfusableDef,
    pool: &KanaPool<'_>,
) -> Option<ConfuseParts<'c>> {
    let options: Vec<&KanaEntry> = taught_members(ctx, group, &target.def.id, pool)
        .into_iter()
        .filter(|entry| entry.def.id == target.def.id || sound_key(entry) != sound_key(target))
        .collect();
    (options.len() >= MIN_CONFUSE_OPTIONS).then(|| ConfuseParts {
        prompt: Prompt {
            instruction_zh: CONFUSE_SHAPE_INSTRUCTION.to_owned(),
            plain_text: Some(target.romaji.clone()),
            speech: (!target.def.listen_disabled).then(|| kana_speech(&target.def)),
            ..Prompt::default()
        },
        options,
    })
}

fn cross_script_counterpart<'c>(
    ctx: &QuizContext<'c>,
    target: &KanaEntry,
    group: &'c ConfusableDef,
    pool: &KanaPool<'_>,
) -> Option<&'c KanaEntry> {
    taught_members(ctx, group, &target.def.id, pool)
        .into_iter()
        .find(|entry| {
            entry.def.script != target.def.script && sound_key(entry) == sound_key(target)
        })
}

/// `cross_script`：題幹是另一種文字的對應字，選項全是目標字的文字。字組多半只有一對（か／カ），
/// 另一種文字的同組字只有正解一個，所以干擾項取同文字的已教字（§8.2）。
fn cross_script_parts<'c>(
    ctx: &QuizContext<'c>,
    target: &'c KanaEntry,
    group: &'c ConfusableDef,
    pool: &KanaPool<'c>,
    rng: &mut ChaCha8Rng,
) -> Option<ConfuseParts<'c>> {
    let counterpart = cross_script_counterpart(ctx, target, group, pool)?;
    let same_script = pool.of_script(target.def.script);
    let distractors = kana_distractors(target, &same_script, ctx.content, rng);
    if distractors.is_empty() {
        return None;
    }
    let instruction = match target.def.script {
        Script::Kata => CONFUSE_TO_KATAKANA_INSTRUCTION,
        Script::Hira => CONFUSE_TO_HIRAGANA_INSTRUCTION,
    };
    Some(ConfuseParts {
        prompt: Prompt {
            instruction_zh: instruction.to_owned(),
            plain_text: Some(mixed_ja(&counterpart.def.ch, &counterpart.def.ch)),
            ..Prompt::default()
        },
        options: std::iter::once(target).chain(distractors).collect(),
    })
}

fn confuse_parts<'c>(
    ctx: &QuizContext<'c>,
    target: &'c KanaEntry,
    group: &'c ConfusableDef,
    pool: &KanaPool<'c>,
    rng: &mut ChaCha8Rng,
) -> Option<ConfuseParts<'c>> {
    match group.kind {
        ConfusableKind::Shape => shape_parts(ctx, target, group, pool),
        ConfusableKind::CrossScript => cross_script_parts(ctx, target, group, pool, rng),
        ConfusableKind::KanaKanji | ConfusableKind::Listen => None,
    }
}

/// 考讀音辨識，判定仍是「選到目標字」：`shape` 由讀音選字形，`cross_script` 由對應字選目標字（§8.2）。
fn confuse_in_group<'c>(
    ctx: &QuizContext<'c>,
    target: &'c KanaEntry,
    group: &'c ConfusableDef,
    pool: &KanaPool<'c>,
    key: QuestionKey<'_>,
    rng: &mut ChaCha8Rng,
) -> Option<Question> {
    let ConfuseParts { prompt, options } = confuse_parts(ctx, target, group, pool, rng)?;
    let kana_id = target.def.id.as_str();
    let options = options.into_iter().map(char_option).collect();
    let body = choice_body(options, kana_id, rng);
    let question = Question::new(
        reference(QuestionType::KanaConfuse, kana_id, key),
        prompt,
        body,
    )
    .with_explain(Some(group.diff_zh.clone()))
    .with_focus(vec![kana_id.to_owned()]);
    Some(question)
}

/// 目標字有多組時依種子選一組；`None` 表示沒有出得了題的字組。
pub fn kana_confuse_question<'c>(
    ctx: &QuizContext<'c>,
    kana_id: &str,
    pool: &KanaPool<'c>,
    key: QuestionKey<'_>,
) -> Result<Option<Question>, QuizError> {
    let target = kana_entry(ctx.content, kana_id)?;
    let eligible: Vec<&ConfusableDef> = confusable_groups(kana_id, ctx.content)
        .into_iter()
        .filter(|group| {
            confuse_parts(ctx, target, group, pool, &mut key.rng(ctx.session_seed)).is_some()
        })
        .collect();
    let mut rng = key.rng(ctx.session_seed);
    let Some(group) = index_below(&mut rng, eligible.len()).map(|index| eligible[index]) else {
        return Ok(None);
    };
    Ok(confuse_in_group(ctx, target, group, pool, key, &mut rng))
}

/// `kana_match`：5 對（§8.4），字數不足時有幾對出幾對，少於 2 對不出題。
pub fn kana_match_question(
    ctx: &QuizContext<'_>,
    kana_ids: &[&str],
    key: QuestionKey<'_>,
) -> Result<Option<Question>, QuizError> {
    let entries = kana_ids
        .iter()
        .map(|id| kana_entry(ctx.content, id))
        .collect::<Result<Vec<_>, _>>()?;
    let mut rng = key.rng(ctx.session_seed);
    let mut seen = HashSet::new();
    let pairs: Vec<MatchPair> = shuffled(&mut rng, entries)
        .into_iter()
        .filter(|entry| seen.insert(sound_key(entry).to_owned()))
        .take(MATCH_PAIR_COUNT)
        .map(|entry| MatchPair {
            left_id: entry.def.id.clone(),
            left: entry.def.ch.clone(),
            right_id: entry.def.id.clone(),
            right: entry.romaji.clone(),
        })
        .collect();
    if pairs.len() < MIN_MATCH_PAIRS {
        return Ok(None);
    }
    let focus_ids = pairs.iter().map(|pair| pair.left_id.clone()).collect();
    let content_id = pairs[0].left_id.clone();
    let prompt = Prompt {
        instruction_zh: MATCH_INSTRUCTION.to_owned(),
        ..Prompt::default()
    };
    let question = Question::new(
        reference(QuestionType::KanaMatch, &content_id, key),
        prompt,
        QuestionBody::Match { pairs },
    );
    Ok(Some(question.with_focus(focus_ids)))
}

/// 新內容的 `KanaQuiz` 步驟：每字兩題（§9.4），依種子打散。
pub fn kana_batch_quiz(
    ctx: &QuizContext<'_>,
    batch: &[&str],
    pool: &KanaPool<'_>,
) -> Result<Vec<Question>, QuizError> {
    let mut questions = Vec::new();
    for &id in batch {
        let read_key = format!("{id}:kana_read");
        let listen_key = format!("{id}:kana_listen");
        questions.extend(kana_read_question(
            ctx,
            id,
            pool,
            QuestionKey::plain(&read_key),
        )?);
        questions.extend(kana_listen_question(
            ctx,
            id,
            pool,
            QuestionKey::plain(&listen_key),
        )?);
    }
    let batch_key = format!("kana_batch:{}", batch.first().copied().unwrap_or(""));
    let mut rng = rng_from_seed(seed_for(ctx.session_seed, &batch_key));
    Ok(shuffled(&mut rng, questions))
}

/// K10 `Confusable` 步驟後的 `kana_confuse`：同組每字各一題。
pub fn confuse_quiz(
    ctx: &QuizContext<'_>,
    group_id: &str,
    pool: &KanaPool<'_>,
) -> Result<Vec<Question>, QuizError> {
    let group = ctx
        .content
        .confusable_by_id(group_id)
        .ok_or_else(|| QuizError::not_found("confusable", group_id))?;
    if group.retired || !is_confuse_kind(group.kind) {
        return Ok(Vec::new());
    }
    let mut questions = Vec::new();
    for member in group.members.iter().filter(|member| pool.contains(member)) {
        let target = kana_entry(ctx.content, member)?;
        let seed_key = format!("{group_id}:{member}");
        let key = QuestionKey::plain(&seed_key);
        let mut rng = key.rng(ctx.session_seed);
        questions.extend(confuse_in_group(ctx, target, group, pool, key, &mut rng));
    }
    Ok(questions)
}

fn rule_drill_questions(
    ctx: &QuizContext<'_>,
    drills: &[String],
    owner: &str,
) -> Result<Vec<Question>, QuizError> {
    drills
        .iter()
        .filter_map(|id| ctx.content.drill_by_id(id))
        .filter(|drill| matches!(drill, DrillDef::MinimalPair { .. }))
        .filter(|drill| is_offered(drill, ctx.audio_available))
        .map(|drill| {
            let seed_key = format!("{owner}:{}", drill.id());
            drill_question(ctx, drill, QuestionKey::plain(&seed_key), None)
        })
        .collect()
}

/// `Rule` 步驟後的 `minimal_pair`；濾完沒有題時回空，不產生 `KanaQuiz`（§8.4）。
pub fn rule_quiz(ctx: &QuizContext<'_>, rule_id: &str) -> Result<Vec<Question>, QuizError> {
    let rule = ctx
        .content
        .rule_card_by_id(rule_id)
        .ok_or_else(|| QuizError::not_found("rule_card", rule_id))?;
    rule_drill_questions(ctx, &rule.drills, rule_id)
}

fn lesson_drills(
    ctx: &QuizContext<'_>,
    lesson_id: &str,
    drill_indices: &[u32],
) -> Result<Vec<Question>, QuizError> {
    drill_indices
        .iter()
        .map(|&index| &ctx.content.drills()[index as usize])
        .filter(|drill| {
            matches!(
                drill,
                DrillDef::MinimalPair { .. } | DrillDef::KanaWord { .. }
            )
        })
        .filter(|drill| is_offered(drill, ctx.audio_available))
        .map(|drill| {
            let seed_key = format!("{lesson_id}:{}", drill.id());
            drill_question(ctx, drill, QuestionKey::plain(&seed_key), None)
        })
        .collect()
}

/// K1 自由練習（§9.4），不影響計畫。課內的字與字組都算「已呈現」。
pub fn kana_session(ctx: &QuizContext<'_>, lesson_id: &str) -> Result<Vec<Question>, QuizError> {
    let content = ctx.content;
    if content.lesson_pos(lesson_id).is_none() {
        return Err(QuizError::not_found("lesson", lesson_id));
    }
    let Some(items) = content.lesson_items(lesson_id) else {
        return Ok(Vec::new());
    };
    let chars: Vec<&str> = items
        .kana
        .iter()
        .map(|&index| &content.kana()[index as usize])
        .filter(|entry| entry.def.kind != KanaKind::Mark)
        .map(|entry| entry.def.id.as_str())
        .collect();
    let groups: Vec<&ConfusableDef> = items
        .confusables
        .iter()
        .map(|&index| &content.confusables()[index as usize])
        .collect();
    let presented: Vec<&str> = groups
        .iter()
        .flat_map(|group| group.members.iter().map(String::as_str))
        .chain(chars.iter().copied())
        .collect();
    let pool = KanaPool::taught(content, ctx.known, &presented);

    let mut questions = kana_batch_quiz(ctx, &chars, &pool)?;
    let match_key = format!("{lesson_id}:kana_match");
    questions.extend(kana_match_question(
        ctx,
        &chars,
        QuestionKey::plain(&match_key),
    )?);
    for group in groups {
        questions.extend(confuse_quiz(ctx, &group.id, &pool)?);
    }
    questions.extend(lesson_drills(ctx, lesson_id, &items.drills)?);
    Ok(questions)
}

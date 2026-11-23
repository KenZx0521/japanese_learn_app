//! 今日任務的純函式組裝（§7.4）。資料庫的資料都由呼叫端備好。

use std::collections::HashSet;

use chrono::NaiveDate;
use jp_content::schema::{DrillDef, PlanPresetDef};
use jp_content::ContentStore;
use jp_lang::quiz::rng::{fnv1a, rng_from_seed, shuffled};
use jp_srs::use_cards::{drill_is_usable, drill_needs_audio};
use jp_store::{MilestoneResultRow, PlanVersionRow};

use crate::budget::{
    assess_recovery, estimate_review_minutes, missed_study_days, review_cap, review_cap_after_tail,
    review_only_split, stage_split, DayBudget, Recovery, RecoveryFacts, Split,
};
use crate::calendar::{is_study_day, PlanHistory};
use crate::milestone::due_checkpoints;
use crate::slice::{integration_days_needed, next_slice, Slice, SliceQuota};
use crate::state::{cursor, cursor_pos, recent_main_lessons, stage_for_cursor, CursorState};
use crate::tasks::{
    checkpoint_key, integration_key, new_content_key, DailyTask, DaySnapshot, KEY_DRILL,
    KEY_LISTEN, KEY_REVIEW,
};

const SECONDS_PER_MINUTE: f64 = 60.0;
const DRILL_SECONDS: f64 = 30.0;
const LISTEN_SECONDS: f64 = 20.0;
const MIN_LISTEN_MINUTES: f64 = 0.5;

#[derive(Debug, Clone, Copy)]
pub struct DayFacts<'a> {
    pub today: NaiveDate,
    pub plan: &'a PlanVersionRow,
    pub preset: &'a PlanPresetDef,
    pub state: &'a CursorState,
    pub history: &'a PlanHistory,
    pub due_facets: &'a [String],
    /// 快照當下收尾可取的 state=0 卡（`available_new_cards`，§7.4 `new_cards`）。
    pub tail_new_cards: u32,
    pub unseen_new: u32,
    pub last_active: Option<NaiveDate>,
    pub previous_recovery_days: u32,
    pub audio_available: bool,
    pub milestone_results: &'a [MilestoneResultRow],
    pub dismissed: &'a HashSet<String>,
}

/// 當天的計算中間結果，組裝任務時共用。
struct DayPlan<'a> {
    facts: &'a DayFacts<'a>,
    is_study_day: bool,
    cursor: Option<&'a str>,
    split: Split,
    recovery: Recovery,
    slice: Option<Slice>,
}

/// `learn_more` 也用這個額度。`Full` 模式。
pub fn slice_quota_for(preset: &PlanPresetDef) -> SliceQuota {
    SliceQuota {
        mode: crate::budget::NewContentMode::Full,
        words: preset.new_words_per_day,
        kana: preset.kana_chars_per_day,
        integration_days_needed: integration_days_needed(preset.minutes),
    }
}

/// `review_cap` 先扣收尾新卡（§7.2）；積壓的兩條線看扣除前的 `capacity`（RULINGS O11）。
fn recovery_facts(facts: &DayFacts<'_>, split: &Split, is_study_day: bool) -> RecoveryFacts {
    RecoveryFacts {
        due_reviews: u32::try_from(facts.due_facets.len()).expect("到期卡數不可能超過 u32"),
        review_cap: review_cap_after_tail(split.review, facts.tail_new_cards, facts.due_facets),
        capacity: review_cap(split.review, facts.due_facets),
        tail_new_cards: facts.tail_new_cards,
        unseen_new: facts.unseen_new,
        new_words_limit: facts.preset.new_words_per_day,
        missed_study_days: missed_study_days(facts.last_active, facts.today, facts.history),
        previous_recovery_days: facts.previous_recovery_days,
        is_study_day,
    }
}

/// 以階段配比判定受限；只排複習的日子改用全給複習的配比，`review_cap` 依此重算（回鍋日仍減半）。
fn day_split(facts: &DayFacts<'_>, stage_split: Split, is_study_day: bool) -> (Split, Recovery) {
    let recovery = assess_recovery(&recovery_facts(facts, &stage_split, is_study_day));
    if !recovery.reviews_only() {
        return (stage_split, recovery);
    }
    let split = review_only_split(&stage_split);
    let review_cap = review_cap_after_tail(split.review, facts.tail_new_cards, facts.due_facets);
    (split, recovery.with_review_cap(review_cap))
}

fn assess<'a>(facts: &'a DayFacts<'a>, content: &'a ContentStore) -> DayPlan<'a> {
    let is_study_day = is_study_day(facts.plan.weekday_mask, facts.today);
    let cursor = cursor(facts.state, content);
    let stage = stage_for_cursor(cursor, content);
    let (split, recovery) = day_split(facts, stage_split(facts.preset, stage), is_study_day);
    let quota = SliceQuota {
        mode: recovery.mode,
        ..slice_quota_for(facts.preset)
    };
    let slice = is_study_day
        .then(|| next_slice(facts.state, &quota, content))
        .flatten();
    DayPlan {
        facts,
        is_study_day,
        cursor,
        split,
        recovery,
        slice,
    }
}

impl DayPlan<'_> {
    fn budget(&self) -> DayBudget {
        DayBudget {
            split: self.split,
            review_cap: self.recovery.review_cap,
            capacity: self.recovery.capacity,
            new_words_limit: self.facts.preset.new_words_per_day,
            kana_chars_limit: self.facts.preset.kana_chars_per_day,
            new_content: self.recovery.mode,
            recovery_reason: self.recovery.reason,
            recovery_days: self.recovery.days,
        }
    }

    fn integration_minutes(&self) -> f64 {
        self.split.new + self.split.drill + self.split.listen
    }

    fn is_integration_day(&self) -> bool {
        matches!(self.slice, Some(Slice::Integration { .. }))
    }

    fn main_slice_task(&self) -> Option<DailyTask> {
        self.slice
            .clone()
            .map(|slice| task_for_slice(slice, self.split.new, self.integration_minutes()))
    }
}

/// `new_minutes` 給 `NewContent`，`integration_minutes` 給 `Integration`。
pub(crate) fn task_for_slice(
    slice: Slice,
    new_minutes: f64,
    integration_minutes: f64,
) -> DailyTask {
    match slice {
        Slice::Integration {
            lesson_id,
            dialogue_id,
            phases,
            day_no,
        } => DailyTask::Integration {
            key: integration_key(&lesson_id, day_no),
            lesson_id,
            dialogue_id,
            phases,
            minutes: integration_minutes,
        },
        other => DailyTask::NewContent {
            key: new_content_key(other.key_item_id()),
            lesson_id: other.lesson_id().to_owned(),
            slice: other,
            minutes: new_minutes,
        },
    }
}

/// `listen_disabled` 的 `minimal_pair` 不出題（§8.4）。
fn drill_is_playable(drill: &DrillDef, audio_available: bool) -> bool {
    let disabled = matches!(
        drill,
        DrillDef::MinimalPair {
            listen_disabled: true,
            ..
        }
    );
    !disabled && (audio_available || !drill_needs_audio(drill))
}

fn count_drill_candidates(lessons: &[&str], facts: &DayFacts<'_>, content: &ContentStore) -> u32 {
    let count = lessons
        .iter()
        .filter_map(|lesson| content.lesson_items(lesson))
        .flat_map(|items| &items.drills)
        .map(|&index| &content.drills()[index as usize])
        .filter(|drill| drill_is_playable(drill, facts.audio_available))
        .filter(|drill| drill_is_usable(drill, &facts.state.introduced, content))
        .count();
    u32::try_from(count).expect("題數不可能超過 u32")
}

fn drill_task(day: &DayPlan<'_>, content: &ContentStore) -> Option<DailyTask> {
    if day.split.drill <= 0.0 {
        return None;
    }
    let lessons = recent_main_lessons(day.cursor, content);
    let candidates = count_drill_candidates(&lessons, day.facts, content);
    if candidates == 0 {
        return None;
    }
    let wanted = (day.split.drill * SECONDS_PER_MINUTE / DRILL_SECONDS).floor() as u32;
    Some(DailyTask::Drill {
        key: KEY_DRILL.to_owned(),
        lesson_ids: lessons.iter().map(|&l| l.to_owned()).collect(),
        question_count: wanted.min(candidates),
        minutes: day.split.drill,
    })
}

/// 該課已可用的句子，只看 `item_intro`（§7.3）。
fn usable_sentences(lesson: &str, facts: &DayFacts<'_>, content: &ContentStore) -> Vec<String> {
    content
        .lesson_items(lesson)
        .map_or(&[][..], |items| items.sentences.as_slice())
        .iter()
        .filter(|&&index| content.sentence_is_usable(index, &facts.state.introduced))
        .map(|&index| content.sentences()[index as usize].def.id.clone())
        .collect()
}

/// 目前課與前兩課優先，其餘已開放的課在後；各組內依日期種子洗牌，每天不同。
fn listen_sentences(day: &DayPlan<'_>, content: &ContentStore) -> Vec<String> {
    let recent = recent_main_lessons(day.cursor, content);
    let limit = cursor_pos(day.facts.state, content);
    let in_range = |id: &&String| match (limit, content.lesson_pos(id)) {
        (Some(limit), Some(pos)) => pos <= limit,
        _ => true,
    };
    let older: Vec<&str> = content
        .course()
        .order
        .iter()
        .filter(in_range)
        .map(String::as_str)
        .filter(|id| !recent.contains(id))
        .collect();
    let mut rng = rng_from_seed(fnv1a(&format!("listen:{}", day.facts.today)));
    let pool = |lessons: &[&str]| -> Vec<String> {
        lessons
            .iter()
            .flat_map(|lesson| usable_sentences(lesson, day.facts, content))
            .collect()
    };
    let (first, second) = (pool(&recent), pool(&older));
    let first = shuffled(&mut rng, first);
    let second = shuffled(&mut rng, second);
    first.into_iter().chain(second).collect()
}

fn listen_task(day: &DayPlan<'_>, content: &ContentStore) -> Option<DailyTask> {
    let minutes = day.split.listen;
    if !day.facts.audio_available || minutes < MIN_LISTEN_MINUTES {
        return None;
    }
    let count = (minutes * SECONDS_PER_MINUTE / LISTEN_SECONDS).floor() as usize;
    let sentence_ids: Vec<String> = listen_sentences(day, content)
        .into_iter()
        .take(count)
        .collect();
    (!sentence_ids.is_empty()).then(|| DailyTask::Listen {
        key: KEY_LISTEN.to_owned(),
        sentence_ids,
        minutes,
    })
}

fn checkpoint_tasks(facts: &DayFacts<'_>, content: &ContentStore) -> Vec<DailyTask> {
    due_checkpoints(
        facts.state,
        facts.milestone_results,
        facts.dismissed,
        content,
    )
    .into_iter()
    .map(|m| DailyTask::Checkpoint {
        key: checkpoint_key(&m.id),
        milestone_id: m.id.clone(),
    })
    .collect()
}

fn study_tasks(day: &DayPlan<'_>, content: &ContentStore) -> Vec<DailyTask> {
    let mut tasks: Vec<DailyTask> = day.main_slice_task().into_iter().collect();
    if !day.is_integration_day() {
        tasks.extend(drill_task(day, content));
        tasks.extend(listen_task(day, content));
    }
    tasks.extend(checkpoint_tasks(day.facts, content));
    tasks
}

pub fn compose_day(facts: &DayFacts<'_>, content: &ContentStore) -> DaySnapshot {
    let day = assess(facts, content);
    let budget = day.budget();
    let review = DailyTask::Review {
        key: KEY_REVIEW.to_owned(),
        minutes: estimate_review_minutes(facts.due_facets, budget.review_cap, 0),
    };
    let mut tasks = vec![review];
    if day.is_study_day {
        tasks.extend(study_tasks(&day, content));
    }
    DaySnapshot { budget, tasks }
}

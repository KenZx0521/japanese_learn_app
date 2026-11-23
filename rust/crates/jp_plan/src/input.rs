//! 計畫輸入與略過規則（§7.1）。

use std::collections::HashSet;

use chrono::NaiveDate;
use jp_content::schema::PlanPresetDef;
use jp_content::ContentStore;
use jp_lang::clock::DayContext;
use jp_store::{ItemIntroRow, NewPlan, PlanVersionRow, SkipWrite};

use crate::calendar::ALL_DAYS_MASK;
use crate::error::PlanError;
use crate::forecast::{forecast, ForecastRequest};
use crate::state::CursorState;

const KANA_LESSON_PREFIX: &str = "le.k";
const MAIN_LESSON_PREFIX: &str = "le.l";
const LAST_HIRAGANA_LESSON: &str = "le.k19";
const LAST_BASIC_SKIP_LESSON: &str = "le.l07";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StartLevel {
    Zero,
    Hiragana,
    Kana,
    Basic,
}

impl StartLevel {
    pub const fn as_sql(self) -> &'static str {
        match self {
            Self::Zero => "zero",
            Self::Hiragana => "hiragana",
            Self::Kana => "kana",
            Self::Basic => "basic",
        }
    }

    pub fn parse(text: &str) -> Option<Self> {
        match text {
            "zero" => Some(Self::Zero),
            "hiragana" => Some(Self::Hiragana),
            "kana" => Some(Self::Kana),
            "basic" => Some(Self::Basic),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanInput {
    pub daily_minutes: u32,
    pub weekday_mask: u8,
    pub start_level: StartLevel,
    pub target_date: Option<NaiveDate>,
    pub known_kana_lessons: Vec<String>,
}

impl PlanInput {
    /// 資料庫的計畫列沒有 `known_kana_lessons`，那些課已寫成略過。
    pub fn from_row(row: &PlanVersionRow) -> Result<Self, PlanError> {
        let start_level = StartLevel::parse(&row.start_level)
            .ok_or_else(|| PlanError::internal(format!("start_level: {}", row.start_level)))?;
        Ok(Self {
            daily_minutes: row.daily_minutes,
            weekday_mask: row.weekday_mask,
            start_level,
            target_date: row.target_date,
            known_kana_lessons: Vec::new(),
        })
    }
}

pub fn preset_for(minutes: u32, content: &ContentStore) -> Option<&PlanPresetDef> {
    content.presets().iter().find(|p| p.minutes == minutes)
}

/// K、KK 課。
pub fn is_kana_lesson(lesson_id: &str) -> bool {
    lesson_id.starts_with(KANA_LESSON_PREFIX)
}

/// L 課。
pub fn is_main_lesson(lesson_id: &str) -> bool {
    lesson_id.starts_with(MAIN_LESSON_PREFIX)
}

pub fn validate_plan_input(input: &PlanInput, content: &ContentStore) -> Result<(), PlanError> {
    if preset_for(input.daily_minutes, content).is_none() {
        let reason = format!("沒有對應的方案：{}", input.daily_minutes);
        return Err(PlanError::invalid("daily_minutes", reason));
    }
    if input.weekday_mask == 0 || input.weekday_mask > ALL_DAYS_MASK {
        let reason = format!("超出範圍：{}", input.weekday_mask);
        return Err(PlanError::invalid("weekday_mask", reason));
    }
    for lesson in &input.known_kana_lessons {
        if !is_kana_lesson(lesson) || content.lesson_pos(lesson).is_none() {
            let reason = format!("不是 K／KK 課：{lesson}");
            return Err(PlanError::invalid("known_kana_lessons", reason));
        }
    }
    Ok(())
}

fn is_skipped_by_level(id: &str, level: StartLevel, content: &ContentStore) -> bool {
    let at_or_before = |limit: &str| match (content.lesson_pos(id), content.lesson_pos(limit)) {
        (Some(pos), Some(limit_pos)) => pos <= limit_pos,
        _ => false,
    };
    match level {
        StartLevel::Zero => false,
        StartLevel::Hiragana => at_or_before(LAST_HIRAGANA_LESSON),
        StartLevel::Kana => is_kana_lesson(id),
        StartLevel::Basic => is_kana_lesson(id) || at_or_before(LAST_BASIC_SKIP_LESSON),
    }
}

/// `start_level` 與 `known_kana_lessons` 跳過的全部課，依 `course.order`。
pub fn skipped_lessons(input: &PlanInput, content: &ContentStore) -> Vec<String> {
    let known: HashSet<&str> = input
        .known_kana_lessons
        .iter()
        .map(String::as_str)
        .collect();
    content
        .course()
        .order
        .iter()
        .filter(|id| {
            known.contains(id.as_str()) || is_skipped_by_level(id, input.start_level, content)
        })
        .cloned()
        .collect()
}

/// 該課每個假名的 ID，含 `kind: mark`。
pub(crate) fn lesson_kana_ids<'c>(
    lesson_id: &str,
    content: &'c ContentStore,
) -> impl Iterator<Item = &'c str> {
    content
        .lesson_items(lesson_id)
        .map_or(&[][..], |items| items.kana.as_slice())
        .iter()
        .map(|&index| content.kana()[index as usize].def.id.as_str())
}

/// `insert_plan` 的略過紀錄：只寫 K／KK 課，每個假名一筆 `item_intro`，不建卡。
pub fn skip_write(input: &PlanInput, content: &ContentStore, ctx: &DayContext) -> SkipWrite {
    let lesson_ids: Vec<String> = skipped_lessons(input, content)
        .into_iter()
        .filter(|lesson| is_kana_lesson(lesson))
        .collect();
    let today = ctx.today();
    let item_intros = lesson_ids
        .iter()
        .flat_map(|lesson| {
            lesson_kana_ids(lesson, content).map(|item_id| ItemIntroRow {
                item_id: item_id.to_owned(),
                lesson_id: lesson.clone(),
                logical_date: today,
                introduced_at: ctx.now,
            })
        })
        .collect();
    SkipWrite {
        item_intros,
        lesson_ids,
        completed_date: today,
        completed_at: ctx.now,
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanWrite {
    pub plan: NewPlan,
    pub baseline: Vec<(String, NaiveDate)>,
    pub skips: SkipWrite,
}

/// `create_plan`、`update_plan` 寫入 `insert_plan` 的三個參數，基準線由當下進度預測。
pub fn plan_write(
    input: &PlanInput,
    state: &CursorState,
    content: &ContentStore,
    ctx: &DayContext,
) -> Result<PlanWrite, PlanError> {
    validate_plan_input(input, content)?;
    let today = ctx.today();
    let request = ForecastRequest {
        today,
        today_slice_done: false,
        plan: input,
    };
    let baseline = forecast(state, &request, content)?.milestones;
    let plan = NewPlan {
        effective_from: today,
        daily_minutes: input.daily_minutes,
        weekday_mask: input.weekday_mask,
        start_level: input.start_level.as_sql().to_owned(),
        target_date: input.target_date,
        created_at: ctx.now,
    };
    Ok(PlanWrite {
        plan,
        baseline,
        skips: skip_write(input, content, ctx),
    })
}

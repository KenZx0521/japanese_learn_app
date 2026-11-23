//! 游標狀態（§7.3）。全部由資料庫的進度推導，不存切分結果。

use std::collections::{HashMap, HashSet};

use chrono::NaiveDate;
use jp_content::ContentStore;
use jp_store::{LessonProgressRow, PlanRepo, StoreError};

use crate::input::{is_kana_lesson, is_main_lesson, lesson_kana_ids, skipped_lessons, PlanInput};

const RECENT_LESSON_COUNT: usize = 3;

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CursorState {
    /// `item_intro`。
    pub introduced: HashSet<String>,
    /// `lesson_progress.completed_date`，含略過。
    pub completed: HashMap<String, NaiveDate>,
    /// `lesson_progress.skipped`，與 `start_level` 在記憶體內跳過的課。
    pub skipped: HashSet<String>,
    pub integration_days: HashMap<String, u32>,
    /// 課→已排過的整合對話。值同時是「已排過的實戰、常體版對話」的集合。
    pub integration_dialogues: HashMap<String, String>,
}

impl CursorState {
    pub fn from_rows(
        introduced: HashSet<String>,
        progress: &HashMap<String, LessonProgressRow>,
    ) -> Self {
        let rows = || progress.values();
        Self {
            introduced,
            completed: rows()
                .filter_map(|r| r.completed_date.map(|on| (r.lesson_id.clone(), on)))
                .collect(),
            skipped: rows()
                .filter(|r| r.skipped)
                .map(|r| r.lesson_id.clone())
                .collect(),
            integration_days: rows()
                .map(|r| (r.lesson_id.clone(), r.integration_days_done))
                .collect(),
            integration_dialogues: rows()
                .filter_map(|r| {
                    r.integration_dialogue
                        .clone()
                        .map(|dialogue| (r.lesson_id.clone(), dialogue))
                })
                .collect(),
        }
    }

    pub fn load<R: PlanRepo + ?Sized>(repo: &R) -> Result<Self, StoreError> {
        Ok(Self::from_rows(
            repo.introduced_items()?,
            &repo.lesson_progress()?,
        ))
    }

    /// `plan_preview` 與 `basic` 的 L 課：把略過的課視為完成，只在記憶體內，可重複套用。
    pub fn with_plan_skips(
        &self,
        input: &PlanInput,
        on: NaiveDate,
        content: &ContentStore,
    ) -> Self {
        let mut applied = self.clone();
        for lesson in skipped_lessons(input, content) {
            if is_kana_lesson(&lesson) {
                applied
                    .introduced
                    .extend(lesson_kana_ids(&lesson, content).map(str::to_owned));
            }
            applied.completed.entry(lesson.clone()).or_insert(on);
            applied.skipped.insert(lesson);
        }
        applied
    }

    pub fn is_completed(&self, lesson_id: &str) -> bool {
        self.completed.contains_key(lesson_id)
    }
}

/// `course.order` 中第一個未完成的課；全部完成時為 `None`。
pub fn cursor<'c>(state: &CursorState, content: &'c ContentStore) -> Option<&'c str> {
    content
        .course()
        .order
        .iter()
        .find(|id| !state.is_completed(id))
        .map(String::as_str)
}

pub fn cursor_pos(state: &CursorState, content: &ContentStore) -> Option<u32> {
    cursor(state, content).and_then(|id| content.lesson_pos(id))
}

fn main_lessons(content: &ContentStore) -> impl DoubleEndedIterator<Item = &str> {
    content
        .course()
        .order
        .iter()
        .map(String::as_str)
        .filter(|id| is_main_lesson(id))
}

/// 目前課的階段；游標走完時取最後一個 L 課的階段。
pub fn stage_for_cursor<'c>(cursor: Option<&str>, content: &'c ContentStore) -> Option<&'c str> {
    let lesson = match cursor {
        Some(id) => content.lesson(id),
        None => main_lessons(content)
            .next_back()
            .and_then(|id| content.lesson(id)),
    };
    lesson.map(|def| def.stage.as_str())
}

/// 目前課與前兩個 L 課；游標走完時為最後三個 L 課。依 `course.order`。
pub fn recent_main_lessons<'c>(cursor: Option<&str>, content: &'c ContentStore) -> Vec<&'c str> {
    let limit = cursor.and_then(|id| content.lesson_pos(id));
    let mut lessons: Vec<&str> = main_lessons(content)
        .filter(|id| match (limit, content.lesson_pos(id)) {
            (Some(limit), Some(pos)) => pos <= limit,
            _ => true,
        })
        .collect();
    let keep_from = lessons.len().saturating_sub(RECENT_LESSON_COUNT);
    lessons.split_off(keep_from)
}

/// 已完成的 L 課數，不含略過（對話輪替）。
pub fn completed_main_lessons(state: &CursorState, content: &ContentStore) -> u32 {
    let count = main_lessons(content)
        .filter(|id| state.is_completed(id) && !state.skipped.contains(*id))
        .count();
    u32::try_from(count).expect("課數不可能超過 u32")
}

//! `impl AppCore`：今日、完成任務、再學一批、新內容與聽力 session（rust-core.md §9.4）。

use super::core::AppCore;
use super::dto_plan::TodayViewDto;
use super::dto_study::{NewContentSessionDto, QuestionDto};
use super::error::CoreError;
use crate::app::{new_content, today};

impl AppCore {
    pub fn today_view(&self, audio_available: bool) -> Result<TodayViewDto, CoreError> {
        today::today_view(&self.deps, audio_available)
    }

    pub fn complete_task(
        &self,
        task_key: String,
        duration_ms: u32,
        audio_available: bool,
    ) -> Result<TodayViewDto, CoreError> {
        today::complete_task(&self.deps, &task_key, duration_ms, audio_available)
    }

    pub fn learn_more(&self, audio_available: bool) -> Result<TodayViewDto, CoreError> {
        today::learn_more(&self.deps, audio_available)
    }

    pub fn new_content_session(
        &self,
        task_key: String,
        session_seed: u32,
        audio_available: bool,
    ) -> Result<NewContentSessionDto, CoreError> {
        new_content::new_content_session(&self.deps, &task_key, session_seed, audio_available)
    }

    pub fn listen_session(
        &self,
        task_key: String,
        session_seed: u32,
        audio_available: bool,
    ) -> Result<Vec<QuestionDto>, CoreError> {
        today::listen_session(&self.deps, &task_key, session_seed, audio_available)
    }
}

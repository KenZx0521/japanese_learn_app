//! `impl AppCore`：演練、檢定（rust-core.md §9.4）。

use super::core::AppCore;
use super::dto_plan::TodayViewDto;
use super::dto_study::{
    AnswerDto, AnswerPayload, CheckpointResultDto, DrillFilterDto, DrillResultDto, QuestionDto,
    QuestionRefDto,
};
use super::error::CoreError;
use crate::app::drill;

impl AppCore {
    pub fn drill_session(
        &self,
        filter: DrillFilterDto,
        session_seed: u32,
        audio_available: bool,
    ) -> Result<Vec<QuestionDto>, CoreError> {
        drill::drill_session(&self.deps, &filter, session_seed, audio_available)
    }

    pub fn grade_drill(
        &self,
        question: QuestionRefDto,
        response: AnswerPayload,
    ) -> Result<DrillResultDto, CoreError> {
        drill::grade_drill(&self.deps, &question, &response)
    }

    pub fn checkpoint_start(
        &self,
        milestone_id: String,
        session_seed: u32,
        audio_available: bool,
    ) -> Result<Vec<QuestionDto>, CoreError> {
        drill::checkpoint_start(&self.deps, &milestone_id, session_seed, audio_available)
    }

    pub fn checkpoint_finish(
        &self,
        milestone_id: String,
        answers: Vec<AnswerDto>,
    ) -> Result<CheckpointResultDto, CoreError> {
        drill::checkpoint_finish(&self.deps, &milestone_id, &answers)
    }

    pub fn checkpoint_dismiss(
        &self,
        milestone_id: String,
        audio_available: bool,
    ) -> Result<TodayViewDto, CoreError> {
        drill::checkpoint_dismiss(&self.deps, &milestone_id, audio_available)
    }
}

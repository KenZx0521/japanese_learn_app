//! `impl AppCore`：複習、作答、假名熟練（rust-core.md §9.4、§9.6）。

use super::core::AppCore;
use super::dto_study::{
    AnswerDto, AnswerPayload, AnswerResultDto, KanaSubmitResultDto, QuestionDto, QuestionRefDto,
    SessionNextDto, SessionSummaryDto,
};
use super::error::CoreError;
use crate::app::session;

impl AppCore {
    pub fn session_summary(&self, audio_available: bool) -> Result<SessionSummaryDto, CoreError> {
        session::session_summary(&self.deps, audio_available)
    }

    pub fn session_next(
        &self,
        session_seed: u32,
        audio_available: bool,
    ) -> Result<SessionNextDto, CoreError> {
        session::session_next(&self.deps, session_seed, audio_available)
    }

    pub fn submit_answer(&self, answer: AnswerDto) -> Result<AnswerResultDto, CoreError> {
        session::submit_answer(&self.deps, &answer)
    }

    /// 只供 K1 自由練習，不影響計畫。
    pub fn kana_session(
        &self,
        lesson_id: String,
        session_seed: u32,
        audio_available: bool,
    ) -> Result<Vec<QuestionDto>, CoreError> {
        session::kana_session(&self.deps, &lesson_id, session_seed, audio_available)
    }

    pub fn kana_submit(
        &self,
        reference: QuestionRefDto,
        response: AnswerPayload,
        duration_ms: u32,
    ) -> Result<KanaSubmitResultDto, CoreError> {
        session::kana_submit(&self.deps, &reference, &response, duration_ms)
    }
}

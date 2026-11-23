//! 今日任務與快照內容（§7.4）。

use serde::{Deserialize, Serialize};

use crate::budget::DayBudget;
use crate::error::PlanError;
use crate::slice::Slice;

pub const KEY_REVIEW: &str = "review";
pub const KEY_DRILL: &str = "drill";
pub const KEY_LISTEN: &str = "listen";

pub fn new_content_key(item_id: &str) -> String {
    format!("new:{item_id}")
}

pub fn integration_key(lesson_id: &str, day_no: u32) -> String {
    format!("integration:{lesson_id}:{day_no}")
}

pub fn checkpoint_key(milestone_id: &str) -> String {
    format!("checkpoint:{milestone_id}")
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum DailyTask {
    Review {
        key: String,
        minutes: f64,
    },
    NewContent {
        key: String,
        lesson_id: String,
        slice: Slice,
        minutes: f64,
    },
    Integration {
        key: String,
        lesson_id: String,
        dialogue_id: Option<String>,
        phases: Vec<u32>,
        minutes: f64,
    },
    Drill {
        key: String,
        lesson_ids: Vec<String>,
        question_count: u32,
        minutes: f64,
    },
    Listen {
        key: String,
        sentence_ids: Vec<String>,
        minutes: f64,
    },
    Checkpoint {
        key: String,
        milestone_id: String,
    },
}

impl DailyTask {
    pub fn key(&self) -> &str {
        match self {
            Self::Review { key, .. }
            | Self::NewContent { key, .. }
            | Self::Integration { key, .. }
            | Self::Drill { key, .. }
            | Self::Listen { key, .. }
            | Self::Checkpoint { key, .. } => key,
        }
    }

    /// `Checkpoint` 回 `None`。
    pub fn minutes(&self) -> Option<f64> {
        match self {
            Self::Review { minutes, .. }
            | Self::NewContent { minutes, .. }
            | Self::Integration { minutes, .. }
            | Self::Drill { minutes, .. }
            | Self::Listen { minutes, .. } => Some(*minutes),
            Self::Checkpoint { .. } => None,
        }
    }

    /// `Review`、`NewContent`、`Integration`、`Drill`、`Listen`（`learn_more` 的前置條件）。
    pub(crate) fn blocks_learn_more(&self) -> bool {
        matches!(
            self,
            Self::Review { .. }
                | Self::NewContent { .. }
                | Self::Integration { .. }
                | Self::Drill { .. }
                | Self::Listen { .. }
        )
    }

    pub(crate) fn is_main_slice(&self) -> bool {
        matches!(self, Self::NewContent { .. } | Self::Integration { .. })
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DaySnapshot {
    pub budget: DayBudget,
    pub tasks: Vec<DailyTask>,
}

impl DaySnapshot {
    pub fn to_json(&self) -> Result<String, PlanError> {
        serde_json::to_string(self)
            .map_err(|err| PlanError::internal(format!("snapshot encode: {err}")))
    }

    pub fn from_json(payload: &str) -> Result<Self, PlanError> {
        serde_json::from_str(payload)
            .map_err(|err| PlanError::internal(format!("snapshot decode: {err}")))
    }
}

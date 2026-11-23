//! 組 DTO 時共用的進度快照：一個 API 呼叫載入一次，之後只讀（§10：不持鎖跨內容查詢）。

use std::collections::HashMap;

use chrono::NaiveDate;
use jp_content::ContentStore;
use jp_plan::state::cursor;
use jp_plan::CursorState;
use jp_store::{KanaMasteryRow, PlanRepo, VocabFlagRow};

use super::deps::Deps;
use super::mapping::sentence::KnownCards;
use crate::api::error::CoreError;

pub(crate) struct Views<'a> {
    pub deps: &'a Deps,
    pub state: CursorState,
    pub today: NaiveDate,
    pub flags: HashMap<String, VocabFlagRow>,
    pub kana: HashMap<String, KanaMasteryRow>,
}

impl<'a> Views<'a> {
    pub(crate) fn load(deps: &'a Deps) -> Result<Self, CoreError> {
        let today = deps.day_ctx()?.today();
        let kana = deps
            .repo
            .all_kana_mastery()?
            .into_iter()
            .map(|row| (row.kana_id.clone(), row))
            .collect();
        Ok(Self {
            deps,
            state: deps.cursor_state(today)?,
            today,
            flags: deps.repo.vocab_flags()?,
            kana,
        })
    }

    pub(crate) fn content(&self) -> &'a ContentStore {
        &self.deps.content
    }

    pub(crate) fn known_cards(&self) -> KnownCards<'a> {
        KnownCards::new(&self.deps.repo)
    }

    pub(crate) fn cursor(&self) -> Option<&'a str> {
        cursor(&self.state, self.content())
    }

    pub(crate) fn cursor_pos(&self) -> Option<u32> {
        self.cursor().and_then(|id| self.content().lesson_pos(id))
    }
}

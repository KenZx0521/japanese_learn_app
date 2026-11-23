//! 出題共用的輸入。

use std::collections::HashSet;

use jp_content::ContentStore;
use jp_lang::quiz::rng::{rng_from_seed, seed_for, ChaCha8Rng};

#[derive(Debug, Clone, Copy)]
pub struct QuizContext<'a> {
    pub content: &'a ContentStore,
    /// 已 `item_intro` 的項目，`new_content_session` 內由呼叫端併入本切片的字。
    pub known: &'a HashSet<String>,
    /// `pos(游標)`；全部課都完成時為 `None`。
    pub cursor_pos: Option<u32>,
    pub session_seed: u32,
    pub audio_available: bool,
}

/// 題目的種子來源：卡片題用卡片 ID（§8.1），其他題用足以區分題目的字串。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct QuestionKey<'a> {
    pub seed_key: &'a str,
    pub card_id: Option<&'a str>,
}

impl<'a> QuestionKey<'a> {
    pub fn plain(seed_key: &'a str) -> Self {
        Self {
            seed_key,
            card_id: None,
        }
    }

    pub fn card(card_id: &'a str) -> Self {
        Self {
            seed_key: card_id,
            card_id: Some(card_id),
        }
    }

    pub(crate) fn rng(&self, session_seed: u32) -> ChaCha8Rng {
        rng_from_seed(seed_for(session_seed, self.seed_key))
    }
}

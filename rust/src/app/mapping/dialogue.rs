//! 對話（§9.5）。

use jp_content::store::DialogueEntry;
use jp_quiz::drill::quizzable_drill_ids;

use super::enums::{dialogue_kind, style_name};
use crate::api::dto_content::{DialogueDto, DialogueRoleDto, DialogueSummaryDto, DialogueTurnDto};
use crate::api::error::CoreError;
use crate::app::views::Views;

impl Views<'_> {
    /// `pos(lesson) > pos(游標)`；游標走完全部已發布的課時一律 false（§9.4）。
    fn is_locked(&self, lesson: &str) -> bool {
        match (self.cursor_pos(), self.content().lesson_pos(lesson)) {
            (Some(cursor), Some(pos)) => pos > cursor,
            _ => false,
        }
    }

    pub(crate) fn dialogue_summary(&self, entry: &DialogueEntry) -> DialogueSummaryDto {
        let def = &entry.def;
        DialogueSummaryDto {
            id: def.id.clone(),
            kind: dialogue_kind(def.kind),
            lesson_id: def.lesson.clone(),
            scene_zh: def.scene_zh.clone(),
            goal_zh: def.goal_zh.clone(),
            locked: self.is_locked(&def.lesson),
        }
    }

    pub(crate) fn dialogue(&self, entry: &DialogueEntry) -> Result<DialogueDto, CoreError> {
        let def = &entry.def;
        let turns = def
            .turns
            .iter()
            .enumerate()
            .map(|(index, turn)| {
                Ok(DialogueTurnDto {
                    role: turn.role.clone(),
                    sentence: self.known_cards().turn(entry, index)?,
                    note_zh: turn.note_zh.clone(),
                })
            })
            .collect::<Result<_, CoreError>>()?;
        Ok(DialogueDto {
            id: def.id.clone(),
            kind: dialogue_kind(def.kind),
            lesson_id: def.lesson.clone(),
            style: style_name(def.style).to_owned(),
            scene_zh: def.scene_zh.clone(),
            goal_zh: def.goal_zh.clone(),
            roles: def
                .roles
                .iter()
                .map(|role| DialogueRoleDto {
                    id: role.id.clone(),
                    name_zh: role.name_zh.clone(),
                    voice: role.voice.clone(),
                })
                .collect(),
            turns,
            focus_ids: def.focus.clone(),
            quiz_drill_ids: quizzable_drill_ids(self.content(), &def.quiz),
        })
    }
}

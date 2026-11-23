//! RC11：L 課必有主對話，主對話必被某一課引用（`lesson.dialogue` 曾全為 null 而沒被抓到）。
//!
//! 指向不存在項目的 `dialogue` 由 R03 回報，這裡只管「沒有填」與「沒人引用」。

use std::collections::HashSet;

use crate::schema::DialogueKind;

use super::context::Ctx;
use super::Finding;

const RULE: &str = "RC11";
const L_LESSON_PREFIX: &str = "le.l";

/// 比照 R17：種子內容（`count_policy.txt` 為 `seed`）不要求每課都有主對話。
pub(super) fn check_rc11(ctx: &Ctx) -> Vec<Finding> {
    if ctx.lists.seed_content {
        return Vec::new();
    }
    let lessons = &ctx.raw.course.lessons;
    let referenced: HashSet<&str> = lessons
        .iter()
        .filter_map(|lesson| lesson.dialogue.as_deref())
        .collect();
    let without_dialogue = lessons
        .iter()
        .filter(|lesson| lesson.id.starts_with(L_LESSON_PREFIX) && lesson.dialogue.is_none())
        .map(|lesson| Finding::error(RULE, &lesson.id, "dialogue", "L 課必須指定主對話"));
    let orphans = ctx
        .raw
        .dialogues
        .iter()
        .filter(|d| d.kind == DialogueKind::Lesson && !d.retired)
        .filter(|d| !referenced.contains(d.id.as_str()))
        .map(|d| {
            Finding::error(
                RULE,
                &d.id,
                &d.lesson,
                "主對話沒有被任何一課的 dialogue 引用",
            )
        });
    without_dialogue.chain(orphans).collect()
}

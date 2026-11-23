//! K11–K15 假名切片後接的手寫題（§9.4）。S0 沒有演練額度，清濁、半濁、拗音的
//! 最小對立靠這裡進主流程。
//!
//! 沒有逐題作答紀錄，「未考過」由課內字序推出：每個字先派定最多一題，切片只取自己的字
//! 派到的題，所以不論額度怎麼切，同一題不會被兩個切片選到。選題不看 `session_seed`。

use std::collections::{HashSet, VecDeque};

use jp_content::schema::{DrillDef, KanaKind};
use jp_content::store::LessonItems;
use jp_content::ContentStore;

use crate::context::{QuestionKey, QuizContext};
use crate::drill::{drill_question, is_offered};
use crate::error::QuizError;
use crate::model::Question;

const SLICE_DRILL_LESSONS: [&str; 5] = ["le.k11", "le.k12", "le.k13", "le.k14", "le.k15"];
const MAX_PAIRS: usize = 3;
const MIN_PAIRS: usize = 2;

/// 一個切片在某一課內的範圍。
struct Scope<'a, 'c> {
    ctx: &'a QuizContext<'c>,
    /// 該課字序，不含 `kind: mark`。
    chars: Vec<&'c str>,
    slice_kana: HashSet<&'a str>,
}

impl Scope<'_, '_> {
    fn is_taught(&self, id: &str) -> bool {
        self.ctx.known.contains(id) || self.slice_kana.contains(id)
    }

    fn targets_are_taught(&self, drill: &DrillDef) -> bool {
        drill.targets().iter().all(|t| self.is_taught(t))
    }

    fn is_in_slice(&self, index: usize) -> bool {
        self.chars
            .get(index)
            .is_some_and(|c| self.slice_kana.contains(c))
    }

    fn is_last_slice(&self) -> bool {
        self.chars.iter().all(|c| self.is_taught(c))
    }

    /// 這課已教過幾個字，用來讓補題輪到不同的題。
    fn chars_before_slice(&self) -> usize {
        self.chars
            .iter()
            .filter(|c| self.ctx.known.contains(**c))
            .count()
    }
}

/// `by_char` 與 `chars` 同長。`surplus` 是字不夠派、從沒排到的題。
struct Assignment<'c> {
    by_char: Vec<Option<&'c DrillDef>>,
    surplus: Vec<&'c DrillDef>,
}

fn lesson_chars<'c>(content: &'c ContentStore, items: &LessonItems) -> Vec<&'c str> {
    items
        .kana
        .iter()
        .map(|&index| &content.kana()[index as usize].def)
        .filter(|kana| kana.kind != KanaKind::Mark)
        .map(|kana| kana.id.as_str())
        .collect()
}

fn lesson_drills<'c>(content: &'c ContentStore, items: &LessonItems) -> Vec<&'c DrillDef> {
    items
        .drills
        .iter()
        .map(|&index| &content.drills()[index as usize])
        .collect()
}

/// 兩字的對立在較晚教的那個字才練得到，所以歸給課內位置最大的目標字。
fn direct_owner(drill: &DrillDef, chars: &[&str]) -> Option<usize> {
    drill
        .targets()
        .iter()
        .filter_map(|target| chars.iter().position(|c| c == target))
        .max()
}

/// 依字序派題：每字先取自己的題，沒有就取排隊的題（目標字都不在本課的題一開始就排隊）。
fn assign_pairs<'c>(pairs: &[&'c DrillDef], chars: &[&str]) -> Assignment<'c> {
    let mut own: Vec<VecDeque<&'c DrillDef>> = vec![VecDeque::new(); chars.len()];
    let mut queue = VecDeque::new();
    for &pair in pairs {
        match direct_owner(pair, chars) {
            Some(owner) => own[owner].push_back(pair),
            None => queue.push_back(pair),
        }
    }
    let by_char = own
        .into_iter()
        .map(|mut mine| {
            let assigned = mine.pop_front().or_else(|| queue.pop_front());
            queue.extend(mine);
            assigned
        })
        .collect();
    Assignment {
        by_char,
        surplus: queue.into(),
    }
}

fn rotated<T: Copy>(items: &[T], by: usize) -> impl Iterator<Item = T> + '_ {
    let start = if items.is_empty() {
        0
    } else {
        by % items.len()
    };
    items[start..].iter().chain(&items[..start]).copied()
}

/// 下限不足時，先補沒排到的題，再由字序尾端往回補：上限只留前面的字，尾端的題最可能還沒考過。
fn fill_candidates<'c>(
    scope: &Scope<'_, 'c>,
    assignment: &Assignment<'c>,
) -> impl Iterator<Item = &'c DrillDef> {
    let others: Vec<&'c DrillDef> = assignment
        .by_char
        .iter()
        .enumerate()
        .filter(|(index, _)| !scope.is_in_slice(*index))
        .filter_map(|(_, pair)| *pair)
        .collect();
    rotated(&assignment.surplus, scope.chars_before_slice())
        .chain(others.into_iter().rev())
        .collect::<Vec<_>>()
        .into_iter()
}

/// 本切片的字派到的題，最多 3 題；不足 2 題時補到 2 題。
fn picked_pairs<'c>(scope: &Scope<'_, 'c>, drills: &[&'c DrillDef]) -> Vec<&'c DrillDef> {
    let pairs: Vec<&'c DrillDef> = drills
        .iter()
        .copied()
        .filter(|drill| matches!(drill, DrillDef::MinimalPair { .. }))
        .filter(|drill| is_offered(drill, scope.ctx.audio_available))
        .collect();
    let assignment = assign_pairs(&pairs, &scope.chars);
    let mut picked: Vec<&'c DrillDef> = assignment
        .by_char
        .iter()
        .enumerate()
        .filter(|(index, _)| scope.is_in_slice(*index))
        .filter_map(|(_, pair)| *pair)
        .filter(|pair| scope.targets_are_taught(pair))
        .take(MAX_PAIRS)
        .collect();
    let missing = MIN_PAIRS.saturating_sub(picked.len());
    let fills: Vec<&'c DrillDef> = fill_candidates(scope, &assignment)
        .filter(|fill| scope.targets_are_taught(fill))
        .filter(|fill| !picked.iter().any(|p| p.id() == fill.id()))
        .take(missing)
        .collect();
    picked.extend(fills);
    picked
}

fn closing_kana_word<'c>(scope: &Scope<'_, 'c>, drills: &[&'c DrillDef]) -> Option<&'c DrillDef> {
    if !scope.is_last_slice() {
        return None;
    }
    drills
        .iter()
        .copied()
        .filter(|drill| matches!(drill, DrillDef::KanaWord { .. }))
        .filter(|drill| is_offered(drill, scope.ctx.audio_available))
        .find(|drill| scope.targets_are_taught(drill))
}

/// 這個切片在 `lesson_id` 內該接的題，依出題順序。不是 K11–K15 回空。
pub fn slice_drills<'c>(
    ctx: &QuizContext<'c>,
    lesson_id: &str,
    slice_kana: &[String],
) -> Vec<&'c DrillDef> {
    if !SLICE_DRILL_LESSONS.contains(&lesson_id) {
        return Vec::new();
    }
    let Some(items) = ctx.content.lesson_items(lesson_id) else {
        return Vec::new();
    };
    let scope = Scope {
        ctx,
        chars: lesson_chars(ctx.content, items),
        slice_kana: slice_kana.iter().map(String::as_str).collect(),
    };
    let drills = lesson_drills(ctx.content, items);
    let mut picked = picked_pairs(&scope, &drills);
    picked.extend(closing_kana_word(&scope, &drills));
    picked
}

/// `new_content_session` 的 `KanaQuiz`：題目本身仍依種子決定播 A 或 B。
pub fn slice_drill_quiz(
    ctx: &QuizContext<'_>,
    lesson_id: &str,
    slice_kana: &[String],
) -> Result<Vec<Question>, QuizError> {
    slice_drills(ctx, lesson_id, slice_kana)
        .into_iter()
        .map(|drill| {
            let seed_key = format!("slice:{lesson_id}:{}", drill.id());
            drill_question(ctx, drill, QuestionKey::plain(&seed_key), None)
        })
        .collect()
}

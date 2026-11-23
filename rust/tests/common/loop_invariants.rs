//! 學習迴路模擬的每日不變量（rust-core.md §7）。`DayLog` 依日期順序餵進 `Checker`，
//! 違反的條文記成 `Violation`，不中斷模擬。條文代號見 `Rule`。

use std::collections::{HashMap, HashSet};

use chrono::NaiveDate;
use jp_core::api::dto_plan::TaskDto;

use super::learner::{DayLog, SeenQuestion, Source};
use super::loop_facts::ContentFacts;

mod budget;

pub use budget::new_cards_minutes;

const KANA_STAGE_LESSON_PREFIXES: [&str; 2] = ["le.k", "le.kk"];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Rule {
    /// §7.2、§7.4 估算分鐘：扣掉收尾新卡後，只容許四捨五入。
    MinutesBudget,
    /// curriculum §11.3-2「任務量以當日分鐘數為上限」：T1 顯示的 `estimated_minutes`（含收尾新卡）。
    MinutesWithNewCards,
    /// §7.4：`NewContent` 的分鐘等於預算的 new 額度，`Listen` 的分鐘等於 listen 額度；
    /// listen 額度不足 0.5 分時不列 `Listen`。
    TaskMinutes,
    /// §7.3 游標：新內容與整合日只來自游標課。
    MainSliceAtCursor,
    /// §7.3 `Vocab` 只取游標課的字；`Kana` 沿 K／KK 課延伸，遇 L 課即停。
    NewItemLesson,
    /// 同一個項目不會在兩天的 `NewContent` 重複介紹。
    NewItemOnce,
    /// §7.2（RULINGS O11、O12）：學習日積壓且不給新內容時只排複習，review 額度等於方案分鐘，
    /// `review_cap` 依合併後的分鐘重算（大於階段配比的 `capacity`；回鍋日再減半，不比）。
    ReviewOnlyDay,
    /// §7.2：`ReviewBacklog` 且到期數 > `5 × capacity` 時不給新內容；積壓第 3 天起、未過這條線時給
    /// 最小切片。兩邊一起釘住 `BACKLOG_PAUSE_FACTOR`。
    BacklogPauseLine,
    /// §7.2：收尾新卡至多用 review 秒數的一半，`capacity ≥ 8` 時 `review_cap` 不會塌成 1。
    ReviewCapFloor,
    /// §7.4：非學習日只回 `Review`；RULINGS O12：複習上限用階段配比（review 分鐘小於方案、
    /// `review_cap` ≤ `capacity`），`recovery_days` 不遞增。
    RestDayReviewOnly,
    /// §6.1、§6.4：主線卡只屬於游標以前的課。
    MainCardLesson,
    /// §7.3「例句與聽力的可用性」：露出的句子，`vo.*`、`gr.*` 引用都已介紹。
    SentenceUsable,
    /// §7.4 `Checkpoint`：里程碑所在課完成後才列出，考過（不論通過）就不再列。
    Checkpoint,
    /// §9.2：每個 API 呼叫都不回 `CoreError`。
    NoCoreError,
}

#[derive(Debug, Clone)]
pub struct Violation {
    pub rule: Rule,
    pub date: NaiveDate,
    pub detail: String,
}

pub struct Checker<'a> {
    facts: &'a ContentFacts,
    /// 方案的每日分鐘。
    daily_minutes: u32,
    completed_on: HashMap<String, NaiveDate>,
    introduced: HashSet<String>,
    checkpoints: Vec<(NaiveDate, String)>,
    /// 連續受限天數，照 §7.2 由打開 App 的學習日接續、休息日維持（DTO 沒有 `recovery_days`）。
    recovery_days: u32,
    /// 檢查過可用性的句子露出次數，用來確認 `SentenceUsable` 不是空轉。
    pub sentences_checked: usize,
    pub violations: Vec<Violation>,
}

fn is_kana_lesson(id: &str) -> bool {
    KANA_STAGE_LESSON_PREFIXES.iter().any(|p| id.starts_with(p))
}

fn card_content(card_id: &str) -> &str {
    card_id.split(':').next().unwrap_or(card_id)
}

impl<'a> Checker<'a> {
    pub fn new(facts: &'a ContentFacts, daily_minutes: u32) -> Self {
        Self {
            facts,
            daily_minutes,
            completed_on: HashMap::new(),
            introduced: HashSet::new(),
            checkpoints: Vec::new(),
            recovery_days: 0,
            sentences_checked: 0,
            violations: Vec::new(),
        }
    }

    pub fn completed_on(&self, lesson: &str) -> Option<NaiveDate> {
        self.completed_on.get(lesson).copied()
    }

    pub fn checkpoints(&self) -> &[(NaiveDate, String)] {
        &self.checkpoints
    }

    fn flag(&mut self, rule: Rule, date: NaiveDate, detail: String) {
        self.violations.push(Violation { rule, date, detail });
    }

    /// 依序檢查一天，再把當天的進度記進狀態。
    pub fn check_day(&mut self, log: &DayLog) {
        self.check_minutes(log);
        self.check_backlog_lines(log);
        self.check_rest_day(log);
        self.check_review_only_day(log);
        self.check_task_minutes(log);
        self.check_main_slice(log);
        self.check_new_items(log);
        self.check_checkpoints(log);
        let known = self.known_after(log);
        for question in &log.questions {
            self.check_question(log, question);
            self.check_sentences(log.date, question, &known);
        }
        for error in &log.errors {
            self.flag(Rule::NoCoreError, log.date, error.clone());
        }
        self.record_progress(log);
    }

    fn record_progress(&mut self, log: &DayLog) {
        let passed = self
            .facts
            .passed_lessons(log.cursor_before.as_deref(), log.cursor_after.as_deref());
        for lesson in passed {
            self.completed_on.entry(lesson).or_insert(log.date);
        }
        for task in &log.first_view.tasks {
            if let TaskDto::Checkpoint { milestone_id, .. } = task {
                self.checkpoints.push((log.date, milestone_id.clone()));
            }
        }
        self.introduced = self.known_after(log);
    }

    /// 當天結束時的已介紹集合：之前介紹過的，加上當天新內容的項目。
    fn known_after(&self, log: &DayLog) -> HashSet<String> {
        self.introduced
            .iter()
            .chain(log.new_items.iter().map(|item| &item.item_id))
            .cloned()
            .collect()
    }

    /// 題目露出的句子只引用已介紹的字與文法；以當天結束時的集合判斷，較寬鬆。
    fn check_sentences(
        &mut self,
        date: NaiveDate,
        question: &SeenQuestion,
        known: &HashSet<String>,
    ) {
        for sentence in &question.sentence_ids {
            let Some(refs) = self.facts.sentence_refs.get(sentence) else {
                continue;
            };
            self.sentences_checked += 1;
            let unknown: Vec<&String> = refs.iter().filter(|r| !known.contains(*r)).collect();
            if !unknown.is_empty() {
                let detail = format!(
                    "{:?} {:?} {} 露出 {sentence}，未介紹 {unknown:?}",
                    question.source, question.question_type, question.content_id
                );
                self.flag(Rule::SentenceUsable, date, detail);
            }
        }
    }

    fn check_main_slice(&mut self, log: &DayLog) {
        for task in &log.first_view.tasks {
            let lesson = match task {
                TaskDto::NewContent { lesson_id, .. } | TaskDto::Integration { lesson_id, .. } => {
                    lesson_id
                }
                _ => continue,
            };
            if Some(lesson.as_str()) != log.cursor_before.as_deref() {
                let detail = format!("{lesson}，游標 {:?}", log.cursor_before);
                self.flag(Rule::MainSliceAtCursor, log.date, detail);
            }
        }
    }

    /// 假名切片可延伸到後面的 K／KK 課，中間不能隔著 L 課。
    fn kana_reach_ok(&self, task_lesson: &str, item_lesson: &str) -> bool {
        let (Some(from), Some(to)) = (self.facts.pos(task_lesson), self.facts.pos(item_lesson))
        else {
            return false;
        };
        from <= to
            && self
                .facts
                .order
                .iter()
                .filter(|id| self.facts.pos(id).is_some_and(|p| p >= from && p <= to))
                .all(|id| is_kana_lesson(id))
    }

    fn check_new_items(&mut self, log: &DayLog) {
        for item in &log.new_items {
            let lesson_ok = if is_kana_lesson(&item.task_lesson) {
                self.kana_reach_ok(&item.task_lesson, &item.item_lesson)
            } else {
                item.item_lesson == item.task_lesson
            };
            if !lesson_ok {
                let detail = format!(
                    "{} 屬 {}，任務 {}",
                    item.item_id, item.item_lesson, item.task_lesson
                );
                self.flag(Rule::NewItemLesson, log.date, detail);
            }
            if self.introduced.contains(&item.item_id) {
                self.flag(Rule::NewItemOnce, log.date, item.item_id.clone());
            }
        }
    }
}

impl Checker<'_> {
    fn check_checkpoints(&mut self, log: &DayLog) {
        for task in &log.first_view.tasks {
            let TaskDto::Checkpoint { milestone_id, .. } = task else {
                continue;
            };
            let lesson = self.facts.milestones.get(milestone_id);
            let lesson_done = lesson.is_some_and(|l| self.completed_on.contains_key(l));
            let repeated = self.checkpoints.iter().any(|(_, id)| id == milestone_id);
            if !lesson_done || repeated {
                let detail =
                    format!("{milestone_id}（{lesson:?}），課完成 {lesson_done}，重複 {repeated}");
                self.flag(Rule::Checkpoint, log.date, detail);
            }
        }
    }
}

impl Checker<'_> {
    fn check_question(&mut self, log: &DayLog, question: &SeenQuestion) {
        let Some(card_id) = question.card_id.as_deref() else {
            return;
        };
        if !matches!(question.source, Source::Review | Source::NewContent) {
            return;
        }
        let subject = card_content(card_id);
        let lesson = self
            .facts
            .vocab
            .get(subject)
            .or_else(|| self.facts.grammar.get(subject))
            .cloned();
        let cursor = log.cursor_after.as_deref();
        if let Some(lesson) = lesson.filter(|l| !self.facts.at_or_before_cursor(l, cursor)) {
            let detail = format!("{subject} 屬 {lesson}，游標 {cursor:?}");
            self.flag(Rule::MainCardLesson, log.date, detail);
        }
    }
}

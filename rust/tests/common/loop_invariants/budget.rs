//! 每日分鐘與複習積壓的條文（rust-core §7.2、§7.4，RULINGS O11、O12）。

use jp_core::api::dto_plan::{RecoveryReason, TaskDto, TodayViewDto};

use super::{Checker, DayLog, Rule};

/// `Review` 的估算四捨五入到 0.5 分（§7.4），最多多出 0.25 分。
const ROUNDING_MINUTES: f64 = 0.5;
const SECONDS_PER_NEW_CARD: f64 = 8.0;
const MINUTES_EPSILON: f64 = 1e-9;
/// rust-core §7.4：listen 額度不足這個分鐘數時不列 `Listen`。
const MIN_LISTEN_MINUTES: f64 = 0.5;
/// rust-core §7.2 `BACKLOG_FACTOR`、`BACKLOG_PAUSE_FACTOR`、`MINIMAL_FROM_RECOVERY_DAY`。
const BACKLOG_FACTOR: u32 = 2;
const PAUSE_LINE_FACTOR: u32 = 5;
const MINIMAL_FROM_DAY: u32 = 3;
/// `capacity` 至少這麼多張時，扣掉一半給收尾、回鍋再減半，`review_cap` 仍 ≥ 2。
const CAP_FLOOR_CAPACITY: u32 = 8;

fn is_return_day(view: &TodayViewDto) -> bool {
    view.recovery_reason == Some(RecoveryReason::ReturnAfterBreak)
}

/// RULINGS O12：到期數 > 2 × `capacity` 就是積壓，不看原因標籤（回鍋日也算）。
fn is_due_backlog(view: &TodayViewDto) -> bool {
    review_due(view) > BACKLOG_FACTOR * view.budget.capacity
}

/// 只排複習的日子不該出現的任務。
fn is_practice(task: &TaskDto) -> bool {
    matches!(
        task,
        TaskDto::NewContent { .. }
            | TaskDto::Integration { .. }
            | TaskDto::Drill { .. }
            | TaskDto::Listen { .. }
    )
}

fn is_main_slice(task: &TaskDto) -> bool {
    matches!(
        task,
        TaskDto::NewContent { .. } | TaskDto::Integration { .. }
    )
}

/// 當天開始時的到期數（`Review.due`，快照建立時的同一個查詢）。
fn review_due(view: &TodayViewDto) -> u32 {
    view.tasks
        .iter()
        .find_map(|task| match task {
            TaskDto::Review { due, .. } => Some(*due),
            _ => None,
        })
        .unwrap_or(0)
}

/// §7.2 `recovery_days` 的接續：受限 +1、不受限歸 0、回鍋當天為 1；休息日維持前值，
/// 但回鍋落在休息日歸 0（RULINGS O12）。
fn next_recovery_days(view: &TodayViewDto, previous: u32) -> u32 {
    match view.recovery_reason {
        Some(RecoveryReason::ReturnAfterBreak) if !view.is_study_day => 0,
        _ if !view.is_study_day => previous,
        None => 0,
        Some(RecoveryReason::ReturnAfterBreak) => 1,
        Some(_) => previous + 1,
    }
}

pub fn new_cards_minutes(view: &TodayViewDto) -> f64 {
    view.tasks
        .iter()
        .find_map(|task| match task {
            TaskDto::Review { new_cards, .. } => Some(f64::from(*new_cards)),
            _ => None,
        })
        .map_or(0.0, |cards| cards * SECONDS_PER_NEW_CARD / 60.0)
}

/// 任務分鐘的精簡列表，例如 `review 5.5（到期 40／新卡 12）new 2 listen 1`。
fn task_minutes(view: &TodayViewDto) -> String {
    view.tasks
        .iter()
        .filter_map(|task| match task {
            TaskDto::Review {
                minutes,
                due,
                new_cards,
                ..
            } => Some(format!("review {minutes}（到期 {due}／新卡 {new_cards}）")),
            TaskDto::NewContent { minutes, .. } => Some(format!("new {minutes}")),
            TaskDto::Integration { minutes, .. } => Some(format!("integration {minutes}")),
            TaskDto::Drill { minutes, .. } => Some(format!("drill {minutes}")),
            TaskDto::Listen { minutes, .. } => Some(format!("listen {minutes}")),
            TaskDto::Checkpoint { .. } => None,
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn listen_minutes(view: &TodayViewDto) -> Option<f64> {
    view.tasks.iter().find_map(|task| match task {
        TaskDto::Listen { minutes, .. } => Some(*minutes),
        _ => None,
    })
}

fn new_content_minutes(view: &TodayViewDto) -> Option<f64> {
    view.tasks.iter().find_map(|task| match task {
        TaskDto::NewContent { minutes, .. } => Some(*minutes),
        _ => None,
    })
}

impl Checker<'_> {
    pub(super) fn check_minutes(&mut self, log: &DayLog) {
        let view = &log.first_view;
        let tail = new_cards_minutes(view);
        let allowed = f64::from(self.daily_minutes) + ROUNDING_MINUTES;
        let detail = format!(
            "預估 {} 分（收尾新卡 {tail:.1} 分）> 容許 {allowed:.1}｜{}",
            view.estimated_minutes,
            task_minutes(view)
        );
        if view.estimated_minutes - tail > allowed {
            self.flag(Rule::MinutesBudget, log.date, detail.clone());
        }
        if view.estimated_minutes > allowed {
            self.flag(Rule::MinutesWithNewCards, log.date, detail);
        }
    }

    /// `Listen`、`NewContent` 任務的分鐘與預算的額度一致（§7.4）。
    pub(super) fn check_task_minutes(&mut self, log: &DayLog) {
        let view = &log.first_view;
        let budget = &view.budget;
        let (listen, new) = (listen_minutes(view), new_content_minutes(view));
        let listen_bad = listen.is_some_and(|m| {
            (m - budget.listen_minutes).abs() > MINUTES_EPSILON
                || budget.listen_minutes < MIN_LISTEN_MINUTES
        });
        let new_bad = new.is_some_and(|m| (m - budget.new_minutes).abs() > MINUTES_EPSILON);
        if listen_bad || new_bad {
            let detail = format!(
                "listen {listen:?}（應 {}）new {new:?}（應 {}）｜{}",
                budget.listen_minutes,
                budget.new_minutes,
                task_minutes(view)
            );
            self.flag(Rule::TaskMinutes, log.date, detail);
        }
    }

    fn check_cap_floor(&mut self, log: &DayLog) {
        let view = &log.first_view;
        let budget = &view.budget;
        if budget.capacity >= CAP_FLOOR_CAPACITY && budget.review_cap < 2 {
            let detail = format!(
                "cap {}／capacity {}｜{}",
                budget.review_cap,
                budget.capacity,
                task_minutes(view)
            );
            self.flag(Rule::ReviewCapFloor, log.date, detail);
        }
    }

    /// 暫停線只用在原因為 `ReviewBacklog` 的學習日；回鍋當天本來就不給新內容。
    pub(super) fn check_backlog_lines(&mut self, log: &DayLog) {
        let view = &log.first_view;
        self.recovery_days = next_recovery_days(view, self.recovery_days);
        self.check_cap_floor(log);
        let is_backlog_reason = view.recovery_reason == Some(RecoveryReason::ReviewBacklog);
        if !view.is_study_day || !is_backlog_reason {
            return;
        }
        let capacity = view.budget.capacity;
        let due = review_due(view);
        let over_line = due > PAUSE_LINE_FACTOR * capacity;
        let has_slice = view.tasks.iter().any(is_main_slice);
        let wants_minimal = !over_line && self.recovery_days >= MINIMAL_FROM_DAY;
        let bad = if over_line {
            view.minimal_new || has_slice
        } else {
            view.minimal_new != wants_minimal
        };
        if bad {
            let detail = format!(
                "到期 {due}／capacity {capacity}（{PAUSE_LINE_FACTOR} 倍線 {over_line}）積壓第 {} 天，minimal_new {}，主線切片 {has_slice}",
                self.recovery_days, view.minimal_new
            );
            self.flag(Rule::BacklogPauseLine, log.date, detail);
        }
    }

    /// §7.4：非學習日只回 `Review`；RULINGS O12：複習上限用階段配比，不併入方案分鐘。
    pub(super) fn check_rest_day(&mut self, log: &DayLog) {
        let view = &log.first_view;
        if view.is_study_day {
            return;
        }
        let budget = &view.budget;
        let others = view
            .tasks
            .iter()
            .filter(|task| !matches!(task, TaskDto::Review { .. }))
            .count();
        let merged = budget.review_minutes >= f64::from(self.daily_minutes)
            || budget.review_cap > budget.capacity;
        if others > 0 || merged {
            let detail = format!(
                "休息日列出 {others} 項其他任務，review {} 分（方案 {}）cap {}／capacity {}｜{}",
                budget.review_minutes,
                self.daily_minutes,
                budget.review_cap,
                budget.capacity,
                task_minutes(view)
            );
            self.flag(Rule::RestDayReviewOnly, log.date, detail);
        }
    }

    /// 學習日積壓（不看原因標籤）且不給新內容：只排複習，review 額度等於方案分鐘。`review_cap`
    /// 依合併後的分鐘重算，回鍋日再減半，所以只對其他日子要求大於階段配比的 `capacity`。
    pub(super) fn check_review_only_day(&mut self, log: &DayLog) {
        let view = &log.first_view;
        if !view.is_study_day || !is_due_backlog(view) || view.minimal_new {
            return;
        }
        let budget = &view.budget;
        let all_review = (budget.review_minutes - f64::from(self.daily_minutes)).abs()
            < MINUTES_EPSILON
            && budget.new_minutes + budget.drill_minutes + budget.listen_minutes == 0.0;
        let cap_raised = is_return_day(view) || budget.review_cap > budget.capacity;
        if !all_review || !cap_raised || view.tasks.iter().any(is_practice) {
            let detail = format!(
                "review {} 分（方案 {}）cap {}／capacity {}，{:?}｜{}",
                budget.review_minutes,
                self.daily_minutes,
                budget.review_cap,
                budget.capacity,
                view.recovery_reason,
                task_minutes(view)
            );
            self.flag(Rule::ReviewOnlyDay, log.date, detail);
        }
    }
}

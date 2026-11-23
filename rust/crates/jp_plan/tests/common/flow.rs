//! 今日任務流程測試的共用輔助。
#![allow(dead_code)]

use chrono::{Duration, NaiveDate};
use jp_content::ContentStore;
use jp_plan::complete::complete_task;
use jp_plan::tasks::DailyTask;
use jp_plan::today::{today_view, TaskView, TodayView};
use jp_store::SqliteRepository;

use super::*;

pub const AUDIO: bool = true;

pub fn monday() -> NaiveDate {
    d(MONDAY)
}

pub fn day(n: i64) -> NaiveDate {
    monday() + Duration::days(n)
}

pub fn view(repo: &SqliteRepository, store: &ContentStore, on: NaiveDate) -> TodayView {
    today_view(repo, store, &ctx_on(on), AUDIO).unwrap()
}

pub fn task<'a>(view: &'a TodayView, key: &str) -> &'a TaskView {
    view.tasks
        .iter()
        .find(|t| t.task.key() == key)
        .unwrap_or_else(|| panic!("{key}: {:?}", keys(view)))
}

pub fn keys(view: &TodayView) -> Vec<&str> {
    view.tasks.iter().map(|t| t.task.key()).collect()
}

pub fn done(repo: &SqliteRepository, store: &ContentStore, on: NaiveDate, key: &str) -> TodayView {
    complete_task(repo, store, &ctx_on(on), key, 60_000, AUDIO).unwrap()
}

pub fn setup(minutes: u32) -> (SqliteRepository, ContentStore) {
    let (repo, store) = (repo(), content());
    create_plan(&repo, &store, &ctx_on(monday()), &input(minutes));
    (repo, store)
}

pub fn new_key(view: &TodayView) -> String {
    view.tasks
        .iter()
        .find_map(|t| {
            matches!(t.task, DailyTask::NewContent { .. }).then(|| t.task.key().to_owned())
        })
        .expect("應有 NewContent")
}

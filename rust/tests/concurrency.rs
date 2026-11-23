//! §11.2 `concurrency`：多執行緒共用同一個 `AppCore`（§10）。

mod common;

use std::sync::Arc;
use std::thread;

use common::*;
use jp_core::api::dto_plan::{SettingsPatchDto, StartLevel};
use jp_core::api::error::CoreError;

const THREADS: usize = 16;

#[test]
fn concurrent_submits_of_one_card_only_succeed_once() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);
    app.next_day();
    let card = expect_card(app.core.session_next(SEED, true).unwrap());
    let answer = answer_for(&card, correct_payload(&card.question));
    let shared = Arc::new(app);

    let handles: Vec<_> = (0..THREADS)
        .map(|_| {
            let app = Arc::clone(&shared);
            let answer = answer.clone();
            thread::spawn(move || app.core.submit_answer(answer))
        })
        .collect();
    let results: Vec<_> = handles.into_iter().map(|h| h.join().unwrap()).collect();

    assert_eq!(results.iter().filter(|r| r.is_ok()).count(), 1);
    assert!(results
        .iter()
        .filter_map(|r| r.as_ref().err())
        .all(|err| matches!(err, CoreError::StaleCard { .. })));
    assert_eq!(shared.core.stats_overview().unwrap().total_reviews, 1);
}

#[test]
fn concurrent_reads_and_writes_all_complete() {
    let app = Arc::new(TestApp::new());
    app.start_plan(&plan_input(20, StartLevel::Zero));

    let handles: Vec<_> = (0..THREADS)
        .map(|index| {
            let app = Arc::clone(&app);
            thread::spawn(move || {
                let patch = SettingsPatchDto {
                    autoplay: Some(index % 2 == 0),
                    ..SettingsPatchDto::default()
                };
                app.core.update_settings(patch).unwrap();
                app.core.today_view(true).unwrap();
                app.core.course_overview().unwrap();
            })
        })
        .collect();

    for handle in handles {
        handle.join().unwrap();
    }
    assert_eq!(app.today().tasks.len(), 2);
}

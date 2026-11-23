//! §10 併發模型：單一 Mutex<Connection>、reps 樂觀鎖。

mod common;

use std::sync::{Arc, Barrier};
use std::thread;

use common::*;
use jp_store::{ActivityDelta, ActivityRepo, Repository, SqliteRepository, SrsRepo, StoreError};

const THREADS: usize = 16;

#[test]
fn only_one_of_many_simultaneous_submissions_succeeds() {
    let db = temp_db();
    db.repo.insert_cards(&[old_card("vo.a:recog", 0)]).unwrap();
    let repo = Arc::new(db.repo);
    let barrier = Arc::new(Barrier::new(THREADS));

    let handles: Vec<_> = (0..THREADS)
        .map(|_| {
            let repo = Arc::clone(&repo);
            let barrier = Arc::clone(&barrier);
            thread::spawn(move || {
                barrier.wait();
                repo.apply_review(&review_write("vo.a:recog", 0, 0, 1, ts(NOW), d(TODAY)))
            })
        })
        .collect();
    let results: Vec<_> = handles.into_iter().map(|h| h.join().unwrap()).collect();

    assert_eq!(results.iter().filter(|r| r.is_ok()).count(), 1);
    assert!(results
        .iter()
        .filter_map(|r| r.as_ref().err())
        .all(|err| matches!(err, StoreError::StaleCard { .. })));
    assert_eq!(repo.reviews_for_card("vo.a:recog").unwrap().len(), 1);
    assert_eq!(repo.card("vo.a:recog").unwrap().unwrap().reps, 1);
}

#[test]
fn parallel_writes_through_trait_object_all_land() {
    let db = temp_db();
    let repo: Arc<dyn Repository> = Arc::new(db.repo);
    let one = ActivityDelta {
        reviews_done: 1,
        ..ActivityDelta::default()
    };
    const WRITES_PER_THREAD: u32 = 20;

    let handles: Vec<_> = (0..THREADS)
        .map(|_| {
            let repo = Arc::clone(&repo);
            thread::spawn(move || {
                for _ in 0..WRITES_PER_THREAD {
                    repo.add_activity(d(TODAY), one).unwrap();
                }
            })
        })
        .collect();
    for handle in handles {
        handle.join().unwrap();
    }

    let rows = repo.activity_range(d(TODAY), d(TODAY)).unwrap();
    assert_eq!(rows[0].reviews_done, THREADS as u32 * WRITES_PER_THREAD);
}

/// §10 hot restart：舊 handle 的連線還開著時，第二條連線靠 WAL 與 busy_timeout 共存。
#[test]
fn second_connection_to_the_same_file_can_write_concurrently() {
    let db = temp_db();
    let other = SqliteRepository::open(&db.path).unwrap();
    let one = ActivityDelta {
        reviews_done: 1,
        ..ActivityDelta::default()
    };
    const WRITES: u32 = 100;
    let repos = [Arc::new(db.repo), Arc::new(other)];

    let handles: Vec<_> = repos
        .iter()
        .map(|repo| {
            let repo = Arc::clone(repo);
            thread::spawn(move || {
                for _ in 0..WRITES {
                    repo.add_activity(d(TODAY), one).unwrap();
                }
            })
        })
        .collect();
    for handle in handles {
        handle.join().unwrap();
    }

    let rows = repos[0].activity_range(d(TODAY), d(TODAY)).unwrap();
    assert_eq!(rows[0].reviews_done, 2 * WRITES);
}

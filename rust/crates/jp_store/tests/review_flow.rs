//! §5.4 apply_review 與卡片、log、activity 的一致性。
//! 交易中途 panic 的回滾需要內部入口，測試放在 src/db.rs。

mod common;

use chrono::Duration;
use common::*;
use jp_store::{ActivityRepo, SrsRepo, StoreError};

const CARD: &str = "vo.taberu:recog";

fn seeded() -> TestDb {
    let db = temp_db();
    db.repo.insert_cards(&[old_card(CARD, 0)]).unwrap();
    db
}

#[test]
fn new_card_moves_through_learning_to_review_with_log_and_activity() {
    let db = seeded();
    let first_at = ts(NOW);
    let second_at = first_at + Duration::minutes(10);
    let third_at = first_at + Duration::days(4);

    db.repo
        .apply_review(&review_write(CARD, 0, 0, 1, first_at, d(TODAY)))
        .unwrap();
    db.repo
        .apply_review(&review_write(CARD, 1, 1, 2, second_at, d(TODAY)))
        .unwrap();
    db.repo
        .apply_review(&review_write(CARD, 2, 2, 2, third_at, d("2026-03-08")))
        .unwrap();

    let card = db.repo.card(CARD).unwrap().unwrap();
    assert_eq!(card.state, 2);
    assert_eq!(card.reps, 3);
    assert_eq!(card.last_review_at, third_at);
    assert_eq!(card.due_at, third_at + Duration::days(4));
    assert_eq!(card.stability, 4.351);
    assert_eq!(card.difficulty, 5.267);
    assert_eq!(card.last_logical_date, Some(d("2026-03-08")));

    let logs = db.repo.reviews_for_card(CARD).unwrap();
    assert_eq!(logs.len(), 3);
    assert!(logs.windows(2).all(|pair| pair[0].id < pair[1].id));
    assert_eq!(logs[0].card_id, CARD);
    assert_eq!(logs[0].entry.state_before, 0);
    assert_eq!(logs[0].entry.state_after, 1);
    assert_eq!(logs[0].entry.reviewed_at, first_at);
    assert_eq!(logs[2].entry.logical_date, d("2026-03-08"));
    assert_eq!(logs[2].entry.question_type, "recog");
    assert!(!logs[2].entry.clock_skewed);

    let activity = db.repo.activity_range(d(TODAY), d("2026-03-08")).unwrap();
    assert_eq!(activity.len(), 2);
    assert_eq!(activity[0].logical_date, d(TODAY));
    assert_eq!(activity[0].reviews_done, 2);
    assert_eq!(activity[0].study_ms, 3000);
    assert_eq!(activity[1].reviews_done, 1);
}

#[test]
fn repeated_submit_with_same_reps_is_stale_and_writes_nothing() {
    let db = seeded();
    let write = review_write(CARD, 0, 0, 1, ts(NOW), d(TODAY));
    db.repo.apply_review(&write).unwrap();

    let err = db.repo.apply_review(&write).unwrap_err();

    match err {
        StoreError::StaleCard { card_id } => assert_eq!(card_id, CARD),
        other => panic!("預期 StaleCard，得到 {other:?}"),
    }
    assert_eq!(db.repo.reviews_for_card(CARD).unwrap().len(), 1);
    let activity = db.repo.activity_range(d(TODAY), d(TODAY)).unwrap();
    assert_eq!(activity[0].reviews_done, 1);
}

#[test]
fn unknown_card_is_reported_as_stale() {
    let db = temp_db();

    let err = db
        .repo
        .apply_review(&review_write("vo.none:recog", 0, 0, 1, ts(NOW), d(TODAY)))
        .unwrap_err();

    assert!(matches!(err, StoreError::StaleCard { .. }), "{err:?}");
    assert!(db
        .repo
        .reviews_for_card("vo.none:recog")
        .unwrap()
        .is_empty());
}

/// F3：SQLite 的 CHECK 擋不住 Infinity，必須在寫入前檢查。
#[test]
fn non_finite_values_are_rejected_before_writing() {
    let db = seeded();
    let mut infinite_stability = review_write(CARD, 0, 0, 1, ts(NOW), d(TODAY));
    infinite_stability.card.stability = f64::INFINITY;
    let mut nan_difficulty = review_write(CARD, 0, 0, 1, ts(NOW), d(TODAY));
    nan_difficulty.log.difficulty_after = f64::NAN;
    let mut infinite_log = review_write(CARD, 0, 0, 1, ts(NOW), d(TODAY));
    infinite_log.log.stability_after = f64::INFINITY;
    let mut nan_card = review_write(CARD, 0, 0, 1, ts(NOW), d(TODAY));
    nan_card.card.difficulty = f64::NAN;

    for write in [infinite_stability, nan_difficulty, infinite_log, nan_card] {
        let err = db.repo.apply_review(&write).unwrap_err();
        assert!(matches!(err, StoreError::Internal { .. }), "{err:?}");
    }

    let card = db.repo.card(CARD).unwrap().unwrap();
    assert_eq!(card.reps, 0);
    assert_eq!(card.state, 0);
    assert!(db.repo.reviews_for_card(CARD).unwrap().is_empty());
}

#[test]
fn failure_after_card_update_rolls_back_the_whole_review() {
    let db = seeded();
    let mut write = review_write(CARD, 0, 0, 1, ts(NOW), d(TODAY));
    // 卡片更新會成功，INSERT review_log 才違反 CHECK。
    write.log.rating = 9;

    let err = db.repo.apply_review(&write).unwrap_err();

    assert!(matches!(err, StoreError::Storage { .. }), "{err:?}");
    let card = db.repo.card(CARD).unwrap().unwrap();
    assert_eq!(card.reps, 0);
    assert_eq!(card.state, 0);
    assert!(db
        .repo
        .activity_range(d(TODAY), d(TODAY))
        .unwrap()
        .is_empty());
}

#[test]
fn clock_skew_flag_is_recorded() {
    let db = seeded();
    let mut write = review_write(CARD, 0, 0, 1, ts(NOW), d(TODAY));
    write.log.clock_skewed = true;

    db.repo.apply_review(&write).unwrap();

    assert!(
        db.repo.reviews_for_card(CARD).unwrap()[0]
            .entry
            .clock_skewed
    );
}

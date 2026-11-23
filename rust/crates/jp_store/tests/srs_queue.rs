//! §5.3 關鍵查詢與 §5.4 SrsRepo 的查詢、建卡、暫停。

mod common;

use std::collections::HashSet;

use chrono::Duration;
use common::*;
use jp_store::{ItemIntroRow, PlanRepo, QueueFilter, SrsRepo};

const ALL: QueueFilter = QueueFilter {
    audio_available: true,
};
const SILENT: QueueFilter = QueueFilter {
    audio_available: false,
};

fn ids(cards: Vec<&str>) -> HashSet<String> {
    cards.into_iter().map(str::to_string).collect()
}

/// 主線字卡要有 `item_intro` 才進第 3、4 步（C04）。
fn teach(db: &TestDb, items: &[&str]) {
    let rows: Vec<_> = items
        .iter()
        .map(|item| ItemIntroRow {
            item_id: (*item).to_string(),
            lesson_id: "le.l01".to_string(),
            logical_date: d(TODAY),
            introduced_at: ts(NOW),
        })
        .collect();
    db.repo.insert_item_intros(&rows).unwrap();
}

#[test]
fn card_returns_none_for_unknown_id() {
    let db = temp_db();

    assert_eq!(db.repo.card("vo.none:recog").unwrap(), None);
}

#[test]
fn inserted_card_starts_as_new_with_creation_time_as_due() {
    let db = temp_db();
    let created = ts(LONG_AGO);
    let card = new_card("vo.a:recog", 1, created);

    assert_eq!(db.repo.insert_cards(&[card]).unwrap(), 1);

    let row = db.repo.card("vo.a:recog").unwrap().unwrap();
    assert_eq!(row.content_id, "vo.a");
    assert_eq!(row.facet, "recog");
    assert_eq!(row.priority, 1);
    assert_eq!(row.state, 0);
    assert_eq!(row.due_at, created);
    assert_eq!(row.last_review_at, created);
    assert_eq!(row.created_at, created);
    assert_eq!(row.stability, 0.0);
    assert_eq!(row.difficulty, 0.0);
    assert_eq!((row.elapsed_days, row.scheduled_days), (0, 0));
    assert_eq!((row.reps, row.lapses), (0, 0));
    assert_eq!(row.last_logical_date, None);
    assert!(!row.suspended);
}

#[test]
fn insert_ignores_existing_cards_and_keeps_their_progress() {
    let db = temp_db();
    let conn = raw(&db.path);
    db.repo.insert_cards(&[old_card("vo.a:recog", 0)]).unwrap();
    place_card(&conn, "vo.a:recog", 2, ts(NOW));

    let inserted = db
        .repo
        .insert_cards(&[old_card("vo.a:recog", 0), old_card("vo.b:recog", 0)])
        .unwrap();

    assert_eq!(inserted, 1);
    assert_eq!(db.repo.card("vo.a:recog").unwrap().unwrap().state, 2);
}

#[test]
fn insert_of_no_cards_is_a_no_op() {
    let db = temp_db();

    assert_eq!(db.repo.insert_cards(&[]).unwrap(), 0);
}

#[test]
fn insert_is_atomic_when_one_card_is_invalid() {
    let db = temp_db();
    let mut bad = old_card("vo.b:recog", 0);
    bad.facet = "write".to_string();

    db.repo
        .insert_cards(&[old_card("vo.a:recog", 0), bad])
        .unwrap_err();

    assert_eq!(db.repo.card("vo.a:recog").unwrap(), None);
}

#[test]
fn introduced_seq_follows_insertion_order_across_batches() {
    let db = temp_db();
    db.repo
        .insert_cards(&[old_card("vo.c:recog", 0), old_card("vo.a:recog", 0)])
        .unwrap();
    db.repo.insert_cards(&[old_card("vo.b:recog", 0)]).unwrap();
    teach(&db, &["vo.a", "vo.b", "vo.c"]);

    let first = db.repo.next_new(0, &ctx(), ALL).unwrap().unwrap();

    assert_eq!(first.card_id, "vo.c:recog");
    let seq = |id: &str| db.repo.card(id).unwrap().unwrap().introduced_seq;
    assert!(seq("vo.c:recog") < seq("vo.a:recog"));
    assert!(seq("vo.a:recog") < seq("vo.b:recog"));
}

#[test]
fn next_learning_orders_by_due_and_respects_limit() {
    let db = temp_db();
    let conn = raw(&db.path);
    db.repo
        .insert_cards(&[
            old_card("vo.a:recog", 0),
            old_card("vo.b:recog", 0),
            old_card("vo.c:recog", 0),
        ])
        .unwrap();
    let now = ts(NOW);
    place_card(&conn, "vo.a:recog", 3, now);
    place_card(&conn, "vo.b:recog", 1, now - Duration::minutes(1));
    place_card(&conn, "vo.c:recog", 1, now + Duration::minutes(1));

    let first = db.repo.next_learning(now, ALL).unwrap().unwrap();
    assert_eq!(first.card_id, "vo.b:recog");

    let before_all = now - Duration::minutes(2);
    assert_eq!(db.repo.next_learning(before_all, ALL).unwrap(), None);

    // due_at 相同時依 card_id；limit 為含邊界。
    place_card(&conn, "vo.b:recog", 2, now);
    place_card(&conn, "vo.c:recog", 1, now);
    let tie = db.repo.next_learning(now, ALL).unwrap().unwrap();
    assert_eq!(tie.card_id, "vo.a:recog");
}

#[test]
fn queue_ignores_suspended_cards_and_can_exclude_listen() {
    let db = temp_db();
    let conn = raw(&db.path);
    db.repo
        .insert_cards(&[old_card("vo.a:listen", 0), old_card("vo.b:recog", 0)])
        .unwrap();
    let now = ts(NOW);
    place_card(&conn, "vo.a:listen", 1, now - Duration::minutes(5));
    place_card(&conn, "vo.b:recog", 1, now);

    assert_eq!(
        db.repo.next_learning(now, ALL).unwrap().unwrap().card_id,
        "vo.a:listen"
    );
    assert_eq!(
        db.repo.next_learning(now, SILENT).unwrap().unwrap().card_id,
        "vo.b:recog"
    );

    db.repo.set_content_suspended("vo.b", true).unwrap();
    assert_eq!(db.repo.next_learning(now, SILENT).unwrap(), None);
}

#[test]
fn next_due_review_uses_exclusive_end_of_today() {
    let db = temp_db();
    let conn = raw(&db.path);
    db.repo
        .insert_cards(&[old_card("vo.a:recog", 0), old_card("vo.b:recog", 0)])
        .unwrap();
    place_card(&conn, "vo.a:recog", 2, ts(END_OF_TODAY));
    place_card(
        &conn,
        "vo.b:recog",
        2,
        ts(END_OF_TODAY) - Duration::milliseconds(1),
    );

    let next = db.repo.next_due_review(&ctx(), ALL).unwrap().unwrap();

    assert_eq!(next.card_id, "vo.b:recog");
}

#[test]
fn next_due_review_excludes_card_whose_sibling_was_done_today() {
    let db = temp_db();
    let conn = raw(&db.path);
    db.repo
        .insert_cards(&[
            old_card("vo.a:recog", 0),
            old_card("vo.a:listen", 0),
            old_card("vo.b:recog", 0),
        ])
        .unwrap();
    let due = ts(NOW) - Duration::hours(1);
    place_card(&conn, "vo.a:listen", 2, due - Duration::hours(1));
    place_card(&conn, "vo.a:recog", 2, due + Duration::days(9));
    place_card(&conn, "vo.b:recog", 2, due);
    mark_reviewed_on(&conn, "vo.a:recog", TODAY);

    let next = db.repo.next_due_review(&ctx(), ALL).unwrap().unwrap();
    assert_eq!(next.card_id, "vo.b:recog");

    // 昨天做過的 sibling 不影響今天。
    mark_reviewed_on(&conn, "vo.a:recog", "2026-03-03");
    let next = db.repo.next_due_review(&ctx(), ALL).unwrap().unwrap();
    assert_eq!(next.card_id, "vo.a:listen");
}

#[test]
fn a_card_is_not_its_own_sibling() {
    let db = temp_db();
    let conn = raw(&db.path);
    db.repo
        .insert_cards(&[old_card("vo.a:recog", 0), old_card("vo.b:produce", 1)])
        .unwrap();
    place_card(&conn, "vo.a:recog", 2, ts(NOW));
    mark_reviewed_on(&conn, "vo.a:recog", TODAY);
    mark_reviewed_on(&conn, "vo.b:produce", TODAY);
    teach(&db, &["vo.b"]);

    let due = db.repo.next_due_review(&ctx(), ALL).unwrap().unwrap();
    let new_card = db.repo.next_new(1, &ctx(), ALL).unwrap().unwrap();

    assert_eq!(due.card_id, "vo.a:recog");
    assert_eq!(new_card.card_id, "vo.b:produce");
}

#[test]
fn next_new_only_takes_cards_created_before_today_in_seq_order() {
    let db = temp_db();
    db.repo
        .insert_cards(&[
            new_card("vo.today:recog", 0, ts(START_OF_TODAY)),
            new_card(
                "vo.yesterday:recog",
                0,
                ts(START_OF_TODAY) - Duration::milliseconds(1),
            ),
            old_card("vo.old:recog", 0),
        ])
        .unwrap();
    teach(&db, &["vo.today", "vo.yesterday", "vo.old"]);

    let next = db.repo.next_new(0, &ctx(), ALL).unwrap().unwrap();

    assert_eq!(next.card_id, "vo.yesterday:recog");
    assert_eq!(db.repo.count_new(0, &ctx(), ALL).unwrap(), 2);
}

#[test]
fn next_new_applies_sibling_exclusion_only_to_priority_one() {
    let db = temp_db();
    let conn = raw(&db.path);
    db.repo
        .insert_cards(&[
            old_card("vo.a:recog", 0),
            old_card("vo.a:listen", 0),
            old_card("vo.a:produce", 1),
        ])
        .unwrap();
    mark_reviewed_on(&conn, "vo.a:listen", TODAY);
    teach(&db, &["vo.a"]);

    assert_eq!(
        db.repo.next_new(0, &ctx(), ALL).unwrap().unwrap().card_id,
        "vo.a:recog"
    );
    assert_eq!(db.repo.next_new(1, &ctx(), ALL).unwrap(), None);
    assert_eq!(db.repo.count_new(0, &ctx(), ALL).unwrap(), 2);
    assert_eq!(db.repo.count_new(1, &ctx(), ALL).unwrap(), 0);
}

#[test]
fn next_new_can_exclude_listen() {
    let db = temp_db();
    db.repo
        .insert_cards(&[old_card("vo.a:listen", 0), old_card("vo.b:recog", 0)])
        .unwrap();
    teach(&db, &["vo.a", "vo.b"]);

    let next = db.repo.next_new(0, &ctx(), SILENT).unwrap().unwrap();

    assert_eq!(next.card_id, "vo.b:recog");
    assert_eq!(db.repo.count_new(0, &ctx(), SILENT).unwrap(), 1);
    assert_eq!(db.repo.count_new(0, &ctx(), ALL).unwrap(), 2);
}

#[test]
fn earliest_learning_due_covers_learning_and_relearning_only() {
    let db = temp_db();
    let conn = raw(&db.path);
    assert_eq!(db.repo.earliest_learning_due(ALL).unwrap(), None);
    db.repo
        .insert_cards(&[
            old_card("vo.a:listen", 0),
            old_card("vo.b:recog", 0),
            old_card("vo.c:recog", 0),
        ])
        .unwrap();
    let base = ts(NOW);
    place_card(&conn, "vo.a:listen", 3, base);
    place_card(&conn, "vo.b:recog", 1, base + Duration::minutes(5));
    place_card(&conn, "vo.c:recog", 2, base - Duration::days(1));

    assert_eq!(db.repo.earliest_learning_due(ALL).unwrap(), Some(base));
    assert_eq!(
        db.repo.earliest_learning_due(SILENT).unwrap(),
        Some(base + Duration::minutes(5))
    );
}

#[test]
fn due_review_facets_and_count_follow_the_same_filter() {
    let db = temp_db();
    let conn = raw(&db.path);
    db.repo
        .insert_cards(&[
            old_card("gr.a:use", 0),
            old_card("vo.a:listen", 0),
            old_card("vo.b:recog", 0),
            old_card("vo.c:recog", 0),
        ])
        .unwrap();
    let due = ts(NOW);
    place_card(&conn, "vo.b:recog", 2, due);
    place_card(&conn, "gr.a:use", 2, due);
    place_card(&conn, "vo.a:listen", 2, due - Duration::hours(1));
    place_card(&conn, "vo.c:recog", 2, ts(END_OF_TODAY));

    assert_eq!(
        db.repo.due_review_facets(&ctx(), ALL).unwrap(),
        vec!["listen", "use", "recog"]
    );
    assert_eq!(
        db.repo.due_review_facets(&ctx(), SILENT).unwrap(),
        vec!["use", "recog"]
    );
    assert_eq!(db.repo.count_due_reviews(&ctx(), ALL).unwrap(), 3);
    assert_eq!(db.repo.count_due_reviews(&ctx(), SILENT).unwrap(), 2);
}

/// 到期數要與 `next_due_review` 可取的卡一致：當日做過 sibling 的卡不算（§6.4）。
#[test]
fn due_counts_exclude_cards_whose_sibling_was_done_today() {
    let db = temp_db();
    let conn = raw(&db.path);
    db.repo
        .insert_cards(&[old_card("vo.a:recog", 0), old_card("vo.a:listen", 0)])
        .unwrap();
    place_card(&conn, "vo.a:recog", 2, ts(NOW));
    place_card(&conn, "vo.a:listen", 1, ts(NOW));
    conn.execute(
        "UPDATE srs_card SET last_logical_date = ?1 WHERE card_id = 'vo.a:listen'",
        [TODAY],
    )
    .unwrap();

    assert_eq!(db.repo.next_due_review(&ctx(), ALL).unwrap(), None);
    assert_eq!(db.repo.count_due_reviews(&ctx(), ALL).unwrap(), 0);
    assert!(db.repo.due_review_facets(&ctx(), ALL).unwrap().is_empty());
}

#[test]
fn count_learning_can_limit_by_creation_time() {
    let db = temp_db();
    let conn = raw(&db.path);
    let boundary = ts(START_OF_TODAY);
    db.repo
        .insert_cards(&[
            new_card("vo.a:recog", 0, boundary - Duration::days(1)),
            new_card("vo.b:recog", 0, boundary),
            new_card("vo.c:listen", 0, boundary - Duration::days(1)),
            new_card("vo.d:recog", 0, boundary - Duration::days(1)),
        ])
        .unwrap();
    let now = ts(NOW);
    place_card(&conn, "vo.a:recog", 1, now);
    place_card(&conn, "vo.b:recog", 3, now);
    place_card(&conn, "vo.c:listen", 1, now);
    place_card(&conn, "vo.d:recog", 1, now + Duration::hours(1));

    assert_eq!(db.repo.count_learning(now, None, ALL).unwrap(), 3);
    assert_eq!(db.repo.count_learning(now, Some(boundary), ALL).unwrap(), 2);
    assert_eq!(
        db.repo.count_learning(now, Some(boundary), SILENT).unwrap(),
        1
    );
}

#[test]
fn count_unseen_new_ignores_kana_listen_priority_one_and_today() {
    let db = temp_db();
    db.repo
        .insert_cards(&[
            old_card("vo.a:recog", 0),
            old_card("gr.a:use", 0),
            old_card("ka.hira.a:read", 0),
            old_card("vo.a:listen", 0),
            old_card("vo.a:produce", 1),
            new_card("vo.today:recog", 0, ts(NOW)),
        ])
        .unwrap();
    teach(&db, &["vo.a", "gr.a", "vo.today"]);

    assert_eq!(db.repo.count_unseen_new(&ctx()).unwrap(), 2);
}

/// C04：開了 `NewContent` 就離開的主線卡還沒教過，隔天不算積壓，也不由佇列取出。
#[test]
fn main_cards_never_introduced_stay_out_of_the_new_queue() {
    let db = temp_db();
    db.repo.insert_cards(&[old_card("vo.a:recog", 0)]).unwrap();

    assert_eq!(db.repo.next_new(0, &ctx(), ALL).unwrap(), None);
    assert_eq!(db.repo.count_new(0, &ctx(), ALL).unwrap(), 0);
    assert_eq!(db.repo.count_unseen_new(&ctx()).unwrap(), 0);
}

/// 假名 `:read` 沒有 `first_card`，靠第 3、4 步第一次出現。
#[test]
fn kana_cards_need_no_intro_to_reach_the_new_queue() {
    let db = temp_db();
    db.repo
        .insert_cards(&[old_card("ka.hira.a:read", 0)])
        .unwrap();

    assert_eq!(db.repo.count_new(0, &ctx(), ALL).unwrap(), 1);
}

#[test]
fn count_new_done_counts_first_contact_by_priority_on_that_day() {
    let db = temp_db();
    db.repo
        .insert_cards(&[
            old_card("vo.a:recog", 0),
            old_card("vo.b:listen", 1),
            old_card("vo.c:listen", 1),
        ])
        .unwrap();
    let today = d(TODAY);
    let now = ts(NOW);
    db.repo
        .apply_review(&review_write("vo.a:recog", 0, 0, 1, now, today))
        .unwrap();
    db.repo
        .apply_review(&review_write("vo.b:listen", 0, 0, 1, now, today))
        .unwrap();
    // 第二次作答不是第一次接觸，昨天做的也不算今天。
    db.repo
        .apply_review(&review_write("vo.b:listen", 1, 1, 2, now, today))
        .unwrap();
    db.repo
        .apply_review(&review_write("vo.c:listen", 0, 0, 1, now, d("2026-03-03")))
        .unwrap();

    assert_eq!(db.repo.count_new_done(1, today).unwrap(), 1);
    assert_eq!(db.repo.count_new_done(0, today).unwrap(), 1);
}

/// §6.4 收尾上限：只算今天以前建立、今天第一次接觸的卡；當天新內容建的卡不算。
#[test]
fn count_tail_new_done_counts_first_contact_of_cards_created_before_today() {
    let db = temp_db();
    let today = d(TODAY);
    let now = ts(NOW);
    db.repo
        .insert_cards(&[
            old_card("vo.a:recog", 0),
            old_card("vo.b:listen", 1),
            old_card("vo.c:recog", 0),
            new_card("vo.d:recog", 0, ts(START_OF_TODAY)),
        ])
        .unwrap();
    for (card, state_before, reps, date) in [
        ("vo.a:recog", 0, 0, today),
        ("vo.b:listen", 0, 0, today),
        ("vo.b:listen", 1, 1, today),
        ("vo.c:recog", 0, 0, d("2026-03-03")),
        ("vo.d:recog", 0, 0, today),
    ] {
        db.repo
            .apply_review(&review_write(card, reps, state_before, 1, now, date))
            .unwrap();
    }

    assert_eq!(db.repo.count_tail_new_done(&ctx()).unwrap(), 2);
}

#[test]
fn set_content_suspended_reports_only_rows_that_changed() {
    let db = temp_db();
    db.repo
        .insert_cards(&[
            old_card("vo.a:recog", 0),
            old_card("vo.a:listen", 0),
            old_card("vo.b:recog", 0),
        ])
        .unwrap();

    assert_eq!(db.repo.set_content_suspended("vo.a", true).unwrap(), 2);
    assert_eq!(db.repo.set_content_suspended("vo.a", true).unwrap(), 0);
    assert!(db.repo.card("vo.a:listen").unwrap().unwrap().suspended);
    assert!(!db.repo.card("vo.b:recog").unwrap().unwrap().suspended);
    assert_eq!(db.repo.set_content_suspended("vo.a", false).unwrap(), 2);
    assert!(!db.repo.card("vo.a:listen").unwrap().unwrap().suspended);
}

#[test]
fn suspend_missing_only_touches_cards_outside_keep_set() {
    let db = temp_db();
    db.repo
        .insert_cards(&[
            old_card("vo.keep:recog", 0),
            old_card("vo.gone:recog", 0),
            old_card("vo.gone:listen", 0),
        ])
        .unwrap();

    let suspended = db.repo.suspend_missing(&ids(vec!["vo.keep"])).unwrap();

    assert_eq!(suspended, 2);
    assert!(!db.repo.card("vo.keep:recog").unwrap().unwrap().suspended);
    assert!(db.repo.card("vo.gone:recog").unwrap().unwrap().suspended);
    assert_eq!(db.repo.suspend_missing(&ids(vec!["vo.keep"])).unwrap(), 0);
}

#[test]
fn card_counts_split_states_and_exclude_suspended() {
    let db = temp_db();
    let conn = raw(&db.path);
    db.repo
        .insert_cards(&[
            old_card("vo.new:recog", 0),
            old_card("vo.learning:recog", 0),
            old_card("vo.relearning:recog", 0),
            old_card("vo.review:recog", 0),
            old_card("vo.mastered:recog", 0),
            old_card("vo.hidden:recog", 0),
        ])
        .unwrap();
    let now = ts(NOW);
    place_card(&conn, "vo.learning:recog", 1, now);
    place_card(&conn, "vo.relearning:recog", 3, now);
    place_card(&conn, "vo.review:recog", 2, now);
    place_card(&conn, "vo.mastered:recog", 2, now);
    conn.execute(
        "UPDATE srs_card SET scheduled_days = 20 WHERE card_id = 'vo.review:recog'",
        [],
    )
    .unwrap();
    conn.execute(
        "UPDATE srs_card SET scheduled_days = 21 WHERE card_id = 'vo.mastered:recog'",
        [],
    )
    .unwrap();
    db.repo.set_content_suspended("vo.hidden", true).unwrap();
    db.repo
        .apply_review(&review_write("vo.new:recog", 0, 0, 0, now, d(TODAY)))
        .unwrap();

    let counts = db.repo.card_counts().unwrap();

    assert_eq!(counts.cards_new, 1);
    assert_eq!(counts.cards_learning, 2);
    assert_eq!(counts.cards_review, 1);
    assert_eq!(counts.cards_mastered, 1);
    assert_eq!(counts.total_reviews, 1);
}

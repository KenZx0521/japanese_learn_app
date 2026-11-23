//! 整合測試共用夾具。每個測試執行檔只用到其中一部分。
#![allow(dead_code)]

use chrono::{DateTime, Duration, NaiveDate, Utc};
use jp_content::disk::borrow_files;
use jp_content::schema::ContentStage;
use jp_content::test_support::fixture_files;
use jp_content::{load_content, ContentStore};
use jp_lang::clock::DayContext;
use jp_store::{
    ActivityDelta, CardReviewUpdate, ItemIntroRow, NewCard, PlanRepo, ReviewLogEntry, ReviewWrite,
    SqliteRepository, SrsRepo,
};

pub const NOW: &str = "2026-03-04T12:00:00Z";
pub const TODAY: &str = "2026-03-04";
pub const END_OF_TODAY: &str = "2026-03-04T20:00:00Z";
pub const START_OF_TODAY: &str = "2026-03-03T20:00:00Z";
pub const LONG_AGO: &str = "2026-03-01T00:00:00Z";
pub const OLD_DATE: &str = "2026-02-01";

pub fn ts(text: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(text).unwrap().to_utc()
}

pub fn d(text: &str) -> NaiveDate {
    text.parse().unwrap()
}

/// 台北時區、換日 4 點：邏輯日 2026-03-04 是 03-03T20:00Z 到 03-04T20:00Z。
pub fn ctx_at(now: DateTime<Utc>) -> DayContext {
    DayContext {
        now,
        utc_offset_minutes: 480,
        rollover_hour: 4,
    }
}

pub fn ctx() -> DayContext {
    ctx_at(ts(NOW))
}

pub fn repo() -> SqliteRepository {
    SqliteRepository::open_in_memory().unwrap()
}

pub fn content() -> ContentStore {
    jp_content::test_support::load_full_fixture(ContentStage::Full)
}

/// 完整夾具做字串替換後載入，用來造出夾具沒有的內容組合。
pub fn content_with(edits: &[(&str, &str)]) -> ContentStore {
    let mut files = fixture_files();
    for (needle, replacement) in edits {
        let hits = files
            .iter()
            .filter(|(_, text)| text.contains(needle))
            .count();
        assert_eq!(hits, 1, "{needle} 應只出現在一個檔案");
        for (_, text) in &mut files {
            *text = text.replacen(needle, replacement, 1);
        }
    }
    load_content(&borrow_files(&files), ContentStage::Full).unwrap()
}

pub fn new_card_at(card_id: &str, priority: u8, created_at: DateTime<Utc>) -> NewCard {
    let (content_id, facet) = card_id.split_once(':').unwrap();
    NewCard {
        card_id: card_id.to_string(),
        content_id: content_id.to_string(),
        facet: facet.to_string(),
        priority,
        created_at,
    }
}

/// 已教過（寫了 `item_intro`）但還沒做的卡，佇列第 3、4 步才取得到。
pub fn add_old_card(repo: &SqliteRepository, card_id: &str, priority: u8) {
    add_taught_card(repo, card_id, priority, ts(LONG_AGO));
}

pub fn add_taught_card(
    repo: &SqliteRepository,
    card_id: &str,
    priority: u8,
    created_at: DateTime<Utc>,
) {
    let card = new_card_at(card_id, priority, created_at);
    repo.insert_item_intros(&[ItemIntroRow {
        item_id: card.content_id.clone(),
        lesson_id: "le.l01".to_string(),
        logical_date: created_at.date_naive(),
        introduced_at: created_at,
    }])
    .unwrap();
    repo.insert_cards(&[card]).unwrap();
}

/// 把卡片擺到指定狀態。`logical_date` 同時決定 `last_logical_date`。
pub fn place_on(
    repo: &SqliteRepository,
    card_id: &str,
    state: u8,
    due_at: DateTime<Utc>,
    logical_date: NaiveDate,
) {
    let row = repo.card(card_id).unwrap().unwrap();
    let write = ReviewWrite {
        card_id: card_id.to_string(),
        expected_reps: row.reps,
        card: CardReviewUpdate {
            state,
            due_at,
            last_review_at: ts(LONG_AGO),
            stability: 5.0,
            difficulty: 5.0,
            elapsed_days: 0,
            scheduled_days: 4,
            reps: row.reps + 1,
            lapses: 0,
        },
        log: ReviewLogEntry {
            rating: 3,
            state_before: row.state,
            state_after: state,
            elapsed_days: 0,
            scheduled_days: 4,
            stability_after: 5.0,
            difficulty_after: 5.0,
            reviewed_at: ts(LONG_AGO),
            logical_date,
            utc_offset_minutes: 480,
            duration_ms: 1000,
            question_type: "recog".to_string(),
            clock_skewed: false,
        },
        activity: ActivityDelta::default(),
    };
    repo.apply_review(&write).unwrap();
}

pub fn place(repo: &SqliteRepository, card_id: &str, state: u8, due_at: DateTime<Utc>) {
    place_on(repo, card_id, state, due_at, d(OLD_DATE));
}

/// 擺到很久以後才到期，讓它離開佇列。
pub fn clear_from_queue(repo: &SqliteRepository, card_id: &str) {
    place(repo, card_id, 2, ts(NOW) + Duration::days(30));
}

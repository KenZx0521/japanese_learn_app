//! 整合測試共用夾具。每個測試執行檔只用到其中一部分。
#![allow(dead_code)]

pub mod flow;

use std::collections::HashSet;

use chrono::{DateTime, Duration, NaiveDate, Utc};
use jp_content::schema::{ContentStage, PlanPresetDef};
use jp_content::ContentStore;
use jp_lang::clock::DayContext;
use jp_plan::calendar::{PlanHistory, ALL_DAYS_MASK};
use jp_plan::compose::DayFacts;
use jp_plan::input::{plan_write, preset_for, PlanInput, StartLevel};
use jp_plan::state::CursorState;
use jp_store::{
    CardReviewUpdate, MilestoneResultRow, NewCard, PlanRepo, PlanVersionRow, ReviewLogEntry,
    ReviewWrite, SqliteRepository, SrsRepo,
};

pub const MONDAY: &str = "2026-03-02";
pub const MWF_MASK: u8 = 0b0010101;

pub fn ts(text: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(text).unwrap().to_utc()
}

pub fn d(text: &str) -> NaiveDate {
    text.parse().unwrap()
}

/// 台北時區、換日 4 點，邏輯日 `date` 當地中午。
pub fn ctx_on(date: NaiveDate) -> DayContext {
    let now = date.and_hms_opt(4, 0, 0).unwrap().and_utc();
    DayContext {
        now,
        utc_offset_minutes: 480,
        rollover_hour: 4,
    }
}

pub fn repo() -> SqliteRepository {
    SqliteRepository::open_in_memory().unwrap()
}

pub fn content() -> ContentStore {
    jp_content::test_support::load_full_fixture(ContentStage::Full)
}

pub fn content_at(stage: ContentStage) -> ContentStore {
    jp_content::test_support::load_full_fixture(stage)
}

pub fn preset(content: &ContentStore, minutes: u32) -> PlanPresetDef {
    preset_for(minutes, content).unwrap().clone()
}

pub fn input(minutes: u32) -> PlanInput {
    PlanInput {
        daily_minutes: minutes,
        weekday_mask: ALL_DAYS_MASK,
        start_level: StartLevel::Zero,
        target_date: None,
        known_kana_lessons: Vec::new(),
    }
}

/// 全部假名、規則、字組、單字、文法的 ID。
pub fn lesson_item_ids(lesson: &str, content: &ContentStore) -> Vec<String> {
    let items = content.lesson_items(lesson).unwrap();
    let kana = items
        .kana
        .iter()
        .map(|&i| content.kana()[i as usize].def.id.clone());
    let rules = items
        .rules
        .iter()
        .map(|&i| content.rule_cards()[i as usize].id.clone());
    let confusables = items
        .confusables
        .iter()
        .map(|&i| content.confusables()[i as usize].id.clone());
    let words = items
        .words
        .iter()
        .map(|&i| content.vocab()[i as usize].def.id.clone());
    let grammar = items
        .grammar
        .iter()
        .map(|&i| content.grammar()[i as usize].id.clone());
    kana.chain(rules)
        .chain(confusables)
        .chain(words)
        .chain(grammar)
        .collect()
}

/// 把 `lessons` 全部項目介紹完並完成，日期為 `on`。
pub fn with_completed(
    mut state: CursorState,
    lessons: &[&str],
    on: NaiveDate,
    content: &ContentStore,
) -> CursorState {
    for lesson in lessons {
        state.introduced.extend(lesson_item_ids(lesson, content));
        state.completed.insert((*lesson).to_owned(), on);
    }
    state
}

/// 游標在 `lesson`：之前的課全部完成。
pub fn state_at(lesson: &str, content: &ContentStore) -> CursorState {
    let pos = content.lesson_pos(lesson).unwrap() as usize;
    let before: Vec<&str> = content.course().order[..pos]
        .iter()
        .map(String::as_str)
        .collect();
    with_completed(CursorState::default(), &before, d("2026-01-01"), content)
}

pub fn state_all_done(content: &ContentStore) -> CursorState {
    let all: Vec<&str> = content.course().order.iter().map(String::as_str).collect();
    with_completed(CursorState::default(), &all, d("2026-01-01"), content)
}

pub fn intro(state: &mut CursorState, ids: &[&str]) {
    state
        .introduced
        .extend(ids.iter().map(|id| (*id).to_owned()));
}

pub fn ids(items: &[&str]) -> Vec<String> {
    items.iter().map(|item| (*item).to_owned()).collect()
}

pub fn facets(items: &[&str]) -> Vec<String> {
    ids(items)
}

/// `count` 張 `facet` 的到期卡。
pub fn due_facets(count: usize, facet: &str) -> Vec<String> {
    vec![facet.to_owned(); count]
}

/// `DayFacts` 的擁有者，測試改欄位後呼叫 `facts()` 組成借用版本。
pub struct FactsFixture {
    pub today: NaiveDate,
    pub plan: PlanVersionRow,
    pub preset: PlanPresetDef,
    pub state: CursorState,
    pub history: PlanHistory,
    pub due_facets: Vec<String>,
    pub tail_new_cards: u32,
    pub unseen_new: u32,
    pub last_active: Option<NaiveDate>,
    pub previous_recovery_days: u32,
    pub audio_available: bool,
    pub milestone_results: Vec<MilestoneResultRow>,
    pub dismissed: HashSet<String>,
}

pub fn plan_row(effective_from: NaiveDate, minutes: u32, mask: u8) -> PlanVersionRow {
    PlanVersionRow {
        id: 1,
        effective_from,
        daily_minutes: minutes,
        weekday_mask: mask,
        start_level: "zero".to_owned(),
        target_date: None,
        created_at: ts("2026-03-01T00:00:00Z"),
    }
}

impl FactsFixture {
    pub fn new(content: &ContentStore, today: NaiveDate, minutes: u32, state: CursorState) -> Self {
        let plan = plan_row(today, minutes, ALL_DAYS_MASK);
        let history = PlanHistory::from_rows(std::slice::from_ref(&plan));
        Self {
            today,
            plan,
            preset: preset(content, minutes),
            state,
            history,
            due_facets: Vec::new(),
            tail_new_cards: 0,
            unseen_new: 0,
            last_active: None,
            previous_recovery_days: 0,
            audio_available: true,
            milestone_results: Vec::new(),
            dismissed: HashSet::new(),
        }
    }

    pub fn facts(&self) -> DayFacts<'_> {
        DayFacts {
            today: self.today,
            plan: &self.plan,
            preset: &self.preset,
            state: &self.state,
            history: &self.history,
            due_facets: &self.due_facets,
            tail_new_cards: self.tail_new_cards,
            unseen_new: self.unseen_new,
            last_active: self.last_active,
            previous_recovery_days: self.previous_recovery_days,
            audio_available: self.audio_available,
            milestone_results: &self.milestone_results,
            dismissed: &self.dismissed,
        }
    }
}

/// 建立計畫，生效日為 `ctx.today()`。
pub fn create_plan(
    repo: &SqliteRepository,
    content: &ContentStore,
    ctx: &DayContext,
    input: &PlanInput,
) {
    let state = CursorState::load(repo).unwrap();
    let write = plan_write(input, &state, content, ctx).unwrap();
    repo.insert_plan(&write.plan, &write.baseline, &write.skips)
        .unwrap();
}

pub fn new_card(content_id: &str, facet: &str, priority: u8, created_at: DateTime<Utc>) -> NewCard {
    NewCard {
        card_id: format!("{content_id}:{facet}"),
        content_id: content_id.to_owned(),
        facet: facet.to_owned(),
        priority,
        created_at,
    }
}

/// 建一張已是 Review、`due_at` 的卡。
pub fn seed_due_review(
    repo: &SqliteRepository,
    content_id: &str,
    facet: &str,
    due_at: DateTime<Utc>,
) {
    let created = due_at - Duration::days(30);
    repo.insert_cards(&[new_card(content_id, facet, 0, created)])
        .unwrap();
    let write = ReviewWrite {
        card_id: format!("{content_id}:{facet}"),
        expected_reps: 0,
        card: CardReviewUpdate {
            state: 2,
            due_at,
            last_review_at: created,
            stability: 10.0,
            difficulty: 5.0,
            elapsed_days: 0,
            scheduled_days: 10,
            reps: 1,
            lapses: 0,
        },
        log: ReviewLogEntry {
            rating: 3,
            state_before: 0,
            state_after: 2,
            elapsed_days: 0,
            scheduled_days: 10,
            stability_after: 10.0,
            difficulty_after: 5.0,
            reviewed_at: created,
            logical_date: created.date_naive(),
            utc_offset_minutes: 480,
            duration_ms: 1000,
            question_type: "recog".to_owned(),
            clock_skewed: false,
        },
        activity: Default::default(),
    };
    repo.apply_review(&write).unwrap();
}

/// 第一次接觸：把 state＝0 的卡推進學習中，模擬 `first_card` 作答。
pub fn first_contact(repo: &SqliteRepository, card_id: &str, when: DateTime<Utc>) {
    first_contact_due(repo, card_id, when, when + Duration::days(30));
}

/// 同上，指定學習中卡片的到期時刻。
pub fn first_contact_due(
    repo: &SqliteRepository,
    card_id: &str,
    when: DateTime<Utc>,
    due_at: DateTime<Utc>,
) {
    let write = ReviewWrite {
        card_id: card_id.to_owned(),
        expected_reps: 0,
        card: CardReviewUpdate {
            state: 1,
            due_at,
            last_review_at: when,
            stability: 1.0,
            difficulty: 5.0,
            elapsed_days: 0,
            scheduled_days: 0,
            reps: 1,
            lapses: 0,
        },
        log: ReviewLogEntry {
            rating: 3,
            state_before: 0,
            state_after: 1,
            elapsed_days: 0,
            scheduled_days: 0,
            stability_after: 1.0,
            difficulty_after: 5.0,
            reviewed_at: when,
            logical_date: when.date_naive(),
            utc_offset_minutes: 480,
            duration_ms: 1000,
            question_type: "recog".to_owned(),
            clock_skewed: false,
        },
        activity: Default::default(),
    };
    repo.apply_review(&write).unwrap();
}

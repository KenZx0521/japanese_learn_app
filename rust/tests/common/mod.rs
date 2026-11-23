//! 整合測試共用：夾具 App、跨日、依題目作答。
#![allow(dead_code)]

pub mod answerable;
pub mod real;

use chrono::{DateTime, Duration, TimeZone, Utc};
use jp_content::schema::ContentStage as FixtureStage;
use jp_content::test_support::load_full_fixture;
use jp_content::ContentStore;
use jp_core::api::core::{AppCore, CoreConfig};
use jp_core::api::dto_plan::{PlanInputDto, StartLevel, TaskDto, TodayViewDto};
use jp_core::api::dto_study::{
    AnswerDto, AnswerPayload, DrillFilterDto, NewContentSessionDto, NewContentStepDto,
    QuestionBodyDto, QuestionDto, Rating, SessionCardDto, SessionNextDto, ShadowLevel,
};
use tempfile::TempDir;

pub mod learner;
pub mod loop_facts;
pub mod loop_invariants;
pub mod loop_report;
pub mod loop_run;

pub const SEED: u32 = 42;
pub const UTC_PLUS_8: i32 = 480;
const MAX_QUEUE_STEPS: usize = 2_000;
const ANSWER_MS: u32 = 2_000;

/// 2026-03-02（週一）台北 09:00，邏輯日就是當天。
pub fn start_time() -> DateTime<Utc> {
    Utc.with_ymd_and_hms(2026, 3, 2, 1, 0, 0).unwrap()
}

pub struct TestApp {
    _dir: TempDir,
    pub db_path: String,
    pub content: ContentStore,
    pub now: DateTime<Utc>,
    pub core: AppCore,
}

impl TestApp {
    pub fn new() -> Self {
        Self::with_stage(FixtureStage::Full)
    }

    pub fn with_stage(stage: FixtureStage) -> Self {
        Self::with_content(load_full_fixture(stage))
    }

    pub fn with_content(content: ContentStore) -> Self {
        let dir = tempfile::tempdir().unwrap();
        let db_path = dir.path().join("jp_core.db").to_string_lossy().into_owned();
        let now = start_time();
        let core = open(&db_path, &content, now);
        Self {
            _dir: dir,
            db_path,
            content,
            now,
            core,
        }
    }

    /// 重開 `AppCore`：FixedClock 換到新時刻，同時驗證進度確實寫進磁碟。
    pub fn advance(&mut self, delta: Duration) {
        self.now += delta;
        self.core = open(&self.db_path, &self.content, self.now);
    }

    pub fn next_day(&mut self) {
        self.advance(Duration::days(1));
    }

    pub fn start_plan(&self, input: &PlanInputDto) {
        self.core.create_plan(input.clone()).unwrap();
    }

    pub fn today(&self) -> TodayViewDto {
        self.core.today_view(true).unwrap()
    }
}

pub fn open(db_path: &str, content: &ContentStore, now: DateTime<Utc>) -> AppCore {
    AppCore::open_with_content(
        CoreConfig {
            db_path: db_path.to_owned(),
            utc_offset_minutes: UTC_PLUS_8,
            fixed_now_utc: Some(now),
        },
        content.clone(),
    )
    .unwrap()
}

pub fn plan_input(minutes: u32, start_level: StartLevel) -> PlanInputDto {
    PlanInputDto {
        daily_minutes: minutes,
        weekdays: vec![1, 2, 3, 4, 5, 6, 7],
        start_level,
        target_date: None,
        known_kana_lessons: Vec::new(),
    }
}

/// 除了 `except` 以外的 K01–K19。
pub fn known_k_lessons_except(except: &[&str]) -> Vec<String> {
    (1..=19)
        .map(|n| format!("le.k{n:02}"))
        .filter(|id| !except.contains(&id.as_str()))
        .collect()
}

pub fn new_content_key(today: &TodayViewDto) -> Option<String> {
    today.tasks.iter().find_map(|task| match task {
        TaskDto::NewContent { key, .. } => Some(key.clone()),
        _ => None,
    })
}

pub fn task_key(task: &TaskDto) -> &str {
    match task {
        TaskDto::Review { key, .. }
        | TaskDto::NewContent { key, .. }
        | TaskDto::Integration { key, .. }
        | TaskDto::Drill { key, .. }
        | TaskDto::Listen { key, .. }
        | TaskDto::Checkpoint { key, .. } => key,
    }
}

pub fn task_done(task: &TaskDto) -> bool {
    match task {
        TaskDto::Review { done, .. }
        | TaskDto::NewContent { done, .. }
        | TaskDto::Integration { done, .. }
        | TaskDto::Drill { done, .. }
        | TaskDto::Listen { done, .. }
        | TaskDto::Checkpoint { done, .. } => *done,
    }
}

pub fn correct_payload(question: &QuestionDto) -> AnswerPayload {
    match &question.body {
        QuestionBodyDto::Choice {
            correct_option_id, ..
        } => AnswerPayload::Choice {
            option_id: correct_option_id.clone(),
        },
        QuestionBodyDto::Reorder { accept_orders, .. } => AnswerPayload::Reorder {
            order: accept_orders[0].clone(),
        },
        QuestionBodyDto::Typing {
            expected_reading, ..
        } => AnswerPayload::Typing {
            input: expected_reading.clone(),
        },
        QuestionBodyDto::Match { .. } => AnswerPayload::Match { all_correct: true },
        QuestionBodyDto::SelfGrade { .. } => AnswerPayload::SelfGrade {
            rating: Rating::Good,
        },
        QuestionBodyDto::Shadow { .. } => AnswerPayload::Shadow {
            level: ShadowLevel::Kept,
        },
    }
}

pub fn wrong_payload(question: &QuestionDto) -> AnswerPayload {
    match &question.body {
        QuestionBodyDto::Choice {
            options,
            correct_option_id,
            ..
        } => AnswerPayload::Choice {
            option_id: options
                .iter()
                .find(|option| option.id != *correct_option_id)
                .expect("選擇題至少兩個選項")
                .id
                .clone(),
        },
        QuestionBodyDto::SelfGrade { .. } => AnswerPayload::SelfGrade {
            rating: Rating::Again,
        },
        _ => correct_payload(question),
    }
}

pub fn answer_for(card: &SessionCardDto, response: AnswerPayload) -> AnswerDto {
    AnswerDto {
        reference: card.question.reference.clone(),
        expected_reps: card.expected_reps,
        response,
        hint_used: false,
        attempts: 1,
        duration_ms: ANSWER_MS,
    }
}

pub fn expect_card(next: SessionNextDto) -> SessionCardDto {
    match next {
        SessionNextDto::Card { card } => card,
        SessionNextDto::Done { next_due_at } => {
            panic!("佇列應有卡片，next_due_at = {next_due_at:?}")
        }
    }
}

pub fn answer_all_kana(core: &AppCore, questions: &[QuestionDto]) {
    for question in questions {
        core.kana_submit(
            question.reference.clone(),
            correct_payload(question),
            ANSWER_MS,
        )
        .unwrap();
    }
}

/// 依序呈現步驟並作答，與 Dart 的 L3 相同。
pub fn walk_new_content(core: &AppCore, session: &NewContentSessionDto) {
    for step in &session.steps {
        match step {
            NewContentStepDto::KanaQuiz { questions } => answer_all_kana(core, questions),
            NewContentStepDto::Vocab {
                first_card: Some(card),
                ..
            }
            | NewContentStepDto::Grammar {
                first_card: Some(card),
                ..
            } => {
                let payload = correct_payload(&card.question);
                core.submit_answer(answer_for(card, payload)).unwrap();
            }
            _ => {}
        }
    }
}

/// `session_next` 拉到 `Done`，全部答對；回傳答了幾張。
pub fn drain_queue(core: &AppCore, audio_available: bool) -> usize {
    for answered in 0..MAX_QUEUE_STEPS {
        match core.session_next(SEED, audio_available).unwrap() {
            SessionNextDto::Done { .. } => return answered,
            SessionNextDto::Card { card } => {
                let payload = correct_payload(&card.question);
                core.submit_answer(answer_for(&card, payload)).unwrap();
            }
        }
    }
    panic!("佇列在 {MAX_QUEUE_STEPS} 步內沒有結束");
}

fn pass_checkpoint(core: &AppCore, milestone_id: &str, audio_available: bool) {
    let questions = core
        .checkpoint_start(milestone_id.to_owned(), SEED, audio_available)
        .unwrap();
    let answers = questions
        .iter()
        .map(|question| AnswerDto {
            reference: question.reference.clone(),
            expected_reps: 0,
            response: correct_payload(question),
            hint_used: false,
            attempts: 1,
            duration_ms: ANSWER_MS,
        })
        .collect();
    core.checkpoint_finish(milestone_id.to_owned(), answers)
        .unwrap();
}

fn run_task(app: &TestApp, task: &TaskDto, audio_available: bool) {
    let core = &app.core;
    match task {
        TaskDto::Review { .. } => {
            drain_queue(core, audio_available);
        }
        TaskDto::NewContent { key, .. } => {
            let session = core
                .new_content_session(key.clone(), SEED, audio_available)
                .unwrap();
            walk_new_content(core, &session);
        }
        TaskDto::Drill { key, .. } => {
            let filter = DrillFilterDto {
                task_key: Some(key.clone()),
                ..DrillFilterDto::default()
            };
            for question in core.drill_session(filter, SEED, audio_available).unwrap() {
                core.grade_drill(question.reference.clone(), correct_payload(&question))
                    .unwrap();
            }
        }
        TaskDto::Listen { key, .. } => {
            for question in core
                .listen_session(key.clone(), SEED, audio_available)
                .unwrap()
            {
                core.grade_drill(question.reference.clone(), correct_payload(&question))
                    .unwrap();
            }
        }
        TaskDto::Checkpoint { milestone_id, .. } => {
            pass_checkpoint(core, milestone_id, audio_available);
        }
        TaskDto::Integration { .. } => {}
    }
}

/// 把當天的任務清單跑完，再收尾到 `Done`，模擬正常使用的一天。
pub fn study_full_day(app: &TestApp, audio_available: bool) -> TodayViewDto {
    let core = &app.core;
    let first = core.today_view(audio_available).unwrap();
    for task in &first.tasks {
        if !task_done(task) || matches!(task, TaskDto::Review { .. }) {
            run_task(app, task, audio_available);
            core.complete_task(task_key(task).to_owned(), 60_000, audio_available)
                .unwrap();
        }
    }
    drain_queue(core, audio_available);
    first
}

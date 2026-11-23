//! 學習迴路模擬的學習者（p0_learning_loop.rs）：每天打開 App，依序做完今日任務，
//! 逐題記下看過的題目與發生的錯誤。錯誤不中斷模擬，留給呼叫端判定。

use std::cell::Cell;
use std::fmt::Debug;

use chrono::NaiveDate;
use jp_content::ContentStore;
use jp_core::api::core::AppCore;
use jp_core::api::dto_plan::{PlanInputDto, PlanViewDto, TaskDto, TodayViewDto};
use jp_core::api::dto_study::{
    AnswerDto, AnswerPayload, DrillFilterDto, NewContentSessionDto, NewContentStepDto,
    QuestionBodyDto, QuestionDto, QuestionType, SessionCardDto, SessionNextDto,
};

use super::{answer_for, correct_payload, task_done, task_key, wrong_payload, TestApp};

const MAX_QUEUE_STEPS: usize = 5_000;
const ANSWER_MS: u32 = 2_000;
const TASK_MS: u32 = 60_000;
const RATIO_BASE: u64 = 10;

/// 每 10 題答錯 `wrong_per_ten` 題，依作答順序決定，可重現。
pub struct AnswerPolicy {
    wrong_per_ten: u64,
    answered: Cell<u64>,
}

impl AnswerPolicy {
    pub fn always_correct() -> Self {
        Self::wrong_per_ten(0)
    }

    pub fn wrong_per_ten(wrong_per_ten: u64) -> Self {
        Self {
            wrong_per_ten,
            answered: Cell::new(0),
        }
    }

    pub fn respond(&self, question: &QuestionDto) -> AnswerPayload {
        let index = self.answered.get();
        self.answered.set(index + 1);
        if index % RATIO_BASE < self.wrong_per_ten {
            wrong_payload(question)
        } else {
            correct_payload(question)
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Source {
    Review,
    NewContent,
    KanaQuiz,
    Drill,
    Listen,
    Checkpoint,
}

#[derive(Debug, Clone)]
pub struct SeenQuestion {
    pub source: Source,
    pub question_type: QuestionType,
    pub content_id: String,
    pub card_id: Option<String>,
    /// 題目露出的句子：題幹、選項與答後顯示。
    pub sentence_ids: Vec<String>,
}

fn shown_sentences(question: &QuestionDto) -> Vec<String> {
    let body: Vec<String> = match &question.body {
        QuestionBodyDto::Choice { options, .. } => options
            .iter()
            .filter_map(|o| o.sentence.as_ref().map(|s| s.id.clone()))
            .collect(),
        QuestionBodyDto::SelfGrade { reveal } | QuestionBodyDto::Shadow { reveal } => {
            vec![reveal.id.clone()]
        }
        _ => Vec::new(),
    };
    question
        .prompt
        .text
        .iter()
        .map(|s| s.id.clone())
        .chain(body)
        .collect()
}

impl SeenQuestion {
    fn of(source: Source, question: &QuestionDto) -> Self {
        Self {
            source,
            question_type: question.question_type,
            content_id: question.reference.content_id.clone(),
            card_id: question.reference.card_id.clone(),
            sentence_ids: shown_sentences(question),
        }
    }
}

/// 新內容學習頁介紹的項目。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewItem {
    pub task_lesson: String,
    pub item_id: String,
    pub item_lesson: String,
}

/// 一天的原始紀錄，判定交給 `loop_invariants`。
#[derive(Debug, Clone)]
pub struct DayLog {
    pub date: NaiveDate,
    pub first_view: TodayViewDto,
    pub cursor_before: Option<String>,
    pub cursor_after: Option<String>,
    pub questions: Vec<SeenQuestion>,
    pub new_items: Vec<NewItem>,
    /// 收尾後仍到期、留到隔天的複習卡（`session_summary.due_reviews`）。
    pub due_left: u32,
    pub errors: Vec<String>,
}

pub struct Learner {
    pub app: TestApp,
    pub created: PlanViewDto,
    policy: AnswerPolicy,
    /// 當天打開 App 時的 `audio_available`；預設有聲。
    audio: Cell<bool>,
}

fn parse_date(text: &str) -> NaiveDate {
    NaiveDate::parse_from_str(text, "%Y-%m-%d").expect("logical_date 應為 YYYY-MM-DD")
}

/// 做一天時的累積狀態；`seed` 每天不同，模擬 Dart 每次開 session 的種子。
struct DayRun<'a> {
    core: &'a AppCore,
    policy: &'a AnswerPolicy,
    seed: u32,
    audio: bool,
    questions: Vec<SeenQuestion>,
    new_items: Vec<NewItem>,
    errors: Vec<String>,
}

impl DayRun<'_> {
    fn ok<T, E: Debug>(&mut self, what: &str, result: Result<T, E>) -> Option<T> {
        result
            .map_err(|err| self.errors.push(format!("{what}: {err:?}")))
            .ok()
    }

    fn answer_card(&mut self, source: Source, card: &SessionCardDto) {
        self.questions
            .push(SeenQuestion::of(source, &card.question));
        let payload = self.policy.respond(&card.question);
        let result = self.core.submit_answer(answer_for(card, payload));
        self.ok(&format!("submit_answer {}", card.card_id), result);
    }

    /// `session_next` 拉到 `Done`。
    fn drain_queue(&mut self) {
        for _ in 0..MAX_QUEUE_STEPS {
            let next = self.core.session_next(self.seed, self.audio);
            match self.ok("session_next", next) {
                Some(SessionNextDto::Card { card }) => self.answer_card(Source::Review, &card),
                Some(SessionNextDto::Done { .. }) | None => return,
            }
        }
        self.errors
            .push(format!("佇列在 {MAX_QUEUE_STEPS} 步內沒有結束"));
    }

    fn grade_drills(&mut self, source: Source, questions: Vec<QuestionDto>) {
        for question in questions {
            self.questions.push(SeenQuestion::of(source, &question));
            let payload = self.policy.respond(&question);
            let result = self.core.grade_drill(question.reference.clone(), payload);
            self.ok("grade_drill", result);
        }
    }

    fn record_step(&mut self, lesson: &str, step: &NewContentStepDto) {
        let (item_id, item_lesson) = match step {
            NewContentStepDto::Kana { detail } => (&detail.cell.id, &detail.lesson_id),
            NewContentStepDto::Vocab { detail, .. } => {
                (&detail.summary.id, &detail.summary.lesson_id)
            }
            NewContentStepDto::Grammar { detail, .. } => {
                (&detail.summary.id, &detail.summary.lesson_id)
            }
            NewContentStepDto::Rule { card } => (&card.id, &card.lesson_id),
            _ => return,
        };
        self.new_items.push(NewItem {
            task_lesson: lesson.to_owned(),
            item_id: item_id.clone(),
            item_lesson: item_lesson.clone(),
        });
    }

    fn walk_new_content(&mut self, session: &NewContentSessionDto) {
        for step in &session.steps {
            self.record_step(&session.lesson_id, step);
            match step {
                NewContentStepDto::KanaQuiz { questions } => self.kana_quiz(questions),
                NewContentStepDto::Vocab {
                    first_card: Some(card),
                    ..
                }
                | NewContentStepDto::Grammar {
                    first_card: Some(card),
                    ..
                } => self.answer_card(Source::NewContent, card),
                _ => {}
            }
        }
    }

    fn kana_quiz(&mut self, questions: &[QuestionDto]) {
        for question in questions {
            self.questions
                .push(SeenQuestion::of(Source::KanaQuiz, question));
            let payload = self.policy.respond(question);
            let result = self
                .core
                .kana_submit(question.reference.clone(), payload, ANSWER_MS);
            self.ok("kana_submit", result);
        }
    }

    fn checkpoint(&mut self, milestone_id: &str) {
        let started = self
            .core
            .checkpoint_start(milestone_id.to_owned(), self.seed, self.audio);
        let Some(questions) = self.ok(&format!("checkpoint_start {milestone_id}"), started) else {
            return;
        };
        let answers: Vec<AnswerDto> = questions
            .iter()
            .map(|question| {
                self.questions
                    .push(SeenQuestion::of(Source::Checkpoint, question));
                AnswerDto {
                    reference: question.reference.clone(),
                    expected_reps: 0,
                    response: self.policy.respond(question),
                    hint_used: false,
                    attempts: 1,
                    duration_ms: ANSWER_MS,
                }
            })
            .collect();
        let finished = self
            .core
            .checkpoint_finish(milestone_id.to_owned(), answers);
        self.ok(&format!("checkpoint_finish {milestone_id}"), finished);
    }
}

impl DayRun<'_> {
    fn new_content(&mut self, key: &str) {
        let session = self
            .core
            .new_content_session(key.to_owned(), self.seed, self.audio);
        if let Some(session) = self.ok(&format!("new_content_session {key}"), session) {
            self.walk_new_content(&session);
        }
    }

    fn drill(&mut self, key: &str) {
        let filter = DrillFilterDto {
            task_key: Some(key.to_owned()),
            ..DrillFilterDto::default()
        };
        let questions = self.core.drill_session(filter, self.seed, self.audio);
        if let Some(questions) = self.ok("drill_session", questions) {
            self.grade_drills(Source::Drill, questions);
        }
    }

    fn listen(&mut self, key: &str) {
        let questions = self
            .core
            .listen_session(key.to_owned(), self.seed, self.audio);
        if let Some(questions) = self.ok("listen_session", questions) {
            self.grade_drills(Source::Listen, questions);
        }
    }

    /// 打開統整任務的對話頁面：學習者會讀說明，頁面本身也不該出錯。
    fn read_pages(&mut self, task: &TaskDto) {
        if let TaskDto::Integration {
            dialogue_id: Some(id),
            ..
        } = task
        {
            let detail = self.core.dialogue_detail(id.clone());
            self.ok(&format!("dialogue_detail {id}"), detail);
        }
    }

    fn run_task(&mut self, task: &TaskDto) {
        match task {
            TaskDto::Review { .. } => self.drain_queue(),
            TaskDto::NewContent { key, .. } => self.new_content(key),
            TaskDto::Drill { key, .. } => self.drill(key),
            TaskDto::Listen { key, .. } => self.listen(key),
            TaskDto::Checkpoint { milestone_id, .. } => self.checkpoint(milestone_id),
            TaskDto::Integration { .. } => self.read_pages(task),
        }
        let key = task_key(task).to_owned();
        let completed = self.core.complete_task(key.clone(), TASK_MS, self.audio);
        self.ok(&format!("complete_task {key}"), completed);
    }
}

impl Learner {
    pub fn start(content: ContentStore, input: &PlanInputDto, policy: AnswerPolicy) -> Self {
        let app = TestApp::with_content(content);
        let created = app.core.create_plan(input.clone()).expect("create_plan");
        Self {
            app,
            created,
            policy,
            audio: Cell::new(true),
        }
    }

    pub fn set_audio(&self, available: bool) {
        self.audio.set(available);
    }

    pub fn next_day(&mut self) {
        self.app.next_day();
    }

    pub fn cursor(&self) -> Option<String> {
        self.app
            .core
            .course_overview()
            .expect("course_overview")
            .current_lesson_id
    }

    /// 打開 App、做完今日清單、收尾到 `Done`。
    pub fn study_day(&self, seed: u32) -> DayLog {
        let core = &self.app.core;
        let audio = self.audio.get();
        let cursor_before = self.cursor();
        let first_view = core.today_view(audio).expect("today_view");
        let mut run = DayRun {
            core,
            policy: &self.policy,
            seed,
            audio,
            questions: Vec::new(),
            new_items: Vec::new(),
            errors: Vec::new(),
        };
        for task in &first_view.tasks {
            if !task_done(task) || matches!(task, TaskDto::Review { .. }) {
                run.run_task(task);
            }
        }
        run.drain_queue();
        let summary = core.session_summary(audio);
        let due_left = run
            .ok("session_summary", summary)
            .map_or(0, |s| s.due_reviews);
        DayLog {
            date: parse_date(&first_view.logical_date),
            first_view,
            cursor_before,
            cursor_after: self.cursor(),
            questions: run.questions,
            new_items: run.new_items,
            due_left,
            errors: run.errors,
        }
    }
}

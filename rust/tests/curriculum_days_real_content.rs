//! curriculum §11.4：真實 `p0a` 內容的主線天數、整合日的主對話、每種題型的判定。

mod common;

use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use chrono::NaiveDate;
use common::{correct_payload, plan_input, start_time, study_full_day, TestApp, UTC_PLUS_8};
use jp_content::disk::{borrow_files, read_content_dir};
use jp_content::schema::ContentStage;
use jp_content::{load_content, ContentStore};
use jp_core::api::core::{AppCore, CoreConfig};
use jp_core::api::dto_content::{CourseOverviewDto, ReadingMode};
use jp_core::api::dto_plan::{PlanInputDto, StartLevel, TaskDto};
use jp_core::api::dto_study::{AnswerPayload, DrillFilterDto, QuestionBodyDto, QuestionDto};
use jp_core::api::tools_api::romanize_reading;
use tempfile::TempDir;

/// §11.4 文件的 p0a 主線天數，每天都學，零基礎起步。
const DOCUMENTED_DAYS: [(u32, i64); 4] = [(10, 145), (20, 91), (30, 66), (45, 53)];
/// 內容微調時實測會小幅浮動，超出這個差距就要更新 §11.4。
const DAYS_TOLERANCE: i64 = 5;
/// 真實內容下的基準，內容或排程變動時要重新確認並更新 §11.4。
const ACTUAL_DAYS: [(u32, i64); 4] = [(10, 145), (20, 91), (30, 66), (45, 53)];
const MAX_STUDY_DAYS: usize = 200;
const DAYS_AFTER_FINISH: usize = 3;

fn real_content() -> ContentStore {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("content");
    let files = read_content_dir(&root).expect("rust/content 應可讀取");
    load_content(&borrow_files(&files), ContentStage::P0a).expect("真實內容應可載入")
}

fn open_core(content: &ContentStore, dir: &TempDir) -> AppCore {
    AppCore::open_with_content(
        CoreConfig {
            db_path: dir.path().join("jp_core.db").to_string_lossy().into_owned(),
            utc_offset_minutes: UTC_PLUS_8,
            fixed_now_utc: Some(start_time()),
        },
        content.clone(),
    )
    .unwrap()
}

fn main_line_days(core: &AppCore, input: PlanInputDto) -> i64 {
    let view = core.plan_preview(input).unwrap();
    let end = view.main_forecast_end.expect("p0a 主線應有完成日");
    let end = NaiveDate::parse_from_str(&end, "%Y-%m-%d").unwrap();
    (end - start_time().date_naive()).num_days() + 1
}

#[test]
fn forecast_stays_close_to_the_documented_p0a_days() {
    let content = real_content();
    for (minutes, documented) in DOCUMENTED_DAYS {
        let dir = TempDir::new().unwrap();
        let core = open_core(&content, &dir);

        let days = main_line_days(&core, plan_input(minutes, StartLevel::Zero));

        assert!(
            (days - documented).abs() <= DAYS_TOLERANCE,
            "{minutes} 分：§11.4 約 {documented} 天，實際 {days} 天"
        );
    }
}

/// 把文件的「約」釘成確切值，內容或排程一改就會被發現。
#[test]
fn forecast_matches_the_measured_baseline() {
    let content = real_content();
    for (minutes, expected) in ACTUAL_DAYS {
        let dir = TempDir::new().unwrap();
        let core = open_core(&content, &dir);

        assert_eq!(
            main_line_days(&core, plan_input(minutes, StartLevel::Zero)),
            expected,
            "{minutes} 分鐘方案"
        );
    }
}

fn lesson_dialogues(overview: &CourseOverviewDto) -> BTreeMap<String, String> {
    overview
        .lessons
        .iter()
        .filter(|lesson| lesson.id.starts_with("le.l"))
        .filter_map(|lesson| Some((lesson.id.clone(), lesson.dialogue_id.clone()?)))
        .collect()
}

/// `lesson.dialogue` 回填後，每課的整合日要排進該課主對話（curriculum §10.1）。
#[test]
fn integration_days_schedule_each_lessons_main_dialogue() {
    let mut app = TestApp::with_content(real_content());
    let expected = lesson_dialogues(&app.core.course_overview().unwrap());
    assert_eq!(expected.len(), 7, "p0a 應有 L01–L07 的主對話");
    app.start_plan(&plan_input(45, StartLevel::Hiragana));

    let mut scheduled = BTreeMap::new();
    for _ in 0..MAX_STUDY_DAYS {
        let today = study_full_day(&app, true);
        for task in &today.tasks {
            if let TaskDto::Integration {
                lesson_id,
                dialogue_id,
                phases,
                ..
            } = task
            {
                assert_eq!(
                    phases,
                    &vec![1, 2, 3, 4],
                    "{lesson_id} 45 分方案一天跑完四段"
                );
                scheduled.insert(
                    lesson_id.clone(),
                    dialogue_id.clone().expect("整合日應排主對話"),
                );
            }
        }
        if scheduled.len() == expected.len() {
            break;
        }
        app.next_day();
    }

    assert_eq!(scheduled, expected);
}

fn body_name(question: &QuestionDto) -> &'static str {
    match question.body {
        QuestionBodyDto::Choice { .. } => "choice",
        QuestionBodyDto::Reorder { .. } => "reorder",
        QuestionBodyDto::Typing { .. } => "typing",
        QuestionBodyDto::Match { .. } => "match",
        QuestionBodyDto::SelfGrade { .. } => "self_grade",
        QuestionBodyDto::Shadow { .. } => "shadow",
    }
}

fn assert_judged_correct(core: &AppCore, question: &QuestionDto) {
    let result = core
        .grade_drill(question.reference.clone(), correct_payload(question))
        .unwrap();
    assert!(
        result.is_correct,
        "{}（{:?}）正解被判錯，correct_display = {}",
        question.reference.content_id, question.question_type, result.correct_display
    );
}

/// 使用者在 UI 打的是羅馬字；Dart 用 `romanize_reading` 產生提示，同樣的字串要能判對。
fn assert_romaji_typing_accepted(core: &AppCore, question: &QuestionDto) {
    let QuestionBodyDto::Typing {
        expected_reading, ..
    } = &question.body
    else {
        return;
    };
    let input = romanize_reading(expected_reading.clone(), ReadingMode::Word)
        .unwrap_or_else(|| panic!("{expected_reading} 應可轉羅馬字"));
    let result = core
        .grade_drill(
            question.reference.clone(),
            AnswerPayload::Typing {
                input: input.clone(),
            },
        )
        .unwrap();
    assert!(
        result.is_correct,
        "{}：打羅馬字 {input} 被判錯（標準答案 {expected_reading}）",
        question.reference.content_id
    );
}

fn assert_wrong_choice_rejected(core: &AppCore, question: &QuestionDto) {
    let QuestionBodyDto::Choice {
        options,
        correct_option_id,
        ..
    } = &question.body
    else {
        return;
    };
    let wrong = options
        .iter()
        .find(|option| option.id != *correct_option_id)
        .expect("選擇題至少兩個選項");
    let result = core
        .grade_drill(
            question.reference.clone(),
            AnswerPayload::Choice {
                option_id: wrong.id.clone(),
            },
        )
        .unwrap();
    assert!(
        !result.is_correct,
        "{} 錯誤選項被判對",
        question.reference.content_id
    );
}

/// `drill_ids` 不看學習進度，所以能涵蓋 p0a 每一題演練（§8.4）。
fn all_drill_ids(content: &ContentStore) -> Vec<String> {
    content
        .drills()
        .iter()
        .map(|drill| drill.id().to_owned())
        .collect()
}

/// 每一題演練都要判得對，且選擇題的錯誤選項判錯；題型涵蓋 p0a 應有的種類。
#[test]
fn every_real_drill_question_is_answerable_and_judged_right() {
    let content = real_content();
    let drill_ids = all_drill_ids(&content);
    let app = TestApp::with_content(content);
    app.start_plan(&plan_input(20, StartLevel::Zero));
    let mut seen: BTreeSet<(String, &'static str)> = BTreeSet::new();

    for audio in [true, false] {
        let filter = DrillFilterDto {
            drill_ids: drill_ids.clone(),
            ..DrillFilterDto::default()
        };
        for question in app.core.drill_session(filter, common::SEED, audio).unwrap() {
            seen.insert((
                format!("{:?}", question.question_type),
                body_name(&question),
            ));
            assert_judged_correct(&app.core, &question);
            assert_wrong_choice_rejected(&app.core, &question);
            assert_romaji_typing_accepted(&app.core, &question);
        }
    }

    println!("真實演練題型：{seen:?}");
    for required in [
        ("ZhToJaChoice", "choice"),
        ("ListenMeaning", "choice"),
        ("ParticleFill", "choice"),
        ("SituationResponse", "choice"),
        ("Reorder", "reorder"),
        ("Substitution", "choice"),
        ("Shadowing", "shadow"),
        ("Conjugate", "typing"),
        ("KanaWord", "typing"),
        ("MinimalPair", "choice"),
    ] {
        let key = (required.0.to_owned(), required.1);
        assert!(seen.contains(&key), "p0a 少了 {key:?}");
    }
}

/// 主線跑到完（含片假名、L02–L07、三個里程碑），每天都做完今日任務：
/// 內容或排程在後面才出錯的狀況，FakeBackend 測不到。
#[test]
fn every_day_plan_reaches_the_end_of_the_main_line() {
    let mut app = TestApp::with_content(real_content());
    app.start_plan(&plan_input(45, StartLevel::Zero));

    let mut milestones_seen = BTreeSet::new();
    let mut finished_on = None;
    for day in 1..=MAX_STUDY_DAYS {
        let today = study_full_day(&app, true);
        for task in &today.tasks {
            if let TaskDto::Checkpoint { milestone_id, .. } = task {
                milestones_seen.insert(milestone_id.clone());
            }
        }
        if finished_on.is_none() && app.core.plan_view().unwrap().current_lesson_id.is_none() {
            finished_on = Some(day);
        }
        // 最後一課完成後，檢定要在之後的學習日排出來
        if finished_on.is_some_and(|end| day > end + DAYS_AFTER_FINISH) {
            break;
        }
        app.next_day();
    }

    assert_eq!(finished_on, Some(53), "45 分方案的實際完成日");
    assert_eq!(
        milestones_seen,
        BTreeSet::from([
            "ms.hira".to_owned(),
            "ms.kata".to_owned(),
            "ms.survive".to_owned(),
        ]),
        "三個里程碑都要排到"
    );
}

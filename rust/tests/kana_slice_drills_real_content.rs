//! curriculum §1 的 S0 目標：K11–K15 的清濁、半濁、拗音最小對立照計畫走也要練得到（真實 `p0a`）。

mod common;

use std::collections::{BTreeMap, HashSet};
use std::path::Path;

use common::*;
use jp_content::disk::{borrow_files, read_content_dir};
use jp_content::schema::{ContentStage, DrillDef};
use jp_content::{load_content, ContentStore};
use jp_core::api::dto_content::LessonStatus;
use jp_core::api::dto_plan::{PlanInputDto, StartLevel};
use jp_core::api::dto_study::{NewContentSessionDto, NewContentStepDto, QuestionDto, QuestionType};

const LESSONS: [&str; 5] = ["le.k11", "le.k12", "le.k13", "le.k14", "le.k15"];
const PRESETS: [u32; 4] = [10, 20, 30, 45];
const MAX_DAYS: usize = 60;
const MIN_PAIRS_PER_SLICE: usize = 2;
const MAX_PAIRS_PER_SLICE: usize = 3;

fn real_content() -> ContentStore {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("content");
    let files = read_content_dir(&root).expect("rust/content 應可讀取");
    load_content(&borrow_files(&files), ContentStage::P0a).expect("真實內容應可載入")
}

fn app_at_k11(minutes: u32) -> TestApp {
    let app = TestApp::with_content(real_content());
    let known = app
        .content
        .course()
        .order
        .iter()
        .take_while(|id| id.as_str() != "le.k11")
        .filter(|id| id.starts_with("le.k"))
        .cloned()
        .collect();
    app.start_plan(&PlanInputDto {
        known_kana_lessons: known,
        ..plan_input(minutes, StartLevel::Zero)
    });
    app
}

fn drill_questions(session: &NewContentSessionDto) -> Vec<&QuestionDto> {
    session
        .steps
        .iter()
        .filter_map(|step| match step {
            NewContentStepDto::KanaQuiz { questions } => Some(questions),
            _ => None,
        })
        .flatten()
        .filter(|question| question.reference.drill_id.is_some())
        .collect()
}

fn lesson_of_drill<'c>(content: &'c ContentStore, question: &QuestionDto) -> &'c str {
    let id = question.reference.drill_id.as_deref().unwrap();
    content.drill_by_id(id).unwrap().lesson()
}

fn taught_kana_of(content: &ContentStore, session: &NewContentSessionDto) -> Vec<String> {
    session
        .steps
        .iter()
        .filter_map(|step| match step {
            NewContentStepDto::Kana { detail } => Some(detail.cell.id.clone()),
            _ => None,
        })
        .filter(|id| content.kana_by_id(id).is_some())
        .collect()
}

/// 一個切片裡，某一課出現的手寫題。
#[derive(Debug, Default, Clone)]
struct SliceLessonDrills {
    pairs: Vec<String>,
    kana_words: Vec<String>,
    /// 到這個切片為止，該課目標字都已教的 `minimal_pair` 數。
    playable: usize,
}

#[derive(Debug, Default)]
struct Walk {
    /// 課 → 依序每個碰到該課的切片。
    by_lesson: BTreeMap<String, Vec<SliceLessonDrills>>,
    /// 到目前為止教過的字。
    taught: HashSet<String>,
}

/// 照計畫一天一天走到 K15 完成，記錄每天切片接的手寫題。
fn walk_k11_to_k15(minutes: u32, audio: bool) -> Walk {
    let mut app = app_at_k11(minutes);
    let mut walk = Walk {
        taught: kana_before_k11(&app.content),
        ..Walk::default()
    };
    for _ in 0..MAX_DAYS {
        let today = app.core.today_view(audio).unwrap();
        let key = new_content_key(&today).expect("還沒走完 K15，每天都要有 NewContent");
        let session = app.core.new_content_session(key, SEED, audio).unwrap();
        record_slice(&app, &session, &mut walk);
        assert_answers_grade_correct(&app, &session);
        study_full_day(&app, audio);
        if lesson_done(&app, "le.k15") {
            return walk;
        }
        app.next_day();
    }
    panic!("{minutes} 分方案 {MAX_DAYS} 天內沒有走完 K15");
}

fn kana_before_k11(content: &ContentStore) -> HashSet<String> {
    content
        .course()
        .order
        .iter()
        .take_while(|id| id.as_str() != "le.k11")
        .filter_map(|lesson| content.lesson_items(lesson))
        .flat_map(|items| &items.kana)
        .map(|&index| content.kana()[index as usize].def.id.clone())
        .collect()
}

fn lesson_pairs<'c>(content: &'c ContentStore, lesson: &str) -> Vec<&'c DrillDef> {
    content
        .lesson_items(lesson)
        .into_iter()
        .flat_map(|items| &items.drills)
        .map(|&index| &content.drills()[index as usize])
        .filter(|drill| matches!(drill, DrillDef::MinimalPair { .. }))
        .collect()
}

fn lesson_done(app: &TestApp, lesson: &str) -> bool {
    app.core
        .lesson_detail(lesson.to_owned())
        .unwrap()
        .summary
        .status
        == LessonStatus::Done
}

fn record_slice(app: &TestApp, session: &NewContentSessionDto, walk: &mut Walk) {
    let content = &app.content;
    let taught = taught_kana_of(content, session);
    walk.taught.extend(taught.iter().cloned());
    let lessons: Vec<&str> = taught
        .iter()
        .map(|id| content.kana_by_id(id).unwrap().def.lesson.as_str())
        .filter(|lesson| LESSONS.contains(lesson))
        .collect::<std::collections::BTreeSet<_>>()
        .into_iter()
        .collect();
    let questions = drill_questions(session);
    for lesson in &lessons {
        let of_lesson: Vec<&&QuestionDto> = questions
            .iter()
            .filter(|q| lesson_of_drill(content, q) == *lesson)
            .collect();
        let ids_of = |kind: QuestionType| -> Vec<String> {
            of_lesson
                .iter()
                .filter(|q| q.question_type == kind)
                .map(|q| q.reference.drill_id.clone().unwrap())
                .collect()
        };
        walk.by_lesson
            .entry((*lesson).to_owned())
            .or_default()
            .push(SliceLessonDrills {
                pairs: ids_of(QuestionType::MinimalPair),
                kana_words: ids_of(QuestionType::KanaWord),
                playable: lesson_pairs(content, lesson)
                    .iter()
                    .filter(|d| d.targets().iter().all(|t| walk.taught.contains(t)))
                    .count(),
            });
    }
    for question in &questions {
        assert!(
            lessons.contains(&lesson_of_drill(content, question)),
            "切片只接本切片教到的課：{:?}",
            question.reference
        );
    }
}

fn assert_answers_grade_correct(app: &TestApp, session: &NewContentSessionDto) {
    for question in drill_questions(session) {
        let graded = app
            .core
            .kana_submit(question.reference.clone(), correct_payload(question), 2_000)
            .unwrap();
        assert!(graded.is_correct, "{:?}", question.reference);
        assert!(graded.mastery.is_none(), "手寫題不計熟練");
    }
}

fn walks() -> Vec<(u32, Walk)> {
    PRESETS
        .iter()
        .map(|&minutes| (minutes, walk_k11_to_k15(minutes, true)))
        .collect()
}

#[test]
fn every_lesson_k11_to_k15_really_serves_minimal_pairs_on_every_preset() {
    for (minutes, walk) in walks() {
        for lesson in LESSONS {
            let slices = walk.by_lesson.get(lesson).expect(lesson);
            let pairs = slices.iter().map(|s| s.pairs.len()).sum::<usize>();
            assert!(pairs > 0, "{minutes} 分 {lesson} 沒有 minimal_pair");
            for slice in slices {
                let count = slice.pairs.len();
                let floor = MIN_PAIRS_PER_SLICE.min(slice.playable);
                assert!(
                    (floor..=MAX_PAIRS_PER_SLICE).contains(&count),
                    "{minutes} 分 {lesson}：{slices:?}"
                );
            }
        }
    }
}

#[test]
fn kana_word_appears_exactly_once_on_the_last_slice_of_each_lesson() {
    for (minutes, walk) in walks() {
        for lesson in LESSONS {
            let slices = walk.by_lesson.get(lesson).expect(lesson);
            let (last, earlier) = slices.split_last().unwrap();
            assert_eq!(
                last.kana_words.len(),
                1,
                "{minutes} 分 {lesson}：{slices:?}"
            );
            assert!(
                earlier.iter().all(|s| s.kana_words.is_empty()),
                "{minutes} 分 {lesson}：{slices:?}"
            );
        }
    }
}

#[test]
fn pairs_repeat_only_when_the_lesson_runs_out_of_new_ones() {
    let content = real_content();
    let pairs_in = |lesson: &str| {
        content
            .drills()
            .iter()
            .filter(|d| d.lesson() == lesson && matches!(d, DrillDef::MinimalPair { .. }))
            .count()
    };
    for (minutes, walk) in walks() {
        for lesson in LESSONS {
            let shown: Vec<&String> = walk
                .by_lesson
                .get(lesson)
                .expect(lesson)
                .iter()
                .flat_map(|s| &s.pairs)
                .collect();
            let unique: HashSet<&&String> = shown.iter().collect();
            let unavoidable = shown.len().saturating_sub(pairs_in(lesson));
            assert!(
                shown.len() - unique.len() <= unavoidable,
                "{minutes} 分 {lesson} 不該重複：{shown:?}"
            );
        }
    }
}

#[test]
fn silent_mode_serves_no_minimal_pair_but_keeps_the_typing_kana_word() {
    for minutes in PRESETS {
        let walk = walk_k11_to_k15(minutes, false);
        for lesson in LESSONS {
            let slices = walk.by_lesson.get(lesson).expect(lesson);
            assert!(
                slices.iter().all(|s| s.pairs.is_empty()),
                "{minutes} 分 {lesson}：{slices:?}"
            );
            assert_eq!(slices.last().unwrap().kana_words.len(), 1);
        }
    }
}

#[test]
fn the_drill_step_comes_after_all_kana_steps_and_is_stable_across_seeds() {
    let app = app_at_k11(20);
    let key = new_content_key(&app.today()).unwrap();

    let session = app.core.new_content_session(key.clone(), 7, true).unwrap();
    let again = app.core.new_content_session(key, 8_000, true).unwrap();

    let drills_only =
        |questions: &[QuestionDto]| questions.iter().all(|q| q.reference.drill_id.is_some());
    let last = session.steps.last().unwrap();
    let NewContentStepDto::KanaQuiz { questions } = last else {
        panic!("最後一步應為手寫題的 KanaQuiz：{last:?}");
    };
    assert!(drills_only(questions), "{questions:?}");
    let ids = |s: &NewContentSessionDto| -> Vec<String> {
        drill_questions(s)
            .iter()
            .map(|q| q.reference.drill_id.clone().unwrap())
            .collect()
    };
    assert_eq!(ids(&session), ids(&again));
}

/// 切片作答與 K1 自由練習多出來的題都計入當天的題數：自由練習不推進計畫（C06），
/// 但作答的日子算活躍日（RULINGS O12）。
#[test]
fn slice_drill_answers_and_free_practice_extras_both_count_toward_the_day() {
    let app = app_at_k11(20);
    let key = new_content_key(&app.today()).unwrap();
    let session = app.core.new_content_session(key, SEED, true).unwrap();
    let drills = drill_questions(&session);
    assert!(!drills.is_empty());

    for question in &drills {
        app.core
            .kana_submit(question.reference.clone(), correct_payload(question), 2_000)
            .unwrap();
    }
    let counted = answers_today(&app);

    let extra = app
        .core
        .kana_session("le.k11".to_owned(), SEED, true)
        .unwrap()
        .into_iter()
        .find(|q| {
            q.question_type == QuestionType::MinimalPair
                && !drills
                    .iter()
                    .any(|d| d.reference.drill_id == q.reference.drill_id)
        })
        .expect("K1 自由練習還有切片沒選到的 minimal_pair");
    app.core
        .kana_submit(extra.reference.clone(), correct_payload(&extra), 2_000)
        .unwrap();
    let after = answers_today(&app);

    assert_eq!(counted, drills.len() as u32);
    assert_eq!(
        after,
        counted + 1,
        "切片沒選到的題是自由練習，也是當天的作答"
    );
}

fn answers_today(app: &TestApp) -> u32 {
    let day = app.today().logical_date;
    app.core
        .activity_range(day.clone(), day)
        .unwrap()
        .into_iter()
        .next()
        .map_or(0, |activity| activity.answers)
}

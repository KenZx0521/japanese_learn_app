//! rust-core §7.3、curriculum §11.4：真實 `p0` 的 L01–L30 在四種分鐘方案下都切得成天。
//! 每片走 AppCore 的 `today_view`／`learn_more`／`new_content_session`／`complete_task`，
//! 驗證每個 `vo.*`、`gr.*` 恰好介紹一次且依 `lesson_order`、沒有空天、沒有超過額度的天、
//! 文法先多後少、整合日的天數與階段、對話輪替的整個序列，以及 `plan_preview` 的主線天數等於實走片數。

mod common;

use std::collections::{BTreeMap, BTreeSet};

use chrono::NaiveDate;
use common::real::{main_lessons, p0_content, walk_slices, SliceRecord};
use common::{plan_input, start_time, TestApp};
use jp_content::schema::DialogueKind;
use jp_core::api::dto_content::LessonStatus;
use jp_core::api::dto_plan::{PlanInputDto, StartLevel};

const TEN_MINUTE_PLAN: u32 = 10;
/// §7.3：10 分方案整合 2 天，其他 1 天；10 分的兩天分成 [1,2]、[3,4]。
const TEN_MINUTE_PHASES: [&[u32]; 2] = [&[1, 2], &[3, 4]];
const NORMAL_PHASES: [&[u32]; 1] = [&[1, 2, 3, 4]];
/// §7.3 對話輪替：已完成的 L 課數為 3 的倍數時輪替。
const ROTATE_EVERY_LESSONS: usize = 3;

/// 每課應有的單字與文法，依 `lesson_order`（`lesson_detail` 的順序）。
struct LessonPlan {
    id: String,
    words: Vec<String>,
    grammar: Vec<String>,
    main_dialogue: String,
}

struct Walked {
    app: TestApp,
    minutes: u32,
    words_limit: usize,
    lessons: Vec<LessonPlan>,
    slices: Vec<SliceRecord>,
    /// 開始前 `plan_preview` 的主線完成日，換算成第幾天。
    forecast_days: i64,
}

/// `start_time()` 當天為第 1 天。
fn main_forecast_days(app: &TestApp, input: &PlanInputDto) -> i64 {
    let view = app.core.plan_preview(input.clone()).unwrap();
    let end = view.main_forecast_end.expect("p0 主線應有完成日");
    let end = NaiveDate::parse_from_str(&end, "%Y-%m-%d").unwrap();
    (end - start_time().date_naive()).num_days() + 1
}

fn lesson_plan(app: &TestApp, id: String) -> LessonPlan {
    let detail = app.core.lesson_detail(id.clone()).unwrap();
    let main_dialogue = detail
        .summary
        .dialogue_id
        .unwrap_or_else(|| panic!("{id} 應有主對話"));
    LessonPlan {
        id,
        words: detail.words.into_iter().map(|w| w.id).collect(),
        grammar: detail.grammar.into_iter().map(|g| g.id).collect(),
        main_dialogue,
    }
}

/// 全部 K、KK 課以 `start_level = kana` 略過，游標從 L01 開始。
fn walk(minutes: u32) -> Walked {
    let app = TestApp::with_content(p0_content());
    let input = plan_input(minutes, StartLevel::Kana);
    let forecast_days = main_forecast_days(&app, &input);
    app.start_plan(&input);
    let words_limit = app.today().budget.new_words_limit as usize;
    let slices = walk_slices(&app.core, |_| false);
    let lessons = main_lessons(&app.content)
        .into_iter()
        .map(|id| lesson_plan(&app, id))
        .collect();
    println!(
        "{minutes} 分：L01–L30 共 {} 片；plan_preview 主線 {forecast_days} 天",
        slices.len()
    );
    Walked {
        app,
        minutes,
        words_limit,
        lessons,
        slices,
        forecast_days,
    }
}

fn slices_of<'w>(walked: &'w Walked, lesson: &str) -> Vec<&'w SliceRecord> {
    walked
        .slices
        .iter()
        .filter(|slice| slice.lesson_id() == lesson)
        .collect()
}

fn vocab_parts(slices: &[&SliceRecord]) -> Vec<(Vec<String>, Vec<String>)> {
    slices
        .iter()
        .filter_map(|slice| match slice {
            SliceRecord::Vocab { words, grammar, .. } => Some((words.clone(), grammar.clone())),
            SliceRecord::Integration { .. } => None,
        })
        .collect()
}

/// 切片的課依 `course.order` 前進，同一課先單字後整合，不會回頭。
fn assert_follows_course_order(walked: &Walked) {
    let order: BTreeMap<&str, usize> = walked
        .lessons
        .iter()
        .enumerate()
        .map(|(pos, lesson)| (lesson.id.as_str(), pos))
        .collect();
    let keys: Vec<(usize, u32)> = walked
        .slices
        .iter()
        .map(|slice| {
            let pos = *order
                .get(slice.lesson_id())
                .unwrap_or_else(|| panic!("切片落在 L01–L30 以外：{slice:?}"));
            let stage = match slice {
                SliceRecord::Vocab { .. } => 0,
                SliceRecord::Integration { day_no, .. } => *day_no,
            };
            (pos, stage)
        })
        .collect();
    assert!(
        keys.windows(2).all(|pair| pair[0] <= pair[1]),
        "{} 分：切片順序 {keys:?}",
        walked.minutes
    );
}

/// 每課的單字與文法依 `lesson_order` 各介紹一次；沒有空天，單字不超過額度。
fn assert_items_introduced_once_within_quota(walked: &Walked) {
    for lesson in &walked.lessons {
        let parts = vocab_parts(&slices_of(walked, &lesson.id));
        let words: Vec<String> = parts.iter().flat_map(|(w, _)| w.clone()).collect();
        let grammar: Vec<String> = parts.iter().flat_map(|(_, g)| g.clone()).collect();
        let tag = format!("{} 分 {}", walked.minutes, lesson.id);

        assert_eq!(words, lesson.words, "{tag}：單字");
        assert_eq!(grammar, lesson.grammar, "{tag}：文法");
        for (words, grammar) in &parts {
            assert!(!words.is_empty() || !grammar.is_empty(), "{tag}：空天");
            assert!(words.len() <= walked.words_limit, "{tag}：{words:?}");
        }
    }
}

/// §11.4：每課單字切片 `ceil(字數 ÷ new_words_per_day)`；文法平均分配、先多後少（§7.3）。
fn assert_slice_count_and_grammar_spread(walked: &Walked) {
    for lesson in &walked.lessons {
        let parts = vocab_parts(&slices_of(walked, &lesson.id));
        let tag = format!("{} 分 {}", walked.minutes, lesson.id);
        let expected = match (lesson.words.len(), lesson.grammar.len()) {
            (0, 0) => 0,
            (words, _) => words.div_ceil(walked.words_limit).max(1),
        };
        assert_eq!(parts.len(), expected, "{tag}：單字切片數");

        let spread: Vec<usize> = parts.iter().map(|(_, g)| g.len()).collect();
        let (most, least) = (spread.iter().max(), spread.iter().min());
        assert!(
            spread.windows(2).all(|pair| pair[0] >= pair[1]),
            "{tag}：文法 {spread:?} 應先多後少"
        );
        assert!(
            most.zip(least)
                .is_none_or(|(most, least)| most - least <= 1),
            "{tag}：文法 {spread:?} 應平均分配"
        );
    }
}

fn expected_phases(minutes: u32) -> Vec<Vec<u32>> {
    let phases: &[&[u32]] = if minutes == TEN_MINUTE_PLAN {
        &TEN_MINUTE_PHASES
    } else {
        &NORMAL_PHASES
    };
    phases.iter().map(|p| p.to_vec()).collect()
}

/// 一個整合日：(day_no, phases, dialogue_id)。
type IntegrationDay = (u32, Vec<u32>, Option<String>);

fn integration_days(walked: &Walked, lesson: &str) -> Vec<IntegrationDay> {
    slices_of(walked, lesson)
        .into_iter()
        .filter_map(|slice| match slice {
            SliceRecord::Integration {
                day_no,
                phases,
                dialogue_id,
                ..
            } => Some((*day_no, phases.clone(), dialogue_id.clone())),
            SliceRecord::Vocab { .. } => None,
        })
        .collect()
}

/// 整合天數與階段照 §7.3，課完成；同一課的整合日排同一篇對話。回傳該課排到的對話。
fn assert_lesson_integration(walked: &Walked, lesson: &LessonPlan) -> String {
    let tag = format!("{} 分 {}", walked.minutes, lesson.id);
    let days = integration_days(walked, &lesson.id);
    let detail = walked.app.core.lesson_detail(lesson.id.clone()).unwrap();
    let phases: Vec<Vec<u32>> = days.iter().map(|(_, p, _)| p.clone()).collect();
    let numbers: Vec<u32> = days.iter().map(|(n, _, _)| *n).collect();
    let picked: Vec<&str> = days.iter().filter_map(|(_, _, d)| d.as_deref()).collect();

    assert_eq!(phases, expected_phases(walked.minutes), "{tag}");
    assert_eq!(days.len() as u32, detail.integration_days_needed, "{tag}");
    assert_eq!(
        numbers,
        (1..=days.len() as u32).collect::<Vec<_>>(),
        "{tag}"
    );
    assert_eq!(picked.len(), days.len(), "{tag}：整合日沒有對話");
    assert!(picked.windows(2).all(|p| p[0] == p[1]), "{tag}：{picked:?}");
    assert_eq!(detail.summary.status, LessonStatus::Done, "{tag}");
    picked[0].to_owned()
}

/// 實戰與常體版對話的 `((pos(lesson), 檔案順序), id)`，由小到大。
/// 經載入後的 ContentStore：`dialogues()` 保留 manifest 與檔內陣列的順序，即 §7.3 的「檔案順序」。
fn rotation_candidates(walked: &Walked) -> Vec<((u32, usize), String)> {
    let content = &walked.app.content;
    let mut candidates: Vec<((u32, usize), String)> = content
        .dialogues()
        .iter()
        .map(|entry| &entry.def)
        .enumerate()
        .filter(|(_, d)| !d.retired && matches!(d.kind, DialogueKind::Extra | DialogueKind::Casual))
        .map(|(index, d)| {
            let pos = content.lesson_pos(&d.lesson).unwrap();
            ((pos, index), d.id.clone())
        })
        .collect();
    candidates.sort();
    candidates
}

/// §7.3 對話輪替推算每課的整合對話：輪到時取 `pos(lesson) ≤ pos(本課)`、尚未排過的候選中最小者，
/// 否則為本課主對話。假名起點沒有略過的 L 課，所以本課之前完成的 L 課數就是它的序號；
/// 完成 0 課不輪替（「每完成 3 課」，真實內容最早的候選在 L19，兩種讀法結果相同）。
fn expected_dialogues(walked: &Walked) -> Vec<(String, String)> {
    let content = &walked.app.content;
    let candidates = rotation_candidates(walked);
    let mut used = BTreeSet::new();
    let mut expected = Vec::new();
    for (completed, lesson) in walked.lessons.iter().enumerate() {
        let cursor = content.lesson_pos(&lesson.id).unwrap();
        let rotates = completed > 0 && completed % ROTATE_EVERY_LESSONS == 0;
        let pick = rotates
            .then(|| {
                candidates
                    .iter()
                    .find(|((pos, _), id)| *pos <= cursor && !used.contains(id))
                    .map(|(_, id)| id.clone())
            })
            .flatten();
        used.extend(pick.clone());
        let dialogue = pick.unwrap_or_else(|| lesson.main_dialogue.clone());
        expected.push((lesson.id.clone(), dialogue));
    }
    expected
}

/// 每課整合日排的對話與 §7.3 推算的整個序列相同，且確實輪替到實戰或常體版。
fn assert_integration_days(walked: &Walked) {
    let actual: Vec<(String, String)> = walked
        .lessons
        .iter()
        .map(|lesson| (lesson.id.clone(), assert_lesson_integration(walked, lesson)))
        .collect();
    let expected = expected_dialogues(walked);

    assert_eq!(actual, expected, "{} 分：對話輪替（§7.3）", walked.minutes);
    let rotated: Vec<&(String, String)> = expected
        .iter()
        .zip(&walked.lessons)
        .filter(|((_, dialogue), lesson)| *dialogue != lesson.main_dialogue)
        .map(|(pair, _)| pair)
        .collect();
    println!("{} 分：輪替 {rotated:?}", walked.minutes);
    assert!(
        !rotated.is_empty(),
        "{} 分：應輪替到實戰或常體版",
        walked.minutes
    );
}

/// §7.5：`forecast` 與切片共用 `next_slice`；`walk_slices` 的每一片就是一天，
/// 所以假名起點的主線完成日（第幾天）等於實走片數，不隨內容筆數變動。
fn assert_forecast_matches_walk(walked: &Walked) {
    assert_eq!(
        walked.forecast_days,
        walked.slices.len() as i64,
        "{} 分：plan_preview 的主線天數與 learn_more 實走片數不同",
        walked.minutes
    );
}

fn check_preset(minutes: u32) {
    let walked = walk(minutes);

    assert_follows_course_order(&walked);
    assert_items_introduced_once_within_quota(&walked);
    assert_slice_count_and_grammar_spread(&walked);
    assert_integration_days(&walked);
    assert_forecast_matches_walk(&walked);
    assert_eq!(walked.app.core.plan_view().unwrap().current_lesson_id, None);
}

#[test]
fn ten_minute_plan_slices_l01_to_l30() {
    check_preset(10);
}

#[test]
fn twenty_minute_plan_slices_l01_to_l30() {
    check_preset(20);
}

#[test]
fn thirty_minute_plan_slices_l01_to_l30() {
    check_preset(30);
}

#[test]
fn forty_five_minute_plan_slices_l01_to_l30() {
    check_preset(45);
}

//! 真實 `p0`：L08–L30 的每一題課程演練，經 `drill_session` 出題後都合法可答
//! （rust-core §8.4、§8.6）：選項 id 有效、正解唯一、排列合法、需要語音的題可播放。

mod common;

use std::collections::BTreeSet;

use common::answerable::{assert_answerable, needs_audio};
use common::real::p0_content;
use common::{plan_input, TestApp, SEED};
use jp_content::schema::DrillDef;
use jp_content::ContentStore;
use jp_core::api::dto_plan::StartLevel;
use jp_core::api::dto_study::{ChunkDto, DrillFilterDto, QuestionBodyDto, QuestionDto};

const FIRST_LESSON: &str = "le.l08";
const LAST_LESSON: &str = "le.l30";
/// L08–L30 應出現的題型（`Debug` 名稱）。
const REQUIRED_TYPES: [&str; 10] = [
    "ZhToJaChoice",
    "ListenMeaning",
    "ParticleFill",
    "SituationResponse",
    "Reorder",
    "Substitution",
    "Shadowing",
    "Conjugate",
    "RegisterConvert",
    "FalseFriend",
];

/// L08–L30 的演練（含實戰、常體版、同形異義題）。
fn scanned_drills(content: &ContentStore) -> BTreeSet<String> {
    let pos = |lesson: &str| content.lesson_pos(lesson).unwrap();
    let range = pos(FIRST_LESSON)..=pos(LAST_LESSON);
    content
        .drills()
        .iter()
        .filter(|drill| !drill.retired())
        .filter(|drill| {
            content
                .lesson_pos(drill.lesson())
                .is_some_and(|p| range.contains(&p))
        })
        .map(|drill| drill.id().to_owned())
        .collect()
}

fn app_and_drills() -> (TestApp, BTreeSet<String>) {
    let content = p0_content();
    let drills = scanned_drills(&content);
    let app = TestApp::with_content(content);
    app.start_plan(&plan_input(20, StartLevel::Zero));
    (app, drills)
}

/// `drill_ids` 不看學習進度，一次取出全部。
fn session(app: &TestApp, drill_ids: &BTreeSet<String>, audio: bool) -> Vec<QuestionDto> {
    let filter = DrillFilterDto {
        drill_ids: drill_ids.iter().cloned().collect(),
        ..DrillFilterDto::default()
    };
    app.core.drill_session(filter, SEED, audio).unwrap()
}

fn drill_ids_of(questions: &[QuestionDto]) -> Vec<String> {
    questions
        .iter()
        .map(|q| q.reference.drill_id.clone().expect("手寫演練帶 drill_id"))
        .collect()
}

#[test]
fn every_scanned_drill_is_served_once_and_answerable_with_audio() {
    let (app, drills) = app_and_drills();

    let questions = session(&app, &drills, true);

    let served = drill_ids_of(&questions);
    let unique: BTreeSet<String> = served.iter().cloned().collect();
    assert_eq!(served.len(), unique.len(), "同一題出了兩次");
    assert_eq!(unique, drills, "有演練沒有出題");
    for question in &questions {
        assert_answerable(&app.core, question, true);
    }
    let types: BTreeSet<String> = questions
        .iter()
        .map(|q| format!("{:?}", q.question_type))
        .collect();
    println!("L08–L30：{} 題，題型 {types:?}", questions.len());
    for required in REQUIRED_TYPES {
        assert!(types.contains(required), "少了 {required}");
    }
}

/// 無聲模式只拿掉需要語音的題（§8.6），其餘照出且同樣可答。
#[test]
fn silent_mode_drops_exactly_the_questions_that_need_audio() {
    let (app, drills) = app_and_drills();
    let with_audio = session(&app, &drills, true);
    let silent_ok: BTreeSet<String> = drill_ids_of(&with_audio)
        .into_iter()
        .zip(&with_audio)
        .filter(|(_, question)| !needs_audio(question))
        .map(|(id, _)| id)
        .collect();

    let silent = session(&app, &drills, false);

    let served: BTreeSet<String> = drill_ids_of(&silent).into_iter().collect();
    assert_eq!(served, silent_ok);
    assert!(!served.is_empty());
    for question in &silent {
        assert_answerable(&app.core, question, false);
    }
}

// ---------- `assert_answerable` 本身會擋下的情況（避免斷言空泛） ----------

/// 只出指定題型的演練（不看學習進度）。
fn questions_of(app: &TestApp, pick: impl Fn(&DrillDef) -> bool) -> Vec<QuestionDto> {
    let ids: BTreeSet<String> = app
        .content
        .drills()
        .iter()
        .filter(|drill| !drill.retired() && pick(drill))
        .map(|drill| drill.id().to_owned())
        .collect();
    session(app, &ids, true)
}

fn reorder_parts(question: &QuestionDto) -> (&[ChunkDto], &[Vec<u32>]) {
    match &question.body {
        QuestionBodyDto::Reorder {
            chunks,
            accept_orders,
        } => (chunks, accept_orders),
        other => panic!("應為 Reorder：{other:?}"),
    }
}

/// 把詞塊依 `order` 重排，當成畫面上的初始順序。
fn shown_as(question: &QuestionDto, order: &[u32]) -> QuestionDto {
    let (chunks, accept_orders) = reorder_parts(question);
    let reordered = order
        .iter()
        .map(|index| chunks.iter().find(|c| c.index == *index).unwrap().clone())
        .collect();
    QuestionDto {
        body: QuestionBodyDto::Reorder {
            chunks: reordered,
            accept_orders: accept_orders.to_vec(),
        },
        ..question.clone()
    }
}

fn is_reorder(drill: &DrillDef) -> bool {
    matches!(drill, DrillDef::Reorder { .. })
}

/// 以正解呈現的詞塊題要被擋下。
#[test]
#[should_panic(expected = "初始順序已是正解")]
fn answerable_rejects_a_reorder_shown_in_its_accepted_order() {
    let (app, _) = app_and_drills();
    let question = questions_of(&app, is_reorder)
        .into_iter()
        .find(|q| reorder_parts(q).1.len() == 1)
        .expect("p0 應有只接受一種順序的詞塊題");
    let answer = reorder_parts(&question).1[0].clone();

    assert_answerable(&app.core, &shown_as(&question, &answer), true);
}

/// 正解裡兩個外觀相同的詞塊位置，互換後索引不同、文字相同。
fn twin_swapped(chunks: &[ChunkDto], answer: &[u32]) -> Option<Vec<u32>> {
    let text = |index: u32| {
        chunks
            .iter()
            .find(|c| c.index == index)
            .unwrap()
            .text
            .clone()
    };
    let positions = 0..answer.len();
    positions
        .clone()
        .flat_map(|i| positions.clone().map(move |j| (i, j)))
        .find(|&(i, j)| i < j && text(answer[i]) == text(answer[j]))
        .map(|(i, j)| {
            let mut swapped = answer.to_vec();
            swapped.swap(i, j);
            swapped
        })
}

/// 判定比文字（jp_quiz `order_is_accepted`）：外觀相同的詞塊互換後仍是正解，初始順序也不能是它。
#[test]
#[should_panic(expected = "初始順序已是正解")]
fn answerable_rejects_a_reorder_shown_as_the_answer_with_twin_chunks_swapped() {
    let (app, _) = app_and_drills();
    let (question, swapped) = questions_of(&app, is_reorder)
        .into_iter()
        .find_map(|q| {
            let (chunks, accept_orders) = reorder_parts(&q);
            let swapped = twin_swapped(chunks, &accept_orders[0])?;
            (!accept_orders.contains(&swapped)).then_some((q.clone(), swapped))
        })
        .expect("p0 應有含外觀相同詞塊、且互換後不在 accept_orders 的詞塊題");

    assert_answerable(&app.core, &shown_as(&question, &swapped), true);
}

/// 有 `blank_word_index` 卻沒有句子的選擇題要被擋下，不能靜默略過。
#[test]
#[should_panic(expected = "卻沒有 prompt.text")]
fn answerable_rejects_a_blank_without_a_sentence() {
    let (app, _) = app_and_drills();
    let question = questions_of(&app, |d| matches!(d, DrillDef::ParticleFill { .. }))
        .into_iter()
        .find(|q| {
            matches!(
                q.body,
                QuestionBodyDto::Choice {
                    blank_word_index: Some(_),
                    ..
                }
            )
        })
        .expect("p0 應有帶 blank_word_index 的助詞填空");
    let mut prompt = question.prompt.clone();
    prompt.text = None;

    assert_answerable(&app.core, &QuestionDto { prompt, ..question }, true);
}

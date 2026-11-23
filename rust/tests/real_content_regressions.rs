//! 真實 `p0a` 內容的回歸：排序題的合法語序、助詞題的干擾項、活用表與主題的顯示字串。

mod common;

use std::path::Path;

use common::TestApp;
use jp_content::disk::{borrow_files, read_content_dir};
use jp_content::schema::{ContentStage, DrillDef};
use jp_content::{load_content, ContentStore};
use jp_core::api::dto_study::{AnswerPayload, QuestionRefDto, QuestionType};

fn real_content() -> ContentStore {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("content");
    let files = read_content_dir(&root).expect("rust/content 應可讀取");
    load_content(&borrow_files(&files), ContentStage::P0a).expect("真實內容應可載入")
}

fn real_app() -> TestApp {
    TestApp::with_content(real_content())
}

fn is_accepted(app: &TestApp, drill_id: &str, order: &[u32]) -> bool {
    let reference = QuestionRefDto {
        question_type: QuestionType::Reorder,
        card_id: None,
        drill_id: Some(drill_id.to_owned()),
        content_id: drill_id.to_owned(),
        variant: None,
    };
    let response = AnswerPayload::Reorder {
        order: order.to_vec(),
    };
    app.core
        .grade_drill(reference, response)
        .unwrap()
        .is_correct
}

/// 兩個「ですか」外觀相同，排出相同的文字就要算對，不看拿的是哪一塊。
#[test]
fn identical_chunks_are_interchangeable_when_grading() {
    let app = real_app();

    assert!(is_accepted(&app, "dr.l02.ord.005", &[0, 1, 2, 3, 4]));
    assert!(is_accepted(&app, "dr.l02.ord.005", &[0, 1, 4, 3, 2]));
    assert!(!is_accepted(&app, "dr.l02.ord.005", &[1, 0, 2, 3, 4]));
}

#[test]
fn swapped_alternatives_of_a_choice_question_are_accepted() {
    let app = real_app();

    assert!(is_accepted(&app, "dr.l02.ord.005", &[0, 3, 2, 1, 4]));
    assert!(is_accepted(&app, "dr.l02.ord.005", &[0, 3, 4, 1, 2]));
}

/// 重複的索引不是合法的排列，就算拼出來的文字相同也不算。
#[test]
fn an_order_that_reuses_a_chunk_is_rejected() {
    let app = real_app();

    assert!(!is_accepted(&app, "dr.l02.ord.005", &[0, 1, 2, 3, 2]));
    assert!(!is_accepted(&app, "dr.l02.ord.005", &[0, 1, 2, 3]));
    assert!(!is_accepted(&app, "dr.l02.ord.005", &[0, 1, 2, 3, 9]));
}

#[test]
fn natural_word_orders_are_accepted() {
    let app = real_app();

    assert!(is_accepted(&app, "dr.l07.ord.004", &[1, 2, 0, 3]));
    assert!(is_accepted(&app, "dr.l06.ord.003", &[0, 2, 1, 3]));
}

fn choices_of<'c>(content: &'c ContentStore, drill_id: &str) -> Vec<&'c str> {
    let Some(DrillDef::ParticleFill { blanks, .. }) = content.drill_by_id(drill_id) else {
        panic!("{drill_id} 應為 particle_fill");
    };
    blanks[0]
        .choices
        .iter()
        .map(|choice| choice.split('|').next().unwrap())
        .collect()
}

/// 這些干擾項代進句子其實成立，改成明確不成立的助詞。
#[test]
fn particle_distractors_are_not_valid_answers() {
    let content = real_content();

    assert!(!choices_of(&content, "dr.l05.par.001").contains(&"は"));
    assert!(!choices_of(&content, "dr.l07.par.004").contains(&"を"));
}

/// 中文要能區分 そこ 與 あそこ，比照 dr.l02.sub.001。
#[test]
fn demonstrative_rows_say_how_far_the_place_is() {
    let content = real_content();
    let Some(DrillDef::Substitution { rows, .. }) = content.drill_by_id("dr.l07.sub.005") else {
        panic!("dr.l07.sub.005 應為 substitution");
    };

    let zh_of = |slot: &str| {
        rows.iter()
            .find(|row| row.slots["b"].starts_with(slot))
            .map(|row| row.zh.clone())
            .unwrap()
    };

    assert!(zh_of("あそこ").contains("離雙方都遠"));
    assert!(zh_of("そこ").contains("靠近對方"));
}

/// V3 的活用表給繁中學習者看：不能露出內部代號。
#[test]
fn conjugation_labels_are_readable_mixed_text() {
    let app = real_app();

    let detail = app.core.vocab_detail("vo.nomu".into()).unwrap();

    let forms: Vec<&str> = detail
        .conjugations
        .iter()
        .map(|row| row.form.as_str())
        .collect();
    assert_eq!(
        forms,
        [
            "{ja:ます}形",
            "{ja:て}形",
            "{ja:た}形",
            "{ja:ない}形",
            "可能形",
            "意向形",
            "{ja:ば}形",
            "命令形",
            "被動形",
            "使役形",
        ]
    );
}

#[test]
fn the_demonstrative_topic_title_marks_its_japanese() {
    let app = real_app();

    let topics = app.core.vocab_topics().unwrap();

    let topic = topics
        .iter()
        .find(|topic| topic.id == "demonstrative")
        .expect("p0a 應有這個主題");
    assert_eq!(topic.title_zh, "{ja:こそあど}與指示");
}

//! §6.1 卡片對應的題目。

mod common;

use std::collections::HashSet;

use common::*;
use jp_content::ContentStore;
use jp_quiz::card::question_for_card;
use jp_quiz::model::QuestionBody;
use jp_quiz::{Question, QuestionType, QuizError};
use jp_srs::CardId;

fn question(store: &ContentStore, known: &HashSet<String>, card: &str, reps: i32) -> Question {
    let id = CardId::parse(card).unwrap();
    question_for_card(&ctx(store, known), &id, reps).unwrap()
}

#[test]
fn vocab_facets_map_to_question_types() {
    let store = content();
    let known = all_known(&store);

    let recog = question(&store, &known, "vo.gohan:recog", 0);
    let listen = question(&store, &known, "vo.gohan:listen", 0);
    let produce = question(&store, &known, "vo.gohan:produce", 0);

    assert_eq!(recog.question_type, QuestionType::Recog);
    assert_eq!(recog.reference.card_id.as_deref(), Some("vo.gohan:recog"));
    assert_eq!(recog.reference.content_id, "vo.gohan");
    assert_eq!(listen.question_type, QuestionType::VocabListen);
    assert_eq!(produce.question_type, QuestionType::Produce);
}

#[test]
fn recog_seed_follows_the_card_id() {
    let store = content();
    let known = all_known(&store);

    let first = question(&store, &known, "vo.gohan:recog", 0);
    let again = question(&store, &known, "vo.gohan:recog", 3);

    assert_eq!(first.body, again.body, "同一天的同一張卡題目不變");
}

#[test]
fn kana_read_card_rotates_with_confuse_by_reps() {
    let store = content();
    let known = all_known(&store);

    let kinds: HashSet<_> = (0..4)
        .map(|reps| question(&store, &known, "ka.hira.nu:read", reps).question_type)
        .collect();

    assert_eq!(
        kinds,
        HashSet::from([QuestionType::KanaRead, QuestionType::KanaConfuse])
    );
}

#[test]
fn kana_card_without_group_is_always_read() {
    let store = content();
    let known = all_known(&store);

    for reps in 0..4 {
        assert_eq!(
            question(&store, &known, "ka.hira.a:read", reps).question_type,
            QuestionType::KanaRead
        );
    }
}

#[test]
fn kana_listen_card_and_its_fallback() {
    let store = content();
    let known = all_known(&store);

    let listen = question(&store, &known, "ka.hira.a:listen", 0);
    assert_eq!(listen.question_type, QuestionType::KanaListen);

    let id = CardId::parse("ka.hira.a:listen").unwrap();
    let silent_question = question_for_card(&silent(&ctx(&store, &known)), &id, 0).unwrap();
    assert_eq!(silent_question.question_type, QuestionType::KanaRead);
}

#[test]
fn kana_card_can_still_be_asked_when_nothing_else_is_taught() {
    let store = content();
    let known = set(&["ka.hira.a"]);

    let read = question(&store, &known, "ka.hira.a:read", 0);

    assert_eq!(read.question_type, QuestionType::KanaRead);
    assert!(options(&read).len() >= 2);
}

#[test]
fn use_card_picks_drill_with_card_reference() {
    let store = content();
    let known = all_known(&store);

    let picked = question(&store, &known, "gr.desu:use", 0);

    assert_eq!(picked.reference.card_id.as_deref(), Some("gr.desu:use"));
    assert_eq!(picked.reference.content_id, "gr.desu");
    assert!(picked.reference.drill_id.is_some());
}

#[test]
fn use_card_rotates_through_candidates() {
    let store = content();
    let known = all_known(&store);

    let drills: HashSet<_> = (0..12)
        .map(|reps| {
            question(&store, &known, "gr.desu:use", reps)
                .reference
                .drill_id
        })
        .collect();

    assert!(drills.len() >= 3, "{drills:?}");
}

/// 少了 `gr.wa_topic`，`gr.plain_style` 的手寫演練只剩 1 題可用，由例句補到 3 題。
#[test]
fn use_card_tops_up_with_auto_listen_meaning() {
    let store = content();
    let mut known = all_known(&store);
    assert!(known.remove("gr.wa_topic"));

    let auto: Vec<_> = (0..6)
        .map(|reps| question(&store, &known, "gr.plain_style:use", reps))
        .filter(|q| q.reference.drill_id.is_none())
        .collect();

    assert!(!auto.is_empty());
    assert_eq!(auto[0].question_type, QuestionType::ListenMeaning);
    assert_eq!(
        auto[0].reference.card_id.as_deref(),
        Some("gr.plain_style:use")
    );
    assert!(auto[0].reference.content_id.starts_with("se."));
}

#[test]
fn use_card_without_candidates_falls_back_to_example_self_grade() {
    let store = content();
    let known = HashSet::new();

    let picked = question(&store, &known, "gr.desu:use", 0);

    assert_eq!(picked.question_type, QuestionType::Recog);
    assert_eq!(picked.reference.content_id, "gr.desu");
    let QuestionBody::SelfGrade { reveal } = &picked.body else {
        panic!("預期 SelfGrade");
    };
    assert_eq!(
        reveal.id, "gr.desu",
        "沒有可用例句時只顯示標題，不露出未教的字"
    );
}

#[test]
fn inconsistent_cards_are_rejected() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    for card in [
        "vo.nope:recog",
        "ka.hira.nope:read",
        "gr.nope:use",
        "vo.gohan:read",
    ] {
        let id = CardId::parse(card).unwrap();
        let result = question_for_card(&context, &id, 0);
        assert!(matches!(result, Err(QuizError::NotFound { .. })), "{card}");
    }
}

//! §8.1 的黃金值與題目層級的確定性。

mod common;

use std::collections::HashSet;

use common::*;
use jp_lang::quiz::rng::{fnv1a, rng_from_seed, seed_for, shuffled};
use jp_quiz::checkpoint::checkpoint_start;
use jp_quiz::distractor::KanaPool;
use jp_quiz::drill::drill_question;
use jp_quiz::kana_quiz::kana_read_question;
use jp_quiz::listen_quiz::listen_session;
use jp_quiz::model::QuestionBody;
use jp_quiz::vocab_quiz::recog_question;
use jp_quiz::QuestionKey;

#[test]
fn spec_golden_values_hold() {
    assert_eq!(fnv1a("vo.taberu:recog"), 3_117_249_249_664_061_045);
    let mut rng = rng_from_seed(seed_for(42, "vo.taberu:recog"));
    let letters = vec!["A", "B", "C", "D", "E", "F"];
    assert_eq!(
        shuffled(&mut rng, letters),
        vec!["B", "A", "F", "D", "E", "C"]
    );
}

/// 黃金值：固定內容與種子得到固定的題目。內容或演算法變動時才需要更新。
#[test]
fn recog_question_golden() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);

    let question =
        recog_question(&context, "vo.gohan", QuestionKey::card("vo.gohan:recog")).unwrap();

    assert_eq!(
        option_ids(&question),
        vec!["vo.tegami", "vo.gohan", "vo.gakusei", "vo.ocha"]
    );
}

#[test]
fn kana_read_question_golden() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let question = kana_read_question(&context, "ka.hira.nu", &pool, QuestionKey::plain("g"))
        .unwrap()
        .unwrap();

    assert_eq!(
        option_ids(&question),
        vec!["ka.hira.me", "ka.hira.nu", "ka.hira.ne", "ka.hira.gu"]
    );
}

fn golden_drill(id: &str) -> jp_quiz::Question {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    drill_question(&context, drill(&store, id), QuestionKey::plain(id), None).unwrap()
}

#[test]
fn substitution_golden() {
    let question = golden_drill("dr.l02.sub.001");

    assert_eq!(question.reference.variant, Some(0));
    assert_eq!(option_ids(&question), vec!["r0", "r1"]);
}

#[test]
fn reorder_golden() {
    assert_eq!(chunk_order(&golden_drill("dr.l02.ord.001")), vec![0, 2, 1]);
}

#[test]
fn conjugate_and_minimal_pair_golden() {
    assert_eq!(golden_drill("dr.l02.cnj.001").reference.variant, Some(1));
    assert_eq!(golden_drill("dr.k11.mpr.001").reference.variant, Some(0));
}

#[test]
fn checkpoint_golden() {
    let store = content();
    let known = HashSet::new();

    let questions = checkpoint_start(&ctx(&store, &known), "ms.hira").unwrap();

    let head: Vec<_> = questions
        .iter()
        .take(4)
        .map(|q| (q.question_type.as_str(), q.reference.content_id.as_str()))
        .collect();
    assert_eq!(
        head,
        vec![
            ("kana_read", "ka.hira.be"),
            ("kana_listen", "ka.hira.ra"),
            ("kana_listen", "ka.hira.a"),
            ("kana_listen", "ka.hira.gyu"),
        ]
    );
}

#[test]
fn listen_session_golden() {
    let store = content();
    let known = all_known(&store);
    let ids: Vec<String> = ["se.l01.003", "se.l01.004", "se.l01.005", "se.l02.001"]
        .iter()
        .map(|id| (*id).to_string())
        .collect();

    let questions = listen_session(&ctx(&store, &known), &ids).unwrap();

    let order: Vec<_> = questions
        .iter()
        .map(|q| q.reference.content_id.as_str())
        .collect();
    assert_eq!(
        order,
        vec!["se.l02.001", "se.l01.005", "se.l01.003", "se.l01.004"]
    );
}

#[test]
fn same_seed_gives_identical_question_and_other_seeds_can_differ() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let key = QuestionKey::card("vo.gohan:recog");

    let first = recog_question(&context, "vo.gohan", key).unwrap();
    let second = recog_question(&context, "vo.gohan", key).unwrap();
    assert_eq!(first, second);

    let differs = (0..50u32).any(|seed| {
        let other = recog_question(&with_seed(&context, seed), "vo.gohan", key).unwrap();
        option_ids(&other) != option_ids(&first)
    });
    assert!(differs, "不同種子應能得到不同選項順序");
    assert!(matches!(first.body, QuestionBody::Choice { .. }));
}

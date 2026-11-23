//! §8.2 假名題的干擾項。

mod common;

use std::collections::HashSet;

use common::*;
use jp_content::schema::Script;
use jp_content::ContentStore;
use jp_quiz::distractor::KanaPool;
use jp_quiz::kana_quiz::kana_read_question;
use jp_quiz::{QuestionKey, QuestionType};

const KEY: QuestionKey<'static> = QuestionKey {
    seed_key: "test",
    card_id: None,
};

fn read_options(store: &ContentStore, known: &HashSet<String>, id: &str, seed: u32) -> Vec<String> {
    let context = with_seed(&ctx(store, known), seed);
    let pool = KanaPool::taught(store, known, &[]);
    let question = kana_read_question(&context, id, &pool, KEY)
        .unwrap()
        .unwrap();
    option_ids(&question)
        .into_iter()
        .map(str::to_owned)
        .collect()
}

#[test]
fn kana_read_shows_char_and_romaji_options_with_item_ids() {
    let store = content();
    let known = set(&[
        "ka.hira.a",
        "ka.hira.i",
        "ka.hira.u",
        "ka.hira.e",
        "ka.hira.o",
    ]);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let question = kana_read_question(&context, "ka.hira.a", &pool, KEY)
        .unwrap()
        .unwrap();

    assert_eq!(question.question_type, QuestionType::KanaRead);
    assert_eq!(question.prompt.plain_text.as_deref(), Some("{ja:あ}"));
    assert_eq!(options(&question).len(), 4);
    assert_eq!(correct_id(&question), "ka.hira.a");
    assert!(option_ids(&question).iter().all(|id| known.contains(*id)));
    assert!(option_texts(&question).contains(&"a"));
    assert_eq!(question.reference.content_id, "ka.hira.a");
    assert_eq!(question.focus_ids, vec!["ka.hira.a"]);
}

#[test]
fn first_batch_of_three_gives_three_options() {
    let store = content();
    let known = HashSet::new();
    let context = ctx(&store, &known);
    let batch = ["ka.hira.a", "ka.hira.i", "ka.hira.u"];
    let pool = KanaPool::taught(&store, &known, &batch);

    let question = kana_read_question(&context, "ka.hira.a", &pool, KEY)
        .unwrap()
        .unwrap();

    assert_eq!(options(&question).len(), 3);
}

#[test]
fn no_question_without_any_distractor() {
    let store = content();
    let known = set(&["ka.hira.a"]);
    let context = ctx(&store, &known);
    let pool = KanaPool::taught(&store, &known, &[]);

    let question = kana_read_question(&context, "ka.hira.a", &pool, KEY).unwrap();

    assert_eq!(question, None);
}

#[test]
fn same_shape_group_members_are_always_picked_first() {
    let store = content();
    let known = all_known(&store);
    for seed in 0..40 {
        let ids = read_options(&store, &known, "ka.hira.nu", seed);
        assert!(
            ids.iter().any(|id| id == "ka.hira.me"),
            "seed {seed}: {ids:?}"
        );
    }
}

#[test]
fn distractors_prefer_same_row_or_column_over_others() {
    let store = content();
    let ids = [
        "ka.hira.ka",
        "ka.hira.ki",
        "ka.hira.ku",
        "ka.hira.ke",
        "ka.hira.a",
        "ka.hira.ni",
        "ka.hira.ne",
        "ka.hira.me",
    ];
    let known = set(&ids);
    for seed in 0..40 {
        let options = read_options(&store, &known, "ka.hira.ka", seed);
        // か行或あ段的字有 ki ku ke a 四個，別行別段的 ni ne me 排不進來
        for far in ["ka.hira.ni", "ka.hira.ne", "ka.hira.me"] {
            assert!(
                !options.iter().any(|id| id == far),
                "seed {seed}: {options:?}"
            );
        }
    }
}

#[test]
fn yoon_and_plain_chars_do_not_share_columns() {
    let store = content();
    let known = all_known(&store);
    let is_yoon = |id: &str| store.kana_by_id(id).unwrap().def.row.is_some();
    for seed in 0..40 {
        let yoon = read_options(&store, &known, "ka.hira.kya", seed);
        assert!(yoon.iter().all(|id| is_yoon(id)), "seed {seed}: {yoon:?}");
        let plain = read_options(&store, &known, "ka.hira.nu", seed);
        assert!(
            plain.iter().all(|id| !is_yoon(id)),
            "seed {seed}: {plain:?}"
        );
    }
}

#[test]
fn same_script_distractors_come_before_other_script() {
    let store = content();
    let ids = [
        "ka.hira.a",
        "ka.hira.ka",
        "ka.hira.sa",
        "ka.hira.ta",
        "ka.kata.ka",
        "ka.kata.a",
        "ka.kata.ki",
        "ka.kata.ku",
    ];
    let known = set(&ids);
    for seed in 0..40 {
        let options = read_options(&store, &known, "ka.hira.a", seed);
        assert!(
            options.iter().all(|id| id.starts_with("ka.hira.")),
            "seed {seed}: {options:?}"
        );
    }
}

#[test]
fn same_reading_chars_never_appear_together() {
    let store = content();
    let known = all_known(&store);
    let pairs = [
        ("ka.hira.ji", "ka.hira.di"),
        ("ka.hira.di", "ka.hira.ji"),
        ("ka.hira.zu", "ka.hira.du"),
        ("ka.hira.o", "ka.hira.wo"),
        ("ka.hira.wo", "ka.hira.o"),
        ("ka.hira.ka", "ka.kata.ka"),
    ];
    for (target, excluded) in pairs {
        for seed in 0..30 {
            let options = read_options(&store, &known, target, seed);
            assert!(
                !options.iter().any(|id| id == excluded),
                "{target}: {options:?}"
            );
        }
    }
}

#[test]
fn two_distractors_with_the_same_reading_are_not_both_used() {
    let store = content();
    let known = set(&["ka.hira.a", "ka.hira.ji", "ka.hira.di"]);

    for seed in 0..20 {
        assert_eq!(read_options(&store, &known, "ka.hira.a", seed).len(), 2);
    }
}

#[test]
fn romaji_options_are_distinct_and_marks_are_excluded() {
    let store = content();
    let known = all_known(&store);
    let pool = KanaPool::taught(&store, &known, &[]);
    assert!(pool
        .entries()
        .iter()
        .all(|entry| entry.def.id != "ka.hira.sokuon"));
    for seed in 0..60 {
        let context = with_seed(&ctx(&store, &known), seed);
        let question = kana_read_question(&context, "ka.hira.shi", &pool, KEY)
            .unwrap()
            .unwrap();
        let mut texts = option_texts(&question);
        texts.sort_unstable();
        texts.dedup();
        assert_eq!(texts.len(), 4, "{texts:?}");
    }
}

#[test]
fn whole_script_pool_ignores_item_intro_and_stays_in_scope() {
    let store = content();
    let max_pos = store.lesson_pos("le.k19").unwrap();
    let known = HashSet::new();
    let context = ctx(&store, &known);

    let pool = KanaPool::whole_script(&store, Script::Hira, max_pos);

    assert!(pool
        .entries()
        .iter()
        .all(|e| e.def.id.starts_with("ka.hira.")));
    assert!(pool
        .entries()
        .iter()
        .all(|e| e.def.kind != jp_content::schema::KanaKind::Mark));
    let question = kana_read_question(&context, "ka.hira.a", &pool, KEY)
        .unwrap()
        .unwrap();
    assert_eq!(options(&question).len(), 4);
}

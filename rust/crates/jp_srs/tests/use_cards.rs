//! §6.1 `use` 卡的題目選取。

mod common;

use std::collections::HashSet;

use common::*;
use jp_content::ContentStore;
use jp_lang::quiz::rng::fnv1a;
use jp_srs::use_cards::{
    drill_is_usable, drill_needs_audio, select_use_question, use_candidates, UseCandidate,
    UseQuery, UseSelection,
};

fn all_known(store: &ContentStore) -> HashSet<String> {
    let vocab = store.vocab().iter().map(|v| v.def.id.clone());
    let grammar = store.grammar().iter().map(|g| g.id.clone());
    vocab.chain(grammar).collect()
}

fn without(store: &ContentStore, ids: &[&str]) -> HashSet<String> {
    let mut known = all_known(store);
    for id in ids {
        assert!(known.remove(*id), "{id} 不在夾具內");
    }
    known
}

fn query<'a>(content_id: &'a str, known: &'a HashSet<String>) -> UseQuery<'a> {
    UseQuery {
        content_id,
        cursor_pos: None,
        known,
        audio_available: true,
    }
}

fn drill_ids(candidates: &[UseCandidate], store: &ContentStore) -> Vec<String> {
    candidates
        .iter()
        .filter_map(|candidate| match candidate {
            UseCandidate::Drill(index) => Some(store.drills()[*index as usize].id().to_string()),
            UseCandidate::AutoListenMeaning(_) => None,
        })
        .collect()
}

fn auto_ids(candidates: &[UseCandidate], store: &ContentStore) -> Vec<String> {
    candidates
        .iter()
        .filter_map(|candidate| match candidate {
            UseCandidate::AutoListenMeaning(index) => {
                Some(store.sentences()[*index as usize].def.id.clone())
            }
            UseCandidate::Drill(_) => None,
        })
        .collect()
}

mod candidates {
    use super::*;

    #[test]
    fn shadowing_is_never_a_candidate() {
        let store = content();
        let known = all_known(&store);

        let found = drill_ids(&use_candidates(&query("gr.desu", &known), &store), &store);

        assert_eq!(
            found,
            [
                "dr.l01.par.001",
                "dr.l01.z2j.001",
                "dr.l01.lsn.001",
                "dr.l01.sit.001",
                "dr.l01.ord.001"
            ]
        );
    }

    #[test]
    fn drills_after_the_cursor_are_excluded() {
        let store = content();
        let known = all_known(&store);
        let before = store.lesson_pos("le.l08").unwrap();
        let at = store.lesson_pos("le.l21").unwrap();

        let early = UseQuery {
            cursor_pos: Some(before),
            ..query("gr.plain_style", &known)
        };
        let on_time = UseQuery {
            cursor_pos: Some(at),
            ..query("gr.plain_style", &known)
        };

        assert_eq!(use_candidates(&early, &store), []);
        assert_eq!(
            drill_ids(&use_candidates(&on_time, &store), &store).len(),
            4
        );
    }

    #[test]
    fn drills_with_unknown_words_are_excluded() {
        let store = content();
        let known = without(&store, &["vo.gohan"]);

        let found = drill_ids(&use_candidates(&query("gr.wo_obj", &known), &store), &store);

        assert_eq!(found, ["dr.l02.lsn.001"]);
    }

    #[test]
    fn silent_mode_excludes_drills_needing_audio() {
        let store = content();
        let known = all_known(&store);
        let silent = UseQuery {
            audio_available: false,
            ..query("gr.masu", &known)
        };

        let found = drill_ids(&use_candidates(&silent, &store), &store);

        assert_eq!(
            found,
            [
                "dr.l02.sub.001",
                "dr.l02.par.001",
                "dr.l02.z2j.001",
                "dr.l02.cnj.001"
            ]
        );
    }

    #[test]
    fn listen_disabled_minimal_pairs_are_never_candidates() {
        let store = content();
        let known = all_known(&store);

        let found = use_candidates(&query("ka.sg.accent_ame", &known), &store);

        assert_eq!(found, []);
    }

    #[test]
    fn enabled_minimal_pairs_stay_when_audio_is_on() {
        let store = content();
        let known = all_known(&store);

        let found = drill_ids(
            &use_candidates(&query("ka.hira.ba", &known), &store),
            &store,
        );

        assert_eq!(found, ["dr.k17.mpr.001"]);
    }
}

mod auto_listen_meaning {
    use super::*;

    /// 少了 `gr.wa_topic`，`gr.plain_style` 的手寫演練只剩 1 題可用，兩句例句都還能用。
    #[test]
    fn fewer_than_three_drills_are_topped_up_from_examples() {
        let store = content();
        let known = without(&store, &["gr.wa_topic"]);

        let found = use_candidates(&query("gr.plain_style", &known), &store);

        assert_eq!(drill_ids(&found, &store), ["dr.l21.lsn.001"]);
        assert_eq!(auto_ids(&found, &store), ["se.l21.001", "se.l21.002"]);
    }

    #[test]
    fn three_drills_are_not_topped_up() {
        let store = content();
        let known = all_known(&store);

        let found = use_candidates(&query("gr.desu", &known), &store);

        assert_eq!(auto_ids(&found, &store), Vec::<String>::new());
    }

    /// 剩 2 題手寫演練時只補 1 句，第二句例句可用也不補。
    #[test]
    fn top_up_stops_at_three_candidates() {
        let store = content();
        let known = without(&store, &["vo.watashi", "vo.sensei"]);

        let found = use_candidates(&query("gr.plain_style", &known), &store);

        assert_eq!(
            drill_ids(&found, &store),
            ["dr.l21.lsn.001", "dr.l21.par.001"]
        );
        assert_eq!(auto_ids(&found, &store), ["se.l21.001"]);
    }

    #[test]
    fn examples_with_unknown_refs_are_skipped() {
        let store = content();
        let known = without(&store, &["vo.gohan"]);

        let found = use_candidates(&query("gr.wo_obj", &known), &store);

        assert_eq!(auto_ids(&found, &store), ["se.l02.002"]);
    }

    #[test]
    fn examples_after_the_cursor_are_skipped() {
        let store = content();
        let known = without(&store, &["gr.wa_topic"]);
        let cursor = UseQuery {
            cursor_pos: Some(store.lesson_pos("le.l02").unwrap()),
            ..query("gr.plain_style", &known)
        };

        assert_eq!(use_candidates(&cursor, &store), []);
    }

    #[test]
    fn silent_mode_gets_no_top_up() {
        let store = content();
        let known = without(&store, &["gr.wa_topic"]);
        let silent = UseQuery {
            audio_available: false,
            ..query("gr.plain_style", &known)
        };

        assert_eq!(use_candidates(&silent, &store), []);
    }

    /// §8.4：少於 1 個干擾項時不出題，這張候選不能留給 jp_quiz 才發現做不出來。
    #[test]
    fn an_example_with_no_possible_distractor_is_skipped() {
        let store = content();
        let known: HashSet<String> = ["gr.desu", "vo.sensei"].map(String::from).into();

        let found = use_candidates(&query("gr.desu", &known), &store);

        assert_eq!(auto_ids(&found, &store), Vec::<String>::new());
    }

    #[test]
    fn a_sentence_with_identical_chinese_is_not_a_distractor() {
        let store = content_with(&[(r#""zh": "是飯。""#, r#""zh": "是老師。""#)]);
        let known: HashSet<String> = ["gr.desu", "vo.sensei", "vo.gohan"]
            .map(String::from)
            .into();

        let found = use_candidates(&query("gr.desu", &known), &store);

        assert_eq!(auto_ids(&found, &store), Vec::<String>::new());
    }
}

mod selection {
    use super::*;

    #[test]
    fn rotates_by_reps_plus_the_card_hash() {
        let store = content();
        let known = all_known(&store);
        let q = query("gr.desu", &known);
        let candidates = use_candidates(&q, &store);
        let len = candidates.len() as u64;
        let base = fnv1a("gr.desu:use");

        for reps in 0..12 {
            let expected = candidates[((reps as u64 + base % len) % len) as usize];

            assert_eq!(
                select_use_question(&q, reps, "gr.desu:use", &store),
                UseSelection::Question(expected),
                "reps {reps}"
            );
        }
    }

    #[test]
    fn the_same_inputs_pick_the_same_question() {
        let store = content();
        let known = all_known(&store);
        let q = query("gr.masu", &known);

        assert_eq!(
            select_use_question(&q, 3, "gr.masu:use", &store),
            select_use_question(&q, 3, "gr.masu:use", &store)
        );
    }

    #[test]
    fn no_candidates_falls_back_to_a_usable_example() {
        let store = content();
        let known = without(&store, &["gr.wa_topic"]);
        let q = UseQuery {
            audio_available: false,
            ..query("gr.plain_style", &known)
        };

        let picked = select_use_question(&q, 0, "gr.plain_style:use", &store);

        assert_eq!(
            picked,
            UseSelection::SelfGradeExample(store.sentence_index("se.l21.001"))
        );
    }

    #[test]
    fn fallback_prefers_an_example_with_known_words() {
        let store = content();
        let known = without(&store, &["vo.gohan"]);
        let q = UseQuery {
            audio_available: false,
            ..query("gr.wo_obj", &known)
        };

        let picked = select_use_question(&q, 0, "gr.wo_obj:use", &store);

        assert_eq!(
            picked,
            UseSelection::SelfGradeExample(store.sentence_index("se.l02.002"))
        );
    }

    #[test]
    /// 第一次接觸不能顯示含未教項目的例句（§6.1、§7.3），退回只顯示標題。
    fn fallback_shows_no_example_when_none_is_usable() {
        let store = content();
        let known = HashSet::new();
        let q = UseQuery {
            audio_available: false,
            ..query("gr.wo_obj", &known)
        };

        let picked = select_use_question(&q, 0, "gr.wo_obj:use", &store);

        assert_eq!(picked, UseSelection::SelfGradeExample(None));
    }

    #[test]
    fn an_item_without_examples_has_nothing_to_show() {
        let store = content();
        let known = all_known(&store);

        let picked = select_use_question(&query("vo.none", &known), 0, "vo.none:use", &store);

        assert_eq!(picked, UseSelection::SelfGradeExample(None));
    }
}

mod drill_checks {
    use super::*;

    fn usable(id: &str, known: &HashSet<String>, store: &ContentStore) -> bool {
        drill_is_usable(store.drill_by_id(id).unwrap(), known, store)
    }

    #[test]
    fn every_fixture_drill_is_usable_when_everything_is_known() {
        let store = content();
        let known = all_known(&store);

        for drill in store.drills() {
            assert!(drill_is_usable(drill, &known, &store), "{}", drill.id());
        }
    }

    /// 每種題型把內含的字拿掉一個，都要變成不可用。
    #[test]
    fn a_missing_ref_makes_each_variant_unusable() {
        let store = content();
        let cases = [
            ("dr.l01.par.001", "vo.gakusei"),
            ("dr.l01.z2j.001", "vo.gakusei"),
            ("dr.l01.z2j.001", "vo.sensei"),
            ("dr.l01.lsn.001", "vo.hai"),
            ("dr.l01.sit.001", "vo.konnichiwa"),
            ("dr.l01.sit.001", "vo.hajimemashite"),
            ("dr.l01.ord.001", "vo.gakusei"),
            ("dr.l01.shd.001", "vo.sensei"),
            ("dr.l02.sub.001", "vo.ocha"),
            ("dr.l02.cnj.001", "vo.nomu"),
            ("dr.l21.reg.001", "vo.watashi"),
            ("dr.l21.reg.001", "gr.plain_style"),
            ("dr.l21.par.001", "gr.wa_topic"),
            ("dr.l08.ffr.001", "vo.tegami"),
        ];

        for (drill, missing) in cases {
            let known = without(&store, &[missing]);

            assert!(!usable(drill, &known, &store), "{drill} 缺 {missing}");
        }
    }

    #[test]
    fn non_vocab_targets_do_not_need_to_be_known() {
        let store = content();
        let known = HashSet::new();

        assert!(usable("dr.k11.kwd.002", &known, &store));
    }

    #[test]
    fn audio_needs_match_the_question_type_table() {
        let store = content();
        let needs = |id: &str| drill_needs_audio(store.drill_by_id(id).unwrap());

        for id in ["dr.l01.lsn.001", "dr.l01.shd.001", "dr.k11.mpr.001"] {
            assert!(needs(id), "{id}");
        }
        assert!(needs("dr.l02.ord.001"), "audio_first 的 reorder");
        for id in [
            "dr.l01.ord.001",
            "dr.l01.par.001",
            "dr.l01.z2j.001",
            "dr.l01.sit.001",
            "dr.l02.sub.001",
            "dr.l02.cnj.001",
            "dr.l21.reg.001",
            "dr.l08.ffr.001",
            "dr.k05.kwd.001",
        ] {
            assert!(!needs(id), "{id}");
        }
    }
}

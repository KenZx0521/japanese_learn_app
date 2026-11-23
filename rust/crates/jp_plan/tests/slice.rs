//! §7.3 新內容切分。

mod common;

use common::*;
use jp_content::ContentStore;
use jp_plan::budget::NewContentMode;
use jp_plan::slice::{integration_days_needed, next_slice, Slice, SliceQuota, FIRST_KANA_BATCH};
use jp_plan::state::{cursor, CursorState};

fn quota(words: u32, kana: u32) -> SliceQuota {
    SliceQuota {
        mode: NewContentMode::Full,
        words,
        kana,
        integration_days_needed: 1,
    }
}

fn minimal() -> SliceQuota {
    SliceQuota {
        mode: NewContentMode::Minimal,
        words: 5,
        kana: 5,
        integration_days_needed: 1,
    }
}

fn kana_of(slice: Slice) -> (Vec<String>, Vec<String>, Vec<String>) {
    match slice {
        Slice::Kana {
            lesson_ids,
            kana,
            rules,
        } => (lesson_ids, kana, rules),
        other => panic!("not kana: {other:?}"),
    }
}

fn vocab_of(slice: Slice) -> (String, Vec<String>, Vec<String>) {
    match slice {
        Slice::Vocab {
            lesson_id,
            words,
            grammar,
        } => (lesson_id, words, grammar),
        other => panic!("not vocab: {other:?}"),
    }
}

fn hira(names: &[&str]) -> Vec<String> {
    names.iter().map(|n| format!("ka.hira.{n}")).collect()
}

mod kana {
    use super::*;

    #[test]
    fn first_batch_of_the_whole_plan_is_three_chars() {
        let store = content();

        let (lessons, chars, rules) =
            kana_of(next_slice(&CursorState::default(), &quota(5, 5), &store).unwrap());

        assert_eq!(FIRST_KANA_BATCH, 3);
        assert_eq!(lessons, ids(&["le.k01"]));
        assert_eq!(chars, hira(&["a", "i", "u"]));
        assert!(rules.is_empty());
    }

    #[test]
    fn first_batch_ignores_a_larger_daily_quota() {
        let (_, chars, _) =
            kana_of(next_slice(&CursorState::default(), &quota(12, 10), &content()).unwrap());

        assert_eq!(chars.len(), 3);
    }

    #[test]
    fn after_first_batch_uses_daily_quota_and_crosses_into_next_lesson() {
        let store = content();
        let mut state = CursorState::default();
        intro(&mut state, &["ka.hira.a", "ka.hira.i", "ka.hira.u"]);

        let (lessons, chars, _) = kana_of(next_slice(&state, &quota(5, 5), &store).unwrap());

        assert_eq!(lessons, ids(&["le.k01", "le.k02"]));
        assert_eq!(chars, hira(&["e", "o", "ka", "ki", "ku"]));
    }

    #[test]
    fn stops_at_a_lesson_without_new_chars() {
        let store = content();

        // K09 剩 5 字，額度 8；K10 沒有新字，當課取完就停。
        let (lessons, chars, _) =
            kana_of(next_slice(&state_at("le.k09", &store), &quota(5, 8), &store).unwrap());

        assert_eq!(lessons, ids(&["le.k09"]));
        assert_eq!(chars.len(), 5);
    }

    #[test]
    fn stops_at_an_l_lesson() {
        let store = content();

        // KK01 之後是 L02。
        let (lessons, chars, _) =
            kana_of(next_slice(&state_at("le.kk01", &store), &quota(5, 99), &store).unwrap());

        assert_eq!(lessons, ids(&["le.kk01"]));
        assert_eq!(chars.len(), 10);
    }

    #[test]
    fn yoon_row_costs_one_and_is_taken_whole() {
        let store = content();

        // K14 有 3 行拗音，加 K15 的 gya 行，額度 5 用 4。
        let (lessons, chars, _) =
            kana_of(next_slice(&state_at("le.k14", &store), &quota(5, 5), &store).unwrap());

        assert_eq!(lessons, ids(&["le.k14", "le.k15"]));
        assert_eq!(chars.len(), 12);
        assert_eq!(chars[0..3].to_vec(), hira(&["kya", "kyu", "kyo"]));
    }

    #[test]
    fn budget_of_two_takes_exactly_two_whole_rows() {
        let store = content();

        let (lessons, chars, _) =
            kana_of(next_slice(&state_at("le.k14", &store), &quota(5, 2), &store).unwrap());

        assert_eq!(lessons, ids(&["le.k14"]));
        assert_eq!(chars, hira(&["kya", "kyu", "kyo", "sha", "shu", "sho"]));
    }

    #[test]
    fn marks_never_enter_the_slice() {
        let store = content();

        let (_, chars, _) =
            kana_of(next_slice(&state_at("le.k14", &store), &quota(5, 5), &store).unwrap());

        assert!(!chars.iter().any(|id| id.contains("small_")));
    }

    #[test]
    fn already_completed_lessons_are_passed_over() {
        let store = content();
        let mut state = state_at("le.k03", &store);
        state = with_completed(state, &["le.k04"], d("2026-01-02"), &store);

        // K03 取完後跨過已完成的 K04，進 K05。
        let (lessons, chars, _) = kana_of(next_slice(&state, &quota(5, 8), &store).unwrap());

        assert_eq!(lessons, ids(&["le.k03", "le.k05"]));
        assert_eq!(chars.len(), 8);
    }

    #[test]
    fn skipped_first_lesson_means_no_first_batch_rule() {
        let store = content();
        let state = with_completed(CursorState::default(), &["le.k01"], d("2026-01-01"), &store);

        let (_, chars, _) = kana_of(next_slice(&state, &quota(5, 5), &store).unwrap());

        assert_eq!(chars.len(), 5);
    }

    #[test]
    fn kk07_rule_card_joins_the_first_slice() {
        let store = content();

        let (lessons, chars, rules) =
            kana_of(next_slice(&state_at("le.kk07", &store), &quota(5, 5), &store).unwrap());

        assert_eq!(lessons, ids(&["le.kk07", "le.kk08"]));
        assert_eq!(chars.len(), 5);
        assert_eq!(rules, ids(&["ka.rule.chouon_kata"]));
    }

    #[test]
    fn rule_card_already_introduced_is_not_repeated() {
        let store = content();
        let mut state = state_at("le.kk07", &store);
        intro(
            &mut state,
            &["ka.rule.chouon_kata", "ka.kata.kya", "ka.kata.kyu"],
        );

        let (lessons, chars, rules) = kana_of(next_slice(&state, &quota(5, 5), &store).unwrap());

        assert_eq!(lessons, ids(&["le.kk07", "le.kk08"]));
        assert_eq!(chars.len(), 3);
        assert!(rules.is_empty());
    }

    #[test]
    fn lesson_with_all_chars_introduced_but_rule_left_is_a_rule_slice() {
        let store = content();
        let mut state = state_at("le.kk07", &store);
        intro(&mut state, &["ka.kata.kya", "ka.kata.kyu", "ka.kata.kyo"]);

        let got = next_slice(&state, &quota(5, 5), &store).unwrap();

        assert_eq!(
            got,
            Slice::KanaRule {
                lesson_id: "le.kk07".to_owned(),
                rules: ids(&["ka.rule.chouon_kata"]),
                confusables: vec![]
            }
        );
    }

    #[test]
    fn k10_is_a_whole_lesson_rule_slice() {
        let store = content();

        let slice = next_slice(&state_at("le.k10", &store), &quota(5, 5), &store).unwrap();

        assert_eq!(
            slice,
            Slice::KanaRule {
                lesson_id: "le.k10".to_owned(),
                rules: vec![],
                confusables: ids(&["ka.cf.nu_me"])
            }
        );
    }

    #[test]
    fn k16_to_k19_are_rule_slices_with_their_cards() {
        let store = content();

        for (lesson, rule) in [
            ("le.k16", "ka.rule.sokuon"),
            ("le.k17", "ka.rule.chouon_hira"),
            ("le.k18", "ka.rule.particle_read"),
            ("le.k19", "ka.rule.accent_intro"),
        ] {
            let slice = next_slice(&state_at(lesson, &store), &quota(5, 5), &store).unwrap();
            let Slice::KanaRule {
                lesson_id, rules, ..
            } = slice
            else {
                panic!("{lesson}")
            };
            assert_eq!(lesson_id, lesson);
            assert_eq!(rules, ids(&[rule]));
        }
    }

    #[test]
    fn minimal_slice_is_three_chars() {
        let store = content();

        let (_, chars, _) =
            kana_of(next_slice(&state_at("le.k02", &store), &minimal(), &store).unwrap());

        assert_eq!(chars, hira(&["ka", "ki", "ku"]));
    }

    #[test]
    fn minimal_slice_at_yoon_is_one_row() {
        let store = content();

        let (lessons, chars, _) =
            kana_of(next_slice(&state_at("le.k14", &store), &minimal(), &store).unwrap());

        assert_eq!(lessons, ids(&["le.k14"]));
        assert_eq!(chars, hira(&["kya", "kyu", "kyo"]));
    }

    #[test]
    fn minimal_slice_stops_after_one_row_even_if_plain_chars_follow() {
        let store = content();

        // KK07 只有 1 行拗音，下一課 KK08 是一般字：最小切片仍只有 1 行。
        let (lessons, chars, _) =
            kana_of(next_slice(&state_at("le.kk07", &store), &minimal(), &store).unwrap());

        assert_eq!(lessons, ids(&["le.kk07"]));
        assert_eq!(chars.len(), 3);
    }

    #[test]
    fn stops_at_an_l_lesson_even_when_it_is_already_completed() {
        let store = content();
        let state = with_completed(
            state_at("le.kk01", &store),
            &["le.l02", "le.l03"],
            d("2026-01-02"),
            &store,
        );

        let (lessons, _, _) = kana_of(next_slice(&state, &quota(5, 99), &store).unwrap());

        assert_eq!(lessons, ids(&["le.kk01"]));
    }

    #[test]
    fn minimal_slice_does_not_append_a_row_after_plain_chars() {
        let store = content();
        let mut state = state_at("le.k13", &store);
        intro(
            &mut state,
            &["ka.hira.pa", "ka.hira.pi", "ka.hira.pu", "ka.hira.pe"],
        );

        // K13 剩 po，下一課開頭是拗音：不併入拗音行。
        let (lessons, chars, _) = kana_of(next_slice(&state, &minimal(), &store).unwrap());

        assert_eq!(lessons, ids(&["le.k13"]));
        assert_eq!(chars, hira(&["po"]));
    }
}

mod vocab {
    use super::*;

    #[test]
    fn words_follow_lesson_order_up_to_the_limit() {
        let store = content();

        let (lesson, words, _) =
            vocab_of(next_slice(&state_at("le.l01", &store), &quota(5, 5), &store).unwrap());

        assert_eq!(lesson, "le.l01");
        assert_eq!(
            words,
            ids(&[
                "vo.watashi",
                "vo.sensei",
                "vo.gakusei",
                "vo.hai",
                "vo.konnichiwa"
            ])
        );
    }

    #[test]
    fn grammar_spreads_over_remaining_word_days_more_first() {
        let store = content();
        let mut state = state_at("le.l01", &store);
        let limit = quota(3, 5);

        // 8 字 ÷3 = 3 天、2 文法：1、1、0。
        let (_, words1, grammar1) = vocab_of(next_slice(&state, &limit, &store).unwrap());
        assert_eq!(grammar1, ids(&["gr.desu"]));
        state.introduced.extend(words1);
        state.introduced.extend(grammar1);

        let (_, words2, grammar2) = vocab_of(next_slice(&state, &limit, &store).unwrap());
        assert_eq!(grammar2, ids(&["gr.wa_topic"]));
        state.introduced.extend(words2);
        state.introduced.extend(grammar2);

        let (_, words3, grammar3) = vocab_of(next_slice(&state, &limit, &store).unwrap());
        assert_eq!(words3.len(), 2);
        assert!(grammar3.is_empty());
    }

    #[test]
    fn grammar_uses_ceiling_of_share() {
        let store = content();

        // 8 字 ÷5 = 2 天、2 文法：第一天 ceil(2/2)=1。
        let (_, _, grammar) =
            vocab_of(next_slice(&state_at("le.l01", &store), &quota(5, 5), &store).unwrap());

        assert_eq!(grammar.len(), 1);
    }

    #[test]
    fn only_grammar_left_takes_it_all_on_full_mode() {
        let store = content();
        let mut state = state_at("le.l01", &store);
        intro(
            &mut state,
            &[
                "vo.watashi",
                "vo.sensei",
                "vo.gakusei",
                "vo.hai",
                "vo.konnichiwa",
                "vo.gohan",
                "vo.ocha",
                "vo.hajimemashite",
            ],
        );

        let (_, words, grammar) = vocab_of(next_slice(&state, &quota(5, 5), &store).unwrap());

        assert!(words.is_empty());
        assert_eq!(grammar, ids(&["gr.desu", "gr.wa_topic"]));
    }

    #[test]
    fn l21_slice_lists_only_the_lesson_words() {
        let store = content();

        let (_, words, _) =
            vocab_of(next_slice(&state_at("le.l21", &store), &quota(12, 5), &store).unwrap());

        assert_eq!(words, ids(&["vo.nani", "vo.suru"]));
    }

    #[test]
    fn minimal_slice_is_three_words_without_grammar() {
        let store = content();

        let (_, words, grammar) =
            vocab_of(next_slice(&state_at("le.l01", &store), &minimal(), &store).unwrap());

        assert_eq!(words.len(), 3);
        assert!(grammar.is_empty());
    }

    #[test]
    fn minimal_slice_with_only_grammar_left_is_one_point() {
        let store = content();
        let mut state = state_at("le.l02", &store);
        intro(&mut state, &["vo.taberu", "vo.nomu"]);

        let (_, words, grammar) = vocab_of(next_slice(&state, &minimal(), &store).unwrap());

        assert!(words.is_empty());
        assert_eq!(grammar, ids(&["gr.wo_obj"]));
    }

    #[test]
    fn plan_change_resplits_with_the_new_quota() {
        let store = content();
        let state = state_at("le.l01", &store);

        let (_, ten, _) = vocab_of(next_slice(&state, &quota(3, 3), &store).unwrap());
        let (_, forty_five, _) = vocab_of(next_slice(&state, &quota(12, 10), &store).unwrap());

        assert_eq!(ten.len(), 3);
        assert_eq!(forty_five.len(), 8);
    }
}

mod integration {
    use super::*;

    fn all_introduced(lesson: &str, store: &ContentStore) -> CursorState {
        let mut state = state_at(lesson, store);
        state.introduced.extend(lesson_item_ids(lesson, store));
        state
    }

    fn slice(state: &CursorState, days: u32, store: &ContentStore) -> Slice {
        let q = SliceQuota {
            integration_days_needed: days,
            ..quota(5, 5)
        };
        next_slice(state, &q, store).unwrap()
    }

    #[test]
    fn integration_days_needed_is_two_only_for_ten_minutes() {
        assert_eq!(integration_days_needed(10), 2);
        for minutes in [20, 30, 45] {
            assert_eq!(integration_days_needed(minutes), 1);
        }
    }

    #[test]
    fn after_all_items_a_lesson_gets_an_integration_day() {
        let store = content();

        assert_eq!(
            slice(&all_introduced("le.l01", &store), 1, &store),
            Slice::Integration {
                lesson_id: "le.l01".to_owned(),
                dialogue_id: Some("di.self_intro".to_owned()),
                phases: vec![1, 2, 3, 4],
                day_no: 1,
            }
        );
    }

    #[test]
    fn ten_minute_plan_splits_phases_over_two_days() {
        let store = content();
        let mut state = all_introduced("le.l01", &store);

        let Slice::Integration { phases, day_no, .. } = slice(&state, 2, &store) else {
            panic!()
        };
        assert_eq!((phases, day_no), (vec![1, 2], 1));

        state.integration_days.insert("le.l01".to_owned(), 1);
        let Slice::Integration { phases, day_no, .. } = slice(&state, 2, &store) else {
            panic!()
        };
        assert_eq!((phases, day_no), (vec![3, 4], 2));
    }

    #[test]
    fn minimal_mode_still_gives_the_integration_day() {
        let store = content();
        let state = all_introduced("le.l01", &store);

        let result = next_slice(
            &state,
            &SliceQuota {
                integration_days_needed: 1,
                ..minimal()
            },
            &store,
        )
        .unwrap();

        assert!(matches!(result, Slice::Integration { .. }));
    }

    #[test]
    fn every_third_completed_lesson_gets_an_extra_dialogue() {
        let store = content();

        // 已完成 L01、L02、L03（3 課），L08 的整合日改排 pos ≤ 游標的 di.tea_shop。
        let Slice::Integration { dialogue_id, .. } =
            slice(&all_introduced("le.l08", &store), 1, &store)
        else {
            panic!()
        };

        assert_eq!(dialogue_id.as_deref(), Some("di.tea_shop"));
    }

    #[test]
    fn already_scheduled_extra_dialogue_is_not_repeated() {
        let store = content();
        let mut state = all_introduced("le.l08", &store);
        state
            .integration_dialogues
            .insert("le.l03".to_owned(), "di.tea_shop".to_owned());

        let Slice::Integration { dialogue_id, .. } = slice(&state, 1, &store) else {
            panic!()
        };

        assert_eq!(dialogue_id, None); // L08 沒有主對話
    }

    #[test]
    fn rotation_includes_a_dialogue_of_the_cursor_lesson_itself() {
        let store = content();
        let mut state = all_introduced("le.l21", &store);
        state.skipped.insert("le.l08".to_owned());
        state
            .integration_dialogues
            .insert("le.l03".to_owned(), "di.tea_shop".to_owned());

        let Slice::Integration { dialogue_id, .. } = slice(&state, 1, &store) else {
            panic!()
        };

        assert_eq!(dialogue_id.as_deref(), Some("di.meal.casual"));
    }

    #[test]
    fn skipped_lessons_do_not_count_toward_rotation() {
        let store = content();
        let mut state = all_introduced("le.l08", &store);
        state.skipped.insert("le.l01".to_owned());

        let Slice::Integration { dialogue_id, .. } = slice(&state, 1, &store) else {
            panic!()
        };

        assert_eq!(dialogue_id, None);
    }

    #[test]
    fn zero_completed_lessons_is_not_a_rotation_day() {
        let store = content();
        let mut state = all_introduced("le.l21", &store);
        for lesson in ["le.l01", "le.l02", "le.l03", "le.l08"] {
            state.skipped.insert(lesson.to_owned());
        }

        let Slice::Integration { dialogue_id, .. } = slice(&state, 1, &store) else {
            panic!()
        };

        assert_eq!(dialogue_id.as_deref(), Some("di.casual_talk"));
    }

    #[test]
    fn second_integration_day_keeps_the_same_dialogue() {
        let store = content();
        let mut state = all_introduced("le.l08", &store);
        state.integration_days.insert("le.l08".to_owned(), 1);
        state
            .integration_dialogues
            .insert("le.l08".to_owned(), "di.tea_shop".to_owned());

        let Slice::Integration {
            dialogue_id,
            day_no,
            ..
        } = slice(&state, 2, &store)
        else {
            panic!()
        };

        assert_eq!(dialogue_id.as_deref(), Some("di.tea_shop"));
        assert_eq!(day_no, 2);
    }
}

#[test]
fn mode_none_returns_no_slice() {
    let store = content();
    let q = SliceQuota {
        mode: NewContentMode::None,
        ..quota(5, 5)
    };

    assert_eq!(next_slice(&CursorState::default(), &q, &store), None);
}

#[test]
fn everything_completed_returns_no_slice() {
    let store = content();

    assert_eq!(
        next_slice(&state_all_done(&store), &quota(5, 5), &store),
        None
    );
    assert_eq!(cursor(&state_all_done(&store), &store), None);
}

#[test]
fn key_item_id_and_lesson_id() {
    let kana = Slice::Kana {
        lesson_ids: ids(&["le.k01"]),
        kana: ids(&["ka.hira.a"]),
        rules: vec![],
    };
    let rule = Slice::KanaRule {
        lesson_id: "le.k10".to_owned(),
        rules: vec![],
        confusables: ids(&["ka.cf.nu_me"]),
    };
    let empty = Slice::KanaRule {
        lesson_id: "le.k18".to_owned(),
        rules: vec![],
        confusables: vec![],
    };
    let vocab = Slice::Vocab {
        lesson_id: "le.l01".to_owned(),
        words: vec![],
        grammar: ids(&["gr.desu"]),
    };

    assert_eq!(kana.key_item_id(), "ka.hira.a");
    assert_eq!(kana.lesson_id(), "le.k01");
    assert_eq!(rule.key_item_id(), "ka.cf.nu_me");
    assert_eq!(empty.key_item_id(), "le.k18");
    assert_eq!(vocab.key_item_id(), "gr.desu");
}

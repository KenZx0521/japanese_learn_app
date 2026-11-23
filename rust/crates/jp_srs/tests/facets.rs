//! §6.1 的建卡表與解鎖門檻（§11.1 `srs/facets.rs`）。

mod common;

use common::*;
use jp_content::ContentStore;
use jp_srs::facets::{cards_for_content, unlocks};
use jp_srs::{CardId, Facet};
use jp_store::NewCard;

const RETIRED_VOCAB: &str = r#"{"id": "vo.zz_retired", "lesson": "le.l01", "lesson_order": 99, "surface": "え", "kana": "え", "zh": ["x"], "pos": "n", "accent": null, "jlpt": "n5", "topics": ["people"], "examples": [], "retired": true},
    {"id": "vo.watashi","#;
const RETIRED_GRAMMAR: &str = r#"{"id": "gr.zz_retired", "lesson": "le.l01", "lesson_order": 99, "jlpt": "n5", "title_zh": "x", "pattern": "x", "meaning_zh": "x", "explain_zh": "x", "compare_zh": "x", "trap_zh": null, "formation": [], "register": "neutral", "requires": [], "examples": [], "contrast": [], "terms": [], "retired": true},
    {"id": "gr.desu","#;

fn summary(cards: &[NewCard]) -> Vec<(String, u8)> {
    cards
        .iter()
        .map(|card| (card.card_id.clone(), card.priority))
        .collect()
}

fn built(id: &str, store: &ContentStore) -> Vec<(String, u8)> {
    summary(&cards_for_content(id, store, ts(NOW)))
}

fn unlocked(id: &str, facet: Facet, days: i64, store: &ContentStore) -> Vec<(String, u8)> {
    summary(&unlocks(&CardId::new(id, facet), days, store, ts(NOW)))
}

fn entry(id: &str, priority: u8) -> (String, u8) {
    (id.to_string(), priority)
}

mod initial_cards {
    use super::*;

    #[test]
    fn kana_gets_a_read_card() {
        assert_eq!(built("ka.hira.a", &content()), [entry("ka.hira.a:read", 0)]);
    }

    #[test]
    fn kana_marks_get_no_card() {
        assert_eq!(built("ka.hira.sokuon", &content()), []);
    }

    #[test]
    fn other_kana_content_gets_no_card() {
        let store = content();
        let ids = ["ka.cf.nu_me", "ka.rule.sokuon", "ka.sg.accent_ame"];

        assert!(ids.iter().all(|id| built(id, &store).is_empty()));
    }

    #[test]
    fn a_plain_word_gets_recog_only() {
        assert_eq!(
            built("vo.gakusei", &content()),
            [entry("vo.gakusei:recog", 0)]
        );
    }

    #[test]
    fn a_same_form_word_gets_recog_and_priority_zero_listen() {
        assert_eq!(
            built("vo.sensei", &content()),
            [entry("vo.sensei:recog", 0), entry("vo.sensei:listen", 0)]
        );
    }

    #[test]
    fn grammar_gets_a_main_use_card() {
        assert_eq!(built("gr.desu", &content()), [entry("gr.desu:use", 0)]);
    }

    #[test]
    fn dialogues_and_unknown_ids_get_no_card() {
        let store = content();

        assert_eq!(built("di.self_intro", &store), []);
        assert_eq!(built("vo.does_not_exist", &store), []);
        assert_eq!(built("nonsense", &store), []);
    }

    #[test]
    fn retired_content_gets_no_card() {
        let store = content_with(&[
            (r#"{"id": "vo.watashi","#, RETIRED_VOCAB),
            (r#"{"id": "gr.desu","#, RETIRED_GRAMMAR),
        ]);

        assert_eq!(built("vo.zz_retired", &store), []);
        assert_eq!(built("gr.zz_retired", &store), []);
    }

    #[test]
    fn created_at_is_the_injected_time_and_ids_are_split() {
        let cards = cards_for_content("vo.gakusei", &content(), ts(NOW));

        assert_eq!(cards[0].created_at, ts(NOW));
        assert_eq!(cards[0].content_id, "vo.gakusei");
        assert_eq!(cards[0].facet, "recog");
    }
}

mod unlocking {
    use super::*;

    #[test]
    fn kana_listen_unlocks_at_four_days() {
        let store = content();

        assert_eq!(unlocked("ka.hira.a", Facet::Read, 3, &store), []);
        assert_eq!(
            unlocked("ka.hira.a", Facet::Read, 4, &store),
            [entry("ka.hira.a:listen", 1)]
        );
    }

    #[test]
    fn listen_disabled_kana_never_unlocks_listen() {
        let store = content_with(&[(
            r#"{"id": "ka.hira.a","#,
            r#"{"listen_disabled": true, "id": "ka.hira.a","#,
        )]);

        assert_eq!(unlocked("ka.hira.a", Facet::Read, 30, &store), []);
    }

    #[test]
    fn vocab_listen_unlocks_at_four_days_and_produce_at_seven() {
        let store = content();

        assert_eq!(unlocked("vo.gakusei", Facet::Recog, 3, &store), []);
        assert_eq!(
            unlocked("vo.gakusei", Facet::Recog, 4, &store),
            [entry("vo.gakusei:listen", 1)]
        );
        assert_eq!(
            unlocked("vo.gakusei", Facet::Recog, 6, &store),
            [entry("vo.gakusei:listen", 1)]
        );
        assert_eq!(
            unlocked("vo.gakusei", Facet::Recog, 7, &store),
            [
                entry("vo.gakusei:listen", 1),
                entry("vo.gakusei:produce", 1)
            ]
        );
    }

    #[test]
    fn recognize_only_words_never_unlock_produce() {
        let store = content_with(&[(
            r#"{"id": "vo.gakusei","#,
            r#"{"use_level": "recognize_only", "id": "vo.gakusei","#,
        )]);

        assert_eq!(
            unlocked("vo.gakusei", Facet::Recog, 30, &store),
            [entry("vo.gakusei:listen", 1)]
        );
    }

    #[test]
    fn friends_only_words_still_unlock_produce() {
        let store = content_with(&[(
            r#"{"id": "vo.gakusei","#,
            r#"{"use_level": "friends_only", "id": "vo.gakusei","#,
        )]);

        let found = unlocked("vo.gakusei", Facet::Recog, 7, &store);

        assert!(found.contains(&entry("vo.gakusei:produce", 1)));
    }

    #[test]
    fn same_form_words_only_unlock_produce_because_listen_already_exists() {
        assert_eq!(
            unlocked("vo.sensei", Facet::Recog, 7, &content()),
            [entry("vo.sensei:produce", 1)]
        );
    }

    #[test]
    fn other_facets_unlock_nothing() {
        let store = content();

        assert_eq!(unlocked("vo.gakusei", Facet::Listen, 30, &store), []);
        assert_eq!(unlocked("vo.gakusei", Facet::Produce, 30, &store), []);
        assert_eq!(unlocked("gr.desu", Facet::Use, 30, &store), []);
        assert_eq!(unlocked("ka.hira.a", Facet::Listen, 30, &store), []);
    }

    #[test]
    fn missing_or_retired_content_unlocks_nothing() {
        let store = content_with(&[(r#"{"id": "vo.watashi","#, RETIRED_VOCAB)]);

        assert_eq!(unlocked("vo.gone", Facet::Recog, 30, &store), []);
        assert_eq!(unlocked("ka.gone", Facet::Read, 30, &store), []);
        assert_eq!(unlocked("vo.zz_retired", Facet::Recog, 30, &store), []);
    }

    #[test]
    fn unlocked_cards_carry_the_injected_time() {
        let cards = unlocks(
            &CardId::new("vo.gakusei", Facet::Recog),
            4,
            &content(),
            ts(LONG_AGO),
        );

        assert_eq!(cards[0].created_at, ts(LONG_AGO));
    }
}

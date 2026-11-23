//! §6.5 假名熟練（§11.1 `srs/kana_mastery.rs`）。

mod common;

use chrono::Duration;
use common::*;
use jp_srs::kana_mastery::{
    counts_toward_mastery, next_mastery, record_kana_answer, KanaAnswer, FAST_ANSWER_MS,
    MASTERY_RUN_REQUIRED,
};
use jp_srs::SrsError;
use jp_store::{
    ItemIntroRow, KanaMasteryRow, PlanRepo, SettingsRepo, SettingsRow, SqliteRepository, SrsRepo,
};

const KANA: &str = "ka.hira.a";
const SLOW: u32 = FAST_ANSWER_MS + 1;

fn answer(is_correct: bool, duration_ms: u32) -> KanaAnswer<'static> {
    KanaAnswer {
        kana_id: KANA,
        question_type: "kana_read",
        is_correct,
        duration_ms,
    }
}

/// 依序作答，回傳最後的 row。
fn play(answers: &[(bool, u32)], time_limit: bool) -> KanaMasteryRow {
    let (first, rest) = answers.split_first().unwrap();
    let start = next_mastery(None, &answer(first.0, first.1), time_limit, ts(NOW));
    rest.iter().fold(start, |row, (correct, ms)| {
        next_mastery(Some(&row), &answer(*correct, *ms), time_limit, ts(NOW))
    })
}

mod rules {
    use super::*;

    #[test]
    fn only_three_question_types_count() {
        for kind in ["kana_read", "kana_listen", "kana_confuse"] {
            assert!(counts_toward_mastery(kind), "{kind}");
        }
        for kind in ["kana_match", "minimal_pair", "kana_word", "recog", ""] {
            assert!(!counts_toward_mastery(kind), "{kind}");
        }
    }

    #[test]
    fn one_correct_answer_is_not_mastery() {
        let row = play(&[(true, 1000)], true);

        assert_eq!(row.correct_run, 1);
        assert_eq!(row.mastered_at, None);
        assert_eq!(row.attempts, 1);
    }

    #[test]
    fn two_correct_in_a_row_is_mastery() {
        let row = play(&[(true, 1000), (true, 1000)], true);

        assert_eq!(row.correct_run, MASTERY_RUN_REQUIRED);
        assert_eq!(row.mastered_at, Some(ts(NOW)));
    }

    #[test]
    fn a_wrong_answer_resets_the_run() {
        let row = play(&[(true, 1000), (false, 1000)], true);

        assert_eq!(row.correct_run, 0);
        assert_eq!(row.mastered_at, None);
        assert_eq!(row.attempts, 2);
    }

    #[test]
    fn slow_but_correct_does_not_reset_the_run() {
        let row = play(&[(true, SLOW), (true, SLOW)], true);

        assert_eq!(row.correct_run, 2);
        assert!(row.mastered_at.is_some());
        assert_eq!(row.fast_run, 0);
    }

    #[test]
    fn mastery_survives_a_later_mistake() {
        let row = play(&[(true, 1000), (true, 1000), (false, 1000)], true);

        assert_eq!(row.correct_run, 0);
        assert!(row.mastered_at.is_some());
    }

    #[test]
    fn mastered_at_keeps_the_first_time() {
        let first = play(&[(true, 1000), (true, 1000)], true);
        let later = ts(NOW) + Duration::days(3);

        let row = next_mastery(Some(&first), &answer(true, 1000), true, later);

        assert_eq!(row.mastered_at, Some(ts(NOW)));
    }
}

mod badge {
    use super::*;

    #[test]
    fn two_fast_correct_answers_earn_the_badge() {
        let row = play(&[(true, FAST_ANSWER_MS), (true, 1)], true);

        assert_eq!(row.fast_run, 2);
        assert_eq!(row.fast_badge_at, Some(ts(NOW)));
    }

    #[test]
    fn a_slow_answer_between_breaks_the_fast_run() {
        let row = play(&[(true, 1000), (true, SLOW), (true, 1000)], true);

        assert_eq!(row.fast_run, 1);
        assert_eq!(row.fast_badge_at, None);
    }

    #[test]
    fn a_wrong_fast_answer_breaks_the_fast_run() {
        let row = play(&[(true, 1000), (false, 1), (true, 1000)], true);

        assert_eq!(row.fast_run, 1);
        assert_eq!(row.fast_badge_at, None);
    }

    #[test]
    fn the_badge_is_kept_after_a_mistake() {
        let row = play(&[(true, 1000), (true, 1000), (false, 1000)], true);

        assert_eq!(row.fast_run, 0);
        assert!(row.fast_badge_at.is_some());
    }

    #[test]
    fn without_the_time_limit_mastery_earns_the_badge() {
        let row = play(&[(true, SLOW), (true, SLOW)], false);

        assert_eq!(row.mastered_at, Some(ts(NOW)));
        assert_eq!(row.fast_badge_at, Some(ts(NOW)));
    }

    #[test]
    fn without_the_time_limit_one_answer_earns_nothing() {
        assert_eq!(play(&[(true, 1)], false).fast_badge_at, None);
    }

    #[test]
    fn turning_the_limit_off_rewards_a_mastered_kana_on_its_next_correct_answer() {
        let mastered = play(&[(true, SLOW), (true, SLOW)], true);
        assert_eq!(mastered.fast_badge_at, None);

        let wrong = next_mastery(Some(&mastered), &answer(false, SLOW), false, ts(NOW));
        assert_eq!(wrong.fast_badge_at, None);

        let right = next_mastery(Some(&wrong), &answer(true, SLOW), false, ts(NOW));
        assert_eq!(right.fast_badge_at, Some(ts(NOW)));
    }
}

mod recording {
    use super::*;

    fn introduce(repo: &SqliteRepository, id: &str) {
        repo.insert_item_intros(&[ItemIntroRow {
            item_id: id.to_string(),
            lesson_id: "le.k01".to_string(),
            logical_date: d(TODAY),
            introduced_at: ts(NOW),
        }])
        .unwrap();
    }

    fn correct_twice(repo: &SqliteRepository, in_today_slice: bool) {
        let store = content();
        for _ in 0..2 {
            record_kana_answer(repo, &store, &answer(true, 1000), in_today_slice, ts(NOW)).unwrap();
        }
    }

    fn read_card_exists(repo: &SqliteRepository) -> bool {
        repo.card("ka.hira.a:read").unwrap().is_some()
    }

    #[test]
    fn progress_is_persisted_and_reported() {
        let repo = repo();
        let store = content();

        let status = record_kana_answer(&repo, &store, &answer(true, 1000), false, ts(NOW))
            .unwrap()
            .unwrap();

        assert_eq!(status.kana_id, KANA);
        assert_eq!(status.run, 1);
        assert_eq!(status.required, MASTERY_RUN_REQUIRED);
        assert!(!status.mastered);
        assert!(!status.fast_badge);
        assert_eq!(repo.kana_mastery(KANA).unwrap().unwrap().correct_run, 1);
    }

    #[test]
    fn the_reported_run_is_capped_at_the_requirement() {
        let repo = repo();
        let store = content();
        correct_twice(&repo, false);

        let status = record_kana_answer(&repo, &store, &answer(true, 1000), false, ts(NOW))
            .unwrap()
            .unwrap();

        assert_eq!(status.run, MASTERY_RUN_REQUIRED);
        assert!(status.mastered);
        assert_eq!(repo.kana_mastery(KANA).unwrap().unwrap().correct_run, 3);
    }

    #[test]
    fn answers_that_do_not_count_change_nothing() {
        let repo = repo();
        let kana_word = KanaAnswer {
            question_type: "kana_word",
            ..answer(true, 1000)
        };

        let status = record_kana_answer(&repo, &content(), &kana_word, true, ts(NOW)).unwrap();

        assert_eq!(status, None);
        assert_eq!(repo.kana_mastery(KANA).unwrap(), None);
    }

    #[test]
    fn unknown_kana_is_not_found() {
        let repo = repo();
        let missing = KanaAnswer {
            kana_id: "ka.hira.zzz",
            ..answer(true, 1000)
        };

        let result = record_kana_answer(&repo, &content(), &missing, true, ts(NOW));

        assert!(matches!(result, Err(SrsError::NotFound { .. })));
    }

    #[test]
    fn mastering_a_kana_in_todays_slice_creates_its_read_card() {
        let repo = repo();

        correct_twice(&repo, true);

        let card = repo.card("ka.hira.a:read").unwrap().unwrap();
        assert_eq!(card.state, 0);
        assert_eq!(card.priority, 0);
        assert_eq!(card.created_at, ts(NOW));
    }

    #[test]
    fn mastering_an_introduced_kana_creates_its_read_card() {
        let repo = repo();
        introduce(&repo, KANA);

        correct_twice(&repo, false);

        assert!(read_card_exists(&repo));
    }

    #[test]
    fn free_practice_only_updates_mastery() {
        let repo = repo();

        correct_twice(&repo, false);

        assert!(!read_card_exists(&repo));
        assert!(repo
            .kana_mastery(KANA)
            .unwrap()
            .unwrap()
            .mastered_at
            .is_some());
    }

    #[test]
    fn answers_before_mastery_create_no_card() {
        let repo = repo();
        let store = content();

        record_kana_answer(&repo, &store, &answer(true, 1000), true, ts(NOW)).unwrap();

        assert!(!read_card_exists(&repo));
    }

    #[test]
    fn card_is_created_only_when_mastery_is_first_reached() {
        let repo = repo();
        let store = content();
        correct_twice(&repo, false);

        record_kana_answer(&repo, &store, &answer(true, 1000), true, ts(NOW)).unwrap();

        assert!(!read_card_exists(&repo));
    }

    #[test]
    fn the_setting_controls_the_time_limit() {
        let repo = repo();
        repo.put_settings(&SettingsRow {
            kana_time_limit: false,
            ..SettingsRow::default()
        })
        .unwrap();
        let store = content();

        record_kana_answer(&repo, &store, &answer(true, SLOW), false, ts(NOW)).unwrap();
        let status = record_kana_answer(&repo, &store, &answer(true, SLOW), false, ts(NOW))
            .unwrap()
            .unwrap();

        assert!(status.fast_badge);
    }

    #[test]
    fn mastery_writes_no_review_log() {
        let repo = repo();

        correct_twice(&repo, true);

        assert_eq!(repo.reviews_for_card("ka.hira.a:read").unwrap().len(), 0);
    }
}

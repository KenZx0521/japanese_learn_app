//! §7.4 今日任務的組裝（純函式）。

mod common;

use chrono::NaiveDate;
use common::*;
use jp_content::ContentStore;
use jp_plan::budget::{DayBudget, NewContentMode, RecoveryReason, Split};
use jp_plan::calendar::{PlanHistory, ALL_DAYS_MASK};
use jp_plan::compose::compose_day;
use jp_plan::slice::Slice;
use jp_plan::tasks::{DailyTask, DaySnapshot};
use jp_store::MilestoneResultRow;

fn today() -> NaiveDate {
    d(MONDAY)
}

fn compose(fixture: &FactsFixture, store: &ContentStore) -> DaySnapshot {
    compose_day(&fixture.facts(), store)
}

fn fixture_at(store: &ContentStore, lesson: &str, minutes: u32) -> FactsFixture {
    FactsFixture::new(store, today(), minutes, state_at(lesson, store))
}

fn kinds(snapshot: &DaySnapshot) -> Vec<&'static str> {
    snapshot
        .tasks
        .iter()
        .map(|task| match task {
            DailyTask::Review { .. } => "review",
            DailyTask::NewContent { .. } => "new",
            DailyTask::Integration { .. } => "integration",
            DailyTask::Drill { .. } => "drill",
            DailyTask::Listen { .. } => "listen",
            DailyTask::Checkpoint { .. } => "checkpoint",
        })
        .collect()
}

fn task<'a>(snapshot: &'a DaySnapshot, kind: &str) -> &'a DailyTask {
    let position = kinds(snapshot)
        .iter()
        .position(|k| *k == kind)
        .unwrap_or_else(|| panic!("{kind}"));
    &snapshot.tasks[position]
}

fn budget(snapshot: &DaySnapshot) -> &DayBudget {
    &snapshot.budget
}

mod first_day {
    use super::*;

    #[test]
    fn lists_review_and_the_first_kana_batch() {
        let store = content();
        let fixture = FactsFixture::new(&store, today(), 20, Default::default());

        let got = compose(&fixture, &store);

        assert_eq!(kinds(&got), vec!["review", "new"]);
        let DailyTask::NewContent {
            key,
            lesson_id,
            slice,
            minutes,
        } = task(&got, "new")
        else {
            panic!()
        };
        assert_eq!(key, "new:ka.hira.a");
        assert_eq!(lesson_id, "le.k01");
        assert_eq!(*minutes, 12.0);
        assert!(matches!(slice, Slice::Kana { kana, .. } if kana.len() == 3));
    }

    #[test]
    fn budget_for_s0() {
        let store = content();
        let fixture = FactsFixture::new(&store, today(), 20, Default::default());

        let b = compose(&fixture, &store).budget;

        assert_eq!(
            b.split,
            Split {
                new: 12.0,
                review: 8.0,
                drill: 0.0,
                listen: 0.0
            }
        );
        assert_eq!(b.review_cap, 60);
        assert_eq!(b.new_words_limit, 5);
        assert_eq!(b.kana_chars_limit, 5);
        assert_eq!(b.new_content, NewContentMode::Full);
        assert_eq!(b.recovery_reason, None);
        assert_eq!(b.recovery_days, 0);
    }

    #[test]
    fn kk_cursor_in_s0_has_no_drill_even_with_usable_questions() {
        let store = content();
        let got = compose(&fixture_at(&store, "le.kk01", 20), &store);

        assert!(!kinds(&got).contains(&"drill"));
    }

    #[test]
    fn s0_lists_neither_drill_nor_listen() {
        let store = content();
        let got = compose(&fixture_at(&store, "le.k05", 20), &store);

        assert!(!kinds(&got).contains(&"drill"));
        assert!(!kinds(&got).contains(&"listen"));
    }
}

mod ordering {
    use super::*;

    #[test]
    fn task_order_is_fixed() {
        let store = content();
        let fixture = fixture_at(&store, "le.l31", 20);

        let got = compose(&fixture, &store);

        assert_eq!(
            kinds(&got),
            vec![
                "review",
                "new",
                "drill",
                "listen",
                "checkpoint",
                "checkpoint",
                "checkpoint",
                "checkpoint"
            ]
        );
    }

    #[test]
    fn checkpoint_lists_every_due_milestone_in_file_order() {
        let store = content();
        let got = compose(&fixture_at(&store, "le.l08", 20), &store);

        let keys: Vec<&str> = got
            .tasks
            .iter()
            .filter(|t| matches!(t, DailyTask::Checkpoint { .. }))
            .map(DailyTask::key)
            .collect();
        assert_eq!(
            keys,
            vec![
                "checkpoint:ms.hira",
                "checkpoint:ms.kata",
                "checkpoint:ms.survive"
            ]
        );
    }
}

mod restricted {
    use super::*;

    #[test]
    fn return_after_break_blocks_new_content_and_halves_cap() {
        let store = content();
        let mut fixture = fixture_at(&store, "le.k02", 20);
        fixture.history = PlanHistory::from_rows(std::slice::from_ref(&plan_row(
            d("2026-01-01"),
            20,
            ALL_DAYS_MASK,
        )));
        fixture.last_active = Some(today() - chrono::Duration::days(4));
        fixture.due_facets = due_facets(1, "recog");

        let got = compose(&fixture, &store);

        assert_eq!(
            budget(&got).recovery_reason,
            Some(RecoveryReason::ReturnAfterBreak)
        );
        assert_eq!(budget(&got).recovery_days, 1);
        assert_eq!(budget(&got).new_content, NewContentMode::None);
        assert_eq!(budget(&got).review_cap, 30); // 60 / 2
        assert!(!kinds(&got).contains(&"new"));
    }

    #[test]
    fn two_scheduled_days_missed_is_not_a_break() {
        let store = content();
        let mut fixture = fixture_at(&store, "le.k02", 20);
        fixture.history = PlanHistory::from_rows(std::slice::from_ref(&plan_row(
            d("2026-01-01"),
            20,
            ALL_DAYS_MASK,
        )));
        fixture.last_active = Some(today() - chrono::Duration::days(3));

        assert_eq!(budget(&compose(&fixture, &store)).recovery_reason, None);
    }

    #[test]
    fn backlog_blocks_new_content() {
        let store = content();
        let mut fixture = fixture_at(&store, "le.k02", 20);
        fixture.due_facets = due_facets(121, "recog"); // 上限 60，2 倍 120

        let got = compose(&fixture, &store);

        assert_eq!(
            budget(&got).recovery_reason,
            Some(RecoveryReason::ReviewBacklog)
        );
        assert_eq!(budget(&got).new_content, NewContentMode::None);
    }

    #[test]
    fn restricted_day_still_lists_drill_and_listen() {
        let store = content();
        let mut fixture = fixture_at(&store, "le.l03", 20);
        fixture.unseen_new = 6;

        let got = compose(&fixture, &store);

        assert_eq!(budget(&got).new_content, NewContentMode::None);
        assert_eq!(kinds(&got), vec!["review", "drill", "listen", "checkpoint"]);
    }

    #[test]
    fn third_day_gets_minimal_slice() {
        let store = content();
        let mut fixture = fixture_at(&store, "le.l01", 20);
        fixture.unseen_new = 6;
        fixture.previous_recovery_days = 2;

        let got = compose(&fixture, &store);

        assert_eq!(budget(&got).new_content, NewContentMode::Minimal);
        assert_eq!(budget(&got).recovery_days, 3);
        let DailyTask::NewContent { slice, .. } = task(&got, "new") else {
            panic!()
        };
        assert!(
            matches!(slice, Slice::Vocab { words, grammar, .. } if words.len() == 3 && grammar.is_empty())
        );
    }
}

mod non_study_day {
    use super::*;

    #[test]
    fn only_review() {
        let store = content();
        let mut fixture =
            FactsFixture::new(&store, d("2026-03-03"), 20, state_at("le.l03", &store));
        fixture.plan = plan_row(d("2026-03-02"), 20, MWF_MASK);
        fixture
            .state
            .introduced
            .extend(lesson_item_ids("le.l01", &store));

        let got = compose(&fixture, &store);

        assert_eq!(kinds(&got), vec!["review"]);
    }
}

mod integration_day {
    use super::*;

    fn integration_fixture(store: &ContentStore) -> FactsFixture {
        let mut fixture = fixture_at(store, "le.l01", 20);
        fixture
            .state
            .introduced
            .extend(lesson_item_ids("le.l01", store));
        fixture
    }

    #[test]
    fn replaces_drill_and_listen_with_their_budget() {
        let store = content();
        let got = compose(&integration_fixture(&store), &store);

        assert_eq!(kinds(&got), vec!["review", "integration", "checkpoint"]);
        let DailyTask::Integration {
            key,
            lesson_id,
            dialogue_id,
            phases,
            minutes,
        } = task(&got, "integration")
        else {
            panic!()
        };
        assert_eq!(key, "integration:le.l01:1");
        assert_eq!(lesson_id, "le.l01");
        assert_eq!(dialogue_id.as_deref(), Some("di.self_intro"));
        assert_eq!(phases, &vec![1, 2, 3, 4]);
        assert_eq!(*minutes, 12.0); // 5 + 5 + 2
    }
}

mod drill_and_listen {
    use super::*;

    #[test]
    fn drill_uses_recent_lessons_and_known_questions() {
        let store = content();
        let got = compose(&fixture_at(&store, "le.l03", 20), &store);

        let DailyTask::Drill {
            key,
            lesson_ids,
            question_count,
            minutes,
        } = task(&got, "drill")
        else {
            panic!()
        };
        assert_eq!(key, "drill");
        assert_eq!(lesson_ids, &ids(&["le.l01", "le.l02", "le.l03"]));
        assert_eq!(*minutes, 5.0);
        assert!(*question_count > 0 && *question_count <= 10);
    }

    #[test]
    fn drill_not_listed_when_no_candidates() {
        let store = content();
        let got = compose(&fixture_at(&store, "le.l01", 20), &store);

        assert!(!kinds(&got).contains(&"drill"));
    }

    #[test]
    fn drill_count_is_capped_by_candidates_and_excludes_audio_without_sound() {
        let store = content();
        let with_audio = compose(&fixture_at(&store, "le.l03", 45), &store);
        let mut silent_fixture = fixture_at(&store, "le.l03", 45);
        silent_fixture.audio_available = false;
        let silent = compose(&silent_fixture, &store);

        let DailyTask::Drill {
            question_count: loud,
            ..
        } = task(&with_audio, "drill")
        else {
            panic!()
        };
        let DailyTask::Drill {
            question_count: quiet,
            ..
        } = task(&silent, "drill")
        else {
            panic!()
        };
        assert!(*loud < 23, "受可用題數限制：{loud}");
        assert!(quiet < loud);
    }

    #[test]
    fn listen_count_uses_listen_minutes() {
        let store = content();
        let fixture = fixture_at(&store, "le.l03", 20);
        // listen 2 分，每句 20 秒 → 6 句。

        let got = compose(&fixture, &store);

        let DailyTask::Listen {
            key,
            sentence_ids,
            minutes,
        } = task(&got, "listen")
        else {
            panic!()
        };
        assert_eq!(key, "listen");
        assert_eq!(*minutes, 2.0);
        assert_eq!(sentence_ids.len(), 6);
    }

    #[test]
    fn listen_not_listed_without_audio() {
        let store = content();
        let mut fixture = fixture_at(&store, "le.l03", 20);
        fixture.audio_available = false;

        assert!(!kinds(&compose(&fixture, &store)).contains(&"listen"));
    }

    #[test]
    fn listen_prefers_recent_lessons_and_is_deterministic() {
        let store = content();
        let fixture = fixture_at(&store, "le.l08", 20);

        let a = compose(&fixture, &store);
        let b = compose(&fixture, &store);

        assert_eq!(a, b);
        let DailyTask::Listen { sentence_ids, .. } = task(&a, "listen") else {
            panic!()
        };
        // 額度 6 句小於最近三課的可用句，全部來自 L02、L03、L08。
        assert!(
            sentence_ids.iter().all(|id| !id.starts_with("se.l01.")),
            "{sentence_ids:?}"
        );
    }

    #[test]
    fn cursor_done_uses_last_three_l_lessons_and_lists_no_new_content() {
        let store = content();
        let fixture = FactsFixture::new(&store, today(), 20, state_all_done(&store));

        let got = compose(&fixture, &store);

        assert!(!kinds(&got).contains(&"new"));
        assert!(!kinds(&got).contains(&"integration"));
        assert_eq!(
            budget(&got).split,
            Split {
                new: 4.0,
                review: 9.0,
                drill: 3.0,
                listen: 4.0
            }
        );
        let DailyTask::Drill { lesson_ids, .. } = task(&got, "drill") else {
            panic!()
        };
        assert_eq!(lesson_ids, &ids(&["le.l08", "le.l21", "le.l31"]));
    }
}

mod checkpoint {
    use super::*;

    fn result(milestone: &str, on: &str, passed: bool) -> MilestoneResultRow {
        MilestoneResultRow {
            milestone_id: milestone.to_owned(),
            correct: if passed { 20 } else { 5 },
            total: 20,
            passed,
            logical_date: d(on),
            taken_at: ts("2026-03-01T00:00:00Z"),
        }
    }

    fn at_l01(store: &ContentStore) -> FactsFixture {
        fixture_at(store, "le.l01", 20)
    }

    #[test]
    fn appears_when_lesson_is_complete_and_no_result() {
        let store = content();
        let got = compose(&at_l01(&store), &store);

        let DailyTask::Checkpoint { key, milestone_id } = task(&got, "checkpoint") else {
            panic!()
        };
        assert_eq!(key, "checkpoint:ms.hira");
        assert_eq!(milestone_id, "ms.hira");
    }

    #[test]
    fn placement_failure_before_completion_does_not_block() {
        let store = content();
        let mut fixture = at_l01(&store);
        fixture.milestone_results = vec![result("ms.hira", "2025-12-01", false)];

        assert!(kinds(&compose(&fixture, &store)).contains(&"checkpoint"));
    }

    #[test]
    fn a_result_on_or_after_completion_removes_it() {
        let store = content();
        let mut fixture = at_l01(&store);
        fixture.milestone_results = vec![result("ms.hira", "2026-01-01", true)];

        assert!(!kinds(&compose(&fixture, &store)).contains(&"checkpoint"));
    }

    #[test]
    fn failed_result_after_completion_also_removes_it() {
        let store = content();
        let mut fixture = at_l01(&store);
        fixture.milestone_results = vec![result("ms.hira", "2026-01-05", false)];

        assert!(!kinds(&compose(&fixture, &store)).contains(&"checkpoint"));
    }

    #[test]
    fn dismissed_is_not_listed() {
        let store = content();
        let mut fixture = at_l01(&store);
        fixture.dismissed.insert("ms.hira".to_owned());

        assert!(!kinds(&compose(&fixture, &store)).contains(&"checkpoint"));
    }

    #[test]
    fn skipped_lesson_is_not_listed() {
        let store = content();
        let mut fixture = at_l01(&store);
        fixture.state.skipped.insert("le.k19".to_owned());

        assert!(!kinds(&compose(&fixture, &store)).contains(&"checkpoint"));
    }

    #[test]
    fn not_listed_before_the_lesson_is_complete() {
        let store = content();

        assert!(!kinds(&compose(&fixture_at(&store, "le.k19", 20), &store)).contains(&"checkpoint"));
    }
}

#[test]
fn snapshot_round_trips_through_json() {
    let store = content();
    let got = compose(&fixture_at(&store, "le.l03", 20), &store);

    let json = got.to_json().unwrap();

    assert_eq!(DaySnapshot::from_json(&json).unwrap(), got);
}

#[test]
fn from_json_rejects_garbage() {
    assert!(DaySnapshot::from_json("{not json").is_err());
}

#[test]
fn every_task_exposes_key_and_minutes() {
    let review = DailyTask::Review {
        key: "review".to_owned(),
        minutes: 2.0,
    };
    let checkpoint = DailyTask::Checkpoint {
        key: "checkpoint:x".to_owned(),
        milestone_id: "x".to_owned(),
    };

    assert_eq!(review.key(), "review");
    assert_eq!(review.minutes(), Some(2.0));
    assert_eq!(checkpoint.minutes(), None);
}

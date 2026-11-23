//! §7.1 計畫輸入與略過規則。

mod common;

use common::*;
use jp_plan::input::*;
use jp_plan::state::{cursor, cursor_pos, recent_main_lessons, stage_for_cursor, CursorState};
use jp_plan::PlanError;
use jp_store::{LessonProgressRow, PlanRepo};

fn invalid(result: Result<(), PlanError>) -> bool {
    matches!(result, Err(PlanError::InvalidInput { .. }))
}

#[test]
fn start_level_round_trips() {
    for level in [
        StartLevel::Zero,
        StartLevel::Hiragana,
        StartLevel::Kana,
        StartLevel::Basic,
    ] {
        assert_eq!(StartLevel::parse(level.as_sql()), Some(level));
    }
    assert_eq!(StartLevel::parse("nope"), None);
}

#[test]
fn lesson_kinds_by_id_prefix() {
    assert!(is_kana_lesson("le.k01"));
    assert!(is_kana_lesson("le.kk07"));
    assert!(!is_kana_lesson("le.l01"));
    assert!(is_main_lesson("le.l01"));
    assert!(!is_main_lesson("le.kk07"));
}

#[test]
fn validate_accepts_all_presets() {
    let store = content();

    for minutes in [10, 20, 30, 45] {
        validate_plan_input(&input(minutes), &store).unwrap();
    }
}

#[test]
fn validate_rejects_unknown_minutes_and_masks() {
    let store = content();

    assert!(invalid(validate_plan_input(&input(15), &store)));
    assert!(invalid(validate_plan_input(
        &PlanInput {
            weekday_mask: 0,
            ..input(20)
        },
        &store
    )));
    assert!(invalid(validate_plan_input(
        &PlanInput {
            weekday_mask: 128,
            ..input(20)
        },
        &store
    )));
}

#[test]
fn validate_rejects_non_kana_or_unknown_known_lessons() {
    let store = content();

    assert!(invalid(validate_plan_input(
        &PlanInput {
            known_kana_lessons: ids(&["le.l01"]),
            ..input(20)
        },
        &store
    )));
    assert!(invalid(validate_plan_input(
        &PlanInput {
            known_kana_lessons: ids(&["le.k99"]),
            ..input(20)
        },
        &store
    )));
}

#[test]
fn zero_skips_nothing() {
    assert!(skipped_lessons(&input(20), &content()).is_empty());
}

#[test]
fn zero_with_known_lessons_skips_those() {
    let store = content();
    let plan = PlanInput {
        known_kana_lessons: ids(&["le.k03", "le.k01"]),
        ..input(20)
    };

    assert_eq!(skipped_lessons(&plan, &store), ids(&["le.k01", "le.k03"]));
}

#[test]
fn hiragana_skips_up_to_k19() {
    let store = content();
    let plan = PlanInput {
        start_level: StartLevel::Hiragana,
        ..input(20)
    };

    let skipped = skipped_lessons(&plan, &store);

    assert_eq!(skipped.len(), 19);
    assert_eq!(skipped.last().map(String::as_str), Some("le.k19"));
}

#[test]
fn kana_level_skips_all_kana_lessons_including_kk() {
    let store = content();
    let plan = PlanInput {
        start_level: StartLevel::Kana,
        ..input(20)
    };

    let skipped = skipped_lessons(&plan, &store);

    assert!(skipped.contains(&"le.kk07".to_owned()));
    assert!(skipped.iter().all(|lesson| is_kana_lesson(lesson)));
}

#[test]
fn basic_also_skips_l_lessons_up_to_l07() {
    // 夾具沒有 L07：只跳假名課，不會多跳也不會崩潰。
    let store = content();
    let plan = PlanInput {
        start_level: StartLevel::Basic,
        ..input(20)
    };

    assert!(skipped_lessons(&plan, &store)
        .iter()
        .all(|lesson| is_kana_lesson(lesson)));
}

#[test]
fn skip_write_records_every_kana_of_skipped_kana_lessons() {
    let store = content();
    let plan = PlanInput {
        known_kana_lessons: ids(&["le.k14"]),
        ..input(20)
    };
    let ctx = ctx_on(d(MONDAY));

    let write = skip_write(&plan, &store, &ctx);

    assert_eq!(write.lesson_ids, ids(&["le.k14"]));
    let intros: Vec<&str> = write
        .item_intros
        .iter()
        .map(|row| row.item_id.as_str())
        .collect();
    assert!(intros.contains(&"ka.hira.kya"));
    assert!(intros.contains(&"ka.hira.small_ya"));
    assert_eq!(write.completed_date, d(MONDAY));
}

#[test]
fn plan_write_builds_baseline_and_skip_from_input() {
    let store = content();
    let plan = input(20);
    let ctx = ctx_on(d(MONDAY));

    let write = plan_write(&plan, &CursorState::default(), &store, &ctx).unwrap();

    assert_eq!(write.plan.effective_from, d(MONDAY));
    assert_eq!(write.plan.start_level, "zero");
    assert_eq!(write.baseline.len(), store.milestones().len());
    assert!(write.skips.lesson_ids.is_empty());
}

#[test]
fn plan_write_rejects_invalid_input() {
    let err = plan_write(
        &input(99),
        &CursorState::default(),
        &content(),
        &ctx_on(d(MONDAY)),
    )
    .unwrap_err();

    assert!(matches!(err, PlanError::InvalidInput { .. }));
}

#[test]
fn from_rows_reads_progress() {
    let row = LessonProgressRow {
        lesson_id: "le.l01".to_owned(),
        integration_days_done: 1,
        integration_dialogue: Some("di.tea_shop".to_owned()),
        skipped: true,
        completed_date: Some(d("2026-03-05")),
        completed_at: None,
    };
    let progress = [("le.l01".to_owned(), row)].into_iter().collect();

    let introduced = ["ka.hira.a".to_owned()].into_iter().collect();

    let state = CursorState::from_rows(introduced, &progress);

    assert!(state.introduced.contains("ka.hira.a"));
    assert_eq!(state.completed.get("le.l01"), Some(&d("2026-03-05")));
    assert!(state.skipped.contains("le.l01"));
    assert_eq!(state.integration_days.get("le.l01"), Some(&1));
    assert_eq!(
        state
            .integration_dialogues
            .get("le.l01")
            .map(String::as_str),
        Some("di.tea_shop")
    );
}

#[test]
fn load_reads_from_repository() {
    let repo = repo();
    let store = content();
    let plan = PlanInput {
        known_kana_lessons: ids(&["le.k02"]),
        ..input(20)
    };
    let ctx = ctx_on(d(MONDAY));
    let write = plan_write(&plan, &CursorState::default(), &store, &ctx).unwrap();
    repo.insert_plan(&write.plan, &write.baseline, &write.skips)
        .unwrap();

    let state = CursorState::load(&repo).unwrap();

    assert!(state.is_completed("le.k02"));
    assert!(state.skipped.contains("le.k02"));
    assert!(state.introduced.contains("ka.hira.ka"));
}

#[test]
fn with_plan_skips_marks_lessons_without_touching_the_original() {
    let store = content();
    let plan = PlanInput {
        known_kana_lessons: ids(&["le.k01"]),
        ..input(20)
    };
    let original = CursorState::default();

    let applied = original.with_plan_skips(&plan, d(MONDAY), &store);

    assert!(applied.is_completed("le.k01"));
    assert!(applied.skipped.contains("le.k01"));
    assert!(applied.introduced.contains("ka.hira.a"));
    assert_eq!(original, CursorState::default());
}

#[test]
fn with_plan_skips_keeps_existing_completed_date() {
    let store = content();
    let plan = PlanInput {
        known_kana_lessons: ids(&["le.k01"]),
        ..input(20)
    };
    let state = with_completed(CursorState::default(), &["le.k01"], d("2026-01-01"), &store);

    let applied = state.with_plan_skips(&plan, d(MONDAY), &store);

    assert_eq!(applied.completed.get("le.k01"), Some(&d("2026-01-01")));
}

#[test]
fn cursor_is_first_incomplete_lesson_in_course_order() {
    let store = content();

    assert_eq!(cursor(&CursorState::default(), &store), Some("le.k01"));
    assert_eq!(cursor(&state_at("le.l02", &store), &store), Some("le.l02"));
    assert_eq!(cursor_pos(&state_at("le.k01", &store), &store), Some(0));
    assert_eq!(cursor_pos(&state_all_done(&store), &store), None);
}

#[test]
fn stage_falls_back_to_last_main_lesson_when_cursor_is_done() {
    let store = content();

    assert_eq!(stage_for_cursor(Some("le.k05"), &store), Some("st.s0"));
    assert_eq!(stage_for_cursor(Some("le.l01"), &store), Some("st.s1"));
    assert_eq!(stage_for_cursor(None, &store), Some("st.s3"));
}

#[test]
fn recent_main_lessons_are_current_plus_two_previous_l_lessons() {
    let store = content();

    assert_eq!(recent_main_lessons(Some("le.l01"), &store), vec!["le.l01"]);
    assert_eq!(
        recent_main_lessons(Some("le.l03"), &store),
        vec!["le.l01", "le.l02", "le.l03"]
    );
    assert_eq!(
        recent_main_lessons(Some("le.l08"), &store),
        vec!["le.l02", "le.l03", "le.l08"]
    );
    assert_eq!(
        recent_main_lessons(None, &store),
        vec!["le.l08", "le.l21", "le.l31"]
    );
}

#[test]
fn recent_main_lessons_with_cursor_on_kk_stops_before_it() {
    let store = content();

    assert_eq!(
        recent_main_lessons(Some("le.kk07"), &store),
        vec!["le.l01", "le.l02", "le.l03"]
    );
}

//! §5.4 ActivityRepo、SettingsRepo。

mod common;

use common::*;
use jp_store::{
    ActivityDelta, ActivityRepo, CompleteTaskWrite, MilestoneResultRow, PlanRepo, SettingsRepo,
    SettingsRow, SqliteRepository, StoreError,
};
use proptest::prelude::*;
use rusqlite::params;

#[test]
fn add_activity_accumulates_every_column() {
    let db = temp_db();
    let delta = ActivityDelta {
        reviews_done: 1,
        new_done: 2,
        relearn_done: 3,
        lessons_done: 4,
        drills_done: 5,
        study_ms: 6,
        shadow_kept: 7,
        shadow_almost: 8,
        shadow_lost: 9,
    };

    db.repo.add_activity(d(TODAY), delta).unwrap();
    db.repo.add_activity(d(TODAY), delta).unwrap();

    let rows = db.repo.activity_range(d(TODAY), d(TODAY)).unwrap();
    assert_eq!(rows.len(), 1);
    let row = &rows[0];
    assert_eq!(row.logical_date, d(TODAY));
    assert_eq!(row.reviews_done, 2);
    assert_eq!(row.new_done, 4);
    assert_eq!(row.relearn_done, 6);
    assert_eq!(row.lessons_done, 8);
    assert_eq!(row.drills_done, 10);
    assert_eq!(row.study_ms, 12);
    assert_eq!(row.shadow_kept, 14);
    assert_eq!(row.shadow_almost, 16);
    assert_eq!(row.shadow_lost, 18);
}

#[test]
fn activity_range_is_inclusive_and_sorted() {
    let db = temp_db();
    let one = ActivityDelta {
        reviews_done: 1,
        ..ActivityDelta::default()
    };
    for on in ["2026-03-05", "2026-03-01", "2026-03-03", "2026-03-07"] {
        db.repo.add_activity(d(on), one).unwrap();
    }

    let rows = db
        .repo
        .activity_range(d("2026-03-01"), d("2026-03-05"))
        .unwrap();

    let dates: Vec<_> = rows.iter().map(|row| row.logical_date).collect();
    assert_eq!(
        dates,
        vec![d("2026-03-01"), d("2026-03-03"), d("2026-03-05")]
    );
}

/// 檢定的作答也是作答：寫 `milestone_result` 時同一個 transaction 把題數計入當天的 `drills_done`，
/// 只考檢定的日子因此是活躍日（RULINGS O12、rust.F4）。
#[test]
fn a_checkpoint_result_counts_its_answers_for_the_day() {
    let db = temp_db();

    db.repo
        .insert_milestone_result(&MilestoneResultRow {
            milestone_id: "ms.hira".to_string(),
            correct: 15,
            total: 20,
            passed: false,
            logical_date: d("2026-03-03"),
            taken_at: ts(NOW),
        })
        .unwrap();

    let rows = db
        .repo
        .activity_range(d("2026-03-03"), d("2026-03-03"))
        .unwrap();
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].drills_done, 20);
    assert_eq!(rows[0].study_ms, 0);
    assert!(db.repo.active_dates().unwrap().contains(&d("2026-03-03")));
}

fn delta_of(field: fn(&mut ActivityDelta)) -> ActivityDelta {
    let mut delta = ActivityDelta::default();
    field(&mut delta);
    delta
}

/// 每個會讓當天算活躍的欄位，各佔一天（2026-03-01 起）。
const ANSWER_FIELDS: [fn(&mut ActivityDelta); 8] = [
    |delta| delta.reviews_done = 1,
    |delta| delta.new_done = 1,
    |delta| delta.relearn_done = 1,
    |delta| delta.drills_done = 1,
    |delta| delta.lessons_done = 1,
    |delta| delta.shadow_kept = 1,
    |delta| delta.shadow_almost = 1,
    |delta| delta.shadow_lost = 1,
];
const DRILLS_DAY: &str = "2026-03-04";
const STUDY_TIME_ONLY_DAY: &str = "2026-03-09";
const EMPTY_DAY: &str = "2026-03-10";

fn seed_one_day_per_field(repo: &SqliteRepository) {
    for (offset, field) in (0_u64..).zip(ANSWER_FIELDS) {
        let on = d("2026-03-01") + chrono::Days::new(offset);
        repo.add_activity(on, delta_of(field)).unwrap();
    }
    let study_only = ActivityDelta {
        study_ms: 1000,
        ..Default::default()
    };
    repo.add_activity(d(STUDY_TIME_ONLY_DAY), study_only)
        .unwrap();
    repo.add_activity(d(EMPTY_DAY), ActivityDelta::default())
        .unwrap();
}

#[test]
fn active_dates_need_an_answer_or_a_finished_lesson() {
    let db = temp_db();
    seed_one_day_per_field(&db.repo);

    let active = db.repo.active_dates().unwrap();

    assert_eq!(active.len(), 8);
    assert!(active.contains(&d("2026-03-08")));
    assert!(!active.contains(&d(STUDY_TIME_ONLY_DAY)));
    assert!(!active.contains(&d(EMPTY_DAY)));
}

/// §7.2 回鍋判定：K1 自由練習、檢定只累加 `drills_done`，不算回到學習計畫（RULINGS O12）。
#[test]
fn plan_active_dates_ignore_answers_outside_the_plan() {
    let db = temp_db();
    seed_one_day_per_field(&db.repo);

    let active = db.repo.plan_active_dates().unwrap();

    assert_eq!(active.len(), 7);
    assert!(active.contains(&d("2026-03-08")));
    assert!(!active.contains(&d(DRILLS_DAY)));
    assert!(!active.contains(&d(STUDY_TIME_ONLY_DAY)));
    assert!(!active.contains(&d(EMPTY_DAY)));
}

/// 演練任務做完（`daily_task_done`）是計畫內的活動，即使 `daily_activity` 只有 `drills_done`。
#[test]
fn a_finished_task_counts_as_plan_activity() {
    let db = temp_db();
    let on = d("2026-03-03");
    db.repo
        .add_activity(on, delta_of(|delta| delta.drills_done = 1))
        .unwrap();
    assert!(!db.repo.plan_active_dates().unwrap().contains(&on));

    db.repo
        .complete_task(&CompleteTaskWrite {
            logical_date: on,
            task_key: "drill".to_string(),
            done_at: ts(NOW),
            item_intros: vec![],
            new_cards: vec![],
            lesson_updates: vec![],
            activity: ActivityDelta::default(),
        })
        .unwrap();

    assert!(db.repo.plan_active_dates().unwrap().contains(&on));
}

/// 檢定的日子算連續天數，但不算回到學習計畫。
#[test]
fn a_checkpoint_result_is_not_plan_activity() {
    let db = temp_db();
    db.repo
        .insert_milestone_result(&MilestoneResultRow {
            milestone_id: "ms.hira".to_string(),
            correct: 15,
            total: 20,
            passed: false,
            logical_date: d("2026-03-03"),
            taken_at: ts(NOW),
        })
        .unwrap();

    assert!(db.repo.active_dates().unwrap().contains(&d("2026-03-03")));
    assert!(!db
        .repo
        .plan_active_dates()
        .unwrap()
        .contains(&d("2026-03-03")));
}

#[test]
fn settings_default_on_a_fresh_database() {
    let db = temp_db();

    let row = db.repo.get_settings().unwrap();

    assert_eq!(row.day_rollover_hour, 4);
    assert_eq!(row.desired_retention, 0.9);
    assert_eq!(row.romaji_override, None);
    assert_eq!(row.furigana_override, None);
    assert_eq!(row.tts_rate, 1.0);
    assert!(row.autoplay);
    assert_eq!(row.voice_id, None);
    assert_eq!(row.theme_mode, "system");
    assert!(!row.silent_mode);
    assert!(row.kana_time_limit);
    assert!(!row.show_rating_intervals);
    assert!(!row.romaji_off_confirmed);
    assert!(row.seen_question_hints.is_empty());
}

fn customized() -> SettingsRow {
    SettingsRow {
        day_rollover_hour: 6,
        desired_retention: 0.85,
        romaji_override: Some("hidden".to_string()),
        furigana_override: Some("unknown_only".to_string()),
        tts_rate: 0.7,
        autoplay: false,
        voice_id: Some("ja-JP-x-htm#local".to_string()),
        theme_mode: "dark".to_string(),
        silent_mode: true,
        kana_time_limit: false,
        show_rating_intervals: true,
        romaji_off_confirmed: true,
        seen_question_hints: vec!["recog".to_string()],
    }
}

#[test]
fn settings_round_trip_and_clear_optionals() {
    let db = temp_db();

    db.repo.put_settings(&customized()).unwrap();
    assert_eq!(db.repo.get_settings().unwrap(), customized());

    let cleared = SettingsRow {
        romaji_override: None,
        furigana_override: None,
        voice_id: None,
        ..customized()
    };
    db.repo.put_settings(&cleared).unwrap();

    assert_eq!(db.repo.get_settings().unwrap(), cleared);
    let conn = raw(&db.path);
    let voice_rows: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM app_setting WHERE key = 'voice_id'",
            [],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(voice_rows, 0);
}

#[test]
fn missing_keys_fall_back_to_defaults_and_unknown_keys_are_ignored() {
    let db = temp_db();
    let conn = raw(&db.path);
    conn.execute_batch(
        "INSERT INTO app_setting VALUES ('tts_rate', '0.8'), ('future_option', 'whatever');",
    )
    .unwrap();

    let row = db.repo.get_settings().unwrap();

    assert_eq!(row.tts_rate, 0.8);
    assert_eq!(row.day_rollover_hour, 4);
}

#[test]
fn corrupt_setting_values_are_reported_with_the_key() {
    let db = temp_db();
    let conn = raw(&db.path);
    let cases = [
        ("day_rollover_hour", "soon"),
        ("autoplay", "maybe"),
        ("seen_question_hints", "not json"),
    ];

    for (key, value) in cases {
        conn.execute(
            "INSERT OR REPLACE INTO app_setting VALUES (?1, ?2)",
            params![key, value],
        )
        .unwrap();

        match db.repo.get_settings().unwrap_err() {
            StoreError::Storage { message } => assert!(message.contains(key), "{message}"),
            other => panic!("預期 Storage，得到 {other:?}"),
        }
        conn.execute("DELETE FROM app_setting WHERE key = ?1", [key])
            .unwrap();
    }
}

#[test]
fn non_finite_settings_are_rejected_and_nothing_changes() {
    let db = temp_db();
    db.repo.put_settings(&customized()).unwrap();
    let cases = [
        SettingsRow {
            tts_rate: f64::NAN,
            ..SettingsRow::default()
        },
        SettingsRow {
            desired_retention: f64::INFINITY,
            ..SettingsRow::default()
        },
    ];

    for row in cases {
        let err = db.repo.put_settings(&row).unwrap_err();
        assert!(matches!(err, StoreError::Internal { .. }), "{err:?}");
    }

    assert_eq!(db.repo.get_settings().unwrap(), customized());
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(32))]

    #[test]
    fn float_settings_round_trip_exactly(rate in -1.0e6f64..1.0e6, retention in 0.0f64..1.0) {
        let db = temp_db();
        let row = SettingsRow {
            tts_rate: rate,
            desired_retention: retention,
            ..SettingsRow::default()
        };

        db.repo.put_settings(&row).unwrap();

        prop_assert_eq!(db.repo.get_settings().unwrap(), row);
    }
}

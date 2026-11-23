//! §11.2 `reset`：清除全部資料後可繼續使用（§5.5）。

mod common;

use std::path::Path;

use common::*;
use jp_core::api::core::{delete_database, AppCore, CoreConfig};
use jp_core::api::dto_plan::{SettingsPatchDto, StartLevel};
use jp_core::api::dto_study::NewContentStepDto;
use jp_core::api::error::CoreError;

#[test]
fn reset_all_clears_progress_and_settings_and_keeps_working() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    study_full_day(&app, true);
    app.core
        .update_settings(SettingsPatchDto {
            desired_retention: Some(0.85),
            autoplay: Some(false),
            ..SettingsPatchDto::default()
        })
        .unwrap();

    app.core.reset_all().unwrap();

    assert!(matches!(
        app.core.today_view(true).unwrap_err(),
        CoreError::NoActivePlan
    ));
    let settings = app.core.settings().unwrap();
    assert!(settings.autoplay);
    assert!((settings.desired_retention - 0.9).abs() < 1e-9);
    let stats = app.core.stats_overview().unwrap();
    assert_eq!(stats.total_reviews, 0);
    assert_eq!(stats.kana_mastered, 0);

    // 重置後可以重新開始，append-only 的表也不受影響
    app.start_plan(&plan_input(20, StartLevel::Zero));
    let today = study_full_day(&app, true);
    assert_eq!(today.logical_date, "2026-03-02");
    assert!(Path::new(&app.db_path).exists());
}

/// 第一個單字 first_card 的四個評分間隔（分鐘）。
fn first_card_previews(app: &TestApp) -> Vec<i64> {
    app.start_plan(&plan_input(20, StartLevel::Kana));
    let key = new_content_key(&app.today()).unwrap();
    let session = app.core.new_content_session(key, SEED, true).unwrap();
    let NewContentStepDto::Vocab {
        first_card: Some(card),
        ..
    } = &session.steps[0]
    else {
        panic!("第一步應為帶 first_card 的 Vocab");
    };
    card.rating_previews
        .iter()
        .map(|p| p.interval_minutes)
        .collect()
}

fn set_retention(app: &TestApp, retention: f64) {
    app.core
        .update_settings(SettingsPatchDto {
            desired_retention: Some(retention),
            ..SettingsPatchDto::default()
        })
        .unwrap();
}

#[test]
fn reset_all_returns_the_scheduler_to_the_default_retention() {
    let baseline = first_card_previews(&TestApp::new());
    let raised = TestApp::new();
    set_retention(&raised, 0.95);
    assert_ne!(
        first_card_previews(&raised),
        baseline,
        "保留率要影響間隔，這個測試才有意義"
    );

    let app = TestApp::new();
    set_retention(&app, 0.95);
    app.core.reset_all().unwrap();

    assert_eq!(first_card_previews(&app), baseline);
}

#[test]
fn delete_database_removes_files_and_a_missing_file_is_fine() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("jp_core.db").to_string_lossy().into_owned();
    let core = AppCore::open(CoreConfig {
        db_path: path.clone(),
        utc_offset_minutes: 0,
        fixed_now_utc: None,
    })
    .unwrap();
    assert!(Path::new(&path).exists());
    drop(core);

    delete_database(path.clone()).unwrap();

    assert!(!Path::new(&path).exists());
    delete_database(path).unwrap();
}

#[test]
fn open_rejects_invalid_offsets_and_unusable_paths() {
    let dir = tempfile::tempdir().unwrap();
    let invalid = AppCore::open(CoreConfig {
        db_path: dir.path().join("a.db").to_string_lossy().into_owned(),
        utc_offset_minutes: 900,
        fixed_now_utc: None,
    });
    assert!(matches!(
        invalid.err(),
        Some(CoreError::InvalidInput { .. })
    ));

    let empty = AppCore::open(CoreConfig {
        db_path: String::new(),
        utc_offset_minutes: 0,
        fixed_now_utc: None,
    });
    assert!(matches!(empty.err(), Some(CoreError::InvalidInput { .. })));

    let unusable = AppCore::open(CoreConfig {
        db_path: dir
            .path()
            .join("no/such/dir/a.db")
            .to_string_lossy()
            .into_owned(),
        utc_offset_minutes: 0,
        fixed_now_utc: None,
    });
    assert!(matches!(unusable.err(), Some(CoreError::Storage { .. })));
}

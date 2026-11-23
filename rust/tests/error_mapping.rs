//! §9.2：各層錯誤轉成 `CoreError` 時，Dart 依變體顯示的分類要對。

use jp_content::ContentError;
use jp_core::api::error::CoreError;
use jp_lang::clock::{validate_rollover_hour, validate_utc_offset};
use jp_plan::PlanError;
use jp_quiz::QuizError;
use jp_srs::SrsError;
use jp_store::StoreError;

fn storage() -> StoreError {
    StoreError::Storage {
        message: "disk".to_owned(),
    }
}

#[test]
fn store_errors_keep_their_variant() {
    assert!(matches!(
        CoreError::from(StoreError::StaleCard { card_id: "c".to_owned() }),
        CoreError::StaleCard { card_id } if card_id == "c"
    ));
    assert!(matches!(
        CoreError::from(StoreError::MigrationFailed {
            from_version: 3,
            message: "m".to_owned()
        }),
        CoreError::MigrationFailed {
            from_version: 3,
            ..
        }
    ));
    assert!(matches!(
        CoreError::from(storage()),
        CoreError::Storage { .. }
    ));
    assert!(matches!(
        CoreError::from(StoreError::Internal {
            message: "x".to_owned()
        }),
        CoreError::Internal { .. }
    ));
}

#[test]
fn srs_errors_unwrap_store_errors() {
    assert!(matches!(
        CoreError::from(SrsError::NotFound {
            entity: "card".to_owned(),
            id: "x".to_owned()
        }),
        CoreError::NotFound { .. }
    ));
    assert!(matches!(
        CoreError::from(SrsError::InvalidInput {
            field: "f".to_owned(),
            reason: "r".to_owned()
        }),
        CoreError::InvalidInput { .. }
    ));
    assert!(matches!(
        CoreError::from(SrsError::Internal {
            message: "x".to_owned()
        }),
        CoreError::Internal { .. }
    ));
    assert!(matches!(
        CoreError::from(SrsError::Store(storage())),
        CoreError::Storage { .. }
    ));
}

#[test]
fn missing_plan_becomes_no_active_plan_but_other_not_found_stays() {
    let missing_plan = PlanError::NotFound {
        entity: "plan".to_owned(),
        id: "2026-03-02".to_owned(),
    };
    assert!(matches!(
        CoreError::from(missing_plan),
        CoreError::NoActivePlan
    ));

    let missing_task = PlanError::NotFound {
        entity: "task".to_owned(),
        id: "new:x".to_owned(),
    };
    assert!(matches!(
        CoreError::from(missing_task),
        CoreError::NotFound { entity, .. } if entity == "task"
    ));
}

#[test]
fn plan_errors_unwrap_nested_layers() {
    assert!(matches!(
        CoreError::from(PlanError::InvalidInput {
            field: "f".to_owned(),
            reason: "r".to_owned()
        }),
        CoreError::InvalidInput { .. }
    ));
    assert!(matches!(
        CoreError::from(PlanError::Internal {
            message: "x".to_owned()
        }),
        CoreError::Internal { .. }
    ));
    assert!(matches!(
        CoreError::from(PlanError::Store(storage())),
        CoreError::Storage { .. }
    ));
    assert!(matches!(
        CoreError::from(PlanError::Srs(SrsError::Store(storage()))),
        CoreError::Storage { .. }
    ));
}

#[test]
fn quiz_errors_unwrap_nested_layers() {
    assert!(matches!(
        CoreError::from(QuizError::NotFound {
            entity: "d".to_owned(),
            id: "x".to_owned()
        }),
        CoreError::NotFound { .. }
    ));
    assert!(matches!(
        CoreError::from(QuizError::InvalidInput {
            field: "f".to_owned(),
            reason: "r".to_owned()
        }),
        CoreError::InvalidInput { .. }
    ));
    assert!(matches!(
        CoreError::from(QuizError::Internal {
            message: "x".to_owned()
        }),
        CoreError::Internal { .. }
    ));
    assert!(matches!(
        CoreError::from(QuizError::Store(storage())),
        CoreError::Storage { .. }
    ));
    assert!(matches!(
        CoreError::from(QuizError::Srs(SrsError::Store(storage()))),
        CoreError::Storage { .. }
    ));
}

#[test]
fn content_errors_keep_file_and_detail() {
    let err = ContentError::Corrupt {
        file: "a.json".to_owned(),
        detail: "bad".to_owned(),
    };

    assert!(matches!(
        CoreError::from(err),
        CoreError::ContentCorrupt { file, detail } if file == "a.json" && detail == "bad"
    ));
}

#[test]
fn clock_errors_name_the_offending_field() {
    let offset = validate_utc_offset(900).unwrap_err();
    let hour = validate_rollover_hour(13).unwrap_err();

    assert!(matches!(
        CoreError::from(offset),
        CoreError::InvalidInput { field, .. } if field == "utc_offset_minutes"
    ));
    assert!(matches!(
        CoreError::from(hour),
        CoreError::InvalidInput { field, .. } if field == "day_rollover_hour"
    ));
}

//! 顯示規則、設定與同步工具函式（rust-core.md §9.4、§9.5）。

mod common;

use common::*;
use jp_core::api::dto_content::{MixedSpanDto, ReadingMode};
use jp_core::api::dto_plan::{
    DisplayContext, DisplayPolicyDto, FuriganaMode, RomajiMode, SettingsPatchDto, ThemeMode,
};
use jp_core::api::dto_study::{AnswerDto, QuestionType};
use jp_core::api::error::CoreError;
use jp_core::api::tools_api::{parse_mixed_text, romaji_input_preview, romanize_reading};

fn policy_of(app: &TestApp, lesson: &str) -> DisplayPolicyDto {
    app.core
        .display_policy(DisplayContext {
            lesson_id: lesson.to_owned(),
        })
        .unwrap()
}

#[test]
fn display_policy_follows_the_lesson_table() {
    let app = TestApp::new();

    let kana = policy_of(&app, "le.k01");
    assert_eq!(
        (kana.romaji, kana.furigana, kana.word_spacing),
        (RomajiMode::Shown, FuriganaMode::All, false)
    );
    let l01 = policy_of(&app, "le.l01");
    assert_eq!(
        (l01.romaji, l01.word_spacing),
        (RomajiMode::ShownToggleable, true)
    );
    let l08 = policy_of(&app, "le.l08");
    assert_eq!(
        (l08.romaji, l08.word_spacing),
        (RomajiMode::TapToReveal, false)
    );
    let l21 = policy_of(&app, "le.l21");
    assert_eq!(
        l21.romaji,
        RomajiMode::TapToReveal,
        "ms.kata 未通過且未確認"
    );
    let l31 = policy_of(&app, "le.l31");
    assert_eq!(
        (l31.romaji, l31.furigana),
        (RomajiMode::TapToReveal, FuriganaMode::UnknownOnly)
    );

    let unknown = app.core.display_policy(DisplayContext {
        lesson_id: "le.nope".to_owned(),
    });
    assert!(matches!(unknown.unwrap_err(), CoreError::NotFound { .. }));
}

#[test]
fn romaji_fades_after_confirmation_and_user_overrides_win() {
    let app = TestApp::new();
    let patch = SettingsPatchDto {
        romaji_off_confirmed: Some(true),
        ..SettingsPatchDto::default()
    };
    app.core.update_settings(patch).unwrap();
    assert_eq!(policy_of(&app, "le.l21").romaji, RomajiMode::LongPressOnly);
    assert_eq!(policy_of(&app, "le.l31").romaji, RomajiMode::Hidden);

    app.core
        .update_settings(SettingsPatchDto {
            romaji_override: Some(RomajiMode::Shown),
            furigana_override: Some(FuriganaMode::UnknownOnly),
            ..SettingsPatchDto::default()
        })
        .unwrap();
    let forced = policy_of(&app, "le.l21");
    assert_eq!(
        (forced.romaji, forced.furigana),
        (RomajiMode::Shown, FuriganaMode::UnknownOnly)
    );

    app.core
        .update_settings(SettingsPatchDto {
            clear_romaji_override: true,
            clear_furigana_override: true,
            ..SettingsPatchDto::default()
        })
        .unwrap();
    assert_eq!(policy_of(&app, "le.l21").romaji, RomajiMode::LongPressOnly);
}

#[test]
fn passing_the_katakana_checkpoint_lets_romaji_fade() {
    let app = TestApp::new();
    assert_eq!(policy_of(&app, "le.l21").romaji, RomajiMode::TapToReveal);
    let exam = app
        .core
        .checkpoint_start("ms.kata".into(), SEED, true)
        .unwrap();
    let answers = exam
        .iter()
        .map(|question| AnswerDto {
            reference: question.reference.clone(),
            expected_reps: 0,
            response: correct_payload(question),
            hint_used: false,
            attempts: 1,
            duration_ms: 500,
        })
        .collect();

    let result = app
        .core
        .checkpoint_finish("ms.kata".into(), answers)
        .unwrap();

    assert!(result.passed);
    assert_eq!(policy_of(&app, "le.l21").romaji, RomajiMode::LongPressOnly);
}

#[test]
fn settings_round_trip_and_clear() {
    let app = TestApp::new();

    let defaults = app.core.settings().unwrap();
    assert_eq!(defaults.day_rollover_hour, 4);

    let updated = app
        .core
        .update_settings(SettingsPatchDto {
            day_rollover_hour: Some(0),
            desired_retention: Some(0.8),
            tts_rate: Some(0.7),
            voice_id: Some("ja-1".to_owned()),
            theme_mode: Some(ThemeMode::Dark),
            silent_mode: Some(true),
            kana_time_limit: Some(false),
            show_rating_intervals: Some(true),
            seen_question_hints: Some(vec![QuestionType::KanaRead]),
            ..SettingsPatchDto::default()
        })
        .unwrap();
    assert_eq!(updated.day_rollover_hour, 0);
    assert_eq!(updated.voice_id.as_deref(), Some("ja-1"));
    assert_eq!(updated.theme_mode, ThemeMode::Dark);
    assert_eq!(updated.seen_question_hints, [QuestionType::KanaRead]);
    assert!(updated.silent_mode && !updated.kana_time_limit && updated.show_rating_intervals);

    let clear_voice = SettingsPatchDto {
        clear_voice_id: true,
        ..SettingsPatchDto::default()
    };
    assert!(app
        .core
        .update_settings(clear_voice)
        .unwrap()
        .voice_id
        .is_none());
}

#[test]
fn invalid_settings_are_rejected_without_writing() {
    let app = TestApp::new();
    let invalid = [
        (
            "day_rollover_hour",
            SettingsPatchDto {
                day_rollover_hour: Some(13),
                ..SettingsPatchDto::default()
            },
        ),
        (
            "desired_retention",
            SettingsPatchDto {
                desired_retention: Some(0.5),
                ..SettingsPatchDto::default()
            },
        ),
        (
            "desired_retention",
            SettingsPatchDto {
                desired_retention: Some(f64::NAN),
                ..SettingsPatchDto::default()
            },
        ),
        (
            "tts_rate",
            SettingsPatchDto {
                tts_rate: Some(9.0),
                ..SettingsPatchDto::default()
            },
        ),
    ];

    for (field, patch) in invalid {
        match app.core.update_settings(patch).unwrap_err() {
            CoreError::InvalidInput { field: actual, .. } => assert_eq!(actual, field),
            other => panic!("{other:?}"),
        }
    }

    assert_eq!(app.core.settings().unwrap().day_rollover_hour, 4);
}

#[test]
fn tools_convert_and_fail_soft() {
    assert_eq!(romaji_input_preview("kya".to_owned()), "きゃ");
    assert_eq!(romaji_input_preview("x!!".to_owned()), "x!!");
    assert_eq!(
        romanize_reading("わたし".to_owned(), ReadingMode::Word).as_deref(),
        Some("watashi")
    );
    assert_eq!(
        romanize_reading("こんにち は".to_owned(), ReadingMode::Sentence).as_deref(),
        Some("konnichi wa")
    );
    assert!(romanize_reading("abc".to_owned(), ReadingMode::Word).is_none());

    let spans = parse_mixed_text("看{ja:食べる|たべる}".to_owned());
    assert_eq!(spans.len(), 2);
    assert!(matches!(&spans[0], MixedSpanDto::Zh { text } if text == "看"));
    assert!(
        matches!(&spans[1], MixedSpanDto::Ja { text, ruby } if text == "食べる" && !ruby.is_empty())
    );
    assert!(matches!(
        &parse_mixed_text("壞{ja:".to_owned())[0],
        MixedSpanDto::Zh { .. }
    ));
}

//! 設定、顯示規則、清除資料（§9.4、§5.5）。

use jp_srs::scheduler::{DEFAULT_REQUEST_RETENTION, MAX_REQUEST_RETENTION, MIN_REQUEST_RETENTION};
use jp_store::{PlanRepo, SettingsRepo, SettingsRow};

use super::deps::Deps;
use super::mapping::settings::{furigana_name, hint_name, romaji_name, settings_dto, theme_name};
use crate::api::dto_plan::{
    DisplayContext, DisplayPolicyDto, FuriganaMode, RomajiMode, SettingsDto, SettingsPatchDto,
};
use crate::api::error::CoreError;

const KANA_LESSON_PREFIX: &str = "le.k";
const MAIN_LESSON_PREFIX: &str = "le.l";
const KATA_MILESTONE: &str = "ms.kata";
const MIN_TTS_RATE: f64 = 0.5;
const MAX_TTS_RATE: f64 = 2.0;
const LAST_TOGGLEABLE_LESSON: u32 = 4;
const LAST_SPACED_LESSON: u32 = 6;
const LAST_TAP_LESSON: u32 = 8;
const LAST_LONG_PRESS_LESSON: u32 = 30;

pub(crate) fn settings(deps: &Deps) -> Result<SettingsDto, CoreError> {
    Ok(settings_dto(&deps.repo.get_settings()?))
}

fn validate_patch(patch: &SettingsPatchDto) -> Result<(), CoreError> {
    if let Some(hour) = patch.day_rollover_hour {
        jp_lang::clock::validate_rollover_hour(hour)?;
    }
    if let Some(retention) = patch.desired_retention {
        if !(MIN_REQUEST_RETENTION..=MAX_REQUEST_RETENTION).contains(&retention) {
            let reason = format!("超出範圍：{retention}");
            return Err(CoreError::invalid("desired_retention", reason));
        }
    }
    if let Some(rate) = patch.tts_rate {
        if !(MIN_TTS_RATE..=MAX_TTS_RATE).contains(&rate) {
            return Err(CoreError::invalid("tts_rate", format!("超出範圍：{rate}")));
        }
    }
    Ok(())
}

fn patched_override(
    current: Option<String>,
    new_value: Option<&'static str>,
    clear: bool,
) -> Option<String> {
    if clear {
        None
    } else {
        new_value.map(str::to_owned).or(current)
    }
}

fn apply_patch(row: SettingsRow, patch: SettingsPatchDto) -> SettingsRow {
    SettingsRow {
        day_rollover_hour: patch.day_rollover_hour.unwrap_or(row.day_rollover_hour),
        desired_retention: patch.desired_retention.unwrap_or(row.desired_retention),
        romaji_override: patched_override(
            row.romaji_override,
            patch.romaji_override.map(romaji_name),
            patch.clear_romaji_override,
        ),
        furigana_override: patched_override(
            row.furigana_override,
            patch.furigana_override.map(furigana_name),
            patch.clear_furigana_override,
        ),
        tts_rate: patch.tts_rate.unwrap_or(row.tts_rate),
        autoplay: patch.autoplay.unwrap_or(row.autoplay),
        voice_id: if patch.clear_voice_id {
            None
        } else {
            patch.voice_id.or(row.voice_id)
        },
        theme_mode: patch
            .theme_mode
            .map_or(row.theme_mode, |mode| theme_name(mode).to_owned()),
        silent_mode: patch.silent_mode.unwrap_or(row.silent_mode),
        kana_time_limit: patch.kana_time_limit.unwrap_or(row.kana_time_limit),
        show_rating_intervals: patch
            .show_rating_intervals
            .unwrap_or(row.show_rating_intervals),
        romaji_off_confirmed: patch
            .romaji_off_confirmed
            .unwrap_or(row.romaji_off_confirmed),
        seen_question_hints: patch
            .seen_question_hints
            .map_or(row.seen_question_hints, |hints| {
                hints.into_iter().map(|h| hint_name(h).to_owned()).collect()
            }),
    }
}

pub(crate) fn update_settings(
    deps: &Deps,
    patch: SettingsPatchDto,
) -> Result<SettingsDto, CoreError> {
    validate_patch(&patch)?;
    let retention = patch.desired_retention;
    let next = apply_patch(deps.repo.get_settings()?, patch);
    deps.repo.put_settings(&next)?;
    if let Some(retention) = retention {
        deps.scheduler.set_request_retention(retention)?;
    }
    Ok(settings_dto(&next))
}

const fn policy(
    romaji: RomajiMode,
    furigana: FuriganaMode,
    word_spacing: bool,
) -> DisplayPolicyDto {
    DisplayPolicyDto {
        romaji,
        furigana,
        word_spacing,
    }
}

/// `L09` 起的羅馬字收斂綁定 `ms.kata` 通過或使用者確認（curriculum §10.2）。
fn romaji_can_fade(deps: &Deps, settings: &SettingsRow) -> Result<bool, CoreError> {
    let kata_passed = deps
        .repo
        .milestone_results()?
        .iter()
        .any(|row| row.milestone_id == KATA_MILESTONE && row.passed);
    Ok(kata_passed || settings.romaji_off_confirmed)
}

fn main_lesson_policy(lesson: u32, can_fade: bool) -> DisplayPolicyDto {
    let faded = |mode| {
        if can_fade {
            mode
        } else {
            RomajiMode::TapToReveal
        }
    };
    if lesson <= LAST_TOGGLEABLE_LESSON {
        policy(RomajiMode::ShownToggleable, FuriganaMode::All, true)
    } else if lesson <= LAST_SPACED_LESSON {
        policy(RomajiMode::TapToReveal, FuriganaMode::All, true)
    } else if lesson <= LAST_TAP_LESSON {
        policy(RomajiMode::TapToReveal, FuriganaMode::All, false)
    } else if lesson <= LAST_LONG_PRESS_LESSON {
        policy(faded(RomajiMode::LongPressOnly), FuriganaMode::All, false)
    } else {
        policy(faded(RomajiMode::Hidden), FuriganaMode::UnknownOnly, false)
    }
}

fn lesson_policy(
    deps: &Deps,
    row: &SettingsRow,
    lesson_id: &str,
) -> Result<DisplayPolicyDto, CoreError> {
    if deps.content.lesson(lesson_id).is_none() {
        return Err(CoreError::not_found("lesson", lesson_id));
    }
    if lesson_id.starts_with(KANA_LESSON_PREFIX) {
        return Ok(policy(RomajiMode::Shown, FuriganaMode::All, false));
    }
    let number = lesson_id
        .strip_prefix(MAIN_LESSON_PREFIX)
        .and_then(|digits| digits.parse().ok())
        .ok_or_else(|| CoreError::invalid("lesson_id", format!("不是 L 課：{lesson_id}")))?;
    Ok(main_lesson_policy(number, romaji_can_fade(deps, row)?))
}

/// 使用者設定優先；`word_spacing` 沒有對應的設定（§9.4）。
pub(crate) fn display_policy(
    deps: &Deps,
    context: &DisplayContext,
) -> Result<DisplayPolicyDto, CoreError> {
    let row = deps.repo.get_settings()?;
    let dto = settings_dto(&row);
    let base = lesson_policy(deps, &row, &context.lesson_id)?;
    Ok(DisplayPolicyDto {
        romaji: dto.romaji_override.unwrap_or(base.romaji),
        furigana: dto.furigana_override.unwrap_or(base.furigana),
        word_spacing: base.word_spacing,
    })
}

pub(crate) fn reset_all(deps: &Deps) -> Result<(), CoreError> {
    deps.repo.reset_all()?;
    // 設定也一併清除，排程器要回到預設的保留率
    deps.scheduler
        .set_request_retention(DEFAULT_REQUEST_RETENTION)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// §9.4 的顯示表：每一列的上下界。
    #[test]
    fn main_lesson_policy_matches_each_row_boundary() {
        use FuriganaMode::{All, UnknownOnly};
        use RomajiMode::{Hidden, LongPressOnly, ShownToggleable, TapToReveal};
        let table = [
            (1, ShownToggleable, All, true),
            (4, ShownToggleable, All, true),
            (5, TapToReveal, All, true),
            (6, TapToReveal, All, true),
            (7, TapToReveal, All, false),
            (8, TapToReveal, All, false),
            (9, LongPressOnly, All, false),
            (30, LongPressOnly, All, false),
            (31, Hidden, UnknownOnly, false),
        ];

        for (lesson, romaji, furigana, word_spacing) in table {
            assert_eq!(
                main_lesson_policy(lesson, true),
                policy(romaji, furigana, word_spacing),
                "L{lesson}"
            );
        }
    }

    #[test]
    fn romaji_stays_tappable_until_it_may_fade() {
        for lesson in [9, 30, 31] {
            assert_eq!(
                main_lesson_policy(lesson, false).romaji,
                RomajiMode::TapToReveal,
                "L{lesson}"
            );
        }
        assert_eq!(main_lesson_policy(8, false).romaji, RomajiMode::TapToReveal);
    }
}

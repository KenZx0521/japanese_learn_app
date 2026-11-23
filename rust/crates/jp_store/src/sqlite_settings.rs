//! SettingsRepo 的 SQLite 實作。`app_setting` 一個欄位一列，缺少的 key 取預設值，
//! 所以新增設定不需要遷移；值為 `None` 的選項不存列。

use std::collections::HashMap;
use std::str::FromStr;

use rusqlite::{params, Connection};

use crate::db::SqliteRepository;
use crate::error::{ensure_finite, StoreError};
use crate::records::SettingsRow;
use crate::repo::SettingsRepo;

const DAY_ROLLOVER_HOUR: &str = "day_rollover_hour";
const DESIRED_RETENTION: &str = "desired_retention";
const ROMAJI_OVERRIDE: &str = "romaji_override";
const FURIGANA_OVERRIDE: &str = "furigana_override";
const TTS_RATE: &str = "tts_rate";
const AUTOPLAY: &str = "autoplay";
const VOICE_ID: &str = "voice_id";
const THEME_MODE: &str = "theme_mode";
const SILENT_MODE: &str = "silent_mode";
const KANA_TIME_LIMIT: &str = "kana_time_limit";
const SHOW_RATING_INTERVALS: &str = "show_rating_intervals";
const ROMAJI_OFF_CONFIRMED: &str = "romaji_off_confirmed";
const SEEN_QUESTION_HINTS: &str = "seen_question_hints";

type Stored = HashMap<String, String>;

fn corrupt(key: &str, detail: impl std::fmt::Display) -> StoreError {
    StoreError::storage(format!("invalid setting {key}: {detail}"))
}

fn parsed<T: FromStr>(stored: &Stored, key: &str, default: T) -> Result<T, StoreError>
where
    T::Err: std::fmt::Display,
{
    stored.get(key).map_or(Ok(default), |value| {
        value.parse().map_err(|err| corrupt(key, err))
    })
}

fn text(stored: &Stored, key: &str, default: String) -> String {
    stored.get(key).cloned().unwrap_or(default)
}

fn list(stored: &Stored, key: &str) -> Result<Vec<String>, StoreError> {
    stored.get(key).map_or(Ok(Vec::new()), |value| {
        serde_json::from_str(value).map_err(|err| corrupt(key, err))
    })
}

fn settings_from(stored: &Stored) -> Result<SettingsRow, StoreError> {
    let default = SettingsRow::default();
    Ok(SettingsRow {
        day_rollover_hour: parsed(stored, DAY_ROLLOVER_HOUR, default.day_rollover_hour)?,
        desired_retention: parsed(stored, DESIRED_RETENTION, default.desired_retention)?,
        romaji_override: stored.get(ROMAJI_OVERRIDE).cloned(),
        furigana_override: stored.get(FURIGANA_OVERRIDE).cloned(),
        tts_rate: parsed(stored, TTS_RATE, default.tts_rate)?,
        autoplay: parsed(stored, AUTOPLAY, default.autoplay)?,
        voice_id: stored.get(VOICE_ID).cloned(),
        theme_mode: text(stored, THEME_MODE, default.theme_mode),
        silent_mode: parsed(stored, SILENT_MODE, default.silent_mode)?,
        kana_time_limit: parsed(stored, KANA_TIME_LIMIT, default.kana_time_limit)?,
        show_rating_intervals: parsed(
            stored,
            SHOW_RATING_INTERVALS,
            default.show_rating_intervals,
        )?,
        romaji_off_confirmed: parsed(stored, ROMAJI_OFF_CONFIRMED, default.romaji_off_confirmed)?,
        seen_question_hints: list(stored, SEEN_QUESTION_HINTS)?,
    })
}

fn json_list(key: &str, values: &[String]) -> Result<String, StoreError> {
    serde_json::to_string(values).map_err(|err| corrupt(key, err))
}

fn entries_of(row: &SettingsRow) -> Result<Vec<(&'static str, String)>, StoreError> {
    let mut entries = vec![
        (DAY_ROLLOVER_HOUR, row.day_rollover_hour.to_string()),
        (DESIRED_RETENTION, row.desired_retention.to_string()),
        (TTS_RATE, row.tts_rate.to_string()),
        (AUTOPLAY, row.autoplay.to_string()),
        (THEME_MODE, row.theme_mode.clone()),
        (SILENT_MODE, row.silent_mode.to_string()),
        (KANA_TIME_LIMIT, row.kana_time_limit.to_string()),
        (SHOW_RATING_INTERVALS, row.show_rating_intervals.to_string()),
        (ROMAJI_OFF_CONFIRMED, row.romaji_off_confirmed.to_string()),
        (
            SEEN_QUESTION_HINTS,
            json_list(SEEN_QUESTION_HINTS, &row.seen_question_hints)?,
        ),
    ];
    let optional = [
        (ROMAJI_OVERRIDE, &row.romaji_override),
        (FURIGANA_OVERRIDE, &row.furigana_override),
        (VOICE_ID, &row.voice_id),
    ];
    entries.extend(
        optional
            .into_iter()
            .filter_map(|(key, value)| value.clone().map(|value| (key, value))),
    );
    Ok(entries)
}

fn load_all(conn: &Connection) -> Result<Stored, StoreError> {
    let mut stmt = conn.prepare_cached("SELECT key, value FROM app_setting")?;
    let rows = stmt.query_map([], |row| Ok((row.get(0)?, row.get(1)?)))?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

impl SettingsRepo for SqliteRepository {
    fn get_settings(&self) -> Result<SettingsRow, StoreError> {
        settings_from(&self.with_conn(load_all)?)
    }

    fn put_settings(&self, row: &SettingsRow) -> Result<(), StoreError> {
        ensure_finite(DESIRED_RETENTION, row.desired_retention)?;
        ensure_finite(TTS_RATE, row.tts_rate)?;
        let entries = entries_of(row)?;
        self.with_tx(|tx| {
            tx.execute("DELETE FROM app_setting", [])?;
            let mut insert =
                tx.prepare_cached("INSERT INTO app_setting(key, value) VALUES (?1, ?2)")?;
            for (key, value) in &entries {
                insert.execute(params![key, value])?;
            }
            Ok(())
        })
    }
}

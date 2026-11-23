//! 資料庫表示與領域型別的轉換：時間存 INTEGER（UTC 毫秒），邏輯日存 TEXT（`YYYY-MM-DD`）。

use chrono::{DateTime, NaiveDate, Utc};
use rusqlite::types::Type;
use rusqlite::Row;

pub(crate) fn millis(at: DateTime<Utc>) -> i64 {
    at.timestamp_millis()
}

pub(crate) fn opt_millis(at: Option<DateTime<Utc>>) -> Option<i64> {
    at.map(millis)
}

pub(crate) fn date_text(date: NaiveDate) -> String {
    date.to_string()
}

pub(crate) fn opt_date_text(date: Option<NaiveDate>) -> Option<String> {
    date.map(date_text)
}

fn conversion_error(index: usize, kind: Type, message: String) -> rusqlite::Error {
    rusqlite::Error::FromSqlConversionFailure(index, kind, message.into())
}

pub(crate) fn parse_millis(index: usize, value: i64) -> rusqlite::Result<DateTime<Utc>> {
    DateTime::from_timestamp_millis(value)
        .ok_or_else(|| conversion_error(index, Type::Integer, format!("timestamp {value}")))
}

pub(crate) fn parse_date(index: usize, text: &str) -> rusqlite::Result<NaiveDate> {
    text.parse()
        .map_err(|_| conversion_error(index, Type::Text, format!("date {text}")))
}

pub(crate) fn time_at(row: &Row<'_>, index: usize) -> rusqlite::Result<DateTime<Utc>> {
    parse_millis(index, row.get(index)?)
}

pub(crate) fn opt_time_at(row: &Row<'_>, index: usize) -> rusqlite::Result<Option<DateTime<Utc>>> {
    row.get::<_, Option<i64>>(index)?
        .map(|value| parse_millis(index, value))
        .transpose()
}

pub(crate) fn date_at(row: &Row<'_>, index: usize) -> rusqlite::Result<NaiveDate> {
    parse_date(index, &row.get::<_, String>(index)?)
}

pub(crate) fn opt_date_at(row: &Row<'_>, index: usize) -> rusqlite::Result<Option<NaiveDate>> {
    row.get::<_, Option<String>>(index)?
        .map(|text| parse_date(index, &text))
        .transpose()
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn rejects_malformed_date_text() {
        assert!(parse_date(0, "2026-13-40").is_err());
        assert!(parse_date(0, "soon").is_err());
    }

    #[test]
    fn rejects_timestamp_outside_chrono_range() {
        assert!(parse_millis(0, i64::MAX).is_err());
    }

    proptest! {
        #[test]
        fn millis_round_trip(value in -8_000_000_000_000i64..8_000_000_000_000) {
            let parsed = parse_millis(0, value).unwrap();
            prop_assert_eq!(millis(parsed), value);
        }

        #[test]
        fn dates_round_trip(days in 0i32..3_000_000) {
            let date = NaiveDate::from_num_days_from_ce_opt(days).unwrap();
            prop_assert_eq!(parse_date(0, &date_text(date)).unwrap(), date);
        }
    }
}

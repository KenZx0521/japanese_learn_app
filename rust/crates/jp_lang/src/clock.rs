//! 時間模型（rust-core.md §2）。所有時間只經由 `Clock` 取得。

use std::sync::atomic::{AtomicI32, Ordering};
use std::sync::{Mutex, PoisonError};

use chrono::{DateTime, Duration, NaiveDate, NaiveDateTime, Utc};
use thiserror::Error;

pub const MIN_UTC_OFFSET_MINUTES: i32 = -720;
pub const MAX_UTC_OFFSET_MINUTES: i32 = 840;
pub const MAX_ROLLOVER_HOUR: u32 = 12;
pub const DEFAULT_ROLLOVER_HOUR: u32 = 4;

/// 邏輯日。DTO 與資料庫一律用 `YYYY-MM-DD` 字串（`to_string()` 的結果）。
pub type LogicalDate = NaiveDate;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
pub enum ClockError {
    #[error("UTC 時差超出範圍：{minutes} 分鐘")]
    OffsetOutOfRange { minutes: i32 },
    #[error("換日時間超出範圍：{hour} 點")]
    RolloverOutOfRange { hour: u32 },
}

pub fn validate_utc_offset(minutes: i32) -> Result<(), ClockError> {
    if (MIN_UTC_OFFSET_MINUTES..=MAX_UTC_OFFSET_MINUTES).contains(&minutes) {
        Ok(())
    } else {
        Err(ClockError::OffsetOutOfRange { minutes })
    }
}

pub fn validate_rollover_hour(hour: u32) -> Result<(), ClockError> {
    if hour <= MAX_ROLLOVER_HOUR {
        Ok(())
    } else {
        Err(ClockError::RolloverOutOfRange { hour })
    }
}

pub trait Clock: Send + Sync {
    fn now_utc(&self) -> DateTime<Utc>;
    fn utc_offset_minutes(&self) -> i32;
}

/// 正式環境的時鐘。時差由 Dart 傳入，不依賴各平台的時區資料庫。
#[derive(Debug)]
pub struct SystemClock {
    offset_minutes: AtomicI32,
}

impl SystemClock {
    pub fn new(offset_minutes: i32) -> Result<Self, ClockError> {
        validate_utc_offset(offset_minutes)?;
        Ok(Self {
            offset_minutes: AtomicI32::new(offset_minutes),
        })
    }

    pub fn set_utc_offset(&self, minutes: i32) -> Result<(), ClockError> {
        validate_utc_offset(minutes)?;
        self.offset_minutes.store(minutes, Ordering::Relaxed);
        Ok(())
    }
}

impl Clock for SystemClock {
    #[allow(clippy::disallowed_methods)] // 全專案唯一允許讀取系統時間的地方
    fn now_utc(&self) -> DateTime<Utc> {
        Utc::now()
    }

    fn utc_offset_minutes(&self) -> i32 {
        self.offset_minutes.load(Ordering::Relaxed)
    }
}

/// 測試用的時鐘，時刻只隨 `advance` 改變。
#[derive(Debug)]
pub struct FixedClock {
    now: Mutex<DateTime<Utc>>,
    offset_minutes: i32,
}

impl FixedClock {
    pub fn new(now: DateTime<Utc>, offset_minutes: i32) -> Self {
        Self {
            now: Mutex::new(now),
            offset_minutes,
        }
    }

    /// `delta` 可為負，用來模擬時鐘倒退。
    pub fn advance(&self, delta: Duration) {
        let mut now = self.now.lock().unwrap_or_else(PoisonError::into_inner);
        *now += delta;
    }
}

impl Clock for FixedClock {
    fn now_utc(&self) -> DateTime<Utc> {
        *self.now.lock().unwrap_or_else(PoisonError::into_inner)
    }

    fn utc_offset_minutes(&self) -> i32 {
        self.offset_minutes
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DayContext {
    pub now: DateTime<Utc>,
    pub utc_offset_minutes: i32,
    pub rollover_hour: u32,
}

impl DayContext {
    pub fn from_clock<C: Clock + ?Sized>(clock: &C, rollover_hour: u32) -> Self {
        Self {
            now: clock.now_utc(),
            utc_offset_minutes: clock.utc_offset_minutes(),
            rollover_hour,
        }
    }

    /// logical_date(t) = (t + offset - rollover_hour).date()
    pub fn logical_date_of(&self, at: DateTime<Utc>) -> LogicalDate {
        (at.naive_utc() + self.offset() - self.rollover()).date()
    }

    pub fn today(&self) -> LogicalDate {
        self.logical_date_of(self.now)
    }

    /// end_of_day_utc(d) = (d + 1天)T00:00 + rollover_hour - offset
    pub fn end_of_day_utc(&self, date: LogicalDate) -> DateTime<Utc> {
        (start_of(date) + Duration::days(1) + self.rollover() - self.offset()).and_utc()
    }

    pub fn end_of_today_utc(&self) -> DateTime<Utc> {
        self.end_of_day_utc(self.today())
    }

    fn offset(&self) -> Duration {
        Duration::minutes(i64::from(self.utc_offset_minutes))
    }

    fn rollover(&self) -> Duration {
        Duration::hours(i64::from(self.rollover_hour))
    }
}

fn start_of(date: LogicalDate) -> NaiveDateTime {
    date.and_time(chrono::NaiveTime::MIN)
}

//! 學習日與 `weekday_mask`。bit0＝週一 … bit6＝週日。

use chrono::{Datelike, Duration, NaiveDate};
use jp_store::PlanVersionRow;

use crate::error::PlanError;

pub const ALL_DAYS_MASK: u8 = 0b111_1111;
const DAYS_IN_WEEK: u32 = 7;

fn bit_of(date: NaiveDate) -> u8 {
    1 << date.weekday().num_days_from_monday()
}

pub fn is_study_day(mask: u8, date: NaiveDate) -> bool {
    mask & bit_of(date) != 0
}

/// `date` 之後（不含）最近的學習日；`mask` 為 0 時回 `None`。
pub fn next_study_date(mask: u8, after: NaiveDate) -> Option<NaiveDate> {
    (1..=i64::from(DAYS_IN_WEEK))
        .map(|offset| after + Duration::days(offset))
        .find(|date| is_study_day(mask, *date))
}

/// DTO 的 `weekdays`（1＝週一 … 7＝週日）轉成 mask。
pub fn mask_from_weekdays(weekdays: &[u32]) -> Result<u8, PlanError> {
    if weekdays.is_empty() {
        return Err(PlanError::invalid("weekdays", "至少要選一天"));
    }
    weekdays.iter().try_fold(0u8, |mask, day| {
        if (1..=DAYS_IN_WEEK).contains(day) {
            Ok(mask | (1 << (day - 1)))
        } else {
            Err(PlanError::invalid("weekdays", format!("超出範圍：{day}")))
        }
    })
}

pub fn weekdays_from_mask(mask: u8) -> Vec<u32> {
    (1..=DAYS_IN_WEEK)
        .filter(|day| mask & (1 << (day - 1)) != 0)
        .collect()
}

/// 依日期查生效的 `weekday_mask`，事後改計畫不會回溯改寫過去（§7.6）。
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct PlanHistory {
    versions: Vec<(NaiveDate, i64, u8)>,
}

impl PlanHistory {
    pub fn from_rows(rows: &[PlanVersionRow]) -> Self {
        let mut versions: Vec<_> = rows
            .iter()
            .map(|row| (row.effective_from, row.id, row.weekday_mask))
            .collect();
        versions.sort_unstable();
        Self { versions }
    }

    /// 同一天多筆取 id 最大者。
    pub fn mask_on(&self, date: NaiveDate) -> Option<u8> {
        self.versions
            .iter()
            .rev()
            .find(|(from, _, _)| *from <= date)
            .map(|(_, _, mask)| *mask)
    }

    /// 第一個計畫生效前一律不是學習日。
    pub fn is_study_day(&self, date: NaiveDate) -> bool {
        self.mask_on(date)
            .is_some_and(|mask| is_study_day(mask, date))
    }
}

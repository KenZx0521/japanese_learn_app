//! 連續天數（§7.6）。

use std::collections::BTreeSet;

use chrono::{Duration, NaiveDate};

pub fn current_streak(
    active: &BTreeSet<NaiveDate>,
    today: NaiveDate,
    is_study_day: impl Fn(NaiveDate) -> bool,
) -> u32 {
    let (Some(first), Some(last)) = (active.iter().next(), active.iter().next_back()) else {
        return 0;
    };
    let first = *first;
    // 時區往西會讓今天早於最後一個活躍日，從今天起算會漏掉那些日子
    let mut cur = today.max(*last);
    let mut count = 0;
    while cur >= first {
        if active.contains(&cur) {
            count += 1;
        } else if cur != today && is_study_day(cur) {
            break;
        }
        cur = cur.pred_opt().expect("邏輯日不可能到 chrono 下限");
    }
    count
}

fn missed_study_day_between(
    from: NaiveDate,
    to: NaiveDate,
    is_study_day: &impl Fn(NaiveDate) -> bool,
) -> bool {
    (1..(to - from).num_days()).any(|offset| is_study_day(from + Duration::days(offset)))
}

/// 掃描 `active` 一次，缺席的學習日切斷連續，休息日透明。
pub fn best_streak(active: &BTreeSet<NaiveDate>, is_study_day: impl Fn(NaiveDate) -> bool) -> u32 {
    let mut best = 0;
    let mut run = 0;
    let mut previous: Option<NaiveDate> = None;
    for &date in active {
        let continues =
            previous.is_some_and(|prev| !missed_study_day_between(prev, date, &is_study_day));
        run = if continues { run + 1 } else { 1 };
        best = best.max(run);
        previous = Some(date);
    }
    best
}

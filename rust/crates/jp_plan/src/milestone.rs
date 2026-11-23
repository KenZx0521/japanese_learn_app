//! 里程碑的 `Checkpoint` 任務條件（§7.4）與預測欄位（§7.5）。

use std::collections::HashSet;

use chrono::NaiveDate;
use jp_content::schema::MilestoneDef;
use jp_content::ContentStore;
use jp_store::MilestoneResultRow;

use crate::forecast::Forecast;
use crate::state::CursorState;

/// 引導 placement 的紀錄早於該課完成日，不會擋住之後的畢業考（RULINGS 第三輪）。
pub fn due_checkpoints<'c>(
    state: &CursorState,
    results: &[MilestoneResultRow],
    dismissed: &HashSet<String>,
    content: &'c ContentStore,
) -> Vec<&'c MilestoneDef> {
    let is_due = |m: &MilestoneDef| {
        let Some(completed) = state.completed.get(&m.lesson) else {
            return false;
        };
        !state.skipped.contains(&m.lesson)
            && !dismissed.contains(&m.id)
            && !results
                .iter()
                .any(|r| r.milestone_id == m.id && r.logical_date >= *completed)
    };
    content.milestones().iter().filter(|m| is_due(m)).collect()
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MilestoneOutlook {
    pub id: String,
    pub forecast_date: Option<NaiveDate>,
    pub planned_date: Option<NaiveDate>,
    pub delay_days: i32,
}

fn date_for(rows: &[(String, NaiveDate)], id: &str) -> Option<NaiveDate> {
    rows.iter()
        .find(|(row_id, _)| row_id == id)
        .map(|(_, date)| *date)
}

/// 依 `milestones` 的順序合併預測與基準線。
pub fn milestone_outlook(
    forecast: &Forecast,
    baseline: &[(String, NaiveDate)],
    content: &ContentStore,
) -> Vec<MilestoneOutlook> {
    content
        .milestones()
        .iter()
        .map(|m| {
            let forecast_date = date_for(&forecast.milestones, &m.id);
            let planned_date = date_for(baseline, &m.id);
            let delay = match (forecast_date, planned_date) {
                (Some(f), Some(p)) => (f - p).num_days(),
                _ => 0,
            };
            MilestoneOutlook {
                id: m.id.clone(),
                forecast_date,
                planned_date,
                delay_days: i32::try_from(delay).expect("里程碑日差不可能超過 i32"),
            }
        })
        .collect()
}

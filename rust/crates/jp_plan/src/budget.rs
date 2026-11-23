//! 每日預算（§7.2）。

use chrono::{Duration, NaiveDate};
use jp_content::schema::PlanPresetDef;
use serde::{Deserialize, Serialize};

use crate::calendar::PlanHistory;

pub const AUTO_CARD_SECONDS: u32 = 8;
pub const USE_CARD_SECONDS: u32 = 25;
pub const BACKLOG_FACTOR: u32 = 2;
/// 到期數超過這個倍數的 `capacity` 時，`ReviewBacklog` 不論第幾天都不給新內容。
/// 倍數由學習迴路模擬選定（RULINGS O12）。
pub const BACKLOG_PAUSE_FACTOR: u32 = 5;
pub const RETURN_AFTER_MISSED_DAYS: u32 = 3;
pub const MINIMAL_FROM_RECOVERY_DAY: u32 = 3;
/// 收尾新卡至多用 review 秒數的一半（§7.2，review_rust R2-H1）。
pub const TAIL_SHARE_DIVISOR: u32 = 2;

const SECONDS_PER_MINUTE: f64 = 60.0;
const USE_FACET: &str = "use";
const KANA_STAGE: &str = "st.s0";

struct StageRatio {
    new: f64,
    drill: f64,
    listen: f64,
}

/// curriculum §11.2。S2 用 `preset.split`，回 `None`。
/// S0 的 review 40%：L07 之後的片假名課也是 S0，那時已有 L01–L07 的字卡要複習（RULINGS O11）。
fn stage_ratio(stage: &str) -> Option<StageRatio> {
    let ratio = |new, drill, listen| Some(StageRatio { new, drill, listen });
    match stage {
        KANA_STAGE => ratio(0.60, 0.0, 0.0),
        "st.s1" => ratio(0.25, 0.25, 0.10),
        "st.s3" => ratio(0.20, 0.15, 0.20),
        _ => None,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Split {
    pub new: f64,
    pub review: f64,
    pub drill: f64,
    pub listen: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NewContentMode {
    Full,
    Minimal,
    None,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryReason {
    ReviewBacklog,
    ReturnAfterBreak,
    UnseenNewCards,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DayBudget {
    pub split: Split,
    pub review_cap: u32,
    /// 積壓判定用的複習容量（階段配比、不扣收尾新卡）。舊快照沒有這欄時為 0。
    #[serde(default)]
    pub capacity: u32,
    pub new_words_limit: u32,
    pub kana_chars_limit: u32,
    pub new_content: NewContentMode,
    pub recovery_reason: Option<RecoveryReason>,
    pub recovery_days: u32,
}

/// 四捨五入到 0.5 分。
pub fn round_half(minutes: f64) -> f64 {
    (minutes * 2.0).round() / 2.0
}

/// S2 用 `preset.split`，其他階段依 curriculum §11.2 比例換算，餘數歸複習。
pub fn stage_split(preset: &PlanPresetDef, stage: Option<&str>) -> Split {
    let Some(ratio) = stage.and_then(stage_ratio) else {
        return Split {
            new: f64::from(preset.split.new),
            review: f64::from(preset.split.review),
            drill: f64::from(preset.split.drill),
            listen: f64::from(preset.split.listen),
        };
    };
    let total = f64::from(preset.minutes);
    let new = round_half(total * ratio.new);
    let drill = round_half(total * ratio.drill);
    let listen = round_half(total * ratio.listen);
    Split {
        new,
        review: total - new - drill - listen,
        drill,
        listen,
    }
}

fn card_seconds(facet: &str) -> u32 {
    if facet == USE_FACET {
        USE_CARD_SECONDS
    } else {
        AUTO_CARD_SECONDS
    }
}

fn review_seconds(review_minutes: f64) -> u32 {
    (review_minutes * SECONDS_PER_MINUTE).floor() as u32
}

/// 收尾新卡一天至多用掉 review 秒數的 `1 / TAIL_SHARE_DIVISOR`（§7.2），以 8 秒一張換算。
/// 長期無聲後打開聲音、上百張 `:listen` 新卡同時可取時，分散到之後幾天。
pub fn tail_card_limit(review_minutes: f64) -> u32 {
    review_seconds(review_minutes) / (TAIL_SHARE_DIVISOR * AUTO_CARD_SECONDS)
}

/// `due_facets` 依 `(due_at, card_id)` 排序。
pub fn review_cap(review_minutes: f64, due_facets: &[String]) -> u32 {
    review_cap_after_tail(review_minutes, 0, due_facets)
}

/// 先從 review 秒數扣掉收尾新卡（至多 `tail_card_limit` 張，每張 8 秒），再換算張數（RULINGS O11）。
/// 這樣 `estimate_review_minutes` 加回收尾新卡後仍不超過 review 額度（curriculum §11.3-2）。
pub fn review_cap_after_tail(review_minutes: f64, tail_cards: u32, due_facets: &[String]) -> u32 {
    let reserved = tail_cards.min(tail_card_limit(review_minutes));
    let budget = review_seconds(review_minutes).saturating_sub(reserved * AUTO_CARD_SECONDS);
    let mut spent = 0;
    let mut count = 0;
    let mut all_fit = true;
    for facet in due_facets {
        let cost = card_seconds(facet);
        if spent + cost > budget {
            all_fit = false;
            break;
        }
        spent += cost;
        count += 1;
    }
    if all_fit {
        count += (budget - spent) / AUTO_CARD_SECONDS;
    }
    count.max(1)
}

/// 前 `cap` 張到期卡的時間加上 `new_cards × 8` 秒，四捨五入到 0.5 分。
pub fn estimate_review_minutes(due_facets: &[String], cap: u32, new_cards: u32) -> f64 {
    let due_seconds: u32 = due_facets
        .iter()
        .take(cap as usize)
        .map(|facet| card_seconds(facet))
        .sum();
    seconds_to_half_minutes(due_seconds + new_cards * AUTO_CARD_SECONDS)
}

/// `new_cards × 8` 秒換成分鐘，四捨五入到 0.5。
pub fn new_cards_minutes(new_cards: u32) -> f64 {
    seconds_to_half_minutes(new_cards * AUTO_CARD_SECONDS)
}

fn seconds_to_half_minutes(seconds: u32) -> f64 {
    round_half(f64::from(seconds) / SECONDS_PER_MINUTE)
}

/// 最後活躍日到今天之間（兩端不含）排定的學習日數。
pub fn missed_study_days(
    last_active: Option<NaiveDate>,
    today: NaiveDate,
    history: &PlanHistory,
) -> u32 {
    let Some(last) = last_active else {
        return 0;
    };
    let gap = (today - last).num_days();
    let missed = (1..gap)
        .filter(|offset| history.is_study_day(last + Duration::days(*offset)))
        .count();
    u32::try_from(missed).expect("缺席天數不可能超過 u32")
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RecoveryFacts {
    pub due_reviews: u32,
    /// 已扣收尾新卡的 `review_cap`，回鍋當天減半後就是當天的上限。
    pub review_cap: u32,
    /// 扣收尾新卡之前的複習容量，`ReviewBacklog` 的 2 倍線與暫停線都以它為準。
    pub capacity: u32,
    /// 收尾可取的新卡。回鍋要有卡可碰（到期卡或這些新卡），見 `is_return_after_break`。
    pub tail_new_cards: u32,
    pub unseen_new: u32,
    pub new_words_limit: u32,
    pub missed_study_days: u32,
    pub previous_recovery_days: u32,
    /// 休息日不遞增 `recovery_days`，也不併入複習（RULINGS O12）。
    pub is_study_day: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Recovery {
    pub reason: Option<RecoveryReason>,
    pub days: u32,
    pub mode: NewContentMode,
    pub review_cap: u32,
    pub capacity: u32,
    /// 到期數 > `BACKLOG_FACTOR × capacity`，不論原因標籤（回鍋日也算，RULINGS O12）。
    pub backlog: bool,
    pub is_study_day: bool,
}

impl Recovery {
    /// 學習日積壓且今天沒有新內容：當天分鐘全部給複習（RULINGS O11）。回鍋日也是（O12）；
    /// 休息日不併入，複習上限照階段配比。
    pub fn reviews_only(&self) -> bool {
        self.is_study_day && self.backlog && self.mode == NewContentMode::None
    }

    /// 換成另一個尚未減半的 `review_cap`（例如只排複習時依合併後的分鐘重算），回鍋當天照樣減半。
    pub fn with_review_cap(self, review_cap: u32) -> Self {
        Self {
            review_cap: halved_on_return(self.reason, review_cap),
            ..self
        }
    }
}

/// 回鍋當天 `review_cap` 減半（`max(floor(cap / 2), 1)`），避免一次面對全部積壓。
fn halved_on_return(reason: Option<RecoveryReason>, review_cap: u32) -> u32 {
    if reason == Some(RecoveryReason::ReturnAfterBreak) {
        (review_cap / 2).max(1)
    } else {
        review_cap
    }
}

/// 只排複習的日子：new、drill、listen 都併入 review，總分鐘不變。
pub fn review_only_split(split: &Split) -> Split {
    Split {
        new: 0.0,
        review: split.new + split.review + split.drill + split.listen,
        drill: 0.0,
        listen: 0.0,
    }
}

/// 缺席夠久、而且今天有卡可碰。什麼卡都沒有時今天做不了事、不會變成活躍日，
/// 判回鍋的話天天都是回鍋，永遠拿不到新內容（RULINGS O12）。
fn is_return_after_break(facts: &RecoveryFacts) -> bool {
    facts.missed_study_days >= RETURN_AFTER_MISSED_DAYS
        && facts.due_reviews + facts.tail_new_cards > 0
}

fn recovery_reason(facts: &RecoveryFacts) -> Option<RecoveryReason> {
    if is_return_after_break(facts) {
        Some(RecoveryReason::ReturnAfterBreak)
    } else if facts.due_reviews > BACKLOG_FACTOR * facts.capacity {
        Some(RecoveryReason::ReviewBacklog)
    } else if facts.unseen_new > facts.new_words_limit {
        Some(RecoveryReason::UnseenNewCards)
    } else {
        None
    }
}

/// 積壓超過 `BACKLOG_PAUSE_FACTOR × capacity` 時不論第幾天都不給新內容。
fn new_content_mode(
    reason: Option<RecoveryReason>,
    days: u32,
    facts: &RecoveryFacts,
) -> NewContentMode {
    let over_pause_line = reason == Some(RecoveryReason::ReviewBacklog)
        && facts.due_reviews > BACKLOG_PAUSE_FACTOR * facts.capacity;
    match reason {
        None => NewContentMode::Full,
        Some(_) if over_pause_line => NewContentMode::None,
        Some(_) if days < MINIMAL_FROM_RECOVERY_DAY => NewContentMode::None,
        Some(_) => NewContentMode::Minimal,
    }
}

/// §7.2 接續規則：受限 +1、不受限歸 0、回鍋當天固定為 1；休息日維持前一筆的值（RULINGS O12）。
/// 回鍋落在休息日歸 0，下個學習日才從 1 起算，缺席前的舊值不帶過這段缺席。
fn recovery_days(reason: Option<RecoveryReason>, facts: &RecoveryFacts) -> u32 {
    match reason {
        Some(RecoveryReason::ReturnAfterBreak) if !facts.is_study_day => 0,
        _ if !facts.is_study_day => facts.previous_recovery_days,
        None => 0,
        Some(RecoveryReason::ReturnAfterBreak) => 1,
        Some(_) => facts.previous_recovery_days + 1,
    }
}

/// 三種受限條件、`recovery_days` 接續、積壓與回鍋當天 `review_cap` 減半。
pub fn assess_recovery(facts: &RecoveryFacts) -> Recovery {
    let reason = recovery_reason(facts);
    let days = recovery_days(reason, facts);
    Recovery {
        reason,
        days,
        mode: new_content_mode(reason, days, facts),
        review_cap: halved_on_return(reason, facts.review_cap),
        capacity: facts.capacity,
        backlog: facts.due_reviews > BACKLOG_FACTOR * facts.capacity,
        is_study_day: facts.is_study_day,
    }
}

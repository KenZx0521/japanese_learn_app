//! 真實內容（`jp_content::manifest::CONTENT_FILES`）的載入，與用「再學一批」逐片走主線。

use std::sync::OnceLock;

use jp_content::manifest::CONTENT_FILES;
use jp_content::schema::ContentStage;
use jp_content::{load_content, ContentStore};
use jp_core::api::core::AppCore;
use jp_core::api::dto_plan::{TaskDto, TodayViewDto};
use jp_core::api::dto_study::{NewContentSessionDto, NewContentStepDto};

use super::{task_done, task_key, SEED};

const MAX_SLICES: usize = 1_000;
const TASK_MS: u32 = 60_000;
const MAIN_LESSON_PREFIX: &str = "le.l";
const AUDIO: bool = true;

/// 嵌入的全部 JSON，依指定階段過濾、驗證後建立索引。
pub fn load_real(stage: ContentStage) -> ContentStore {
    load_content(CONTENT_FILES, stage)
        .unwrap_or_else(|err| panic!("真實 {} 內容應可載入：{err}", stage.name()))
}

/// 同一個測試執行檔只解析一次 `p0`。
pub fn p0_content() -> ContentStore {
    static P0: OnceLock<ContentStore> = OnceLock::new();
    P0.get_or_init(|| load_real(ContentStage::P0)).clone()
}

pub fn p0a_content() -> ContentStore {
    load_real(ContentStage::P0a)
}

/// `course.order` 中的 L 課，依課程順序。
pub fn main_lessons(content: &ContentStore) -> Vec<String> {
    content
        .course()
        .order
        .iter()
        .filter(|id| id.starts_with(MAIN_LESSON_PREFIX))
        .cloned()
        .collect()
}

/// 一天的新內容或整合切片。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SliceRecord {
    Vocab {
        lesson_id: String,
        words: Vec<String>,
        grammar: Vec<String>,
    },
    Integration {
        lesson_id: String,
        day_no: u32,
        phases: Vec<u32>,
        dialogue_id: Option<String>,
    },
}

impl SliceRecord {
    pub fn lesson_id(&self) -> &str {
        match self {
            Self::Vocab { lesson_id, .. } | Self::Integration { lesson_id, .. } => lesson_id,
        }
    }
}

/// 同一個邏輯日內做完今日任務，再用 `learn_more` 一片接一片取下去，直到 `stop` 成立或沒有下一片。
/// 時鐘不動就沒有到期複習與積壓，`new_content` 一直是 `Full`；`learn_more` 的額度與隔天的切片
/// 相同（rust-core §7.4），所以每一片就是正常使用時的一天。
pub fn walk_slices(core: &AppCore, stop: impl Fn(&AppCore) -> bool) -> Vec<SliceRecord> {
    let mut slices = Vec::new();
    let mut view = core.today_view(AUDIO).unwrap();
    for _ in 0..MAX_SLICES {
        let (records, latest) = finish_open_tasks(core, &view);
        slices.extend(records);
        if stop(core) || !latest.can_learn_more {
            return slices;
        }
        view = core.learn_more(AUDIO).unwrap();
    }
    panic!("{MAX_SLICES} 片內沒有走完");
}

/// 擋住 `learn_more` 的任務（§7.4）。
fn blocks_learn_more(task: &TaskDto) -> bool {
    matches!(
        task,
        TaskDto::Review { .. }
            | TaskDto::NewContent { .. }
            | TaskDto::Integration { .. }
            | TaskDto::Drill { .. }
            | TaskDto::Listen { .. }
    )
}

fn finish_open_tasks(core: &AppCore, view: &TodayViewDto) -> (Vec<SliceRecord>, TodayViewDto) {
    view.tasks
        .iter()
        .filter(|task| blocks_learn_more(task) && !task_done(task))
        .fold((Vec::new(), view.clone()), |(records, _), task| {
            let record = record_slice(core, task);
            let latest = core
                .complete_task(task_key(task).to_owned(), TASK_MS, AUDIO)
                .unwrap();
            (records.into_iter().chain(record).collect(), latest)
        })
}

fn record_slice(core: &AppCore, task: &TaskDto) -> Option<SliceRecord> {
    match task {
        TaskDto::NewContent {
            key,
            lesson_id,
            words,
            grammar,
            kana,
            rules,
            ..
        } => {
            assert_eq!((*kana, *rules), (0, 0), "{key}：只走 L 課");
            let session = core.new_content_session(key.clone(), SEED, AUDIO).unwrap();
            let record = vocab_record(&session);
            let SliceRecord::Vocab {
                lesson_id: listed,
                words: taught_words,
                grammar: taught_grammar,
            } = &record
            else {
                unreachable!("vocab_record 只回 Vocab");
            };
            assert_eq!(listed, lesson_id, "{key}：session 與任務的課不同");
            assert_eq!(
                (taught_words.len(), taught_grammar.len()),
                (*words as usize, *grammar as usize),
                "{key}：任務列出的筆數與 session 的步驟不符"
            );
            Some(record)
        }
        TaskDto::Integration {
            key,
            lesson_id,
            dialogue_id,
            phases,
            ..
        } => Some(SliceRecord::Integration {
            lesson_id: lesson_id.clone(),
            day_no: integration_day_no(key),
            phases: phases.clone(),
            dialogue_id: dialogue_id.clone(),
        }),
        _ => None,
    }
}

/// key 為 `integration:<lesson_id>:<day_no>`（rust-core §7.4）。
fn integration_day_no(key: &str) -> u32 {
    key.rsplit(':')
        .next()
        .and_then(|day| day.parse().ok())
        .unwrap_or_else(|| panic!("整合任務 key 格式不符：{key}"))
}

fn vocab_record(session: &NewContentSessionDto) -> SliceRecord {
    let words = session
        .steps
        .iter()
        .filter_map(|step| match step {
            NewContentStepDto::Vocab { detail, .. } => Some(detail.summary.id.clone()),
            _ => None,
        })
        .collect();
    let grammar = session
        .steps
        .iter()
        .filter_map(|step| match step {
            NewContentStepDto::Grammar { detail, .. } => Some(detail.summary.id.clone()),
            _ => None,
        })
        .collect();
    SliceRecord::Vocab {
        lesson_id: session.lesson_id.clone(),
        words,
        grammar,
    }
}

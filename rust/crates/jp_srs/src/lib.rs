//! 間隔重複（rust-core.md §6）：`CardId`、rs-fsrs 包裝、內容→卡片、佇列、作答流程與假名熟練。

pub mod card_id;
pub mod error;
pub mod facets;
pub mod kana_mastery;
pub mod queue;
pub mod review;
pub mod scheduler;
pub mod use_cards;

pub use card_id::{CardId, Facet};
pub use error::SrsError;
pub use scheduler::{CardState, FsrsScheduler, Outcome, Rating, SrsScheduler, SrsState};

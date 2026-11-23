//! SQLite 持久層：連線、遷移、Repository traits 與 record 型別。不依賴 jp_content。

mod convert;
mod db;
mod error;
mod migrate;
mod plan_progress;
mod plan_versions;
mod records;
mod repo;
mod sqlite_activity;
mod sqlite_plan;
mod sqlite_settings;
mod sqlite_srs;
mod srs_write;

pub use db::{delete_database, SqliteRepository};
pub use error::StoreError;
pub use migrate::LATEST_SCHEMA_VERSION;
pub use records::*;
pub use repo::{ActivityRepo, PlanRepo, QueueFilter, Repository, SettingsRepo, SrsRepo};

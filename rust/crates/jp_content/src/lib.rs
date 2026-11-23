//! 內容載入：嵌入的 JSON、結構定義、`ContentStore` 與索引。

#[cfg(feature = "tooling")]
pub mod disk;
pub mod error;
mod filter;
#[cfg(feature = "tooling")]
pub mod lint;
mod load;
pub mod manifest;
pub mod mixed;
mod raw;
mod refs;
#[cfg(feature = "tooling")]
pub mod scan;
pub mod schema;
pub mod sentence;
pub mod speech;
pub mod store;
#[cfg(feature = "test-support")]
pub mod test_support;
mod validate;

pub use error::ContentError;
pub use load::{load_content, load_embedded};
pub use store::ContentStore;

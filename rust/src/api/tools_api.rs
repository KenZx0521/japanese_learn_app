//! 不碰鎖與 IO 的微秒級工具函式，在呼叫端執行緒同步執行（rust-core.md §9.1）。

use flutter_rust_bridge::frb;
use jp_lang::kana::{romaji_to_hiragana, to_romaji_reading};

use super::dto_content::{MixedSpanDto, ReadingMode};
use crate::app::mapping::enums::reading_mode;
use crate::app::mapping::sentence::mixed_span_dto;

/// 打字即時預覽，失敗回原字串。
#[frb(sync)]
pub fn romaji_input_preview(input: String) -> String {
    romaji_to_hiragana(&input).unwrap_or(input)
}

#[frb(sync)]
pub fn romanize_reading(reading: String, mode: ReadingMode) -> Option<String> {
    to_romaji_reading(&reading, reading_mode(mode)).ok()
}

/// `{ja:…}` 標記，語法錯誤時整段回 `Zh`。
#[frb(sync)]
pub fn parse_mixed_text(input: String) -> Vec<MixedSpanDto> {
    jp_content::mixed::parse_mixed_text(&input)
        .iter()
        .map(mixed_span_dto)
        .collect()
}

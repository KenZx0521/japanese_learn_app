//! 假名與羅馬字引擎（rust-core.md §4）。

mod furigana;
mod grade;
mod reverse;
mod romanize;
mod table;

pub use furigana::{furigana, furigana_or_whole, Ruby};
pub use grade::typed_answer_matches;
pub use reverse::{romaji_to_hiragana, RomajiError};
pub use romanize::{
    reading_mode_of, romanize_words, to_hiragana, to_romaji_reading, to_romaji_sentence,
    to_romaji_word, KanaError, Morph, ReadingMode, Word, FIXED_WA_WORDS,
};
pub use table::{is_kana_text, is_punct_text};

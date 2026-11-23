//! 內容列舉，JSON 一律 snake_case。

use serde::Deserialize;

/// 內容階段，`P0a < P0 < Full`。
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContentStage {
    P0a,
    P0,
    Full,
}

impl ContentStage {
    /// 解析 `CONTENT_STAGE` 的值；無效值回 `None`。
    pub fn parse(name: &str) -> Option<Self> {
        match name {
            "p0a" => Some(Self::P0a),
            "p0" => Some(Self::P0),
            "full" => Some(Self::Full),
            _ => None,
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            Self::P0a => "p0a",
            Self::P0 => "p0",
            Self::Full => "full",
        }
    }
}

macro_rules! content_enum {
    ($($name:ident { $($variant:ident),+ $(,)? })+) => {
        $(
            #[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Deserialize)]
            #[serde(rename_all = "snake_case")]
            pub enum $name { $($variant),+ }
        )+
    };
}

content_enum! {
    Jlpt { N5, N4, Beyond }
    Transitivity { Tr, In, Both }
    UseLevel { Safe, FriendsOnly, RecognizeOnly }
    TtsMode { Auto, Kana }
    Style { Polite, Plain, Mixed, Neutral }
    Register { Polite, Plain, Neutral }
    Script { Hira, Kata }
    KanaKind { Basic, Dakuten, Yoon, Extended, Mark }
    ConfusableKind { Shape, CrossScript, KanaKanji, Listen }
    SoundGroupKind { Voicing, Length, Sokuon, Yoon, Accent }
    DialogueKind { Lesson, Extra, Casual }
    KanaWordMode { Choice, Typing }
}

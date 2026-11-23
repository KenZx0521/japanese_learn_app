//! 非句子內容的語音文字（rust-core.md §3.3 表）。

use jp_lang::kana::reading_mode_of;

use crate::schema::{KanaDef, PairDef, RuleExampleDef, TtsMode, VocabDef};
use crate::sentence::Speech;

/// 假名：`tts_text`，省略時 `char`；`kana` 同 `text`。
pub fn kana_speech(kana: &KanaDef) -> Speech {
    let text = kana.tts_text.clone().unwrap_or_else(|| kana.ch.clone());
    Speech {
        kana: text.clone(),
        text,
    }
}

/// 單字：`tts` 省略時 `Kana`。含空白的 `kana`（`こんにち は`）獨立的 は／へ 換成 わ／え。
pub fn vocab_speech(vocab: &VocabDef) -> Speech {
    let spoken = spoken_reading(&vocab.kana);
    match vocab.tts.unwrap_or(TtsMode::Kana) {
        TtsMode::Kana => Speech {
            text: spoken.clone(),
            kana: spoken,
        },
        TtsMode::Auto => Speech {
            text: vocab.surface.clone(),
            kana: spoken,
        },
    }
}

fn spoken_reading(reading: &str) -> String {
    match reading_mode_of(reading) {
        jp_lang::kana::ReadingMode::Word => reading.to_owned(),
        jp_lang::kana::ReadingMode::Sentence => reading
            .split(' ')
            .map(|token| match token {
                "は" => "わ",
                "へ" => "え",
                other => other,
            })
            .collect::<Vec<_>>()
            .join(" "),
    }
}

/// 最小對立組與語音示範組的一側：`a_tts_text` 省略時 `a`；`a_kana` 省略時同 `text`。
pub fn pair_side_speech(text: &str, kana: Option<&str>, tts_text: Option<&str>) -> Speech {
    let spoken = tts_text.unwrap_or(text).to_owned();
    Speech {
        kana: kana.map_or_else(|| spoken.clone(), str::to_owned),
        text: spoken,
    }
}

pub fn pair_speech(pair: &PairDef) -> (Speech, Speech) {
    (
        pair_side_speech(&pair.a, pair.a_kana.as_deref(), pair.a_tts_text.as_deref()),
        pair_side_speech(&pair.b, pair.b_kana.as_deref(), pair.b_tts_text.as_deref()),
    )
}

/// 規則卡例字：`text`、`kana` 都是例字本身。
pub fn rule_example_speech(example: &RuleExampleDef) -> Speech {
    Speech {
        text: example.text.clone(),
        kana: example.text.clone(),
    }
}

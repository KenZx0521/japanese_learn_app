//! rust-core.md §3.3 非句子內容的語音文字。

use jp_content::schema::{KanaDef, PairDef, RuleExampleDef, TtsMode, VocabDef};
use jp_content::speech::{
    kana_speech, pair_side_speech, pair_speech, rule_example_speech, vocab_speech,
};

fn kana(tts_text: Option<&str>) -> KanaDef {
    let mut value = serde_json::json!({
        "id": "ka.hira.n", "lesson": "le.k08", "script": "hira", "kind": "basic",
        "char": "ん", "hint_zh": "自成一拍"
    });
    if let Some(text) = tts_text {
        value["tts_text"] = serde_json::Value::String(text.to_owned());
    }
    serde_json::from_value(value).expect("kana")
}

fn vocab(kana: &str, surface: &str, tts: Option<&str>) -> VocabDef {
    let mut value = serde_json::json!({
        "id": "vo.x", "lesson": "le.l01", "lesson_order": 1, "surface": surface, "kana": kana,
        "zh": ["測試"], "pos": "n", "jlpt": "n5", "topics": ["home"]
    });
    if let Some(mode) = tts {
        value["tts"] = serde_json::Value::String(mode.to_owned());
    }
    serde_json::from_value(value).expect("vocab")
}

#[test]
fn kana_speech_uses_tts_text_or_char() {
    assert_eq!(kana_speech(&kana(None)).text, "ん");
    let with_text = kana_speech(&kana(Some("んー")));
    assert_eq!(with_text.text, "んー");
    assert_eq!(with_text.kana, "んー");
}

#[test]
fn vocab_speech_defaults_to_kana_mode() {
    let speech = vocab_speech(&vocab("わたし", "私", None));
    assert_eq!(speech.text, "わたし");
    assert_eq!(speech.kana, "わたし");
}

#[test]
fn vocab_speech_auto_uses_surface_but_keeps_kana() {
    let speech = vocab_speech(&vocab("あめ", "雨", Some("auto")));
    assert_eq!(speech.text, "雨");
    assert_eq!(speech.kana, "あめ");
    assert_eq!(TtsMode::Auto, TtsMode::Auto);
}

#[test]
fn vocab_speech_with_space_replaces_standalone_particles() {
    let speech = vocab_speech(&vocab("こんにち は", "こんにちは", None));
    assert_eq!(speech.text, "こんにち わ");
    let speech = vocab_speech(&vocab("へ の", "へ", None));
    assert_eq!(speech.text, "え の");
}

#[test]
fn single_word_vocab_ha_is_not_replaced() {
    let speech = vocab_speech(&vocab("は", "歯", None));
    assert_eq!(speech.text, "は");
}

#[test]
fn pair_speech_prefers_tts_text_and_kana() {
    let pair = PairDef {
        a: "雨".into(),
        a_zh: "雨".into(),
        b: "飴".into(),
        b_zh: "糖果".into(),
        a_kana: Some("あめ".into()),
        b_kana: None,
        a_tts_text: None,
        b_tts_text: Some("あめ".into()),
        listen_disabled: false,
    };
    let (a, b) = pair_speech(&pair);
    assert_eq!((a.text.as_str(), a.kana.as_str()), ("雨", "あめ"));
    assert_eq!((b.text.as_str(), b.kana.as_str()), ("あめ", "あめ"));
    let side = pair_side_speech("かき", None, None);
    assert_eq!(side.text, "かき");
    assert_eq!(side.kana, "かき");
}

#[test]
fn rule_example_speech_is_the_text() {
    let example = RuleExampleDef {
        text: "きって".into(),
        zh: "郵票".into(),
        beats: vec!["き".into()],
    };
    let speech = rule_example_speech(&example);
    assert_eq!(speech.text, "きって");
    assert_eq!(speech.kana, "きって");
}

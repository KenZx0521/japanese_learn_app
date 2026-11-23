//! rust-core.md §4.5 的反向對照與打字判定表。

use jp_lang::kana::{
    reading_mode_of, romaji_to_hiragana, to_romaji_word, typed_answer_matches, ReadingMode,
    RomajiError,
};

#[test]
fn reverse_cases() {
    let cases = [
        ("konnichiwa", "こんにちわ"),
        ("sushi", "すし"),
        ("susi", "すし"),
        ("tiketto", "ちけっと"),
        ("matcha", "まっちゃ"),
        ("mattya", "まっちゃ"),
        ("kitte", "きって"),
        ("hon'ya", "ほんや"),
        ("honnya", "ほんにゃ"),
        ("honya", "ほにゃ"),
        ("kin'en", "きんえん"),
        ("onna", "おんな"),
        ("onnna", "おんな"),
        ("shinbun", "しんぶん"),
        ("hon", "ほん"),
        ("honn", "ほん"),
        ("ko-hi-", "こーひー"),
        ("wo", "を"),
        ("o", "お"),
        ("fu", "ふ"),
        ("hu", "ふ"),
        ("ja", "じゃ"),
        ("zya", "じゃ"),
        ("jya", "じゃ"),
        ("TOKYO", "ときょ"),
        ("tsu", "つ"),
        ("tu", "つ"),
        ("di", "でぃ"),
        ("kya", "きゃ"),
        ("n", "ん"),
    ];
    for (romaji, want) in cases {
        assert_eq!(romaji_to_hiragana(romaji).as_deref(), Ok(want), "{romaji}");
    }
}

#[test]
fn reverse_accepts_lenient_spellings() {
    let cases = [
        ("si", "し"),
        ("ti", "ち"),
        ("tu", "つ"),
        ("hu", "ふ"),
        ("zi", "じ"),
        ("sya", "しゃ"),
        ("syu", "しゅ"),
        ("syo", "しょ"),
        ("tya", "ちゃ"),
        ("tyu", "ちゅ"),
        ("tyo", "ちょ"),
        ("cya", "ちゃ"),
        ("cyu", "ちゅ"),
        ("cyo", "ちょ"),
        ("zya", "じゃ"),
        ("zyu", "じゅ"),
        ("zyo", "じょ"),
        ("jya", "じゃ"),
        ("jyu", "じゅ"),
        ("jyo", "じょ"),
        ("KoNnIcHiWa", "こんにちわ"),
    ];
    for (romaji, want) in cases {
        assert_eq!(romaji_to_hiragana(romaji).as_deref(), Ok(want), "{romaji}");
    }
}

#[test]
fn reverse_handles_nasal_table() {
    let cases = [
        ("n'a", "んあ"),
        ("nna", "んな"),
        ("nnya", "んにゃ"),
        ("nnn", "んん"),
        ("nka", "んか"),
        ("na", "な"),
        ("nya", "にゃ"),
        ("n-", "んー"),
        ("n a", "ん あ"),
    ];
    for (romaji, want) in cases {
        assert_eq!(romaji_to_hiragana(romaji).as_deref(), Ok(want), "{romaji}");
    }
}

#[test]
fn reverse_doubles_consonants_into_sokuon() {
    let cases = [
        ("kko", "っこ"),
        ("ssha", "っしゃ"),
        ("ttsu", "っつ"),
        ("tcha", "っちゃ"),
        ("ccha", "っちゃ"),
        ("ppa", "っぱ"),
        ("bba", "っば"),
        ("ffa", "っふぁ"),
        ("jja", "っじゃ"),
    ];
    for (romaji, want) in cases {
        assert_eq!(romaji_to_hiragana(romaji).as_deref(), Ok(want), "{romaji}");
    }
}

#[test]
fn reverse_keeps_spaces_and_maps_punctuation_for_preview() {
    let cases = [
        ("watashi wa", "わたし わ"),
        ("a\u{3000}i", "あ い"),
        ("a\ti", "あ い"),
        ("desu.", "です。"),
        ("hai, sou", "はい、 そう"),
        ("a!", "あ！"),
        ("a?", "あ？"),
        ("a~", "あ〜"),
    ];
    for (romaji, want) in cases {
        assert_eq!(romaji_to_hiragana(romaji).as_deref(), Ok(want), "{romaji}");
    }
}

#[test]
fn reverse_reports_unparsable_char_index() {
    let at = |pos| Err(RomajiError::Unparsable { pos });
    assert_eq!(romaji_to_hiragana("xq"), at(0));
    assert_eq!(romaji_to_hiragana("kaxq"), at(2));
    assert_eq!(romaji_to_hiragana("k"), at(0));
    assert_eq!(romaji_to_hiragana("kk"), at(1));
    assert_eq!(romaji_to_hiragana("'a"), at(0));
    assert_eq!(romaji_to_hiragana("3ji"), at(0));
    assert_eq!(romaji_to_hiragana("あ"), at(0));
}

#[test]
fn round_trips_spike_samples() {
    let samples = [
        "か",
        "し",
        "ち",
        "つ",
        "ふ",
        "じ",
        "ず",
        "ん",
        "きゃ",
        "しゃ",
        "ちゃ",
        "じゃ",
        "りょ",
        "ふぁ",
        "でぃ",
        "しぇ",
        "がっこう",
        "ほんや",
        "きんえん",
        "まっちゃ",
        "おんな",
        "しんぶん",
        "がくせい",
    ];
    for kana in samples {
        let romaji = to_romaji_word(kana).expect("樣本都合法");
        assert_eq!(romaji_to_hiragana(&romaji).as_deref(), Ok(kana), "{romaji}");
    }
}

fn matches(input: &str, expected: &str) -> bool {
    typed_answer_matches(input, expected, reading_mode_of(expected))
}

#[test]
fn typed_answer_table() {
    let cases = [
        ("watashi wa gakusei desu", "わたし は がくせい です", true),
        ("watasi wa gakusei desu.", "わたし は がくせい です。", true),
        ("watashi ha gakusei desu", "わたし は がくせい です", false),
        ("hon wo yomimasu", "ほん を よみます", false),
        ("arigatoo", "ありがとう", true),
        ("arigatou", "ありがとう", true),
        ("わたしはがくせいです", "わたし は がくせい です。", true),
        ("ワタシハガクセイデス", "わたし は がくせい です", true),
        ("konnichiwa", "こんにち は", true),
        ("konnichi wa", "こんにち は", true),
        ("honya", "ほんや", true),
        ("paatii", "パーティー", true),
        ("paati-", "パーティー", true),
        ("PAATII", "パーティー", true),
        ("paachii", "パーティー", false),
        ("matcha", "まっちゃ", true),
        ("mattya", "まっちゃ", true),
        ("ha", "は", true),
        ("wa", "は", false),
    ];
    for (input, expected, want) in cases {
        assert_eq!(matches(input, expected), want, "{input} / {expected}");
    }
}

#[test]
fn typed_answer_accepts_spike_extras() {
    assert!(matches("hon o yomimasu", "ほん を よみます"));
    assert!(typed_answer_matches(
        "konnichiwa",
        "こんにちは",
        ReadingMode::Sentence
    ));
}

#[test]
fn typed_answer_word_mode_follows_mode_argument() {
    assert!(typed_answer_matches("wa", "は", ReadingMode::Sentence));
    assert!(!typed_answer_matches("ha", "は", ReadingMode::Sentence));
}

#[test]
fn typed_answer_folds_long_vowels_on_both_sides() {
    assert!(matches("oneisan", "おねえさん"));
    assert!(matches("oneesan", "おねえさん"));
    assert!(matches("oukii", "おおきい"));
    assert!(matches("sensee", "せんせい"));
}

#[test]
fn typed_answer_converts_lenient_spellings_via_kana() {
    assert!(matches("tiketto", "ちけっと"));
    assert!(matches("tyuui", "ちゅうい"));
    assert!(matches("si-do", "シード"));
    assert!(matches("kin'ensi", "きんえんし"));
}

#[test]
fn typed_answer_rejects_blank_and_garbage() {
    assert!(!matches("", "ほん"));
    assert!(!matches("   ", "ほん"));
    assert!(!matches("xq", "ほん"));
    assert!(!matches("...", "。"));
}

#[test]
fn typed_answer_with_invalid_expected_is_false() {
    assert!(!matches("kanji", "漢字"));
}

#[test]
fn typed_answer_kana_input_compares_without_punctuation_or_spaces() {
    assert!(matches("わたし　は", "わたし は。"));
    assert!(!matches("わたしが", "わたし は"));
    assert!(matches("コーヒー", "こーひー"));
    assert!(!matches("わたしha", "わたし は"));
}

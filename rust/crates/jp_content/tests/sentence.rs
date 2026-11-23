//! rust-core.md §3.3 的 `t` 案例表與衍生欄位。

use jp_content::schema::TtsMode;
use jp_content::sentence::{analyze_t, parse_t, reorder_chunks, TParseError};
use jp_lang::kana::{Morph, Word};

const TABLE: &[(&str, &str, &str)] = &[
    (
        "私|わたし|vo.watashi は|gr.wa_topic 毎朝|まいあさ|vo.maiasa ご飯|ごはん|vo.gohan を|gr.wo_obj 食べ|たべ|vo.taberu+ます|gr.masu 。",
        "私は毎朝ご飯を食べます。",
        "watashi wa maiasa gohan o tabemasu.",
    ),
    ("こんにち|vo.konnichiwa は|vo.konnichiwa", "こんにちは", "konnichi wa"),
    (
        "何|なに|vo.nani し|vo.suru+てる|gr.te_iru_prog の|gr.n_desu ？",
        "何してるの？",
        "nani shiteru no?",
    ),
    (
        "歯|は|vo.ha が|gr.ga_subject 痛|いた|vo.itai+い|gr.i_adj 。",
        "歯が痛い。",
        "ha ga itai.",
    ),
    ("3本|さんぼん|gr.counters", "3本", "sanbon"),
    (
        "はい|vo.hai 、 見|み|vo.miru+ませんでした|gr.masu_past 。",
        "はい、見ませんでした。",
        "hai, mimasendeshita.",
    ),
    (
        "「 それ|vo.sore 」 は|gr.wa_topic 何|なに|vo.nani",
        "「それ」は何",
        "\"sore\" wa nani",
    ),
];

#[test]
fn table_cases_produce_display_and_romaji() {
    for (t, display, romaji) in TABLE {
        let parsed = analyze_t(t, None, None).expect(t);
        assert_eq!(parsed.display, *display, "{t}");
        assert_eq!(parsed.romaji, *romaji, "{t}");
    }
}

#[test]
fn parse_t_splits_words_and_morphs() {
    let words = parse_t("食べ|たべ|vo.taberu+ます|gr.masu 。").expect("合法");
    assert_eq!(
        words,
        vec![
            Word::Morphs(vec![
                Morph {
                    surface: "食べ".into(),
                    kana: "たべ".into(),
                    r#ref: "vo.taberu".into()
                },
                Morph {
                    surface: "ます".into(),
                    kana: "ます".into(),
                    r#ref: "gr.masu".into()
                },
            ]),
            Word::Punct("。".into()),
        ]
    );
}

#[test]
fn parse_errors_match_spec() {
    assert!(matches!(
        parse_t("食べ|vo.taberu"),
        Err(TParseError::MissingKana { .. })
    ));
    assert!(matches!(
        parse_t("3本|gr.counters"),
        Err(TParseError::MissingKana { .. })
    ));
    assert!(matches!(
        parse_t("はい"),
        Err(TParseError::MissingRef { .. })
    ));
    assert!(matches!(
        parse_t("ご飯|ごはん"),
        Err(TParseError::MissingRef { .. })
    ));
    assert!(matches!(
        parse_t("はい|xx.hai"),
        Err(TParseError::BadRef { .. })
    ));
    assert!(matches!(
        parse_t("ご飯|ごはん|xx.gohan"),
        Err(TParseError::BadRef { .. })
    ));
    assert!(matches!(parse_t(""), Err(TParseError::Empty)));
    assert!(matches!(parse_t("   "), Err(TParseError::Empty)));
}

#[test]
fn name_and_new_refs_are_accepted() {
    let parsed =
        analyze_t("林|はやし|@name さん|gr.san 猫|ねこ|@new:貓 。", None, None).expect("合法");
    assert!(parsed.has_name);
    let cat = &parsed.words[2];
    assert_eq!(cat.gloss_zh.as_deref(), Some("貓"));
    assert_eq!(cat.ref_id, None);
    assert_eq!(parsed.words[1].ref_id.as_deref(), Some("gr.san"));
}

#[test]
fn bare_at_refs_are_rejected() {
    assert!(matches!(
        parse_t("林|はやし|@place"),
        Err(TParseError::BadRef { .. })
    ));
    assert!(matches!(
        parse_t("猫|ねこ|@new:"),
        Err(TParseError::BadRef { .. })
    ));
}

#[test]
fn spaced_kana_keeps_word_boundaries() {
    let parsed = analyze_t(TABLE[0].0, None, None).expect("合法");
    assert_eq!(
        parsed.spaced_kana,
        "わたし は まいあさ ごはん を たべます。"
    );
}

#[test]
fn speech_kana_replaces_lone_kana_particles() {
    let parsed = analyze_t(TABLE[0].0, None, None).expect("合法");
    assert_eq!(
        parsed.speech.kana,
        "わたし わ まいあさ ごはん を たべます。"
    );
    assert_eq!(parsed.words[1].speech_kana, "わ");
    assert_eq!(parsed.words[1].kana, "は");
}

#[test]
fn speech_kana_keeps_kanji_ha() {
    let parsed = analyze_t(TABLE[3].0, None, None).expect("合法");
    assert_eq!(parsed.words[0].speech_kana, "は");
    assert_eq!(parsed.speech.kana, "は が いたい。");
}

#[test]
fn he_particle_becomes_e_in_speech() {
    let parsed = analyze_t("学校|がっこう|vo.gakkou へ|gr.e_dir", None, None).expect("合法");
    assert_eq!(parsed.speech.kana, "がっこう え");
}

#[test]
fn tts_resolution_prefers_own_then_drill_then_auto() {
    let t = TABLE[0].0;
    let auto = analyze_t(t, None, None).expect("合法");
    assert_eq!(auto.speech.text, auto.display);

    let own = analyze_t(t, Some(TtsMode::Kana), Some(TtsMode::Auto)).expect("合法");
    assert_eq!(own.speech.text, own.speech.kana);

    let drill = analyze_t(t, None, Some(TtsMode::Kana)).expect("合法");
    assert_eq!(drill.speech.text, drill.speech.kana);

    let own_auto = analyze_t(t, Some(TtsMode::Auto), Some(TtsMode::Kana)).expect("合法");
    assert_eq!(own_auto.speech.text, own_auto.display);
}

#[test]
fn name_forces_kana_speech() {
    let parsed =
        analyze_t("林|はやし|@name です|gr.desu 。", Some(TtsMode::Auto), None).expect("合法");
    assert_eq!(parsed.speech.text, parsed.speech.kana);
    assert_eq!(parsed.speech.kana, "はやし です。");
}

#[test]
fn ruby_comes_from_furigana_alignment() {
    let parsed = analyze_t("食べ|たべ|vo.taberu+ます|gr.masu", None, None).expect("合法");
    let word = &parsed.words[0];
    let parts: Vec<(&str, Option<&str>)> = word
        .ruby
        .iter()
        .map(|r| (r.base.as_str(), r.ruby.as_deref()))
        .collect();
    assert_eq!(
        parts,
        vec![("食", Some("た")), ("べ", None), ("ます", None)]
    );
    assert_eq!(word.refs, vec!["vo.taberu", "gr.masu"]);
    assert_eq!(word.ref_id.as_deref(), Some("vo.taberu"));
    assert!(!word.is_punct);
}

#[test]
fn punctuation_word_is_flagged() {
    let parsed = analyze_t("はい|vo.hai 。", None, None).expect("合法");
    assert!(parsed.words[1].is_punct);
    assert_eq!(parsed.words[1].surface, "。");
    assert_eq!(parsed.words[1].ref_id, None);
}

#[test]
fn chunks_glue_particles_to_previous_word() {
    let parsed = analyze_t(TABLE[0].0, None, None).expect("合法");
    let surfaces: Vec<String> = reorder_chunks(&parsed)
        .into_iter()
        .map(|chunk| chunk.surface)
        .collect();
    assert_eq!(surfaces, vec!["私は", "毎朝", "ご飯を", "食べます"]);
}

#[test]
fn chunk_particle_only_when_gr_ref_and_single_morph() {
    let parsed = analyze_t("歯|は|vo.ha が|vo.ga で|gr.de_place 。", None, None).expect("合法");
    let surfaces: Vec<String> = reorder_chunks(&parsed)
        .into_iter()
        .map(|chunk| chunk.surface)
        .collect();
    assert_eq!(surfaces, vec!["歯", "がで"]);
}

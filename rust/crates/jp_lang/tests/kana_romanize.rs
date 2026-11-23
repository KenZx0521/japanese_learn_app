//! rust-core.md §4.2–§4.4 與 curriculum.md §12.7 的羅馬字案例表。

use jp_lang::kana::{
    reading_mode_of, romanize_words, to_hiragana, to_romaji_reading, to_romaji_sentence,
    to_romaji_word, KanaError, Morph, ReadingMode, Word,
};

fn assert_word_cases(cases: &[(&str, &str)]) {
    for (kana, want) in cases {
        assert_eq!(to_romaji_word(kana).as_deref(), Ok(*want), "{kana}");
    }
}

#[test]
fn word_basic() {
    assert_word_cases(&[
        ("あいうえお", "aiueo"),
        ("し", "shi"),
        ("ち", "chi"),
        ("つ", "tsu"),
        ("ふ", "fu"),
        ("じ", "ji"),
        ("ぢ", "ji"),
        ("づ", "zu"),
        ("カタカナ", "katakana"),
    ]);
}

#[test]
fn word_yoon() {
    assert_word_cases(&[
        ("きゃ", "kya"),
        ("しゃしゅしょ", "shashusho"),
        ("ちゃ", "cha"),
        ("じゃ", "ja"),
        ("ぢゃ", "ja"),
        ("りょこう", "ryokou"),
    ]);
}

#[test]
fn word_sokuon() {
    assert_word_cases(&[
        ("がっこう", "gakkou"),
        ("きって", "kitte"),
        ("ざっし", "zasshi"),
        ("まっちゃ", "matcha"),
        ("こっち", "kotchi"),
        ("みっつ", "mittsu"),
        ("はっぴょう", "happyou"),
        ("ベッド", "beddo"),
        ("バッグ", "baggu"),
        ("マッチ", "matchi"),
        ("あっ", "a"),
        ("えっ", "e"),
    ]);
}

#[test]
fn word_sokuon_is_dropped_before_vowel_and_punctuation() {
    assert_word_cases(&[("あっあ", "aa"), ("あっ！", "a!"), ("あっっか", "akka")]);
}

#[test]
fn word_nasal() {
    assert_word_cases(&[
        ("ほん", "hon"),
        ("ほんや", "hon'ya"),
        ("ほにゃ", "honya"),
        ("きんえん", "kin'en"),
        ("きねん", "kinen"),
        ("ぜんいん", "zen'in"),
        ("でんわ", "denwa"),
        ("おんな", "onna"),
        ("しんぶん", "shinbun"),
        ("さんぽ", "sanpo"),
        ("てんき", "tenki"),
        ("ほんを", "honwo"),
    ]);
}

#[test]
fn word_long_mark() {
    assert_word_cases(&[
        ("コーヒー", "koohii"),
        ("ラーメン", "raamen"),
        ("スーパー", "suupaa"),
        ("ケーキ", "keeki"),
        ("ノート", "nooto"),
        ("ビール", "biiru"),
        ("らーめん", "raamen"),
        ("ねーー", "neee"),
        ("んー", "nn"),
        ("すごーい", "sugooi"),
    ]);
}

#[test]
fn word_long_vowel_is_spelled_out() {
    assert_word_cases(&[
        ("ありがとう", "arigatou"),
        ("おおきい", "ookii"),
        ("おとうさん", "otousan"),
        ("おかあさん", "okaasan"),
        ("せんせい", "sensei"),
        ("おねえさん", "oneesan"),
        ("おいしい", "oishii"),
        ("くうき", "kuuki"),
        ("とけい", "tokei"),
        ("とうきょう", "toukyou"),
    ]);
}

#[test]
fn word_loanword_digraphs() {
    assert_word_cases(&[
        ("ティー", "tii"),
        ("パーティー", "paatii"),
        ("ディズニー", "dizunii"),
        ("ファン", "fan"),
        ("フィルム", "firumu"),
        ("カフェ", "kafe"),
        ("フォーク", "fooku"),
        ("ウィンドウ", "windou"),
        ("ウェブ", "webu"),
        ("シェフ", "shefu"),
        ("ジェット", "jetto"),
        ("チェック", "chekku"),
        ("ツアー", "tsuaa"),
        ("トゥ", "tu"),
        ("ドゥ", "du"),
        ("デュエット", "dyuetto"),
        ("ヴァイオリン", "vaiorin"),
        ("イェ", "ye"),
        ("クォーター", "kwootaa"),
        ("グァム", "gwamu"),
    ]);
}

#[test]
fn word_every_digraph_in_rule_table() {
    assert_word_cases(&[
        ("テュ", "tyu"),
        ("ファフィフェフォ", "fafifefo"),
        ("フュ", "fyu"),
        ("ウォ", "wo"),
        ("ツァツィツェツォ", "tsatsitsetso"),
        ("ヴ", "vu"),
        ("ヴィヴェヴォ", "vivevo"),
        ("ヴュ", "vyu"),
        ("クァクィクェ", "kwakwikwe"),
        ("スィ", "si"),
        ("ズィ", "zi"),
        ("ヂョ", "jo"),
        ("ヂュ", "ju"),
    ]);
}

#[test]
fn word_small_kana_alone() {
    assert_word_cases(&[
        ("ねぇ", "nee"),
        ("はぁ", "haa"),
        ("あぁ", "aa"),
        ("きゃぁ", "kyaa"),
        ("ぃ", "i"),
        ("ぅ", "u"),
        ("ぉ", "o"),
        ("ゃ", "ya"),
        ("ゅ", "yu"),
        ("ょ", "yo"),
        ("ゎ", "wa"),
        ("ヵ", "ka"),
        ("ヶ", "ke"),
    ]);
}

#[test]
fn word_particle_chars_keep_letter_reading() {
    assert_word_cases(&[
        ("は", "ha"),
        ("へ", "he"),
        ("を", "wo"),
        ("はな", "hana"),
        ("へや", "heya"),
    ]);
}

#[test]
fn word_punctuation() {
    assert_word_cases(&[
        ("はい、そうです。", "hai,soudesu."),
        ("あ！", "a!"),
        ("あ？", "a?"),
        ("「あ」", "\"a\""),
        ("『あ』", "\"a\""),
        ("あ…", "a..."),
        ("あ〜", "a~"),
        ("あ～", "a~"),
        ("あ~", "a~"),
        ("（あ）", "(a)"),
        ("あ・い", "a i"),
        ("あ.", "a."),
        ("あ,", "a,"),
        ("あ!", "a!"),
        ("あ?", "a?"),
    ]);
}

#[test]
fn word_archaic_kana() {
    assert_word_cases(&[("ゐ", "i"), ("ゑ", "e"), ("ヰ", "i"), ("ヱ", "e")]);
}

#[test]
fn curriculum_12_7_word_cases() {
    assert_word_cases(&[
        ("まっちゃ", "matcha"),
        ("コーヒー", "koohii"),
        ("とうきょう", "toukyou"),
        ("せんせい", "sensei"),
        ("ほんい", "hon'i"),
        ("ほんや", "hon'ya"),
        ("ティ", "ti"),
        ("ファ", "fa"),
        ("あっ", "a"),
        ("えっ", "e"),
        ("は", "ha"),
        ("へ", "he"),
    ]);
}

#[test]
fn empty_input_romanizes_to_empty() {
    assert_eq!(to_romaji_word("").as_deref(), Ok(""));
    assert_eq!(to_romaji_sentence("").as_deref(), Ok(""));
}

#[test]
fn every_hiragana_and_katakana_in_supported_range_romanizes() {
    let hiragana = '\u{3041}'..='\u{3096}';
    let katakana = '\u{30A1}'..='\u{30F6}';
    for c in hiragana.chain(katakana) {
        assert!(to_romaji_word(&c.to_string()).is_ok(), "{c}");
    }
}

#[test]
fn word_errors_report_char_index() {
    let invalid = |ch, pos| Err(KanaError::InvalidChar { ch, pos });
    assert_eq!(
        to_romaji_word("ーあ"),
        Err(KanaError::DanglingLongMark { pos: 0 })
    );
    assert_eq!(to_romaji_word("漢字"), invalid('漢', 0));
    assert_eq!(to_romaji_word("abc"), invalid('a', 0));
    assert_eq!(to_romaji_word("3じ"), invalid('3', 0));
    assert_eq!(to_romaji_word("いすゞ"), invalid('ゞ', 2));
    assert_eq!(to_romaji_word("ヷ"), invalid('ヷ', 0));
    assert_eq!(to_romaji_word("こゝ"), invalid('ゝ', 1));
    assert_eq!(to_romaji_word("ヽ"), invalid('ヽ', 0));
    assert_eq!(to_romaji_word("ヾ"), invalid('ヾ', 0));
}

#[test]
fn long_mark_needs_a_preceding_sound() {
    assert_eq!(
        to_romaji_word("っー"),
        Err(KanaError::DanglingLongMark { pos: 1 })
    );
    assert_eq!(
        to_romaji_word("あっー"),
        Err(KanaError::DanglingLongMark { pos: 2 })
    );
    assert_eq!(
        to_romaji_word("、ー"),
        Err(KanaError::DanglingLongMark { pos: 1 })
    );
}

#[test]
fn sentence_cases() {
    let cases = [
        ("わたし は がくせい です。", "watashi wa gakusei desu."),
        ("がっこう へ いきます", "gakkou e ikimasu"),
        ("ほん を よみます", "hon o yomimasu"),
        ("こんにち は", "konnichi wa"),
        ("で は", "de wa"),
        ("こんにちは", "konnichiwa"),
        ("こんばんは。", "konbanwa."),
        ("こんにちは、 せかい！", "konnichiwa, sekai!"),
        ("では また", "dewa mata"),
        ("それでは", "soredewa"),
        ("はは は げんき です", "haha wa genki desu"),
        ("はな が きれい", "hana ga kirei"),
        ("わたし は、 がくせい", "watashi wa, gakusei"),
        ("「は」 は じょし", "\"wa\" wa joshi"),
        ("ほん や", "hon ya"),
        ("にほん へ は いきません", "nihon e wa ikimasen"),
        ("コーヒー を のみます か？", "koohii o nomimasu ka?"),
        ("わたし\u{3000}は\u{3000}がくせい", "watashi wa gakusei"),
        ("\u{3000}がくせい  です ", "gakusei desu"),
        ("わたし\tは", "watashi wa"),
        ("", ""),
    ];
    for (reading, want) in cases {
        assert_eq!(
            to_romaji_sentence(reading).as_deref(),
            Ok(want),
            "{reading}"
        );
    }
}

#[test]
fn sentence_fixed_words_read_final_ha_as_wa() {
    let cases = [
        ("または", "matawa"),
        ("あるいは", "aruiwa"),
        ("もしくは", "moshikuwa"),
    ];
    for (reading, want) in cases {
        assert_eq!(
            to_romaji_sentence(reading).as_deref(),
            Ok(want),
            "{reading}"
        );
    }
}

#[test]
fn sentence_errors_use_char_index_in_whole_reading() {
    assert_eq!(
        to_romaji_sentence("あ ーい"),
        Err(KanaError::DanglingLongMark { pos: 2 })
    );
    assert_eq!(
        to_romaji_sentence("あ\u{3000}「漢"),
        Err(KanaError::InvalidChar { ch: '漢', pos: 3 })
    );
}

#[test]
fn middle_dot_token_does_not_leave_double_spaces() {
    assert_eq!(to_romaji_sentence("あ ・ い").as_deref(), Ok("a i"));
}

#[test]
fn reading_mode_is_sentence_only_with_whitespace() {
    assert_eq!(reading_mode_of("は"), ReadingMode::Word);
    assert_eq!(reading_mode_of("へ"), ReadingMode::Word);
    assert_eq!(reading_mode_of("こんにちは"), ReadingMode::Word);
    assert_eq!(reading_mode_of("こんにち は"), ReadingMode::Sentence);
    assert_eq!(reading_mode_of("こんにち\u{3000}は"), ReadingMode::Sentence);
    assert_eq!(reading_mode_of("こんにち\tは"), ReadingMode::Sentence);
}

#[test]
fn reading_dispatches_on_mode() {
    let of = |r: &str| to_romaji_reading(r, reading_mode_of(r));
    assert_eq!(of("は").as_deref(), Ok("ha"));
    assert_eq!(of("へ").as_deref(), Ok("he"));
    assert_eq!(of("こんにち は").as_deref(), Ok("konnichi wa"));
    assert_eq!(
        to_romaji_reading("は", ReadingMode::Sentence).as_deref(),
        Ok("wa")
    );
    assert_eq!(
        to_romaji_reading("は", ReadingMode::Word).as_deref(),
        Ok("ha")
    );
}

#[test]
fn to_hiragana_shifts_katakana_only() {
    assert_eq!(to_hiragana("カタカナ"), "かたかな");
    assert_eq!(to_hiragana("ヴ"), "ゔ");
    assert_eq!(to_hiragana("コーヒー"), "こーひー");
    assert_eq!(to_hiragana("食べるabc"), "食べるabc");
    assert_eq!(to_hiragana("ヷ"), "ヷ");
}

/// 測試用的簡化 `t` 解析，真正的 `parse_t` 在 jp_content。
fn parse(t: &str) -> Vec<Word> {
    t.split(' ').map(parse_word).collect()
}

fn parse_word(word: &str) -> Word {
    if word.contains('|') {
        Word::Morphs(word.split('+').map(parse_morph).collect())
    } else {
        Word::Punct(word.to_owned())
    }
}

fn parse_morph(morph: &str) -> Morph {
    let parts: Vec<&str> = morph.split('|').collect();
    let (surface, kana, r#ref) = match parts.as_slice() {
        [s, r] => (*s, *s, *r),
        [s, k, r] => (*s, *k, *r),
        other => panic!("測試資料格式錯誤：{other:?}"),
    };
    Morph {
        surface: surface.to_owned(),
        kana: kana.to_owned(),
        r#ref: r#ref.to_owned(),
    }
}

#[test]
fn t_mode_cases_from_section_3_3() {
    let cases = [
        ("私|わたし|vo.watashi は|gr.wa_topic 毎朝|まいあさ|vo.maiasa ご飯|ごはん|vo.gohan を|gr.wo_obj 食べ|たべ|vo.taberu+ます|gr.masu 。", "watashi wa maiasa gohan o tabemasu."),
        ("こんにち|vo.konnichiwa は|vo.konnichiwa", "konnichi wa"),
        ("何|なに|vo.nani し|vo.suru+てる|gr.te_iru_prog の|gr.n_desu ？", "nani shiteru no?"),
        ("歯|は|vo.ha が|gr.ga_subject 痛|いた|vo.itai+い|gr.i_adj 。", "ha ga itai."),
        ("3本|さんぼん|gr.counters", "sanbon"),
        ("はい|vo.hai 、 見|み|vo.miru+ませんでした|gr.masu_past 。", "hai, mimasendeshita."),
        ("「 それ|vo.sore 」 は|gr.wa_topic 何|なに|vo.nani", "\"sore\" wa nani"),
    ];
    for (t, want) in cases {
        assert_eq!(romanize_words(&parse(t)).as_deref(), Ok(want), "{t}");
    }
}

#[test]
fn t_mode_opening_bracket_sticks_to_next_word() {
    let t = "あれ|vo.are は|gr.wa_topic 「 それ|vo.sore 」 。 （ そう|vo.sou ）";
    assert_eq!(
        romanize_words(&parse(t)).as_deref(),
        Ok("are wa \"sore\". (sou)")
    );
}

#[test]
fn t_mode_joins_kana_across_morphs_for_sokuon_and_nasal() {
    let cases = [
        ("行っ|いっ|vo.iku+て|gr.te", "itte"),
        ("読ん|よん|vo.yomu+で|gr.te", "yonde"),
        ("本|ほん|vo.hon+屋|や|vo.ya", "hon'ya"),
    ];
    for (t, want) in cases {
        assert_eq!(romanize_words(&parse(t)).as_deref(), Ok(want), "{t}");
    }
}

#[test]
fn t_mode_particle_rule_needs_single_kana_morph() {
    assert_eq!(romanize_words(&parse("葉|は|vo.ha")).as_deref(), Ok("ha"));
    assert_eq!(romanize_words(&parse("へ|gr.e_dir")).as_deref(), Ok("e"));
    assert_eq!(romanize_words(&parse("を|gr.wo_obj")).as_deref(), Ok("o"));
    assert_eq!(
        romanize_words(&parse("は|gr.a+は|gr.b")).as_deref(),
        Ok("haha")
    );
    assert_eq!(
        romanize_words(&parse("こんにちは|vo.konnichiwa")).as_deref(),
        Ok("konnichiwa")
    );
}

#[test]
fn t_mode_errors_use_running_kana_index() {
    let words = parse("あ|gr.a 漢|gr.b");
    assert_eq!(
        romanize_words(&words),
        Err(KanaError::InvalidChar { ch: '漢', pos: 1 })
    );
}

#[test]
fn t_mode_empty_is_empty() {
    assert_eq!(romanize_words(&[]).as_deref(), Ok(""));
}

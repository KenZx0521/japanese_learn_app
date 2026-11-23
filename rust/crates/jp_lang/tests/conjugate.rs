//! rust-core.md §4.7：各類別×形式、敬語例外、`vs` 語幹。`legal_stems` 在 legal_stems.rs。

use jp_lang::grammar::conjugate::{
    conjugate_kana, conjugate_surface, Form,
    Form::{Ba, Causative, Imperative, Masu, Nai, Passive, Potential, Ta, Te, Volitional},
    Pos,
    Pos::{AdjI, AdjNa, Vk, Vs, N, V1, V1S, V5},
};

const ALL_FORMS: [Form; 10] = [
    Masu, Te, Ta, Nai, Potential, Volitional, Ba, Imperative, Passive, Causative,
];

fn assert_kana_row(kana: &str, pos: Pos, expected: [&str; 10]) {
    for (form, want) in ALL_FORMS.into_iter().zip(expected) {
        assert_eq!(
            conjugate_kana(kana, pos, form).as_deref(),
            Some(want),
            "{kana} {form:?}"
        );
    }
}

fn assert_surface_row(surface: &str, kana: &str, pos: Pos, expected: [&str; 10]) {
    for (form, want) in ALL_FORMS.into_iter().zip(expected) {
        let got = conjugate_surface(surface, kana, pos, form);
        assert_eq!(got.as_deref(), Some(want), "{surface} {form:?}");
    }
}

#[test]
fn v1_all_forms() {
    assert_kana_row(
        "たべる",
        V1,
        [
            "たべます",
            "たべて",
            "たべた",
            "たべない",
            "たべられる",
            "たべよう",
            "たべれば",
            "たべろ",
            "たべられる",
            "たべさせる",
        ],
    );
    assert_kana_row(
        "みる",
        V1,
        [
            "みます",
            "みて",
            "みた",
            "みない",
            "みられる",
            "みよう",
            "みれば",
            "みろ",
            "みられる",
            "みさせる",
        ],
    );
}

/// 特殊一段（くれる）：只有命令形是語幹，其餘同 v1。
#[test]
fn v1_s_imperative_is_bare_stem() {
    assert_kana_row(
        "くれる",
        V1S,
        [
            "くれます",
            "くれて",
            "くれた",
            "くれない",
            "くれられる",
            "くれよう",
            "くれれば",
            "くれ",
            "くれられる",
            "くれさせる",
        ],
    );
    assert_eq!(
        conjugate_surface("くれる", "くれる", V1S, Imperative).as_deref(),
        Some("くれ")
    );
    assert_eq!(
        conjugate_surface("呉れる", "くれる", V1S, Imperative).as_deref(),
        Some("呉れ")
    );
    assert_eq!(
        conjugate_surface("呉れる", "くれる", V1S, Te).as_deref(),
        Some("呉れて")
    );
}

/// 一般一段的命令形仍接 ろ，同音的 暮れる 也不受 くれる 影響。
#[test]
fn v1_imperative_keeps_ro() {
    assert_eq!(
        conjugate_kana("くれる", V1, Imperative).as_deref(),
        Some("くれろ")
    );
    assert_eq!(
        conjugate_surface("暮れる", "くれる", V1, Imperative).as_deref(),
        Some("暮れろ")
    );
    assert_eq!(
        conjugate_surface("食べる", "たべる", V1, Imperative).as_deref(),
        Some("食べろ")
    );
}

#[test]
fn v1_s_matches_v1_except_imperative() {
    for form in ALL_FORMS.into_iter().filter(|&form| form != Imperative) {
        assert_eq!(
            conjugate_surface("呉れる", "くれる", V1S, form),
            conjugate_surface("暮れる", "くれる", V1, form).map(|v1| v1.replacen('暮', "呉", 1)),
            "{form:?}"
        );
    }
}

#[test]
fn pos_family_groups_v1_s_with_v1() {
    assert_eq!(V1S.family(), V1);
    for pos in [V1, V5, Vs, Vk, AdjI, AdjNa, N] {
        assert_eq!(pos.family(), pos, "{pos:?}");
    }
}

#[test]
fn v5_all_forms() {
    assert_kana_row(
        "のむ",
        V5,
        [
            "のみます",
            "のんで",
            "のんだ",
            "のまない",
            "のめる",
            "のもう",
            "のめば",
            "のめ",
            "のまれる",
            "のませる",
        ],
    );
    assert_kana_row(
        "かう",
        V5,
        [
            "かいます",
            "かって",
            "かった",
            "かわない",
            "かえる",
            "かおう",
            "かえば",
            "かえ",
            "かわれる",
            "かわせる",
        ],
    );
    assert_kana_row(
        "はなす",
        V5,
        [
            "はなします",
            "はなして",
            "はなした",
            "はなさない",
            "はなせる",
            "はなそう",
            "はなせば",
            "はなせ",
            "はなされる",
            "はなさせる",
        ],
    );
}

#[test]
fn v5_te_and_ta_sound_changes_cover_every_ending() {
    let cases = [
        ("かう", "かって", "かった"),
        ("まつ", "まって", "まった"),
        ("とる", "とって", "とった"),
        ("のむ", "のんで", "のんだ"),
        ("よぶ", "よんで", "よんだ"),
        ("しぬ", "しんで", "しんだ"),
        ("かく", "かいて", "かいた"),
        ("およぐ", "およいで", "およいだ"),
        ("はなす", "はなして", "はなした"),
    ];
    for (kana, te, ta) in cases {
        assert_eq!(conjugate_kana(kana, V5, Te).as_deref(), Some(te), "{kana}");
        assert_eq!(conjugate_kana(kana, V5, Ta).as_deref(), Some(ta), "{kana}");
    }
}

#[test]
fn v5_passive_and_causative_use_a_row() {
    let cases = [
        ("かく", "かかれる", "かかせる"),
        ("いく", "いかれる", "いかせる"),
        ("まつ", "またれる", "またせる"),
        ("しぬ", "しなれる", "しなせる"),
        ("よぶ", "よばれる", "よばせる"),
        ("およぐ", "およがれる", "およがせる"),
        ("とる", "とられる", "とらせる"),
    ];
    for (kana, passive, causative) in cases {
        assert_eq!(
            conjugate_kana(kana, V5, Passive).as_deref(),
            Some(passive),
            "{kana}"
        );
        assert_eq!(
            conjugate_kana(kana, V5, Causative).as_deref(),
            Some(causative),
            "{kana}"
        );
    }
}

#[test]
fn iku_exception_applies_only_to_te_and_ta() {
    assert_eq!(conjugate_kana("いく", V5, Te).as_deref(), Some("いって"));
    assert_eq!(conjugate_kana("いく", V5, Ta).as_deref(), Some("いった"));
    assert_eq!(
        conjugate_kana("いく", V5, Masu).as_deref(),
        Some("いきます")
    );
    assert_eq!(conjugate_kana("いく", V5, Nai).as_deref(), Some("いかない"));
    assert_eq!(
        conjugate_kana("もっていく", V5, Te).as_deref(),
        Some("もっていって")
    );
    assert_eq!(conjugate_kana("かく", V5, Te).as_deref(), Some("かいて"));
}

#[test]
fn aru_negative_is_nai_and_other_forms_stay_regular() {
    assert_eq!(conjugate_kana("ある", V5, Nai).as_deref(), Some("ない"));
    assert_eq!(
        conjugate_kana("ある", V5, Masu).as_deref(),
        Some("あります")
    );
    assert_eq!(conjugate_kana("ある", V5, Te).as_deref(), Some("あって"));
    assert_eq!(
        conjugate_surface("ある", "ある", V5, Nai).as_deref(),
        Some("ない")
    );
    assert_eq!(
        conjugate_surface("有る", "ある", V5, Nai).as_deref(),
        Some("ない")
    );
    assert_eq!(
        conjugate_surface("有る", "ある", V5, Masu).as_deref(),
        Some("有ります")
    );
}

#[test]
fn honorific_verbs_all_forms() {
    assert_kana_row(
        "いらっしゃる",
        V5,
        [
            "いらっしゃいます",
            "いらっしゃって",
            "いらっしゃった",
            "いらっしゃらない",
            "いらっしゃれる",
            "いらっしゃろう",
            "いらっしゃれば",
            "いらっしゃい",
            "いらっしゃられる",
            "いらっしゃらせる",
        ],
    );
    assert_kana_row(
        "くださる",
        V5,
        [
            "くださいます",
            "くださって",
            "くださった",
            "くださらない",
            "くだされる",
            "くださろう",
            "くだされば",
            "ください",
            "くださられる",
            "くださらせる",
        ],
    );
    assert_kana_row(
        "おっしゃる",
        V5,
        [
            "おっしゃいます",
            "おっしゃって",
            "おっしゃった",
            "おっしゃらない",
            "おっしゃれる",
            "おっしゃろう",
            "おっしゃれば",
            "おっしゃい",
            "おっしゃられる",
            "おっしゃらせる",
        ],
    );
    assert_kana_row(
        "なさる",
        V5,
        [
            "なさいます",
            "なさって",
            "なさった",
            "なさらない",
            "なされる",
            "なさろう",
            "なされば",
            "なさい",
            "なさられる",
            "なさらせる",
        ],
    );
}

#[test]
fn gozaru_only_changes_masu() {
    assert_eq!(
        conjugate_kana("ござる", V5, Masu).as_deref(),
        Some("ございます")
    );
    assert_eq!(
        conjugate_kana("ござる", V5, Imperative).as_deref(),
        Some("ござれ")
    );
    assert_eq!(
        conjugate_kana("ござる", V5, Nai).as_deref(),
        Some("ござらない")
    );
}

#[test]
fn honorific_verbs_keep_kanji_in_surface() {
    let cases = [
        ("下さる", "くださる", "下さいます", "下さい"),
        ("仰る", "おっしゃる", "仰います", "仰い"),
        ("為さる", "なさる", "為さいます", "為さい"),
    ];
    for (surface, kana, masu, imperative) in cases {
        assert_eq!(
            conjugate_surface(surface, kana, V5, Masu).as_deref(),
            Some(masu)
        );
        assert_eq!(
            conjugate_surface(surface, kana, V5, Imperative).as_deref(),
            Some(imperative)
        );
    }
    assert_eq!(
        conjugate_surface("御座る", "ござる", V5, Masu).as_deref(),
        Some("御座います")
    );
}

#[test]
fn ordinary_ru_godan_verbs_are_not_honorific() {
    assert_eq!(
        conjugate_kana("かえる", V5, Masu).as_deref(),
        Some("かえります")
    );
    assert_eq!(
        conjugate_kana("かえる", V5, Imperative).as_deref(),
        Some("かえれ")
    );
}

#[test]
fn vs_stem_takes_suru_endings() {
    assert_kana_row(
        "べんきょう",
        Vs,
        [
            "べんきょうします",
            "べんきょうして",
            "べんきょうした",
            "べんきょうしない",
            "べんきょうできる",
            "べんきょうしよう",
            "べんきょうすれば",
            "べんきょうしろ",
            "べんきょうされる",
            "べんきょうさせる",
        ],
    );
    assert_surface_row(
        "勉強",
        "べんきょう",
        Vs,
        [
            "勉強します",
            "勉強して",
            "勉強した",
            "勉強しない",
            "勉強できる",
            "勉強しよう",
            "勉強すれば",
            "勉強しろ",
            "勉強される",
            "勉強させる",
        ],
    );
}

#[test]
fn suru_itself_has_empty_stem() {
    let row = [
        "します",
        "して",
        "した",
        "しない",
        "できる",
        "しよう",
        "すれば",
        "しろ",
        "される",
        "させる",
    ];
    assert_kana_row("する", Vs, row);
    assert_surface_row("する", "する", Vs, row);
}

#[test]
fn vs_tolerates_lemma_written_with_suru() {
    assert_eq!(
        conjugate_kana("べんきょうする", Vs, Masu).as_deref(),
        Some("べんきょうします")
    );
    assert_eq!(
        conjugate_surface("勉強する", "べんきょうする", Vs, Masu).as_deref(),
        Some("勉強します")
    );
}

#[test]
fn vk_all_forms() {
    assert_kana_row(
        "くる",
        Vk,
        [
            "きます",
            "きて",
            "きた",
            "こない",
            "こられる",
            "こよう",
            "くれば",
            "こい",
            "こられる",
            "こさせる",
        ],
    );
    assert_surface_row(
        "来る",
        "くる",
        Vk,
        [
            "来ます",
            "来て",
            "来た",
            "来ない",
            "来られる",
            "来よう",
            "来れば",
            "来い",
            "来られる",
            "来させる",
        ],
    );
    assert_surface_row(
        "くる",
        "くる",
        Vk,
        [
            "きます",
            "きて",
            "きた",
            "こない",
            "こられる",
            "こよう",
            "くれば",
            "こい",
            "こられる",
            "こさせる",
        ],
    );
}

#[test]
fn vk_compound_keeps_prefix() {
    assert_eq!(
        conjugate_kana("もってくる", Vk, Te).as_deref(),
        Some("もってきて")
    );
    assert_eq!(
        conjugate_surface("持って来る", "もってくる", Vk, Nai).as_deref(),
        Some("持って来ない")
    );
    assert_eq!(
        conjugate_surface("持ってくる", "もってくる", Vk, Nai).as_deref(),
        Some("持ってこない")
    );
}

#[test]
fn adj_i_forms() {
    let cases = [
        ("たかい", Nai, "たかくない"),
        ("たかい", Te, "たかくて"),
        ("たかい", Ta, "たかかった"),
        ("たかい", Ba, "たかければ"),
        ("いい", Nai, "よくない"),
        ("いい", Te, "よくて"),
        ("いい", Ta, "よかった"),
        ("いい", Ba, "よければ"),
        ("かっこいい", Nai, "かっこよくない"),
        ("かわいい", Nai, "かわいくない"),
        ("よい", Nai, "よくない"),
    ];
    for (kana, form, want) in cases {
        assert_eq!(
            conjugate_kana(kana, AdjI, form).as_deref(),
            Some(want),
            "{kana} {form:?}"
        );
    }
}

#[test]
fn adj_i_rejects_verb_only_forms() {
    for form in [Masu, Potential, Volitional, Imperative, Passive, Causative] {
        assert_eq!(conjugate_kana("たかい", AdjI, form), None, "{form:?}");
    }
}

#[test]
fn surface_cases_from_spike() {
    let cases = [
        ("食べる", "たべる", V1, Masu, "食べます"),
        ("食べる", "たべる", V1, Te, "食べて"),
        ("飲む", "のむ", V5, Te, "飲んで"),
        ("飲む", "のむ", V5, Masu, "飲みます"),
        ("行く", "いく", V5, Te, "行って"),
        ("書く", "かく", V5, Te, "書いて"),
        ("買う", "かう", V5, Nai, "買わない"),
        ("来る", "くる", Vk, Nai, "来ない"),
        ("来る", "くる", Vk, Masu, "来ます"),
        ("高い", "たかい", AdjI, Nai, "高くない"),
        ("いい", "いい", AdjI, Nai, "よくない"),
        ("ある", "ある", V5, Nai, "ない"),
        ("する", "する", Vs, Te, "して"),
        ("見る", "みる", V1, Masu, "見ます"),
        ("寝る", "ねる", V1, Te, "寝て"),
    ];
    for (surface, kana, pos, form, want) in cases {
        assert_eq!(
            conjugate_surface(surface, kana, pos, form).as_deref(),
            Some(want),
            "{surface} {form:?}"
        );
    }
}

#[test]
fn surface_passive_and_causative() {
    let cases = [
        ("食べる", "たべる", V1, Passive, "食べられる"),
        ("食べる", "たべる", V1, Causative, "食べさせる"),
        ("飲む", "のむ", V5, Passive, "飲まれる"),
        ("飲む", "のむ", V5, Causative, "飲ませる"),
        ("買う", "かう", V5, Passive, "買われる"),
        ("買う", "かう", V5, Causative, "買わせる"),
        ("行く", "いく", V5, Passive, "行かれる"),
        ("行く", "いく", V5, Causative, "行かせる"),
    ];
    for (surface, kana, pos, form, want) in cases {
        assert_eq!(
            conjugate_surface(surface, kana, pos, form).as_deref(),
            Some(want),
            "{surface} {form:?}"
        );
    }
}

#[test]
fn surface_of_ii_keeps_kanji_or_rewrites_kana() {
    let cases = [
        ("良い", "いい", Nai, "良くない"),
        ("良い", "いい", Ta, "良かった"),
        ("良い", "いい", Ba, "良ければ"),
        ("いい", "いい", Ta, "よかった"),
        ("かっこいい", "かっこいい", Te, "かっこよくて"),
        ("格好いい", "かっこいい", Nai, "格好よくない"),
        ("可愛い", "かわいい", Nai, "可愛くない"),
    ];
    for (surface, kana, form, want) in cases {
        assert_eq!(
            conjugate_surface(surface, kana, AdjI, form).as_deref(),
            Some(want),
            "{surface} {form:?}"
        );
    }
}

#[test]
fn non_inflecting_or_malformed_lemmas_return_none() {
    let cases = [
        ("ほん", N, Masu),
        ("きれい", AdjNa, Te),
        ("たべ", V1, Masu),
        ("たべ", V5, Masu),
        ("たか", AdjI, Nai),
        ("き", Vk, Masu),
        ("", Vs, Masu),
        ("", V5, Te),
    ];
    for (kana, pos, form) in cases {
        assert_eq!(
            conjugate_kana(kana, pos, form),
            None,
            "{kana} {pos:?} {form:?}"
        );
    }
}

#[test]
fn surface_mismatch_returns_none() {
    assert_eq!(conjugate_surface("飲み", "のむ", V5, Masu), None);
    assert_eq!(conjugate_surface("本", "ほん", N, Masu), None);
    assert_eq!(conjugate_surface("来る", "たべる", Vk, Masu), None);
    assert_eq!(conjugate_surface("行", "くる", Vk, Masu), None);
}

#[test]
fn pos_and_form_deserialize_from_curriculum_names() {
    let pos = |s: &str| serde_json::from_str::<Pos>(&format!("\"{s}\"")).expect("合法的 pos");
    let form = |s: &str| serde_json::from_str::<Form>(&format!("\"{s}\"")).expect("合法的 form");
    assert_eq!(pos("v5"), V5);
    assert_eq!(pos("v1"), V1);
    assert_eq!(pos("v1_s"), V1S);
    assert_eq!(pos("vs"), Vs);
    assert_eq!(pos("vk"), Vk);
    assert_eq!(pos("adj_i"), AdjI);
    assert_eq!(pos("adj_na"), AdjNa);
    assert_eq!(pos("n"), N);
    for (name, want) in [
        ("masu", Masu),
        ("te", Te),
        ("ta", Ta),
        ("nai", Nai),
        ("potential", Potential),
        ("volitional", Volitional),
        ("ba", Ba),
        ("passive", Passive),
        ("causative", Causative),
        ("imperative", Imperative),
    ] {
        assert_eq!(form(name), want);
    }
}

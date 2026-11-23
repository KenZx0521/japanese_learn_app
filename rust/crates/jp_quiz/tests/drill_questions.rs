//! §8.4 手寫演練轉題目。

mod common;

use common::*;
use jp_content::ContentStore;
use jp_quiz::drill::drill_question;
use jp_quiz::model::QuestionBody;
use jp_quiz::{Question, QuestionKey, QuestionType};

fn build(store: &ContentStore, id: &str) -> Question {
    build_seeded(store, id, SEED)
}

fn build_seeded(store: &ContentStore, id: &str, seed: u32) -> Question {
    let known = all_known(store);
    let context = with_seed(&ctx(store, &known), seed);
    drill_question(&context, drill(store, id), QuestionKey::plain(id), None).unwrap()
}

#[test]
fn every_drill_carries_reference_and_focus_ids() {
    let store = content();
    let question = build(&store, "dr.l01.par.001");

    assert_eq!(
        question.reference.drill_id.as_deref(),
        Some("dr.l01.par.001")
    );
    assert_eq!(question.reference.card_id, None);
    assert_eq!(question.reference.content_id, "gr.wa_topic");
    assert_eq!(question.reference.question_type, QuestionType::ParticleFill);
    assert_eq!(question.focus_ids, vec!["gr.wa_topic", "gr.desu"]);
}

#[test]
fn card_key_and_content_override_reach_the_reference() {
    let store = content();
    let known = all_known(&store);
    let context = ctx(&store, &known);
    let key = QuestionKey::card("gr.desu:use");

    let question = drill_question(
        &context,
        drill(&store, "dr.l01.par.001"),
        key,
        Some("gr.desu"),
    )
    .unwrap();

    assert_eq!(question.reference.card_id.as_deref(), Some("gr.desu:use"));
    assert_eq!(question.reference.content_id, "gr.desu");
}

#[test]
fn particle_fill_uses_blank_choices_and_marks_blank_word() {
    let store = content();

    let question = build(&store, "dr.l01.par.001");

    assert_eq!(question.question_type, QuestionType::ParticleFill);
    assert_eq!(sorted(option_ids(&question)), vec!["c0", "c1"]);
    assert_eq!(correct_id(&question), "c0");
    assert_eq!(blank_index(&question), Some(1));
    assert!(option_texts(&question).contains(&"は"));
    assert_eq!(question.explain_zh.as_deref(), Some("主題用 {ja:は}。"));
    assert_eq!(question.prompt.text.as_ref().unwrap().id, "se.l01.001");
}

/// 正解靠語境決定，作答時要看得到中文。
#[test]
fn particle_fill_shows_the_sentence_meaning() {
    let store = content();
    let zh = store
        .sentences()
        .iter()
        .find(|entry| entry.def.id == "se.l01.001")
        .unwrap()
        .def
        .zh
        .clone();

    let question = build(&store, "dr.l01.par.001");

    assert_eq!(question.prompt.plain_text.as_deref(), Some(zh.as_str()));
}

#[test]
fn zh_to_ja_uses_answer_and_distractors_with_why() {
    let store = content();

    let question = build(&store, "dr.l01.z2j.001");

    assert_eq!(question.question_type, QuestionType::ZhToJaChoice);
    assert_eq!(sorted(option_ids(&question)), vec!["a", "d0"]);
    assert_eq!(correct_id(&question), "a");
    assert_eq!(question.prompt.plain_text.as_deref(), Some("我是老師。"));
    let opts = options(&question);
    let answer = opts.iter().find(|o| o.id == "a").unwrap();
    let distractor = opts.iter().find(|o| o.id == "d0").unwrap();
    assert_eq!(answer.text, "私は先生。");
    assert_eq!(answer.why_zh, None);
    assert_eq!(distractor.why_zh.as_deref(), Some("這是說自己是學生。"));
    assert!(answer.sentence.is_some() && answer.speech.is_some());
    assert!(distractor.sentence.is_some() && distractor.speech.is_some());
}

#[test]
fn drill_level_tts_applies_only_when_sentence_has_none() {
    let store = content_with(&[(
        r#""why_zh": "這是吃飯。"}], "tts": "auto""#,
        r#""why_zh": "這是吃飯。"}], "tts": "kana""#,
    )]);

    let question = build(&store, "dr.l02.z2j.001");

    let opts = options(&question);
    let answer = opts.iter().find(|o| o.id == "a").unwrap();
    assert_eq!(
        answer.speech.as_ref().unwrap().text,
        "わたし わ おちゃ を のみます。"
    );
    let distractor = opts.iter().find(|o| o.id == "d0").unwrap();
    assert_eq!(
        distractor.speech.as_ref().unwrap().text,
        "わたし わ ごはん を たべます。"
    );
}

#[test]
fn situation_response_accepts_inline_answer_and_keeps_style() {
    let store = content();

    let question = build(&store, "dr.l01.sit.001");

    assert_eq!(question.question_type, QuestionType::SituationResponse);
    assert_eq!(correct_id(&question), "a");
    assert_eq!(
        question.prompt.plain_text.as_deref(),
        Some("第一次見面打招呼。")
    );
    let answer = options(&question).iter().find(|o| o.id == "a").unwrap();
    assert_eq!(answer.text, "はじめまして。");
    let sentence = answer.sentence.as_ref().unwrap();
    assert_eq!(sentence.style, jp_content::schema::Style::Polite);
    assert_eq!(sentence.id, "dr.l01.sit.001:a");
}

#[test]
fn situation_response_prompt_line_goes_to_text() {
    let store = content_with(&[(
        r#""style": "polite", "answer": "はじめまして|vo.hajimemashite 。""#,
        r#""style": "polite", "prompt": "こんにち|vo.konnichiwa は|vo.konnichiwa 。", "answer": "はじめまして|vo.hajimemashite 。""#,
    )]);

    let question = build(&store, "dr.l01.sit.001");

    let text = question.prompt.text.as_ref().unwrap();
    assert_eq!(text.parsed.display, "こんにちは。");
}

#[test]
fn listen_meaning_hides_text_and_answer_index_becomes_stable_id() {
    let store = content();

    let question = build(&store, "dr.l01.lsn.001");

    assert_eq!(question.question_type, QuestionType::ListenMeaning);
    assert_eq!(sorted(option_ids(&question)), vec!["c0", "c1", "c2"]);
    assert_eq!(correct_id(&question), "c0");
    assert!(question.prompt.autoplay && question.prompt.hide_text_until_answered);
    assert_eq!(question.prompt.text.as_ref().unwrap().id, "se.l01.003");
    assert!(question.prompt.speech.is_some());
}

#[test]
fn false_friend_shows_prompt_and_note_as_explanation() {
    let store = content();

    let question = build(&store, "dr.l08.ffr.001");

    assert_eq!(question.question_type, QuestionType::FalseFriend);
    assert_eq!(correct_id(&question), "c0");
    assert_eq!(
        question.prompt.plain_text.as_deref(),
        Some("「{ja:手紙|てがみ}」是什麼意思？")
    );
    let explain = question.explain_zh.as_deref().unwrap();
    assert!(
        explain.contains("信（書信）") && explain.contains("衛生紙"),
        "{explain}"
    );
}

#[test]
fn reorder_chunks_follow_sentence_and_accept_orders_are_kept() {
    let store = content();

    let question = build(&store, "dr.l02.ord.001");

    assert_eq!(question.question_type, QuestionType::Reorder);
    assert_eq!(accept_orders(&question), &[vec![0, 1, 2], vec![1, 0, 2]]);
    let QuestionBody::Reorder { chunks, .. } = &question.body else {
        panic!("預期 Reorder");
    };
    let by_index = |index: u32| {
        chunks
            .iter()
            .find(|c| c.index == index)
            .unwrap()
            .text
            .as_str()
    };
    assert_eq!(by_index(0), "私は");
    assert_eq!(by_index(1), "ご飯を");
    assert_eq!(by_index(2), "食べます");
}

#[test]
fn audio_first_reorder_hides_text_and_plain_reorder_shows_chinese_only() {
    let store = content();

    let audio_first = build(&store, "dr.l02.ord.001");
    assert!(audio_first.prompt.hide_text_until_answered && audio_first.prompt.autoplay);
    assert!(audio_first.prompt.text.is_some());
    assert_eq!(audio_first.prompt.plain_text, None);

    let plain = build(&store, "dr.l01.ord.001");
    assert!(!plain.prompt.hide_text_until_answered && !plain.prompt.autoplay);
    assert_eq!(plain.prompt.text, None);
    assert_eq!(plain.prompt.plain_text.as_deref(), Some("是的，是學生。"));
    assert_eq!(plain.prompt.speech, None);
}

#[test]
fn reorder_never_presents_an_accepted_order() {
    let store = content();

    for id in [
        "dr.l01.ord.001",
        "dr.l02.ord.001",
        "dr.l21.ord.001",
        "dr.l21.reg.001",
    ] {
        for seed in 0..200 {
            let question = build_seeded(&store, id, seed);
            let presented = chunk_order(&question);
            assert!(
                !accept_orders(&question).contains(&presented),
                "{id} seed {seed}: {presented:?}"
            );
        }
    }
}

#[test]
fn reorder_returns_directly_when_every_permutation_is_legal() {
    let store = content_with(&[(
        r#""sentence": "se.l01.003", "accept_orders": [[0, 1, 2]]"#,
        r#""sentence": "se.l01.003", "accept_orders": [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]"#,
    )]);

    let question = build(&store, "dr.l01.ord.001");

    assert_eq!(chunk_order(&question).len(), 3);
}

#[test]
fn reorder_escapes_rotations_when_all_of_them_are_accepted() {
    let store = content_with(&[(
        r#""sentence": "se.l01.003", "accept_orders": [[0, 1, 2]]"#,
        r#""sentence": "se.l01.003", "accept_orders": [[0,1,2],[1,2,0],[2,0,1]]"#,
    )]);

    for seed in 0..50 {
        let question = build_seeded(&store, "dr.l01.ord.001", seed);
        assert!(!accept_orders(&question).contains(&chunk_order(&question)));
    }
}

#[test]
fn register_convert_shows_source_and_orders_target() {
    let store = content();

    let question = build(&store, "dr.l21.reg.001");

    assert_eq!(question.question_type, QuestionType::RegisterConvert);
    assert_eq!(question.prompt.text.as_ref().unwrap().id, "se.l02.001");
    assert_eq!(accept_orders(&question), &[vec![0, 1]]);
    assert_eq!(question.prompt.plain_text.as_deref(), Some("改成常體"));
}

#[test]
fn conjugate_picks_a_lemma_by_seed_and_expects_generated_reading() {
    let store = content();

    let question = build(&store, "dr.l02.cnj.001");

    assert_eq!(question.question_type, QuestionType::Conjugate);
    let variant = question.reference.variant.unwrap();
    let QuestionBody::Typing {
        expected_reading, ..
    } = &question.body
    else {
        panic!("預期 Typing");
    };
    let (word, reading) = [("食べる", "たべます"), ("飲む", "のみます")][variant as usize];
    assert_eq!(expected_reading, reading);
    let prompt = question.prompt.plain_text.as_deref().unwrap();
    assert!(
        prompt.contains(word) && prompt.contains("{ja:ます}形"),
        "{prompt}"
    );

    let variants: std::collections::HashSet<_> = (0..50)
        .map(|seed| {
            build_seeded(&store, "dr.l02.cnj.001", seed)
                .reference
                .variant
        })
        .collect();
    assert_eq!(variants.len(), 2);
}

#[test]
fn minimal_pair_plays_one_side_and_offers_both_speeches() {
    let store = content();

    let question = build(&store, "dr.k11.mpr.001");

    assert_eq!(question.question_type, QuestionType::MinimalPair);
    assert_eq!(sorted(option_ids(&question)), vec!["a", "b"]);
    let variant = question.reference.variant.unwrap();
    assert_eq!(correct_id(&question), ["a", "b"][variant as usize]);
    assert_eq!(
        question.prompt.speech.as_ref().unwrap().text,
        ["か", "が"][variant as usize]
    );
    assert!(question.prompt.autoplay);
    assert_eq!(question.prompt.plain_text, None);
    assert_eq!(question.prompt.text, None);
    assert!(options(&question).iter().all(|o| o.speech.is_some()));
    assert!(option_texts(&question).contains(&"清音"));
}

#[test]
fn minimal_pair_uses_pair_speech_fields() {
    let store = content_with(&[(
        r#""targets": ["ka.sg.accent_ame"], "a": "雨", "a_kana": "あめ", "a_zh": "雨", "b": "飴", "b_kana": "あめ", "b_zh": "糖果", "listen_disabled": true"#,
        r#""targets": ["ka.sg.accent_ame"], "a": "雨", "a_kana": "あめ", "a_zh": "雨", "b": "飴", "b_kana": "あめ", "b_zh": "糖果""#,
    )]);

    let question = build(&store, "dr.k19.mpr.001");

    let option = options(&question).iter().find(|o| o.id == "a").unwrap();
    let speech = option.speech.as_ref().unwrap();
    assert_eq!(speech.text, "雨");
    assert_eq!(speech.kana, "あめ");
}

#[test]
fn kana_word_choice_and_typing_modes() {
    let store = content();

    let choice = build(&store, "dr.k05.kwd.001");
    assert_eq!(choice.question_type, QuestionType::KanaWord);
    assert_eq!(choice.prompt.plain_text.as_deref(), Some("{ja:いぬ}"));
    assert_eq!(correct_id(&choice), "c0");
    assert_eq!(options(&choice).len(), 4);
    assert!(!choice.prompt.autoplay);

    let typing = build(&store, "dr.k11.kwd.002");
    let QuestionBody::Typing {
        expected_reading, ..
    } = &typing.body
    else {
        panic!("預期 Typing");
    };
    assert_eq!(expected_reading, "かぎ");
    assert_eq!(typing.question_type, QuestionType::KanaWord);
}

#[test]
fn shadowing_gives_shadow_body_with_sentence() {
    let store = content();

    let question = build(&store, "dr.l01.shd.001");

    assert_eq!(question.question_type, QuestionType::Shadowing);
    let QuestionBody::Shadow { reveal } = &question.body else {
        panic!("預期 Shadow");
    };
    assert_eq!(reveal.id, "se.l01.002");
    assert!(question.prompt.autoplay);
    assert!(question.prompt.speech.is_some());
}

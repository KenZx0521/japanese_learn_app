//! 內容查詢、旗標、顯示規則與工具函式（rust-core.md §9.4、§9.5）。

mod common;

use common::*;
use jp_content::schema::ContentStage as FixtureStage;
use jp_core::api::dto_content::LessonStatus;
use jp_core::api::dto_content::{
    ConfusableKindDto, JlptLevel, KanaKindDto, KanaScript, KanaStatus, NoteDto, NoteKind,
    SrsStateLabel, UseLevelDto, VocabFilterDto, VocabFlagsDto,
};
use jp_core::api::dto_plan::StartLevel;
use jp_core::api::dto_study::{NewContentStepDto, SessionNextDto};
use jp_core::api::error::CoreError;

fn assert_not_found<T: std::fmt::Debug>(result: Result<T, CoreError>) {
    assert!(matches!(result.unwrap_err(), CoreError::NotFound { .. }));
}

#[test]
fn kana_chart_keeps_vowel_alignment_with_empty_cells() {
    let app = TestApp::new();

    let chart = app.core.kana_chart(KanaScript::Hiragana).unwrap();

    assert_eq!(chart[0].columns, 5);
    let basic = &chart[0].rows;
    let row_of = |id: &str| {
        basic
            .iter()
            .find(|row| row.cells.iter().flatten().any(|cell| cell.id == id))
            .unwrap()
    };
    let ya: Vec<bool> = row_of("ka.hira.ya")
        .cells
        .iter()
        .map(Option::is_some)
        .collect();
    assert_eq!(ya, [true, false, true, false, true]);
    let wa: Vec<bool> = row_of("ka.hira.wa")
        .cells
        .iter()
        .map(Option::is_some)
        .collect();
    assert_eq!(wa, [true, false, false, false, true]);
    let n = row_of("ka.hira.n");
    assert_eq!(n.cells.iter().flatten().count(), 1);
    assert_eq!(n.cells.len(), 5);

    let shi = row_of("ka.hira.shi").cells[1].as_ref().unwrap();
    assert_eq!(shi.ch, "し");
    assert_eq!(shi.romaji, "shi");
    assert_eq!(shi.kind, KanaKindDto::Basic);
    assert_eq!(shi.status, KanaStatus::NotStarted);

    let yoon = chart.iter().find(|g| g.columns == 3).unwrap();
    assert_eq!(yoon.rows[0].cells.len(), 3);
    assert_eq!(yoon.rows[0].cells[1].as_ref().unwrap().id, "ka.hira.kyu");
}

#[test]
fn katakana_chart_includes_extended_sounds() {
    let app = TestApp::new();

    let chart = app.core.kana_chart(KanaScript::Katakana).unwrap();

    let all: Vec<_> = chart
        .iter()
        .flat_map(|g| &g.rows)
        .flat_map(|r| r.cells.iter().flatten())
        .collect();
    assert!(all.iter().any(|c| c.kind == KanaKindDto::Extended));
    assert!(all.iter().any(|c| c.id == "ka.kata.a"));
}

#[test]
fn kana_detail_includes_confusables_and_examples() {
    let app = TestApp::new();

    let detail = app.core.kana_detail("ka.hira.nu".into()).unwrap();

    assert_eq!(detail.lesson_id, "le.k05");
    assert_eq!(detail.confusables[0].id, "ka.cf.nu_me");
    assert_eq!(detail.confusables[0].kind, ConfusableKindDto::Shape);
    assert_eq!(detail.confusables[0].members.len(), 2);
    assert_not_found(app.core.kana_detail("ka.hira.nope".into()));
}

#[test]
fn rule_cards_hide_drills_that_are_not_playable() {
    let app = TestApp::new();

    assert_eq!(
        app.core
            .rule_card("ka.rule.sokuon".into())
            .unwrap()
            .drill_ids,
        ["dr.k16.mpr.001"]
    );
    assert!(app
        .core
        .rule_card("ka.rule.accent_intro".into())
        .unwrap()
        .drill_ids
        .is_empty());
    assert_not_found(app.core.rule_card("ka.rule.nope".into()));

    let groups = app.core.sound_groups().unwrap();
    assert!(groups
        .iter()
        .any(|g| g.id == "ka.sg.voicing_k" && g.test_drill_ids == ["dr.k11.mpr.001"]));
    let accent = groups.iter().find(|g| g.id == "ka.sg.accent_ame").unwrap();
    assert!(
        accent.test_drill_ids.is_empty(),
        "listen_disabled 的題要濾掉"
    );
    assert!(!accent.pairs.is_empty());
}

#[test]
fn vocab_page_filters_and_paginates_in_course_order() {
    let app = TestApp::new();

    let page = app
        .core
        .vocab_page(VocabFilterDto::default(), 0, 3)
        .unwrap();
    assert_eq!(page.items.len(), 3);
    assert_eq!(page.items[0].id, "vo.watashi");
    let all = page.total;
    assert!(all > 3);

    let next = app
        .core
        .vocab_page(VocabFilterDto::default(), 3, 3)
        .unwrap();
    assert_ne!(next.items[0].id, page.items[0].id);

    let food = VocabFilterDto {
        topic: Some("food".to_owned()),
        ..VocabFilterDto::default()
    };
    assert_eq!(app.core.vocab_page(food, 0, 50).unwrap().total, 2);
    let verbs = VocabFilterDto {
        pos: Some("v1".to_owned()),
        ..VocabFilterDto::default()
    };
    assert!(app
        .core
        .vocab_page(verbs, 0, 50)
        .unwrap()
        .items
        .iter()
        .all(|v| v.pos == "v1"));
    let lesson = VocabFilterDto {
        lesson_id: Some("le.l02".to_owned()),
        ..VocabFilterDto::default()
    };
    assert_eq!(app.core.vocab_page(lesson, 0, 50).unwrap().total, 2);
    let n4 = VocabFilterDto {
        jlpt: Some("n4".to_owned()),
        ..VocabFilterDto::default()
    };
    assert_eq!(app.core.vocab_page(n4, 0, 50).unwrap().total, 0);
    for limit in [0, 201] {
        assert!(matches!(
            app.core
                .vocab_page(VocabFilterDto::default(), 0, limit)
                .unwrap_err(),
            CoreError::InvalidInput { .. }
        ));
    }
}

#[test]
fn vocab_page_supports_introduced_and_srs_filters() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));
    let total_of = |core: &jp_core::api::core::AppCore, wanted: SrsStateLabel| {
        let filter = VocabFilterDto {
            srs_state: Some(wanted),
            ..VocabFilterDto::default()
        };
        core.vocab_page(filter, 0, 50).unwrap().total
    };

    // 第一次接觸答一次：離開 state=0，進入學習中
    let key = new_content_key(&app.today()).unwrap();
    let session = app.core.new_content_session(key, SEED, true).unwrap();
    let NewContentStepDto::Vocab {
        first_card: Some(card),
        ..
    } = &session.steps[0]
    else {
        panic!("第一步應為帶 first_card 的 Vocab");
    };
    app.core
        .submit_answer(answer_for(card, correct_payload(&card.question)))
        .unwrap();
    assert_eq!(total_of(&app.core, SrsStateLabel::Learning), 1);
    assert_eq!(total_of(&app.core, SrsStateLabel::Review), 0);

    // 收尾後畢業成複習卡，未介紹的字仍是 NotStarted
    study_full_day(&app, true);
    app.next_day();
    assert!(total_of(&app.core, SrsStateLabel::Review) >= 1);
    assert!(total_of(&app.core, SrsStateLabel::NotStarted) >= 3);

    // 第一個切片 5 字
    let introduced = VocabFilterDto {
        only_introduced: true,
        ..VocabFilterDto::default()
    };
    let page = app.core.vocab_page(introduced, 0, 50).unwrap();
    assert_eq!(page.total, 5);
}

#[test]
fn vocab_detail_exposes_conjugations_notes_and_examples() {
    let app = TestApp::new();

    let taberu = app.core.vocab_detail("vo.taberu".into()).unwrap();
    assert_eq!(taberu.jlpt, JlptLevel::N5);
    assert_eq!(taberu.use_level, UseLevelDto::Safe);
    assert_eq!(taberu.summary.pos, "v1");
    let te = taberu
        .conjugations
        .iter()
        .find(|c| c.form == "{ja:て}形")
        .unwrap();
    assert_eq!(te.kana, "たべて");
    assert_eq!(te.surface, "食べて");
    assert!(!taberu.examples.is_empty());
    assert!(taberu.examples.iter().all(|e| !e.words.is_empty()));

    let noun = app.core.vocab_detail("vo.tegami".into()).unwrap();
    assert!(noun.conjugations.is_empty());
    assert!(noun.same_form_zh);
    assert_eq!(noun.notes.len(), 1);
    assert_not_found(app.core.vocab_detail("vo.nope".into()));
}

#[test]
fn search_matches_kana_romaji_and_chinese_with_ranking() {
    let app = TestApp::new();

    assert_eq!(
        app.core.search_vocab("わたし".into(), 10).unwrap()[0].id,
        "vo.watashi"
    );
    assert_eq!(
        app.core.search_vocab("ワタシ".into(), 10).unwrap()[0].id,
        "vo.watashi"
    );
    assert_eq!(
        app.core.search_vocab("watashi".into(), 10).unwrap()[0].id,
        "vo.watashi"
    );
    assert_eq!(
        app.core.search_vocab("先生".into(), 10).unwrap()[0].id,
        "vo.sensei"
    );
    assert!(app.core.search_vocab("   ".into(), 10).unwrap().is_empty());
    assert!(app
        .core
        .search_vocab("xyzzy".into(), 10)
        .unwrap()
        .is_empty());
    for limit in [0, 201] {
        assert!(matches!(
            app.core.search_vocab("a".into(), limit).unwrap_err(),
            CoreError::InvalidInput { .. }
        ));
    }

    // 前綴相符（た べる，L02）排在包含（わ た し，L01）之前，即使課序較晚
    let ranked = app.core.search_vocab("た".into(), 10).unwrap();
    let position = |id: &str| ranked.iter().position(|v| v.id == id).unwrap();
    assert!(position("vo.taberu") < position("vo.watashi"));
}

#[test]
fn vocab_topics_count_primary_topics() {
    let app = TestApp::new();

    let topics = app.core.vocab_topics().unwrap();

    let food = topics.iter().find(|t| t.id == "food").unwrap();
    assert_eq!(food.title_zh, "食物、飲料、餐廳");
    assert_eq!(food.count, 2);
    assert!(topics.iter().all(|t| t.count > 0));
}

#[test]
fn known_flag_suspends_cards_and_unmarking_restores_them() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));
    let key = new_content_key(&app.today()).unwrap();
    app.core.new_content_session(key, SEED, true).unwrap();
    let before = app.core.stats_overview().unwrap().cards_new;

    let marked = app
        .core
        .set_vocab_flags(
            "vo.watashi".into(),
            VocabFlagsDto {
                known: true,
                starred: false,
            },
        )
        .unwrap();
    assert!(marked.known);
    assert_eq!(app.core.stats_overview().unwrap().cards_new, before - 1);

    let unmarked = app
        .core
        .set_vocab_flags(
            "vo.watashi".into(),
            VocabFlagsDto {
                known: false,
                starred: true,
            },
        )
        .unwrap();
    assert!(!unmarked.known);
    assert!(unmarked.starred);
    assert_eq!(app.core.stats_overview().unwrap().cards_new, before);
    let starred = VocabFilterDto {
        only_starred: true,
        ..VocabFilterDto::default()
    };
    assert_eq!(app.core.vocab_page(starred, 0, 50).unwrap().total, 1);
}

#[test]
fn marking_an_untaught_word_known_introduces_it_so_slices_skip_it() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));

    app.core
        .set_vocab_flags(
            "vo.watashi".into(),
            VocabFlagsDto {
                known: true,
                starred: false,
            },
        )
        .unwrap();

    let key = new_content_key(&app.core.today_view(true).unwrap());
    let session = app
        .core
        .new_content_session(key.unwrap(), SEED, true)
        .unwrap();
    // 快照在標記前已建立，切片內仍可能有它；隔天重算才跳過，這裡只檢查介紹紀錄
    let introduced = VocabFilterDto {
        only_introduced: true,
        ..VocabFilterDto::default()
    };
    assert_eq!(app.core.vocab_page(introduced, 0, 50).unwrap().total, 1);
    assert!(!session.steps.is_empty());
}

#[test]
fn starring_an_untaught_word_does_not_create_cards() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));

    app.core
        .set_vocab_flags(
            "vo.gohan".into(),
            VocabFlagsDto {
                known: false,
                starred: true,
            },
        )
        .unwrap();

    assert_eq!(app.core.stats_overview().unwrap().cards_new, 0);
}

/// 字所在的課已完成時才建卡；未教的字回到切片（`first_contact.rs`）。
#[test]
fn unmarking_a_word_of_a_completed_lesson_creates_its_recog_card() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(45, StartLevel::Kana));
    let word = "vo.gohan";
    let flags = |known| VocabFlagsDto {
        known,
        starred: false,
    };
    app.core.set_vocab_flags(word.into(), flags(true)).unwrap();
    for _ in 0..20 {
        study_full_day(&app, true);
        app.next_day();
    }
    assert_eq!(
        app.core
            .lesson_detail("le.l01".into())
            .unwrap()
            .summary
            .status,
        LessonStatus::Done
    );
    let before = app.core.stats_overview().unwrap().cards_new;

    app.core.set_vocab_flags(word.into(), flags(false)).unwrap();

    assert_eq!(app.core.stats_overview().unwrap().cards_new, before + 1);
}

#[test]
fn set_vocab_flags_rejects_unknown_words() {
    let app = TestApp::new();
    assert_not_found(app.core.set_vocab_flags(
        "vo.nope".into(),
        VocabFlagsDto {
            known: true,
            starred: false,
        },
    ));
}

#[test]
fn grammar_list_filters_by_stage_query_and_tracks_status() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));

    let all = app.core.grammar_list(None, None).unwrap();
    assert!(all.iter().any(|g| g.id == "gr.desu"));
    assert!(app
        .core
        .grammar_list(Some("st.s0".into()), None)
        .unwrap()
        .is_empty());
    assert!(!app
        .core
        .grammar_list(Some("st.s1".into()), None)
        .unwrap()
        .is_empty());
    let found = app.core.grammar_list(None, Some("desu".into())).unwrap();
    assert!(found.iter().any(|g| g.id == "gr.desu"), "拉丁字母先轉假名");
    assert!(
        app.core
            .grammar_list(None, Some("   ".into()))
            .unwrap()
            .len()
            == all.len()
    );

    study_full_day(&app, true);
    app.next_day();
    let status_of = |id: &str| {
        app.core
            .grammar_list(None, None)
            .unwrap()
            .into_iter()
            .find(|g| g.id == id)
            .unwrap()
            .status
    };
    assert_ne!(
        status_of("gr.desu"),
        jp_core::api::dto_content::GrammarStatus::NotStarted
    );
}

#[test]
fn grammar_detail_maps_formation_terms_and_examples() {
    let app = TestApp::new();

    let detail = app.core.grammar_detail("gr.masu".into()).unwrap();

    assert_eq!(detail.summary.lesson_id, "le.l02");
    assert_eq!(detail.summary.stage_id, "st.s1");
    assert_eq!(detail.terms.len(), 1);
    assert!(!detail.register.is_empty());
    assert!(!detail.examples.is_empty());
    assert_not_found(app.core.grammar_detail("gr.nope".into()));
}

#[test]
fn sentence_and_dialogue_detail_keep_words_and_speech() {
    let app = TestApp::new();

    let sentence = app.core.sentence("se.l01.003".into()).unwrap();
    assert_eq!(sentence.style, "polite");
    assert!(sentence.words.iter().any(|w| w.is_punct));
    assert!(!sentence.speech.kana.is_empty());
    assert_not_found(app.core.sentence("se.nope".into()));

    let dialogue = app.core.dialogue_detail("di.self_intro".into()).unwrap();
    assert!(!dialogue.turns.is_empty());
    assert_eq!(dialogue.quiz_drill_ids, ["dr.l01.lsn.001"]);
    assert_not_found(app.core.dialogue_detail("di.nope".into()));
}

/// 對話清單的鎖定：游標所在課的對話可看，後面課的對話鎖住。
#[test]
fn dialogues_lock_future_lessons() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));

    let dialogues = app.core.dialogues().unwrap();

    let current = dialogues.iter().find(|d| d.id == "di.self_intro").unwrap();
    assert!(!current.locked, "游標在 L01");
    let later = dialogues.iter().find(|d| d.id == "di.meal").unwrap();
    assert!(later.locked);
}

#[test]
fn note_list_returns_each_kind_in_file_order() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));

    assert!(matches!(
        app.core.note_list(NoteKind::FalseFriend).unwrap()[0],
        NoteDto::FalseFriend { .. }
    ));
    assert!(matches!(
        app.core.note_list(NoteKind::Shinjitai).unwrap()[0],
        NoteDto::Shinjitai { .. }
    ));
    assert!(matches!(
        app.core.note_list(NoteKind::Reading).unwrap()[0],
        NoteDto::Reading { .. }
    ));
    assert!(matches!(
        app.core.note_list(NoteKind::Transfer).unwrap()[0],
        NoteDto::Transfer { .. }
    ));
    let terms = app.core.note_list(NoteKind::Term).unwrap();
    assert!(matches!(&terms[0], NoteDto::Term { id, .. } if id == "no.term.masu_stem"));
}

/// `p0a` 內容沒有筆記，入口也不露出。
#[test]
fn p0a_stage_has_no_notes_entry_point() {
    let app = TestApp::with_stage(FixtureStage::P0a);

    let overview = app.core.course_overview().unwrap();

    assert!(!overview.notes_available);
    assert!(app.core.note_list(NoteKind::Term).unwrap().is_empty());
}

#[test]
fn full_stage_exposes_the_notes_entry_point() {
    let app = TestApp::new();

    let overview = app.core.course_overview().unwrap();

    assert!(overview.notes_available);
}

#[test]
fn peek_table_covers_each_prefix() {
    let app = TestApp::new();

    let vocab = app.core.peek("vo.sensei".into()).unwrap();
    assert_eq!(vocab.title, "先生");
    assert_eq!(vocab.kana.as_deref(), Some("せんせい"));
    assert!(vocab.romaji.is_some());
    assert_eq!(vocab.lesson_id.as_deref(), Some("le.l01"));

    let kana = app.core.peek("ka.hira.a".into()).unwrap();
    assert_eq!(kana.title, "あ");
    assert_eq!(kana.romaji.as_deref(), Some("a"));
    assert!(kana.kana.is_none());

    let group = app.core.peek("ka.cf.ka_chikara".into()).unwrap();
    assert_eq!(group.title, "カ／力");

    let rule = app.core.peek("ka.rule.sokuon".into()).unwrap();
    assert!(!rule.title.is_empty());
    assert!(!rule.summary_zh.is_empty());

    let sound = app.core.peek("ka.sg.accent_ame".into()).unwrap();
    assert!(sound.title.contains('／'));

    assert!(app.core.peek("gr.desu".into()).unwrap().summary_zh.len() > 1);
    assert_not_found(app.core.peek("se.l01.001".into()));
    assert_not_found(app.core.peek("@new:x".into()));
}

#[test]
fn word_is_known_after_a_long_review_interval() {
    let mut app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Kana));
    study_full_day(&app, true);

    for _ in 0..80 {
        app.next_day();
        drain_queue(&app.core, true);
        let sentence = app.core.sentence("se.l01.001".into()).unwrap();
        if sentence.words.iter().any(|w| w.is_known) {
            return;
        }
        let _ = matches!(
            app.core.session_next(SEED, true),
            Ok(SessionNextDto::Done { .. })
        );
    }
    panic!("連續答對 80 天後，單字應標成已熟");
}

#[test]
fn course_overview_lists_stages_and_lesson_links() {
    let app = TestApp::new();
    app.start_plan(&plan_input(20, StartLevel::Zero));

    let overview = app.core.course_overview().unwrap();

    assert_eq!(overview.current_lesson_id.as_deref(), Some("le.k01"));
    assert!(!overview.stages.is_empty());
    let l01 = overview.lessons.iter().find(|l| l.id == "le.l01").unwrap();
    assert_eq!(l01.dialogue_id.as_deref(), Some("di.self_intro"));
    let k19 = overview.lessons.iter().find(|l| l.id == "le.k19").unwrap();
    assert_eq!(k19.milestone_id.as_deref(), Some("ms.hira"));

    let detail = app.core.lesson_detail("le.l01".into()).unwrap();
    assert_eq!(detail.words.len(), 8);
    assert_eq!(detail.grammar.len(), 2);
    assert_eq!(
        detail.dialogue.as_ref().map(|d| d.id.as_str()),
        Some("di.self_intro")
    );
    let kana = app.core.lesson_detail("le.k16".into()).unwrap();
    assert_eq!(kana.rules.len(), 1);
    assert_eq!(kana.integration_days_needed, 0);
    assert_not_found(app.core.lesson_detail("le.nope".into()));
}

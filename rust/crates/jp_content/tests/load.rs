//! rust-core.md §3.4：載入、階段過濾、軟引用修剪、索引。

use jp_content::schema::{ContentStage, Pos};
use jp_content::store::ItemKind;
use jp_content::test_support::{
    fixture_files, fixture_files_with_overlay, load_full_fixture, FixtureFiles,
};
use jp_content::{load_content, ContentError};

fn borrow(files: &FixtureFiles) -> Vec<(&str, &str)> {
    files
        .iter()
        .map(|(path, text)| (path.as_str(), text.as_str()))
        .collect()
}

fn corrupt_detail(result: Result<jp_content::store::ContentStore, ContentError>) -> String {
    match result {
        Err(ContentError::Corrupt { file, detail }) => format!("{file}: {detail}"),
        Ok(_) => panic!("應該失敗"),
    }
}

#[test]
fn full_stage_loads_everything() {
    let store = load_full_fixture(ContentStage::Full);
    assert_eq!(store.stage(), ContentStage::Full);
    assert_eq!(store.course().lessons.len(), 28);
    assert!(store.vocab_by_id("vo.miru").is_some());
    assert!(store.note_by_id("no.term.masu_stem").is_some());
    assert_eq!(store.presets().len(), 4);
    assert_eq!(store.milestones().len(), 5);
}

#[test]
fn p0a_filters_lessons_and_notes_and_keeps_only_s0_s1_stages() {
    let store = load_full_fixture(ContentStage::P0a);
    let stage_ids: Vec<&str> = store
        .course()
        .stages
        .iter()
        .map(|s| s.id.as_str())
        .collect();
    assert_eq!(stage_ids, vec!["st.s0", "st.s1"]);
    assert!(store.course().order.iter().all(|id| id != "le.l08"));
    assert!(store.vocab_by_id("vo.tegami").is_none());
    assert!(store.note_by_id("no.ff.tegami").is_none());
    assert!(store.note_by_id("no.sj.gaku").is_none());
    assert_eq!(store.presets().len(), 4);
    assert_eq!(store.milestones().len(), 3);
}

#[test]
fn p0a_drops_false_friend_drills_whose_notes_are_skipped() {
    let files = fixture_files_with_overlay("load_p0a_false_friend_drill");

    let p0a = load_content(&borrow(&files), ContentStage::P0a).expect("p0a 應可載入");
    let p0 = load_content(&borrow(&files), ContentStage::P0).expect("p0 應可載入");

    assert!(
        p0a.drill_by_id("dr.l01.ffr.001").is_none(),
        "no.* 在 p0a 略過，題目跟著略過"
    );
    assert!(p0a.drill_by_id("dr.l01.par.001").is_some());
    assert!(p0.drill_by_id("dr.l01.ffr.001").is_some());
}

#[test]
fn p0_keeps_shinjitai_and_drops_full_only_items() {
    let store = load_full_fixture(ContentStage::P0);
    assert!(store.note_by_id("no.sj.gaku").is_some());
    assert!(store.vocab_by_id("vo.miru").is_none());
    assert!(store.vocab_by_id("vo.suru").is_some());
}

#[test]
fn soft_references_to_filtered_items_are_pruned() {
    let store = load_full_fixture(ContentStage::P0a);
    let grammar = store.grammar_by_id("gr.masu").expect("存在");
    assert!(grammar.terms.is_empty(), "no.term.* 在 p0a 被過濾");
}

#[test]
fn soft_references_remain_when_target_is_present() {
    let store = load_full_fixture(ContentStage::Full);
    let grammar = store.grammar_by_id("gr.masu").expect("存在");
    assert_eq!(grammar.terms, vec!["no.term.masu_stem"]);
}

#[test]
fn hard_reference_missing_is_corrupt() {
    let files = fixture_files_with_overlay("load_bad_hard_ref");
    let detail = corrupt_detail(load_content(&borrow(&files), ContentStage::Full));
    assert!(detail.contains("vo.no_such_word"), "{detail}");
}

#[test]
fn item_with_unknown_lesson_is_corrupt_even_though_filter_would_drop_it() {
    let files = fixture_files_with_overlay("r03_unknown_lesson");
    let detail = corrupt_detail(load_content(&borrow(&files), ContentStage::Full));
    assert!(detail.contains("le.l99"), "{detail}");
}

#[test]
fn soft_reference_to_nonexistent_item_is_corrupt() {
    let files = fixture_files_with_overlay("load_bad_soft_ref");
    let detail = corrupt_detail(load_content(&borrow(&files), ContentStage::Full));
    assert!(detail.contains("se.no_such"), "{detail}");
}

#[test]
fn wrong_schema_version_is_corrupt() {
    let files = fixture_files_with_overlay("load_bad_schema");
    let detail = corrupt_detail(load_content(&borrow(&files), ContentStage::Full));
    assert!(detail.contains("schema"), "{detail}");
}

#[test]
fn unknown_file_path_is_corrupt() {
    let files = fixture_files_with_overlay("load_bad_unknown_file");
    let detail = corrupt_detail(load_content(&borrow(&files), ContentStage::Full));
    assert!(detail.contains("whatever/odd.json"), "{detail}");
}

#[test]
fn input_order_does_not_change_result() {
    let mut files = fixture_files();
    let forward = load_content(&borrow(&files), ContentStage::Full).expect("夾具應可載入");
    files.reverse();
    let backward = load_content(&borrow(&files), ContentStage::Full).expect("夾具應可載入");
    assert_eq!(forward.kana()[0].def.id, backward.kana()[0].def.id);
    assert_eq!(
        forward.sentences()[0].def.id,
        backward.sentences()[0].def.id
    );
}

#[test]
fn id_index_resolves_kinds_and_retired_items() {
    let store = load_full_fixture(ContentStage::Full);
    assert_eq!(
        store.item_ref("vo.taberu").expect("存在").kind,
        ItemKind::Vocab
    );
    assert_eq!(
        store.item_ref("le.l01").expect("存在").kind,
        ItemKind::Lesson
    );
    assert!(store.item_ref("vo.nothing").is_none());
}

#[test]
fn lesson_pos_follows_course_order() {
    let store = load_full_fixture(ContentStage::Full);
    assert_eq!(store.lesson_pos("le.k01"), Some(0));
    assert!(store.lesson_pos("le.l01") < store.lesson_pos("le.kk01"));
    assert!(store.lesson_pos("le.kk01") < store.lesson_pos("le.l02"));
}

#[test]
fn lesson_items_list_the_words_of_the_lesson() {
    let store = load_full_fixture(ContentStage::Full);
    let l21 = store.lesson_items("le.l21").expect("存在");
    let words: Vec<&str> = l21
        .words
        .iter()
        .map(|&i| store.vocab()[i as usize].def.id.as_str())
        .collect();
    assert_eq!(words, vec!["vo.nani", "vo.suru"]);
}

#[test]
fn lesson_items_are_ordered_by_lesson_order() {
    let store = load_full_fixture(ContentStage::Full);
    let l01 = store.lesson_items("le.l01").expect("存在");
    let orders: Vec<u32> = l01
        .words
        .iter()
        .map(|&i| store.vocab()[i as usize].def.lesson_order)
        .collect();
    assert_eq!(orders, vec![1, 2, 3, 4, 5, 6, 7, 8]);
    let grammar: Vec<&str> = l01
        .grammar
        .iter()
        .map(|&i| store.grammar()[i as usize].id.as_str())
        .collect();
    assert_eq!(grammar, vec!["gr.desu", "gr.wa_topic"]);
}

#[test]
fn secondary_indexes_exclude_retired_and_work() {
    let files = fixture_files_with_overlay("load_retired");
    let store = load_content(&borrow(&files), ContentStage::Full).expect("夾具應可載入");
    assert!(
        store.vocab_by_id("vo.retired_word").is_some(),
        "淘汰項目仍可解析"
    );
    assert!(store
        .vocab_with_pos(Pos::N)
        .iter()
        .all(|&i| store.vocab()[i as usize].def.id != "vo.retired_word"));
    let l01 = store.lesson_items("le.l01").expect("存在");
    assert!(l01
        .words
        .iter()
        .all(|&i| store.vocab()[i as usize].def.id != "vo.retired_word"));
}

#[test]
fn sentence_refs_and_usability_follow_known_set() {
    let store = load_full_fixture(ContentStage::Full);
    let index = store.sentence_index("se.l01.002").expect("存在");
    assert!(!store.sentence_is_usable(index, &["vo.sensei".to_owned()].into()));
    let known = ["vo.sensei".to_owned(), "gr.desu".to_owned()].into();
    assert!(store.sentence_is_usable(index, &known));
}

#[test]
fn drills_by_target_and_vocab_indexes() {
    let store = load_full_fixture(ContentStage::Full);
    assert!(store.drills_for_target("gr.masu").len() >= 4);
    assert!(store.vocab_with_topic("food").len() >= 2);
    assert!(store.vocab_with_pos(Pos::Vs).len() == 1);
}

/// 干擾項的「同 pos」把 `v1_s` 與 `v1` 視為同組（rust-core.md §8.3）。
#[test]
fn vocab_with_pos_groups_v1_s_with_v1() {
    let files: FixtureFiles = fixture_files()
        .into_iter()
        .map(|(path, text)| {
            let text = text.replace(
                r#""surface": "見る", "kana": "みる", "zh": ["看"], "pos": "v1""#,
                r#""surface": "見る", "kana": "みる", "zh": ["看"], "pos": "v1_s""#,
            );
            (path, text)
        })
        .collect();
    let store = load_content(&borrow(&files), ContentStage::Full).expect("夾具應可載入");
    assert_eq!(
        store.vocab_by_id("vo.miru").expect("存在").def.pos,
        Pos::V1S
    );
    let ids = |pos| -> Vec<&str> {
        store
            .vocab_with_pos(pos)
            .iter()
            .map(|&i| store.vocab()[i as usize].def.id.as_str())
            .collect()
    };
    assert_eq!(ids(Pos::V1), ids(Pos::V1S));
    assert!(ids(Pos::V1).contains(&"vo.miru"));
    assert!(ids(Pos::V1).contains(&"vo.taberu"));
}

#[test]
fn accessors_resolve_every_kind_by_id() {
    let store = load_full_fixture(ContentStage::Full);
    assert!(store.kana_by_id("ka.hira.a").is_some());
    assert!(store.confusable_by_id("ka.cf.nu_me").is_some());
    assert!(store.rule_card_by_id("ka.rule.sokuon").is_some());
    assert!(store.sound_group_by_id("ka.sg.voicing_k").is_some());
    assert!(store.drill_by_id("dr.l01.lsn.001").is_some());
    assert!(store.preset_by_id("pl.min20").is_some());
    assert_eq!(store.lesson("le.l01").expect("存在").title_zh, "初次見面");
    assert!(store.milestone_for_lesson("le.k19").is_some());
    assert!(store.milestone_for_lesson("le.k01").is_none());
    assert!(store.kana().iter().any(|k| k.def.id == "ka.hira.sokuon"));
    assert_eq!(store.confusables().len(), 4);
    assert_eq!(store.rule_cards().len(), 5);
    assert_eq!(store.sound_groups().len(), 5);
    assert!(!store.vocab().is_empty());
    assert!(!store.drills().is_empty());
    assert!(!store.dialogues().is_empty());
    assert!(!store.notes().is_empty());
    assert!(store.lesson_pos("le.nope").is_none());
    assert!(store.lesson_items("le.nope").is_none());
    assert!(store.drills_for_target("no.such").is_empty());
    assert!(store.vocab_with_topic("no_topic").is_empty());
    assert!(store.vocab_with_pos(Pos::Counter).is_empty());
    assert!(store.sentence_index("vo.taberu").is_none());
    let refs: Vec<&str> = store.sentence_ref_ids(0).collect();
    assert!(refs
        .iter()
        .all(|r| r.starts_with("vo.") || r.starts_with("gr.")));
    let lesson = store.lesson_items("le.l01").expect("存在");
    assert!(!lesson.sentences.is_empty());
    assert!(!lesson.drills.is_empty());
    assert_eq!(
        store
            .lesson_items("le.k11")
            .expect("存在")
            .sound_groups
            .len(),
        1
    );
    assert_eq!(store.lesson_items("le.k16").expect("存在").rules.len(), 1);
    assert_eq!(
        store
            .lesson_items("le.k10")
            .expect("存在")
            .confusables
            .len(),
        1
    );
    assert_eq!(store.lesson_items("le.k11").expect("存在").kana.len(), 10);
    assert_eq!(
        store.lesson_items("le.l01").expect("存在").dialogues.len(),
        1
    );
}

#[test]
fn sentence_entries_carry_derivations() {
    let store = load_full_fixture(ContentStage::Full);
    let entry = store.sentence_by_id("se.l01.002").expect("存在");
    assert_eq!(entry.parsed.display, "先生です。");
    assert_eq!(entry.parsed.speech.text, entry.parsed.display);
    // 句子層級的 `tts: kana`：送出的文字改用假名。
    let kana = store.sentence_by_id("se.l21.010").expect("存在");
    assert_eq!(kana.parsed.display, "何をする。");
    assert_eq!(kana.parsed.speech.text, kana.parsed.speech.kana);
    assert_ne!(kana.parsed.speech.text, kana.parsed.display);
}

#[test]
fn dialogue_entries_carry_parsed_turns() {
    let store = load_full_fixture(ContentStage::Full);
    let entry = store.dialogue_by_id("di.self_intro").expect("存在");
    assert_eq!(entry.turns.len(), entry.def.turns.len());
    assert_eq!(entry.turns[1].speech.text, entry.turns[1].speech.kana);
}

#[test]
fn load_embedded_uses_build_time_stage() {
    let store = jp_content::load_embedded().expect("種子內容應可載入");
    assert_eq!(
        store.stage().name(),
        jp_content::manifest::CONTENT_STAGE_NAME
    );
}

#[test]
fn embedded_content_manifest_loads() {
    let files: Vec<(&str, &str)> = jp_content::manifest::CONTENT_FILES.to_vec();
    let store = load_content(&files, ContentStage::P0a).expect("內嵌內容應可載入");
    assert_eq!(store.kana().len(), 238);
    assert_eq!(store.presets().len(), 4);
}

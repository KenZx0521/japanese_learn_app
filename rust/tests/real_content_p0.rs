//! 真實 `p0` 內容的 API 回歸：載入與 curriculum §14 的筆數、誠實範圍（RULINGS O7）、
//! 筆記（rust-core §9.4 `note_list`）、對話與其測驗、`plan_preview` 的主線完成日。
//! 切片、演練另見 `real_content_p0_slices.rs`、`real_content_p0_drills.rs`。

mod common;

use std::collections::{BTreeMap, BTreeSet};

use chrono::NaiveDate;
use common::answerable::{assert_answerable, assert_sentence_playable};
use common::real::{main_lessons, p0_content, p0a_content};
use common::{plan_input, start_time, TestApp, SEED};
use jp_content::schema::DrillDef;
use jp_content::ContentStore;
use jp_core::api::core::AppCore;
use jp_core::api::dto_content::{
    ContentStage, DialogueKindDto, KanaScript, NoteDto, NoteKind, VocabFilterDto,
};
use jp_core::api::dto_plan::StartLevel;
use jp_core::api::dto_study::DrillFilterDto;

const PRESETS: [u32; 4] = [10, 20, 30, 45];
const LAST_P0_LESSON: &str = "le.l30";
const PAGE_LIMIT: u32 = 1;
/// 以 `common::start_time()` 起算、每天都學、零基礎（§11.4 的表同條件）的實測值。
/// 內容或排程變動時要重新確認，並同步更新 curriculum §11.4。
const MAIN_DAYS: [(u32, i64); 4] = [(10, 413), (20, 251), (30, 180), (45, 144)];

/// curriculum §14 的 `p0` 欄（R17：低於目標才算不足）。
const NOTE_TARGETS: [(NoteKind, usize); 5] = [
    (NoteKind::FalseFriend, 60),
    (NoteKind::Shinjitai, 120),
    (NoteKind::Reading, 20),
    (NoteKind::Transfer, 20),
    (NoteKind::Term, 12),
];

fn p0_app() -> TestApp {
    TestApp::with_content(p0_content())
}

fn shortfalls(rows: &[(&str, usize, usize)]) -> Vec<String> {
    rows.iter()
        .filter(|(_, actual, target)| actual < target)
        .map(|(label, actual, target)| format!("{label} {actual} < {target}"))
        .collect()
}

fn is_kana_drill(drill: &DrillDef) -> bool {
    matches!(
        drill,
        DrillDef::MinimalPair { .. } | DrillDef::KanaWord { .. }
    )
}

fn count_drills(content: &ContentStore, pick: impl Fn(&DrillDef) -> bool) -> usize {
    content
        .drills()
        .iter()
        .filter(|d| !d.retired() && pick(d))
        .count()
}

fn count_sentences(content: &ContentStore) -> usize {
    content
        .sentences()
        .iter()
        .filter(|s| !s.def.retired)
        .count()
}

fn dialogue_count(app: &TestApp, kind: DialogueKindDto) -> usize {
    app.core
        .dialogues()
        .unwrap()
        .iter()
        .filter(|d| d.kind == kind)
        .count()
}

/// 五十音圖（平假名＋片假名）上的格子，含 `kind: mark`。
fn kana_chart_cells(core: &AppCore) -> usize {
    [KanaScript::Hiragana, KanaScript::Katakana]
        .into_iter()
        .flat_map(|script| core.kana_chart(script).unwrap())
        .flat_map(|group| group.rows)
        .map(|row| row.cells.iter().flatten().count())
        .sum()
}

/// AppCore 公開 API 看得到的類別。
fn api_counts(app: &TestApp) -> Vec<(&'static str, usize, usize)> {
    let core = &app.core;
    let vocab_total = core
        .vocab_page(VocabFilterDto::default(), 0, PAGE_LIMIT)
        .unwrap()
        .total as usize;
    let preview = core
        .plan_preview(plan_input(PRESETS[0], StartLevel::Zero))
        .unwrap();
    vec![
        ("假名（字元＋符號）", kana_chart_cells(core), 229 + 9),
        ("課程", core.course_overview().unwrap().lessons.len(), 57),
        ("單字", vocab_total, 800),
        ("文法點", core.grammar_list(None, None).unwrap().len(), 138),
        ("主對話", dialogue_count(app, DialogueKindDto::Lesson), 30),
        ("實戰對話", dialogue_count(app, DialogueKindDto::Extra), 6),
        (
            "常體版對話",
            dialogue_count(app, DialogueKindDto::Casual),
            12,
        ),
        ("里程碑", preview.milestones.len(), 6),
    ]
}

/// API 列舉不出來的類別，經載入後的 ContentStore 計；等同 lint R17，驗的是載入與階段過濾，不是 API。
/// 例句只能逐 id 查（`sentence`）；演練與計畫預設沒有列舉 API。
fn store_counts(content: &ContentStore) -> Vec<(&'static str, usize, usize)> {
    let lesson_drill = |d: &DrillDef| !is_kana_drill(d);
    vec![
        ("主線例句", count_sentences(content), 1_140),
        ("手寫演練（課程）", count_drills(content, lesson_drill), 900),
        (
            "手寫演練（假名）",
            count_drills(content, is_kana_drill),
            100,
        ),
        ("計畫預設", content.presets().len(), 4),
    ]
}

#[test]
fn p0_loads_with_at_least_the_curriculum_counts() {
    let app = p0_app();

    let api = api_counts(&app);
    let store = store_counts(&app.content);

    println!("p0 筆數（API）：{api:?}");
    println!("p0 筆數（載入後的 ContentStore）：{store:?}");
    let rows: Vec<_> = api.into_iter().chain(store).collect();
    assert_eq!(shortfalls(&rows), Vec::<String>::new());
}

/// O7：`p0` 只發布到 L30，筆記入口露出。
#[test]
fn p0_publishes_up_to_l30_and_exposes_notes() {
    let app = p0_app();
    let lessons = main_lessons(&app.content);

    let overview = app.core.course_overview().unwrap();

    assert_eq!(overview.content_stage, ContentStage::P0);
    assert_eq!(lessons.len(), 30);
    assert_eq!(lessons.last().map(String::as_str), Some(LAST_P0_LESSON));
    let last_pos = app.content.lesson_pos(LAST_P0_LESSON).unwrap();
    assert!(overview
        .lessons
        .iter()
        .all(|l| app.content.lesson_pos(&l.id).unwrap() <= last_pos));
    assert!(app
        .core
        .grammar_list(None, None)
        .unwrap()
        .iter()
        .all(|g| lessons.contains(&g.lesson_id)));
    assert!(overview.notes_available);
}

// ---------- 筆記 ----------

fn note_id(note: &NoteDto) -> &str {
    match note {
        NoteDto::FalseFriend { id, .. }
        | NoteDto::Shinjitai { id, .. }
        | NoteDto::Reading { id, .. }
        | NoteDto::Transfer { id, .. }
        | NoteDto::Term { id, .. } => id,
    }
}

fn note_kind(note: &NoteDto) -> NoteKind {
    match note {
        NoteDto::FalseFriend { .. } => NoteKind::FalseFriend,
        NoteDto::Shinjitai { .. } => NoteKind::Shinjitai,
        NoteDto::Reading { .. } => NoteKind::Reading,
        NoteDto::Transfer { .. } => NoteKind::Transfer,
        NoteDto::Term { .. } => NoteKind::Term,
    }
}

#[test]
fn every_note_kind_is_listed_with_its_curriculum_count() {
    let app = p0_app();

    for (kind, target) in NOTE_TARGETS {
        let notes = app.core.note_list(kind).unwrap();
        let ids: BTreeSet<&str> = notes.iter().map(note_id).collect();

        assert!(notes.len() >= target, "{kind:?} 只有 {} 則", notes.len());
        assert_eq!(ids.len(), notes.len(), "{kind:?} 的 id 重複");
        assert!(notes.iter().all(|n| note_kind(n) == kind), "{kind:?}");
    }
}

fn all_notes(app: &TestApp) -> BTreeMap<String, NoteDto> {
    NOTE_TARGETS
        .iter()
        .flat_map(|(kind, _)| app.core.note_list(*kind).unwrap())
        .map(|note| (note_id(&note).to_owned(), note))
        .collect()
}

/// くれる 只寫假名，J05 會因同音的 暮れる（`v1`）放行，所以用真實內容確認它仍標 `v1_s`：
/// 命令形是 くれ，`conj_omit` 列的形不出現在活用表；分かる 不會把 分かれる 列成可能形。
/// `v1` 篩選仍要列出 くれる（同 family）。
#[test]
fn real_conjugation_tables_follow_v1_s_and_conj_omit() {
    let app = p0_app();
    let forms_of = |id: &str| -> Vec<(String, String)> {
        app.core
            .vocab_detail(id.into())
            .unwrap()
            .conjugations
            .into_iter()
            .map(|c| (c.form, c.kana))
            .collect()
    };

    let kureru = forms_of("vo.kureru");
    assert!(
        kureru.iter().any(|(f, k)| f == "命令形" && k == "くれ"),
        "{kureru:?}"
    );
    for omitted in ["可能形", "被動形", "使役形", "意向形"] {
        assert!(
            kureru.iter().all(|(f, _)| f != omitted),
            "{omitted}: {kureru:?}"
        );
    }
    let wakaru = forms_of("vo.wakaru");
    assert!(wakaru.iter().all(|(f, _)| f != "可能形"), "{wakaru:?}");

    let v1_in_l28 = VocabFilterDto {
        pos: Some("v1".to_owned()),
        lesson_id: Some("le.l28".to_owned()),
        ..VocabFilterDto::default()
    };
    let page = app.core.vocab_page(v1_in_l28, 0, 200).unwrap();
    assert!(page.items.iter().any(|v| v.id == "vo.kureru"));
}

#[test]
fn vocab_detail_returns_the_notes_the_word_points_to() {
    let app = p0_app();
    let listed = all_notes(&app);
    let with_notes: Vec<_> = app
        .content
        .vocab()
        .iter()
        .filter(|v| !v.def.retired && !v.def.notes.is_empty())
        .collect();
    assert!(!with_notes.is_empty(), "p0 應有帶筆記的單字");

    for entry in with_notes {
        let detail = app.core.vocab_detail(entry.def.id.clone()).unwrap();

        let got: Vec<&str> = detail.notes.iter().map(note_id).collect();
        assert_eq!(got, entry.def.notes, "{}", entry.def.id);
        for note in &detail.notes {
            assert_eq!(listed.get(note_id(note)), Some(note), "{}", entry.def.id);
        }
    }
}

#[test]
fn grammar_terms_point_to_existing_term_notes() {
    let app = p0_app();
    let terms: BTreeSet<String> = app
        .core
        .note_list(NoteKind::Term)
        .unwrap()
        .iter()
        .map(|n| note_id(n).to_owned())
        .collect();
    let with_terms: Vec<_> = app
        .content
        .grammar()
        .iter()
        .filter(|g| !g.retired && !g.terms.is_empty())
        .collect();
    assert!(!with_terms.is_empty(), "p0 應有帶術語的文法");

    for def in with_terms {
        let detail = app.core.grammar_detail(def.id.clone()).unwrap();

        let got: Vec<&str> = detail.terms.iter().map(note_id).collect();
        assert_eq!(got, def.terms, "{} 的 terms 有指向不存在的筆記", def.id);
        assert!(got.iter().all(|id| terms.contains(*id)), "{}", def.id);
    }
}

/// 筆記反向指向的單字與文法都查得到。
#[test]
fn notes_point_back_to_existing_words_and_grammar() {
    let app = p0_app();

    for note in all_notes(&app).values() {
        let (vocab, grammar): (Vec<String>, Vec<String>) = match note {
            NoteDto::FalseFriend { vocab_id, .. } => (vocab_id.iter().cloned().collect(), vec![]),
            NoteDto::Shinjitai { vocab_ids, .. } => (vocab_ids.clone(), vec![]),
            NoteDto::Term { grammar_ids, .. } => (vec![], grammar_ids.clone()),
            NoteDto::Reading { .. } | NoteDto::Transfer { .. } => (vec![], vec![]),
        };
        for id in vocab {
            assert!(app.core.vocab_detail(id.clone()).is_ok(), "{note:?} → {id}");
        }
        for id in grammar {
            assert!(
                app.core.grammar_detail(id.clone()).is_ok(),
                "{note:?} → {id}"
            );
        }
    }
}

/// 既有行為：`p0a` 沒有任何筆記，入口也不露出。
#[test]
fn p0a_lists_no_notes() {
    let app = TestApp::with_content(p0a_content());

    for (kind, _) in NOTE_TARGETS {
        assert!(app.core.note_list(kind).unwrap().is_empty(), "{kind:?}");
    }
    let overview = app.core.course_overview().unwrap();
    assert!(!overview.notes_available);
}

// ---------- 對話 ----------

#[test]
fn dialogues_list_main_extra_and_casual() {
    let app = p0_app();
    let overview = app.core.course_overview().unwrap();

    let dialogues = app.core.dialogues().unwrap();

    let kinds: BTreeSet<String> = dialogues.iter().map(|d| format!("{:?}", d.kind)).collect();
    assert_eq!(
        kinds,
        BTreeSet::from(["Casual".to_owned(), "Extra".to_owned(), "Lesson".to_owned()])
    );
    let main_ids: BTreeSet<&str> = dialogues
        .iter()
        .filter(|d| d.kind == DialogueKindDto::Lesson)
        .map(|d| d.id.as_str())
        .collect();
    for lesson in overview.lessons.iter().filter(|l| l.id.starts_with("le.l")) {
        let id = lesson.dialogue_id.as_deref().expect("每個 L 課都有主對話");
        assert!(
            main_ids.contains(id),
            "{} 的主對話 {id} 不在清單",
            lesson.id
        );
    }
}

#[test]
fn every_dialogue_detail_is_playable_line_by_line() {
    let app = p0_app();

    for summary in app.core.dialogues().unwrap() {
        let dialogue = app.core.dialogue_detail(summary.id.clone()).unwrap();

        assert_eq!(dialogue.kind, summary.kind, "{}", summary.id);
        assert!(!dialogue.turns.is_empty(), "{}", summary.id);
        let roles: BTreeSet<&str> = dialogue.roles.iter().map(|r| r.id.as_str()).collect();
        for turn in &dialogue.turns {
            assert!(roles.contains(turn.role.as_str()), "{}", summary.id);
            assert_sentence_playable(&turn.sentence);
        }
    }
}

/// 台詞裡點詞看說明（`peek`，§9.4）的 `ref_id` 都查得到。
#[test]
fn every_word_in_dialogue_lines_can_be_peeked() {
    let app = p0_app();
    let refs: BTreeSet<String> = app
        .core
        .dialogues()
        .unwrap()
        .into_iter()
        .flat_map(|summary| app.core.dialogue_detail(summary.id).unwrap().turns)
        .flat_map(|turn| turn.sentence.words)
        .filter_map(|word| word.ref_id)
        .collect();
    assert!(!refs.is_empty());

    let missing: Vec<&String> = refs
        .iter()
        .filter(|id| app.core.peek((*id).clone()).is_err())
        .collect();

    assert_eq!(missing, Vec::<&String>::new(), "peek 查不到");
}

#[test]
fn casual_and_extra_dialogue_quizzes_produce_answerable_questions() {
    let app = p0_app();
    app.start_plan(&plan_input(20, StartLevel::Zero));
    let quizzed = app
        .core
        .dialogues()
        .unwrap()
        .into_iter()
        .filter(|d| matches!(d.kind, DialogueKindDto::Casual | DialogueKindDto::Extra));

    for summary in quizzed {
        let dialogue = app.core.dialogue_detail(summary.id.clone()).unwrap();
        assert!(!dialogue.quiz_drill_ids.is_empty(), "{}", summary.id);
        let filter = DrillFilterDto {
            drill_ids: dialogue.quiz_drill_ids.clone(),
            ..DrillFilterDto::default()
        };

        let questions = app.core.drill_session(filter, SEED, true).unwrap();

        let served: BTreeSet<String> = questions
            .iter()
            .filter_map(|q| q.reference.drill_id.clone())
            .collect();
        let quiz: BTreeSet<String> = dialogue.quiz_drill_ids.iter().cloned().collect();
        assert_eq!(served, quiz, "{} 的測驗沒有全部出題", summary.id);
        for question in &questions {
            assert_answerable(&app.core, question, true);
        }
    }
}

// ---------- 計畫 ----------

fn days_until(date: &str) -> i64 {
    let end = NaiveDate::parse_from_str(date, "%Y-%m-%d").unwrap();
    (end - start_time().date_naive()).num_days() + 1
}

/// (分鐘, 主線天數)。
fn forecast_days(content: &ContentStore) -> Vec<(u32, i64)> {
    PRESETS
        .iter()
        .map(|&minutes| {
            let app = TestApp::with_content(content.clone());
            let view = app
                .core
                .plan_preview(plan_input(minutes, StartLevel::Zero))
                .unwrap();
            let main = view.main_forecast_end.expect("p0 主線應有完成日");
            (minutes, days_until(&main))
        })
        .collect()
}

#[test]
fn plan_preview_forecasts_main_end_for_every_preset() {
    let days = forecast_days(&p0_content());
    println!("p0 預估天數（分鐘, 主線）：{days:?}");

    for pair in days.windows(2) {
        let ((slow, slow_main), (fast, fast_main)) = (pair[0], pair[1]);
        assert!(
            fast_main < slow_main,
            "{fast} 分（{fast_main} 天）應比 {slow} 分（{slow_main} 天）早完成主線"
        );
    }
    assert_eq!(days, MAIN_DAYS, "主線天數與基準不同，請確認後更新 §11.4");
}

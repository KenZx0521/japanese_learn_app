//! rust-core.md §11.2：curriculum.md §12.4–12.6 的 JSON 範例必須能反序列化成 §3.2 的 struct。

use std::path::Path;

use jp_content::schema::{
    ConfusableDef, ConjForm, CourseDef, DialogueDef, DrillDef, FalseFriendNoteDef, GrammarDef,
    KanaDef, MilestoneDef, PlanPresetDef, Pos, ReadingNoteDef, RuleCardDef, SentenceDef,
    ShinjitaiNoteDef, SoundGroupDef, TermNoteDef, TransferNoteDef, VocabDef,
};
use serde::de::DeserializeOwned;
use serde_json::Value;

fn curriculum() -> String {
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../docs/design/curriculum.md");
    std::fs::read_to_string(path).expect("curriculum.md 應存在")
}

/// 取出某個標題之後、下一個同級標題之前的所有 ```json 區塊。
fn json_blocks_after(doc: &str, heading: &str) -> Vec<Value> {
    let start = doc.find(heading).expect("找不到標題");
    let section = doc[start + heading.len()..]
        .split("\n### ")
        .next()
        .unwrap_or_default();
    section
        .split("```json")
        .skip(1)
        .map(|chunk| chunk.split("```").next().unwrap_or_default())
        .map(|body| serde_json::from_str(body).expect("JSON 範例應可解析"))
        .collect()
}

fn check<T: DeserializeOwned>(value: &Value, key: &str) {
    let item = value.get(key).unwrap_or_else(|| panic!("範例缺 {key}"));
    serde_json::from_value::<T>(item.clone())
        .unwrap_or_else(|err| panic!("{key} 無法反序列化：{err}"));
}

#[test]
fn course_example_deserializes() {
    let doc = curriculum();
    let blocks = json_blocks_after(&doc, "### 12.4");
    serde_json::from_value::<CourseDef>(blocks[0].clone()).expect("course 範例");
}

#[test]
fn every_section_12_4_item_example_deserializes() {
    let doc = curriculum();
    let blocks = json_blocks_after(&doc, "### 12.4");
    let items = &blocks[1];
    for key in ["kana", "kana_n", "kana_yoon", "kana_mark"] {
        check::<KanaDef>(items, key);
    }
    for key in ["confusable_shape", "confusable_kanji", "confusable_listen"] {
        check::<ConfusableDef>(items, key);
    }
    check::<RuleCardDef>(items, "rule_card");
    for key in ["sound_group", "sound_group_accent"] {
        check::<SoundGroupDef>(items, key);
    }
    for key in [
        "vocab",
        "vocab_vs",
        "vocab_accent",
        "vocab_phrase",
        "vocab_v1_s",
    ] {
        check::<VocabDef>(items, key);
    }
    check::<GrammarDef>(items, "grammar");
    check::<SentenceDef>(items, "sentence");
    check::<FalseFriendNoteDef>(items, "note_false_friend");
    check::<ShinjitaiNoteDef>(items, "note_shinjitai");
    check::<ReadingNoteDef>(items, "note_reading");
    check::<TransferNoteDef>(items, "note_transfer");
    check::<TermNoteDef>(items, "note_term");
}

#[test]
fn every_drill_example_deserializes_and_covers_all_variants() {
    let doc = curriculum();
    let blocks = json_blocks_after(&doc, "### 12.5");
    let items = blocks[0]["items"].as_array().expect("items");
    let types: Vec<&str> = items
        .iter()
        .map(|item| {
            serde_json::from_value::<DrillDef>(item.clone())
                .unwrap_or_else(|err| panic!("{item} 無法反序列化：{err}"));
            item["type"].as_str().expect("type")
        })
        .collect();
    assert_eq!(types.len(), 13);
    for kind in [
        "substitution",
        "reorder",
        "particle_fill",
        "zh_to_ja_choice",
        "listen_meaning",
        "situation_response",
        "conjugate",
        "register_convert",
        "shadowing",
        "false_friend",
        "minimal_pair",
        "kana_word",
    ] {
        assert!(types.contains(&kind), "缺少 {kind} 範例");
    }
}

#[test]
fn every_section_12_6_item_example_deserializes() {
    let doc = curriculum();
    let blocks = json_blocks_after(&doc, "### 12.6");
    let items = &blocks[0];
    check::<DialogueDef>(items, "dialogue");
    check::<PlanPresetDef>(items, "plan_preset");
    check::<MilestoneDef>(items, "milestone");
}

#[test]
fn unknown_fields_are_rejected() {
    let with_seq = serde_json::json!({
        "id": "se.l01.001", "lesson": "le.l01", "t": "はい|vo.hai 。", "zh": "是。",
        "style": "polite", "seq": 3
    });
    assert!(serde_json::from_value::<SentenceDef>(with_seq).is_err());

    let reorder_distractors = serde_json::json!({
        "id": "dr.l01.ord.001", "type": "reorder", "lesson": "le.l01", "targets": ["gr.desu"],
        "sentence": "se.l01.001", "accept_orders": [[0]], "distractors": []
    });
    assert!(serde_json::from_value::<DrillDef>(reorder_distractors).is_err());
}

#[test]
fn optional_collections_and_flags_default() {
    let minimal = serde_json::json!({
        "id": "ka.hira.a", "lesson": "le.k01", "script": "hira", "kind": "basic",
        "char": "あ", "hint_zh": "x"
    });
    let kana: KanaDef = serde_json::from_value(minimal).expect("預設欄位");
    assert!(kana.confusable.is_empty());
    assert!(kana.example_words.is_empty());
    assert!(!kana.listen_disabled);
    assert!(!kana.retired);
    assert!(kana.replaced_by.is_none());
}

fn vocab_with(extra: Value) -> Result<VocabDef, serde_json::Error> {
    let mut value = serde_json::json!({
        "id": "vo.kureru", "lesson": "le.l28", "lesson_order": 2, "surface": "くれる",
        "kana": "くれる", "zh": ["給（我）"], "pos": "v1_s", "jlpt": "n4", "topics": ["verb"]
    });
    for (key, field) in extra.as_object().expect("物件") {
        value[key] = field.clone();
    }
    serde_json::from_value(value)
}

#[test]
fn vocab_conj_omit_defaults_empty_and_reads_form_names() {
    let plain = vocab_with(serde_json::json!({})).expect("省略 conj_omit");
    assert_eq!(plain.pos, Pos::V1S);
    assert!(plain.conj_omit.is_empty());

    let omitted = vocab_with(serde_json::json!({
        "conj_omit": ["potential", "passive", "causative", "volitional", "imperative"]
    }))
    .expect("conj_omit 用 form 名稱");
    assert_eq!(
        omitted.conj_omit,
        [
            ConjForm::Potential,
            ConjForm::Passive,
            ConjForm::Causative,
            ConjForm::Volitional,
            ConjForm::Imperative
        ]
    );

    assert!(vocab_with(serde_json::json!({"conj_omit": ["kanou"]})).is_err());
}

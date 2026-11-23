//! 解析內容檔：依路徑分派（rust-core.md §3.2 表）。

use serde::de::DeserializeOwned;
use serde::Deserialize;

use crate::error::ContentError;
use crate::schema::{
    ConfusableDef, CourseDef, DialogueDef, DrillDef, GrammarDef, KanaDef, MilestoneDef, NoteDef,
    PlanPresetDef, RuleCardDef, SentenceDef, SoundGroupDef, VocabDef,
};
use crate::store::ItemKind;

const SCHEMA_VERSION: u32 = 1;
const COURSE_PATH: &str = "course.json";

#[derive(Debug, Clone, Default, PartialEq)]
pub struct RawContent {
    pub course: CourseDef,
    pub kana: Vec<KanaDef>,
    pub confusables: Vec<ConfusableDef>,
    pub rule_cards: Vec<RuleCardDef>,
    pub sound_groups: Vec<SoundGroupDef>,
    pub vocab: Vec<VocabDef>,
    pub grammar: Vec<GrammarDef>,
    pub sentences: Vec<SentenceDef>,
    pub drills: Vec<DrillDef>,
    pub dialogues: Vec<DialogueDef>,
    pub notes: Vec<NoteDef>,
    pub presets: Vec<PlanPresetDef>,
    pub milestones: Vec<MilestoneDef>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Envelope<T> {
    schema: Option<u32>,
    items: Vec<T>,
}

#[derive(Clone, Copy)]
enum FileKind {
    Course,
    Kana,
    Confusables,
    Rules,
    SoundGroups,
    Vocab,
    Grammar,
    Sentences,
    Drills,
    Dialogues,
    FalseFriends,
    Shinjitai,
    Readings,
    Transfer,
    Terms,
    Presets,
    Milestones,
}

fn is_json_under(path: &str, prefix: &str) -> bool {
    path.starts_with(prefix) && path.ends_with(".json")
}

fn classify_fixed(path: &str) -> Option<FileKind> {
    Some(match path {
        COURSE_PATH => FileKind::Course,
        "kana/hiragana.json" | "kana/katakana.json" => FileKind::Kana,
        "kana/confusables.json" => FileKind::Confusables,
        "kana/rules.json" => FileKind::Rules,
        "kana/sound_groups.json" => FileKind::SoundGroups,
        "notes/false_friends.json" => FileKind::FalseFriends,
        "notes/shinjitai.json" => FileKind::Shinjitai,
        "notes/readings.json" => FileKind::Readings,
        "notes/transfer.json" => FileKind::Transfer,
        "notes/terms.json" => FileKind::Terms,
        "plan/presets.json" => FileKind::Presets,
        "plan/milestones.json" => FileKind::Milestones,
        _ => return None,
    })
}

fn classify_prefix(path: &str) -> Option<FileKind> {
    [
        ("vocab/", FileKind::Vocab),
        ("grammar/", FileKind::Grammar),
        ("sentences/", FileKind::Sentences),
        ("drills/", FileKind::Drills),
        ("dialogues/", FileKind::Dialogues),
    ]
    .into_iter()
    .find(|(prefix, _)| is_json_under(path, prefix))
    .map(|(_, kind)| kind)
}

fn classify(path: &str) -> Option<FileKind> {
    classify_fixed(path).or_else(|| classify_prefix(path))
}

fn check_schema(path: &str, schema: Option<u32>) -> Result<(), ContentError> {
    if schema == Some(SCHEMA_VERSION) {
        Ok(())
    } else {
        Err(ContentError::corrupt(
            path,
            format!("schema 必須為 {SCHEMA_VERSION}，實際為 {schema:?}"),
        ))
    }
}

fn parse_items<T: DeserializeOwned>(path: &str, text: &str) -> Result<Vec<T>, ContentError> {
    let envelope: Envelope<T> = serde_json::from_str(text)
        .map_err(|err| ContentError::corrupt(path, format!("JSON 解析失敗：{err}")))?;
    check_schema(path, envelope.schema)?;
    Ok(envelope.items)
}

fn parse_course(path: &str, text: &str) -> Result<CourseDef, ContentError> {
    let course: CourseDef = serde_json::from_str(text)
        .map_err(|err| ContentError::corrupt(path, format!("JSON 解析失敗：{err}")))?;
    check_schema(path, course.schema)?;
    Ok(course)
}

fn notes_of<T: DeserializeOwned>(
    path: &str,
    text: &str,
    wrap: fn(T) -> NoteDef,
) -> Result<Vec<NoteDef>, ContentError> {
    Ok(parse_items(path, text)?.into_iter().map(wrap).collect())
}

fn merge_file(
    raw: &mut RawContent,
    kind: FileKind,
    path: &str,
    text: &str,
) -> Result<(), ContentError> {
    match kind {
        FileKind::Course => raw.course = parse_course(path, text)?,
        FileKind::Kana => raw.kana.extend(parse_items(path, text)?),
        FileKind::Confusables => raw.confusables.extend(parse_items(path, text)?),
        FileKind::Rules => raw.rule_cards.extend(parse_items(path, text)?),
        FileKind::SoundGroups => raw.sound_groups.extend(parse_items(path, text)?),
        FileKind::Vocab => raw.vocab.extend(parse_items(path, text)?),
        FileKind::Grammar => raw.grammar.extend(parse_items(path, text)?),
        FileKind::Sentences => raw.sentences.extend(parse_items(path, text)?),
        FileKind::Drills => raw.drills.extend(parse_items(path, text)?),
        FileKind::Dialogues => raw.dialogues.extend(parse_items(path, text)?),
        FileKind::FalseFriends => raw
            .notes
            .extend(notes_of(path, text, NoteDef::FalseFriend)?),
        FileKind::Shinjitai => raw.notes.extend(notes_of(path, text, NoteDef::Shinjitai)?),
        FileKind::Readings => raw.notes.extend(notes_of(path, text, NoteDef::Reading)?),
        FileKind::Transfer => raw.notes.extend(notes_of(path, text, NoteDef::Transfer)?),
        FileKind::Terms => raw.notes.extend(notes_of(path, text, NoteDef::Term)?),
        FileKind::Presets => raw.presets.extend(parse_items(path, text)?),
        FileKind::Milestones => raw.milestones.extend(parse_items(path, text)?),
    }
    Ok(())
}

/// 依路徑排序後解析，結果與輸入順序無關。
pub fn parse_files(files: &[(&str, &str)]) -> Result<RawContent, ContentError> {
    let mut sorted = files.to_vec();
    sorted.sort_by_key(|(path, _)| *path);
    let mut raw = RawContent::default();
    let mut has_course = false;
    for (path, text) in sorted {
        let kind = classify(path)
            .ok_or_else(|| ContentError::corrupt(path, "無法分派的內容檔路徑".to_owned()))?;
        has_course |= matches!(kind, FileKind::Course);
        merge_file(&mut raw, kind, path, text)?;
    }
    if !has_course {
        return Err(ContentError::corrupt(COURSE_PATH, "缺少 course.json"));
    }
    Ok(raw)
}

fn extend_ids<'a, T>(
    ids: &mut Vec<(&'a str, ItemKind)>,
    items: &'a [T],
    id: impl Fn(&'a T) -> &'a str,
    kind: ItemKind,
) {
    ids.extend(items.iter().map(|item| (id(item), kind)));
}

/// 主索引的 ID 清單；`validate` 用來查重，也用來判定軟引用是否存在於任一階段。
pub fn item_ids(raw: &RawContent) -> Vec<(&str, ItemKind)> {
    let mut ids = Vec::new();
    extend_ids(&mut ids, &raw.course.stages, |s| &s.id, ItemKind::Stage);
    extend_ids(&mut ids, &raw.course.lessons, |l| &l.id, ItemKind::Lesson);
    extend_ids(&mut ids, &raw.kana, |k| &k.id, ItemKind::Kana);
    extend_ids(&mut ids, &raw.confusables, |c| &c.id, ItemKind::Confusable);
    extend_ids(&mut ids, &raw.rule_cards, |c| &c.id, ItemKind::RuleCard);
    extend_ids(&mut ids, &raw.sound_groups, |s| &s.id, ItemKind::SoundGroup);
    extend_ids(&mut ids, &raw.vocab, |v| &v.id, ItemKind::Vocab);
    extend_ids(&mut ids, &raw.grammar, |g| &g.id, ItemKind::Grammar);
    extend_ids(&mut ids, &raw.sentences, |s| &s.id, ItemKind::Sentence);
    extend_ids(&mut ids, &raw.drills, DrillDef::id, ItemKind::Drill);
    extend_ids(&mut ids, &raw.dialogues, |d| &d.id, ItemKind::Dialogue);
    extend_ids(&mut ids, &raw.notes, NoteDef::id, ItemKind::Note);
    extend_ids(&mut ids, &raw.presets, |p| &p.id, ItemKind::Preset);
    extend_ids(&mut ids, &raw.milestones, |m| &m.id, ItemKind::Milestone);
    ids
}

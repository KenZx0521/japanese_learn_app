//! `ContentStore` 的衍生資料與次級索引。

use std::collections::HashMap;

use jp_lang::kana::{reading_mode_of, to_romaji_reading, to_romaji_word, Word};

use crate::error::ContentError;
use crate::raw::{item_ids, RawContent};
use crate::schema::{
    ContentStage, CourseDef, DialogueDef, DrillDef, KanaDef, KanaKind, Pos, SentenceDef, VocabDef,
};
use crate::sentence::{analyze_t, parse_t, TParseError};
use crate::speech::vocab_speech;

use super::{
    ContentStore, CourseIndex, DialogueEntry, ItemKind, ItemRef, KanaEntry, LessonItems,
    SentenceEntry, VocabEntry,
};

fn t_error(item: &str, error: TParseError) -> ContentError {
    ContentError::corrupt(item, error.to_string())
}

fn kana_entry(def: KanaDef) -> Result<KanaEntry, ContentError> {
    // 符號單獨出現時可能沒有對應音（ー、っ），不需要羅馬字。
    let romaji = match (to_romaji_word(&def.ch), def.kind) {
        (Ok(romaji), _) => romaji,
        (Err(_), KanaKind::Mark) => String::new(),
        (Err(err), _) => return Err(ContentError::corrupt(&def.id, err.to_string())),
    };
    Ok(KanaEntry { def, romaji })
}

fn vocab_entry(def: VocabDef) -> Result<VocabEntry, ContentError> {
    let romaji = to_romaji_reading(&def.kana, reading_mode_of(&def.kana))
        .map_err(|err| ContentError::corrupt(&def.id, err.to_string()))?;
    let speech = vocab_speech(&def);
    Ok(VocabEntry {
        def,
        romaji,
        speech,
    })
}

fn sentence_entry(def: SentenceDef) -> Result<SentenceEntry, ContentError> {
    let parsed = analyze_t(&def.t, def.tts, None).map_err(|err| t_error(&def.id, err))?;
    Ok(SentenceEntry { def, parsed })
}

fn dialogue_entry(def: DialogueDef) -> Result<DialogueEntry, ContentError> {
    let turns = def
        .turns
        .iter()
        .map(|turn| analyze_t(&turn.t, turn.tts, None))
        .collect::<Result<Vec<_>, _>>()
        .map_err(|err| t_error(&def.id, err))?;
    Ok(DialogueEntry { def, turns })
}

fn index_of(position: usize) -> u32 {
    u32::try_from(position).expect("內容筆數不可能超過 u32")
}

fn lesson_pos_of(order: &[String]) -> HashMap<String, u32> {
    order
        .iter()
        .enumerate()
        .map(|(position, id)| (id.clone(), index_of(position)))
        .collect()
}

fn course_index(course: CourseDef, positions: &HashMap<String, u32>) -> CourseIndex {
    let mut lessons = course.lessons;
    lessons.sort_by_key(|lesson| positions.get(&lesson.id).copied());
    CourseIndex {
        stages: course.stages,
        order: course.order,
        lessons,
    }
}

fn indices_by_lesson<'a, T: 'a>(
    items: &'a [T],
    active: impl Fn(&T) -> bool + 'a,
    lesson_of: impl Fn(&T) -> &str + 'a,
) -> impl Iterator<Item = (&'a str, u32)> + 'a {
    items
        .iter()
        .enumerate()
        .filter(move |(_, item)| active(item))
        .map(move |(index, item)| (lesson_of(item), index_of(index)))
}

fn slot<'m>(map: &'m mut HashMap<String, LessonItems>, lesson: &str) -> &'m mut LessonItems {
    map.entry(lesson.to_owned()).or_default()
}

fn lesson_items(store: &ContentStore) -> HashMap<String, LessonItems> {
    let mut map: HashMap<String, LessonItems> = store
        .course
        .order
        .iter()
        .map(|lesson| (lesson.clone(), LessonItems::default()))
        .collect();
    for (lesson, i) in indices_by_lesson(&store.kana, |k| !k.def.retired, |k| &k.def.lesson) {
        slot(&mut map, lesson).kana.push(i);
    }
    for (lesson, i) in indices_by_lesson(&store.rule_cards, |c| !c.retired, |c| &c.lesson) {
        slot(&mut map, lesson).rules.push(i);
    }
    for (lesson, i) in indices_by_lesson(&store.confusables, |c| !c.retired, |c| &c.lesson) {
        slot(&mut map, lesson).confusables.push(i);
    }
    for (lesson, i) in indices_by_lesson(&store.sound_groups, |s| !s.retired, |s| &s.lesson) {
        slot(&mut map, lesson).sound_groups.push(i);
    }
    for (lesson, i) in indices_by_lesson(&store.sentences, |s| !s.def.retired, |s| &s.def.lesson) {
        slot(&mut map, lesson).sentences.push(i);
    }
    for (lesson, i) in indices_by_lesson(&store.drills, |d| !d.retired(), |d| d.lesson()) {
        slot(&mut map, lesson).drills.push(i);
    }
    for (lesson, i) in indices_by_lesson(&store.dialogues, |d| !d.def.retired, |d| &d.def.lesson) {
        slot(&mut map, lesson).dialogues.push(i);
    }
    lesson_words_and_grammar(store, &mut map);
    map
}

fn lesson_words_and_grammar(store: &ContentStore, map: &mut HashMap<String, LessonItems>) {
    for (lesson, i) in indices_by_lesson(&store.vocab, |v| !v.def.retired, |v| &v.def.lesson) {
        slot(map, lesson).words.push(i);
    }
    for (lesson, i) in indices_by_lesson(&store.grammar, |g| !g.retired, |g| &g.lesson) {
        slot(map, lesson).grammar.push(i);
    }
    for items in map.values_mut() {
        items
            .words
            .sort_by_key(|&i| store.vocab[i as usize].def.lesson_order);
        items
            .grammar
            .sort_by_key(|&i| store.grammar[i as usize].lesson_order);
    }
}

/// 每句的 `vo.*`、`gr.*` 引用，以 `ref_ids` 的下標表示。
fn sentence_refs(store: &ContentStore) -> (Vec<Box<[u32]>>, Vec<String>) {
    let mut ids: Vec<String> = Vec::new();
    let mut lookup: HashMap<String, u32> = HashMap::new();
    let mut intern = |reference: &str| -> u32 {
        *lookup.entry(reference.to_owned()).or_insert_with(|| {
            ids.push(reference.to_owned());
            index_of(ids.len() - 1)
        })
    };
    let refs = store
        .sentences
        .iter()
        .map(|entry| {
            let words = parse_t(&entry.def.t).unwrap_or_default();
            word_ref_list(&words)
                .into_iter()
                .map(&mut intern)
                .collect::<Vec<_>>()
                .into_boxed_slice()
        })
        .collect();
    (refs, ids)
}

fn word_ref_list(words: &[Word]) -> Vec<&str> {
    let mut refs: Vec<&str> = words
        .iter()
        .filter_map(|word| match word {
            Word::Morphs(morphs) => Some(morphs),
            Word::Punct(_) => None,
        })
        .flatten()
        .map(|m| m.r#ref.as_str())
        .filter(|r| r.starts_with("vo.") || r.starts_with("gr."))
        .collect();
    refs.sort_unstable();
    refs.dedup();
    refs
}

fn drills_by_target(drills: &[DrillDef]) -> HashMap<String, Vec<u32>> {
    let mut map: HashMap<String, Vec<u32>> = HashMap::new();
    for (position, drill) in drills.iter().enumerate().filter(|(_, d)| !d.retired()) {
        for target in drill.targets() {
            map.entry(target.clone())
                .or_default()
                .push(index_of(position));
        }
    }
    map
}

/// 鍵是 `Pos::family`：`v1_s` 與 `v1` 同組。
fn vocab_by_pos(vocab: &[VocabEntry]) -> HashMap<Pos, Vec<u32>> {
    let mut map: HashMap<Pos, Vec<u32>> = HashMap::new();
    for (position, entry) in vocab.iter().enumerate().filter(|(_, v)| !v.def.retired) {
        map.entry(entry.def.pos.family())
            .or_default()
            .push(index_of(position));
    }
    map
}

fn vocab_by_topic(vocab: &[VocabEntry]) -> HashMap<String, Vec<u32>> {
    let mut map: HashMap<String, Vec<u32>> = HashMap::new();
    for (position, entry) in vocab.iter().enumerate().filter(|(_, v)| !v.def.retired) {
        for topic in &entry.def.topics {
            map.entry(topic.clone())
                .or_default()
                .push(index_of(position));
        }
    }
    map
}

fn id_index(raw: &RawContent) -> HashMap<String, ItemRef> {
    let mut counters: HashMap<ItemKind, u32> = HashMap::new();
    item_ids(raw)
        .into_iter()
        .map(|(id, kind)| {
            let counter = counters.entry(kind).or_insert(0);
            let reference = ItemRef {
                kind,
                index: *counter,
            };
            *counter += 1;
            (id.to_owned(), reference)
        })
        .collect()
}

fn entries<T, U>(
    items: Vec<T>,
    make: impl Fn(T) -> Result<U, ContentError>,
) -> Result<Vec<U>, ContentError> {
    items.into_iter().map(make).collect()
}

impl ContentStore {
    /// 輸入已通過 `validate` 且完成軟引用修剪；這裡只計算衍生資料與索引。
    pub(crate) fn build(raw: RawContent, stage: ContentStage) -> Result<Self, ContentError> {
        let id_index = id_index(&raw);
        let lesson_pos = lesson_pos_of(&raw.course.order);
        let course = course_index(raw.course, &lesson_pos);
        let mut store = Self {
            stage,
            kana: entries(raw.kana, kana_entry)?,
            confusables: raw.confusables,
            rule_cards: raw.rule_cards,
            sound_groups: raw.sound_groups,
            vocab: entries(raw.vocab, vocab_entry)?,
            grammar: raw.grammar,
            sentences: entries(raw.sentences, sentence_entry)?,
            drills: raw.drills,
            dialogues: entries(raw.dialogues, dialogue_entry)?,
            notes: raw.notes,
            course,
            presets: raw.presets,
            milestones: raw.milestones,
            id_index,
            lesson_pos,
            items_by_lesson: HashMap::new(),
            sentence_refs: Vec::new(),
            ref_ids: Vec::new(),
            drills_by_target: HashMap::new(),
            vocab_by_pos: HashMap::new(),
            vocab_by_topic: HashMap::new(),
        };
        store.items_by_lesson = lesson_items(&store);
        let (refs, ids) = sentence_refs(&store);
        store.sentence_refs = refs;
        store.ref_ids = ids;
        store.drills_by_target = drills_by_target(&store.drills);
        store.vocab_by_pos = vocab_by_pos(&store.vocab);
        store.vocab_by_topic = vocab_by_topic(&store.vocab);
        Ok(store)
    }
}

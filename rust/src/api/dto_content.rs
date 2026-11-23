//! 內容類 DTO（rust-core.md §9.5）：句子、課程、假名、單字、文法、對話。

// ---------- 句子與語音 ----------

/// 行動平台送 `text`，Linux 送 `kana`（§3.3）。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SpeechDto {
    pub text: String,
    pub kana: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SentenceDto {
    pub id: String,
    pub display: String,
    pub romaji: String,
    pub zh: String,
    pub style: String,
    pub words: Vec<WordDto>,
    pub speech: SpeechDto,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WordDto {
    pub surface: String,
    pub kana: String,
    pub romaji: String,
    pub speech_kana: String,
    pub ruby: Vec<RubyPartDto>,
    pub refs: Vec<String>,
    /// 第一個非 `@` 的 ref，供 `peek`。
    pub ref_id: Option<String>,
    /// `@new` 的中文釋義。
    pub gloss_zh: Option<String>,
    pub is_punct: bool,
    pub is_known: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RubyPartDto {
    pub base: String,
    pub ruby: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MixedSpanDto {
    Zh {
        text: String,
    },
    Ja {
        text: String,
        ruby: Vec<RubyPartDto>,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReadingMode {
    Word,
    Sentence,
}

// ---------- 課程 ----------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContentStage {
    P0a,
    P0,
    Full,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LessonStatus {
    NotStarted,
    Current,
    Done,
    Skipped,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StageDto {
    pub id: String,
    pub title_zh: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LessonSummaryDto {
    pub id: String,
    pub stage_id: String,
    pub title_zh: String,
    pub can_do_zh: String,
    pub dialogue_id: Option<String>,
    pub milestone_id: Option<String>,
    pub status: LessonStatus,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CourseOverviewDto {
    pub content_stage: ContentStage,
    pub stages: Vec<StageDto>,
    pub lessons: Vec<LessonSummaryDto>,
    pub current_lesson_id: Option<String>,
    /// 內容就緒才露出入口。
    pub notes_available: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LessonDetailDto {
    pub summary: LessonSummaryDto,
    pub kana: Vec<KanaCellDto>,
    pub rules: Vec<RuleCardDto>,
    pub words: Vec<VocabSummaryDto>,
    pub grammar: Vec<GrammarSummaryDto>,
    pub dialogue: Option<DialogueSummaryDto>,
    pub integration_days_done: u32,
    pub integration_days_needed: u32,
}

// ---------- 假名 ----------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KanaScript {
    Hiragana,
    Katakana,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KanaKindDto {
    Basic,
    Dakuten,
    Yoon,
    Extended,
    Mark,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KanaStatus {
    NotStarted,
    Learning,
    Mastered,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConfusableKindDto {
    Shape,
    CrossScript,
    KanaKanji,
    Listen,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SoundGroupKindDto {
    Voicing,
    Length,
    Sokuon,
    Yoon,
    Accent,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KanaCellDto {
    pub id: String,
    pub ch: String,
    pub romaji: String,
    pub kind: KanaKindDto,
    pub status: KanaStatus,
    pub fast_badge: bool,
    pub speech: SpeechDto,
    pub listen_disabled: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KanaRowDto {
    /// `None` 為保留對位的空格。
    pub cells: Vec<Option<KanaCellDto>>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KanaGroupDto {
    pub title_zh: String,
    pub columns: u32,
    pub rows: Vec<KanaRowDto>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KanaExampleDto {
    pub surface: String,
    pub zh: String,
    pub speech: SpeechDto,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KanaDetailDto {
    pub cell: KanaCellDto,
    pub lesson_id: String,
    pub origin_kanji: Option<String>,
    pub hint_zh: String,
    pub example_words: Vec<KanaExampleDto>,
    pub confusables: Vec<ConfusableDto>,
    pub rule_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LiteralDto {
    pub text: String,
    pub zh: String,
    pub speech: SpeechDto,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConfusableDto {
    pub id: String,
    pub kind: ConfusableKindDto,
    pub members: Vec<KanaCellDto>,
    pub literals: Vec<LiteralDto>,
    pub diff_zh: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuleExampleDto {
    pub text: String,
    pub zh: String,
    pub beats: Vec<String>,
    pub speech: SpeechDto,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuleCardDto {
    pub id: String,
    pub lesson_id: String,
    pub title_zh: String,
    pub body_zh: String,
    pub examples: Vec<RuleExampleDto>,
    pub sound_groups: Vec<SoundGroupDto>,
    pub drill_ids: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SoundSideDto {
    pub text: String,
    pub kana: Option<String>,
    pub zh: String,
    pub speech: SpeechDto,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SoundPairDto {
    pub a: SoundSideDto,
    pub b: SoundSideDto,
    pub listen_disabled: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SoundGroupDto {
    pub id: String,
    pub lesson_id: String,
    pub kind: SoundGroupKindDto,
    pub title_zh: String,
    pub body_zh: String,
    pub pairs: Vec<SoundPairDto>,
    pub test_drill_ids: Vec<String>,
}

// ---------- 單字 ----------

/// `Mastered`：`state=Review` 且 `scheduled_days ≥ 21`。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SrsStateLabel {
    NotStarted,
    Learning,
    Review,
    Mastered,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JlptLevel {
    N5,
    N4,
    Beyond,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UseLevelDto {
    Safe,
    FriendsOnly,
    RecognizeOnly,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransitivityDto {
    Transitive,
    Intransitive,
    Both,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VocabRefDto {
    pub id: String,
    pub surface: String,
    pub kana: String,
    pub zh: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VocabSummaryDto {
    pub id: String,
    pub surface: String,
    pub kana: String,
    pub romaji: String,
    pub zh: Vec<String>,
    pub pos: String,
    pub lesson_id: String,
    pub srs_state: SrsStateLabel,
    pub speech: SpeechDto,
    pub known: bool,
    pub starred: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConjugationDto {
    pub form: String,
    pub surface: String,
    pub kana: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VocabDetailDto {
    pub summary: VocabSummaryDto,
    pub accent: Option<u8>,
    pub jlpt: JlptLevel,
    pub use_level: UseLevelDto,
    pub trans: Option<TransitivityDto>,
    pub same_form_zh: bool,
    pub hook_zh: Option<String>,
    pub trap_zh: Option<String>,
    pub pair: Option<VocabRefDto>,
    pub reading_family: Vec<VocabRefDto>,
    pub examples: Vec<SentenceDto>,
    pub notes: Vec<NoteDto>,
    pub conjugations: Vec<ConjugationDto>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VocabPageDto {
    pub items: Vec<VocabSummaryDto>,
    pub total: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct VocabFilterDto {
    pub topic: Option<String>,
    pub pos: Option<String>,
    pub jlpt: Option<String>,
    pub lesson_id: Option<String>,
    pub only_introduced: bool,
    pub only_starred: bool,
    pub srs_state: Option<SrsStateLabel>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct VocabFlagsDto {
    pub known: bool,
    pub starred: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicDto {
    pub id: String,
    pub title_zh: String,
    pub count: u32,
}

// ---------- 文法與筆記 ----------

/// `Introduced`：已 `item_intro`；`Practiced`：`use` 卡 `reps ≥ 1`。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GrammarStatus {
    NotStarted,
    Introduced,
    Practiced,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GrammarRefDto {
    pub id: String,
    pub title_zh: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GrammarSummaryDto {
    pub id: String,
    pub title_zh: String,
    pub pattern: String,
    pub meaning_zh: String,
    pub lesson_id: String,
    pub stage_id: String,
    pub jlpt: JlptLevel,
    pub status: GrammarStatus,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FormationRowDto {
    pub from: String,
    pub to: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GrammarDetailDto {
    pub summary: GrammarSummaryDto,
    pub explain_zh: String,
    pub compare_zh: String,
    pub trap_zh: Option<String>,
    pub formation: Vec<FormationRowDto>,
    pub register: String,
    pub requires: Vec<GrammarRefDto>,
    pub examples: Vec<SentenceDto>,
    pub contrast: Vec<GrammarRefDto>,
    pub terms: Vec<NoteDto>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NoteKind {
    FalseFriend,
    Shinjitai,
    Reading,
    Transfer,
    Term,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadingExampleDto {
    pub hanzi: String,
    pub tai: String,
    pub ja: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NoteDto {
    FalseFriend {
        id: String,
        surface: String,
        ja_zh: String,
        misread_zh: String,
        vocab_id: Option<String>,
    },
    Shinjitai {
        id: String,
        ja: String,
        zh_tw: String,
        kind: String,
        vocab_ids: Vec<String>,
    },
    Reading {
        id: String,
        title_zh: String,
        body_zh: String,
        examples: Vec<ReadingExampleDto>,
        caveat_zh: String,
    },
    Transfer {
        id: String,
        title_zh: String,
        zh_pattern: String,
        wrong: String,
        right: String,
        explain_zh: String,
    },
    Term {
        id: String,
        term: String,
        aka_zh: Option<String>,
        body_zh: String,
        grammar_ids: Vec<String>,
    },
}

// ---------- 對話 ----------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DialogueKindDto {
    Lesson,
    Extra,
    Casual,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DialogueSummaryDto {
    pub id: String,
    pub kind: DialogueKindDto,
    pub lesson_id: String,
    pub scene_zh: String,
    pub goal_zh: String,
    pub locked: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DialogueRoleDto {
    pub id: String,
    pub name_zh: String,
    pub voice: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DialogueTurnDto {
    pub role: String,
    pub sentence: SentenceDto,
    pub note_zh: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DialogueDto {
    pub id: String,
    pub kind: DialogueKindDto,
    pub lesson_id: String,
    pub style: String,
    pub scene_zh: String,
    pub goal_zh: String,
    pub roles: Vec<DialogueRoleDto>,
    pub turns: Vec<DialogueTurnDto>,
    pub focus_ids: Vec<String>,
    /// 取題用 `drill_session` 的 `DrillFilterDto.drill_ids`。
    pub quiz_drill_ids: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PeekDto {
    pub ref_id: String,
    pub title: String,
    pub kana: Option<String>,
    pub romaji: Option<String>,
    pub summary_zh: String,
    pub lesson_id: Option<String>,
}

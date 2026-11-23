//! serde 結構（rust-core.md §3.2），與 curriculum.md §12 逐欄對應。

mod course;
mod dialogue;
mod drills;
mod enums;
mod kana;
mod lexicon;
mod notes;

pub use course::{CourseDef, LessonDef, MilestoneDef, PlanPresetDef, SplitDef, StageDef};
pub use dialogue::{DialogueDef, RoleDef, TurnDef};
pub use drills::{BlankDef, DistractorDef, DrillCommon, DrillDef, SubRowDef};
pub use enums::{
    ConfusableKind, ContentStage, DialogueKind, Jlpt, KanaKind, KanaWordMode, Register, Script,
    SoundGroupKind, Style, Transitivity, TtsMode, UseLevel,
};
pub use jp_lang::grammar::conjugate::{Form as ConjForm, Pos};
pub use kana::{
    ConfusableDef, ExampleWordDef, KanaDef, LiteralDef, PairDef, RuleCardDef, RuleExampleDef,
    SoundGroupDef,
};
pub use lexicon::{FormationRowDef, GrammarDef, SentenceDef, VocabDef};
pub use notes::{
    FalseFriendNoteDef, NoteDef, ReadingExampleDef, ReadingNoteDef, ShinjitaiNoteDef, TermNoteDef,
    TransferNoteDef,
};

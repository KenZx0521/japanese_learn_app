//! 列舉內容中的引用與 `t` 字串（啟動驗證與 lint 共用）。

use std::borrow::Cow;

use crate::raw::RawContent;
use crate::schema::{DrillDef, NoteDef, TtsMode};
use crate::sentence::{expand_frame, is_inline_t};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Strength {
    /// 必須存在於當前階段。
    Hard,
    /// 可指向被階段過濾掉的項目（載入時修剪）。
    Soft,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RefSite<'a> {
    pub owner: &'a str,
    pub field: &'static str,
    pub target: &'a str,
    pub strength: Strength,
}

#[derive(Default)]
struct Sites<'a> {
    out: Vec<RefSite<'a>>,
}

impl<'a> Sites<'a> {
    fn add<I>(&mut self, owner: &'a str, field: &'static str, strength: Strength, targets: I)
    where
        I: IntoIterator<Item = &'a str>,
    {
        self.out.extend(targets.into_iter().map(|target| RefSite {
            owner,
            field,
            target,
            strength,
        }));
    }

    fn hard<I>(&mut self, owner: &'a str, field: &'static str, targets: I)
    where
        I: IntoIterator<Item = &'a String>,
    {
        self.add(
            owner,
            field,
            Strength::Hard,
            targets.into_iter().map(String::as_str),
        );
    }

    fn soft<I>(&mut self, owner: &'a str, field: &'static str, targets: I)
    where
        I: IntoIterator<Item = &'a String>,
    {
        self.add(
            owner,
            field,
            Strength::Soft,
            targets.into_iter().map(String::as_str),
        );
    }

    /// `lesson` 欄位：過濾前後都要檢查（見 `validate`）。
    fn lesson(&mut self, owner: &'a str, lesson: &'a str) {
        self.add(owner, "lesson", Strength::Hard, [lesson]);
    }
}

fn course_refs<'a>(raw: &'a RawContent, sites: &mut Sites<'a>) {
    for lesson in &raw.course.lessons {
        sites.hard(&lesson.id, "stage", [&lesson.stage]);
        sites.hard(&lesson.id, "dialogue", &lesson.dialogue);
    }
    for id in &raw.course.order {
        sites.hard(id, "order", [id]);
    }
}

fn kana_refs<'a>(raw: &'a RawContent, sites: &mut Sites<'a>) {
    for kana in &raw.kana {
        sites.lesson(&kana.id, &kana.lesson);
        sites.hard(&kana.id, "rule", &kana.rule);
        sites.soft(&kana.id, "confusable", &kana.confusable);
    }
    for item in &raw.confusables {
        sites.lesson(&item.id, &item.lesson);
        sites.hard(&item.id, "members", &item.members);
    }
    for card in &raw.rule_cards {
        sites.lesson(&card.id, &card.lesson);
        sites.hard(&card.id, "sound_groups", &card.sound_groups);
        sites.hard(&card.id, "drills", &card.drills);
    }
    for group in &raw.sound_groups {
        sites.lesson(&group.id, &group.lesson);
        sites.hard(&group.id, "test_drills", &group.test_drills);
    }
}

fn lexicon_refs<'a>(raw: &'a RawContent, sites: &mut Sites<'a>) {
    for vocab in &raw.vocab {
        sites.lesson(&vocab.id, &vocab.lesson);
        sites.soft(&vocab.id, "examples", &vocab.examples);
        sites.soft(&vocab.id, "notes", &vocab.notes);
        sites.soft(&vocab.id, "pair", &vocab.pair);
        sites.soft(&vocab.id, "reading_family", &vocab.reading_family);
    }
    for grammar in &raw.grammar {
        sites.lesson(&grammar.id, &grammar.lesson);
        sites.hard(&grammar.id, "requires", &grammar.requires);
        sites.soft(&grammar.id, "examples", &grammar.examples);
        sites.soft(&grammar.id, "contrast", &grammar.contrast);
        sites.soft(&grammar.id, "terms", &grammar.terms);
    }
    for sentence in &raw.sentences {
        sites.lesson(&sentence.id, &sentence.lesson);
    }
}

fn drill_refs<'a>(raw: &'a RawContent, sites: &mut Sites<'a>) {
    for drill in &raw.drills {
        let id = drill.id();
        sites.lesson(id, drill.lesson());
        sites.hard(id, "targets", drill.targets());
        match drill {
            DrillDef::Reorder { sentence, .. }
            | DrillDef::ParticleFill { sentence, .. }
            | DrillDef::ListenMeaning { sentence, .. }
            | DrillDef::Shadowing { sentence, .. } => sites.hard(id, "sentence", [sentence]),
            DrillDef::ZhToJaChoice { answer, .. } | DrillDef::SituationResponse { answer, .. }
                if !is_inline_t(answer) =>
            {
                sites.hard(id, "answer", [answer]);
            }
            DrillDef::Conjugate { lemmas, .. } => sites.hard(id, "lemmas", lemmas),
            DrillDef::RegisterConvert { from, to, .. } => {
                sites.hard(id, "from", [from]);
                sites.hard(id, "to", [to]);
            }
            DrillDef::FalseFriend { note, .. } => sites.hard(id, "note", [note]),
            _ => {}
        }
    }
}

fn dialogue_refs<'a>(raw: &'a RawContent, sites: &mut Sites<'a>) {
    for dialogue in &raw.dialogues {
        sites.lesson(&dialogue.id, &dialogue.lesson);
        sites.hard(&dialogue.id, "focus", &dialogue.focus);
        sites.hard(&dialogue.id, "quiz", &dialogue.quiz);
    }
    for milestone in &raw.milestones {
        sites.lesson(&milestone.id, &milestone.lesson);
    }
}

fn note_refs<'a>(raw: &'a RawContent, sites: &mut Sites<'a>) {
    for note in &raw.notes {
        match note {
            NoteDef::FalseFriend(n) => {
                sites.add(&n.id, "lesson", Strength::Hard, n.lesson.as_deref());
                sites.soft(&n.id, "vocab", &n.vocab);
            }
            NoteDef::Shinjitai(n) => sites.soft(&n.id, "vocab", &n.vocab),
            NoteDef::Reading(n) => {
                sites.lesson(&n.id, &n.lesson);
                sites.soft(&n.id, "vocab", &n.vocab);
            }
            NoteDef::Transfer(n) => {
                sites.lesson(&n.id, &n.lesson);
                sites.soft(&n.id, "grammar", &n.grammar);
                sites.soft(&n.id, "vocab", &n.vocab);
            }
            NoteDef::Term(n) => {
                sites.lesson(&n.id, &n.lesson);
                sites.soft(&n.id, "grammar", &n.grammar);
            }
        }
    }
}

/// 全部 ID 引用。`t` 內的 ref 由 [`t_sites`] 解析後另外檢查。
pub fn reference_sites(raw: &RawContent) -> Vec<RefSite<'_>> {
    let mut sites = Sites::default();
    course_refs(raw, &mut sites);
    kana_refs(raw, &mut sites);
    lexicon_refs(raw, &mut sites);
    drill_refs(raw, &mut sites);
    dialogue_refs(raw, &mut sites);
    note_refs(raw, &mut sites);
    sites.out
}

/// `t` 在內容中的角色。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TKind {
    Sentence,
    Turn,
    Row,
    Prompt,
    Answer,
    Distractor,
    BlankChoice,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TSite<'a> {
    pub owner: &'a str,
    pub lesson: &'a str,
    pub kind: TKind,
    pub text: Cow<'a, str>,
    pub own_tts: Option<TtsMode>,
    pub drill_tts: Option<TtsMode>,
    /// 是否屬於演練題（R05 禁用 `@new`）。
    pub in_drill: bool,
}

/// 句框展開失敗的項目。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FrameIssue<'a> {
    pub owner: &'a str,
    pub detail: String,
}

struct SiteCollector<'a> {
    sites: Vec<TSite<'a>>,
    issues: Vec<FrameIssue<'a>>,
}

impl<'a> SiteCollector<'a> {
    fn push(
        &mut self,
        owner: &'a str,
        lesson: &'a str,
        kind: TKind,
        text: &'a str,
        own_tts: Option<TtsMode>,
        drill_tts: Option<TtsMode>,
    ) {
        self.sites.push(TSite {
            owner,
            lesson,
            kind,
            text: Cow::Borrowed(text),
            own_tts,
            drill_tts,
            in_drill: owner.starts_with("dr."),
        });
    }

    fn drill(&mut self, drill: &'a DrillDef) {
        let owner = drill.id();
        let lesson = drill.lesson();
        match drill {
            DrillDef::Substitution { frame, rows, .. } => self.rows(owner, lesson, frame, rows),
            DrillDef::ParticleFill { blanks, .. } => {
                for choice in blanks.iter().flat_map(|blank| &blank.choices) {
                    self.push(owner, lesson, TKind::BlankChoice, choice, None, None);
                }
            }
            DrillDef::ZhToJaChoice {
                answer,
                distractors,
                tts,
                ..
            } => {
                self.answer(owner, lesson, answer, *tts);
                self.distractors(owner, lesson, distractors, *tts);
            }
            DrillDef::SituationResponse {
                prompt,
                answer,
                distractors,
                tts,
                ..
            } => {
                if let Some(prompt) = prompt {
                    self.push(owner, lesson, TKind::Prompt, prompt, None, *tts);
                }
                self.answer(owner, lesson, answer, *tts);
                self.distractors(owner, lesson, distractors, *tts);
            }
            _ => {}
        }
    }

    fn rows(
        &mut self,
        owner: &'a str,
        lesson: &'a str,
        frame: &'a str,
        rows: &'a [crate::schema::SubRowDef],
    ) {
        for row in rows {
            match expand_frame(frame, &row.slots) {
                Ok(text) => self.sites.push(TSite {
                    owner,
                    lesson,
                    kind: TKind::Row,
                    text: Cow::Owned(text),
                    own_tts: row.tts,
                    drill_tts: None,
                    in_drill: true,
                }),
                Err(detail) => self.issues.push(FrameIssue { owner, detail }),
            }
        }
    }

    fn answer(&mut self, owner: &'a str, lesson: &'a str, answer: &'a str, tts: Option<TtsMode>) {
        if is_inline_t(answer) {
            self.push(owner, lesson, TKind::Answer, answer, None, tts);
        }
    }

    fn distractors(
        &mut self,
        owner: &'a str,
        lesson: &'a str,
        distractors: &'a [crate::schema::DistractorDef],
        tts: Option<TtsMode>,
    ) {
        for distractor in distractors {
            self.push(owner, lesson, TKind::Distractor, &distractor.t, None, tts);
        }
    }
}

/// 全部 `t` 字串（含句框展開後的每一列）。
pub fn t_sites(raw: &RawContent) -> (Vec<TSite<'_>>, Vec<FrameIssue<'_>>) {
    let mut collector = SiteCollector {
        sites: Vec::new(),
        issues: Vec::new(),
    };
    for sentence in &raw.sentences {
        collector.push(
            &sentence.id,
            &sentence.lesson,
            TKind::Sentence,
            &sentence.t,
            sentence.tts,
            None,
        );
    }
    for dialogue in &raw.dialogues {
        for turn in &dialogue.turns {
            collector.push(
                &dialogue.id,
                &dialogue.lesson,
                TKind::Turn,
                &turn.t,
                turn.tts,
                None,
            );
        }
    }
    for drill in &raw.drills {
        collector.drill(drill);
    }
    (collector.sites, collector.issues)
}

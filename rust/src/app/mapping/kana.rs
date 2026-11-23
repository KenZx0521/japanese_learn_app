//! 假名、易混字組、規則卡、語音示範組（§9.5）。

use jp_content::schema::{ConfusableDef, ExampleWordDef, LiteralDef, RuleCardDef, SoundGroupDef};
use jp_content::sentence::Speech;
use jp_content::speech::{kana_speech, pair_speech, rule_example_speech};
use jp_content::store::KanaEntry;
use jp_quiz::drill::quizzable_drill_ids;

use super::enums::{confusable_kind, kana_kind, sound_group_kind};
use super::sentence::speech_dto;
use crate::api::dto_content::{
    ConfusableDto, KanaCellDto, KanaDetailDto, KanaExampleDto, KanaStatus, LiteralDto, RuleCardDto,
    RuleExampleDto, SoundGroupDto, SoundPairDto, SoundSideDto,
};
use crate::app::views::Views;

fn plain_speech(text: &str) -> Speech {
    Speech {
        text: text.to_owned(),
        kana: text.to_owned(),
    }
}

fn example_dto(example: &ExampleWordDef) -> KanaExampleDto {
    KanaExampleDto {
        surface: example.surface.clone(),
        zh: example.zh.clone(),
        speech: speech_dto(&plain_speech(&example.surface)),
    }
}

fn literal_dto(literal: &LiteralDef) -> LiteralDto {
    LiteralDto {
        text: literal.text.clone(),
        zh: literal.zh.clone(),
        speech: speech_dto(&plain_speech(&literal.text)),
    }
}

impl Views<'_> {
    fn kana_status(&self, id: &str) -> KanaStatus {
        match self.kana.get(id) {
            Some(row) if row.mastered_at.is_some() => KanaStatus::Mastered,
            Some(_) => KanaStatus::Learning,
            None if self.state.introduced.contains(id) => KanaStatus::Learning,
            None => KanaStatus::NotStarted,
        }
    }

    pub(crate) fn kana_cell(&self, entry: &KanaEntry) -> KanaCellDto {
        let def = &entry.def;
        KanaCellDto {
            id: def.id.clone(),
            ch: def.ch.clone(),
            romaji: entry.romaji.clone(),
            kind: kana_kind(def.kind),
            status: self.kana_status(&def.id),
            fast_badge: self
                .kana
                .get(&def.id)
                .is_some_and(|row| row.fast_badge_at.is_some()),
            speech: speech_dto(&kana_speech(def)),
            listen_disabled: def.listen_disabled,
        }
    }

    pub(crate) fn confusable(&self, def: &ConfusableDef) -> ConfusableDto {
        ConfusableDto {
            id: def.id.clone(),
            kind: confusable_kind(def.kind),
            members: def
                .members
                .iter()
                .filter_map(|id| self.content().kana_by_id(id))
                .map(|entry| self.kana_cell(entry))
                .collect(),
            literals: def.literals.iter().map(literal_dto).collect(),
            diff_zh: def.diff_zh.clone(),
        }
    }

    pub(crate) fn kana_detail(&self, entry: &KanaEntry) -> KanaDetailDto {
        let def = &entry.def;
        KanaDetailDto {
            cell: self.kana_cell(entry),
            lesson_id: def.lesson.clone(),
            origin_kanji: def.origin_kanji.clone(),
            hint_zh: def.hint_zh.clone(),
            example_words: def.example_words.iter().map(example_dto).collect(),
            confusables: def
                .confusable
                .iter()
                .filter_map(|id| self.content().confusable_by_id(id))
                .map(|group| self.confusable(group))
                .collect(),
            rule_id: def.rule.clone(),
        }
    }

    pub(crate) fn sound_group(&self, def: &SoundGroupDef) -> SoundGroupDto {
        SoundGroupDto {
            id: def.id.clone(),
            lesson_id: def.lesson.clone(),
            kind: sound_group_kind(def.kind),
            title_zh: def.title_zh.clone(),
            body_zh: def.body_zh.clone(),
            pairs: def
                .pairs
                .iter()
                .map(|pair| {
                    let (a_speech, b_speech) = pair_speech(pair);
                    SoundPairDto {
                        a: SoundSideDto {
                            text: pair.a.clone(),
                            kana: pair.a_kana.clone(),
                            zh: pair.a_zh.clone(),
                            speech: speech_dto(&a_speech),
                        },
                        b: SoundSideDto {
                            text: pair.b.clone(),
                            kana: pair.b_kana.clone(),
                            zh: pair.b_zh.clone(),
                            speech: speech_dto(&b_speech),
                        },
                        listen_disabled: pair.listen_disabled,
                    }
                })
                .collect(),
            test_drill_ids: quizzable_drill_ids(self.content(), &def.test_drills),
        }
    }

    pub(crate) fn rule_card(&self, def: &RuleCardDef) -> RuleCardDto {
        RuleCardDto {
            id: def.id.clone(),
            lesson_id: def.lesson.clone(),
            title_zh: def.title_zh.clone(),
            body_zh: def.body_zh.clone(),
            examples: def
                .examples
                .iter()
                .map(|example| RuleExampleDto {
                    text: example.text.clone(),
                    zh: example.zh.clone(),
                    beats: example.beats.clone(),
                    speech: speech_dto(&rule_example_speech(example)),
                })
                .collect(),
            sound_groups: def
                .sound_groups
                .iter()
                .filter_map(|id| self.content().sound_group_by_id(id))
                .map(|group| self.sound_group(group))
                .collect(),
            drill_ids: quizzable_drill_ids(self.content(), &def.drills),
        }
    }
}

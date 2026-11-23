//! `conjugate`、`minimal_pair`、`kana_word`、`shadowing`（§8.4）。

use jp_content::schema::{ConjForm, DrillDef, KanaWordMode, Pos};
use jp_content::sentence::Speech;
use jp_content::speech::pair_side_speech;
use jp_content::store::VocabEntry;
use jp_content::ContentStore;
use jp_lang::grammar::conjugate::{conjugate_kana, conjugate_surface};
use jp_lang::quiz::rng::{index_below, shuffled, ChaCha8Rng};

use crate::drill::choice::choice_id;
use crate::drill::{wrong_kind, Draft};
use crate::error::QuizError;
use crate::model::{ChoiceOption, Prompt, QuestionBody};
use crate::view::{lookup_sentence, mixed_ja, sentence_view, strip_spaces};

const PAIR_SIDES: usize = 2;
pub(super) const OPTION_A: &str = "a";
pub(super) const OPTION_B: &str = "b";
const SURU_SUFFIX: &str = "する";

const CONJUGATE_INSTRUCTION: &str = "打出指定的變化形";
const PAIR_INSTRUCTION: &str = "聽聲音，選出聽到的那一個";
const KANA_WORD_INSTRUCTION: &str = "讀出這個字，選出意思";
const KANA_WORD_TYPING_INSTRUCTION: &str = "讀出這個字，打出讀音";
const SHADOW_INSTRUCTION: &str = "跟著念一次";
const TYPING_PLACEHOLDER: &str = "輸入羅馬字";

pub(super) struct Conjugated {
    pub surface: String,
    pub reading: String,
}

pub(super) fn lemma_entry<'c>(
    content: &'c ContentStore,
    lemma: &str,
) -> Result<&'c VocabEntry, QuizError> {
    content
        .vocab_by_id(lemma)
        .ok_or_else(|| QuizError::not_found("vocab", lemma))
}

pub(super) fn conjugated(
    id: &str,
    entry: &VocabEntry,
    form: ConjForm,
) -> Result<Conjugated, QuizError> {
    let kana = strip_spaces(&entry.def.kana);
    let reading = conjugate_kana(&kana, entry.def.pos, form);
    let surface = conjugate_surface(&entry.def.surface, &kana, entry.def.pos, form);
    match (surface, reading) {
        (Some(surface), Some(reading)) => Ok(Conjugated { surface, reading }),
        _ => Err(QuizError::content(
            id,
            format!("{} 無法產生 {form:?}", entry.def.id),
        )),
    }
}

/// 活用形的中文名稱（MixedText）：演練題幹與 V3 活用表共用。{ja:} 標記依 C16，純假名也要包。
pub fn conj_form_label(form: ConjForm) -> &'static str {
    match form {
        ConjForm::Masu => "{ja:ます}形",
        ConjForm::Te => "{ja:て}形",
        ConjForm::Ta => "{ja:た}形",
        ConjForm::Nai => "{ja:ない}形",
        ConjForm::Potential => "可能形",
        ConjForm::Volitional => "意向形",
        ConjForm::Ba => "{ja:ば}形",
        ConjForm::Imperative => "命令形",
        ConjForm::Passive => "被動形",
        ConjForm::Causative => "使役形",
    }
}

/// `vs` 的單字只存語幹，題幹要顯示字典形。
fn dictionary_form(entry: &VocabEntry) -> String {
    let kana = strip_spaces(&entry.def.kana);
    if entry.def.pos == Pos::Vs && !kana.ends_with(SURU_SUFFIX) {
        mixed_ja(
            &format!("{}{SURU_SUFFIX}", entry.def.surface),
            &format!("{kana}{SURU_SUFFIX}"),
        )
    } else {
        mixed_ja(&entry.def.surface, &kana)
    }
}

pub(super) fn conjugate(
    content: &ContentStore,
    drill: &DrillDef,
    rng: &mut ChaCha8Rng,
) -> Result<Draft, QuizError> {
    let DrillDef::Conjugate { form, lemmas, .. } = drill else {
        return Err(wrong_kind(drill));
    };
    let id = drill.id();
    let variant = index_below(rng, lemmas.len())
        .ok_or_else(|| QuizError::content(id, "conjugate 沒有 lemmas"))?;
    let entry = lemma_entry(content, &lemmas[variant])?;
    let answer = conjugated(id, entry, *form)?;
    let prompt = Prompt {
        instruction_zh: CONJUGATE_INSTRUCTION.to_owned(),
        plain_text: Some(format!(
            "{} → {}",
            dictionary_form(entry),
            conj_form_label(*form)
        )),
        ..Prompt::default()
    };
    let body = QuestionBody::Typing {
        expected_reading: answer.reading,
        placeholder_zh: TYPING_PLACEHOLDER.to_owned(),
    };
    Ok(Draft {
        variant: u32::try_from(variant).ok(),
        ..Draft::new(prompt, body)
    })
}

struct PairSide<'a> {
    option_id: &'a str,
    zh: &'a str,
    speech: Speech,
}

fn pair_draft(a: PairSide<'_>, b: PairSide<'_>, rng: &mut ChaCha8Rng) -> Draft {
    // index_below 的上界是常數 2，不會回 None
    let variant = index_below(rng, PAIR_SIDES).unwrap_or(0);
    let picked = if variant == 0 { &a } else { &b };
    let correct = picked.option_id.to_owned();
    let speech = picked.speech.clone();
    let options = [a, b]
        .map(|side| ChoiceOption {
            id: side.option_id.to_owned(),
            text: side.zh.to_owned(),
            speech: Some(side.speech),
            ..ChoiceOption::default()
        })
        .to_vec();
    let prompt = Prompt {
        instruction_zh: PAIR_INSTRUCTION.to_owned(),
        speech: Some(speech),
        autoplay: true,
        hide_text_until_answered: true,
        ..Prompt::default()
    };
    let body = QuestionBody::Choice {
        options: shuffled(rng, options),
        correct_option_id: correct,
        blank_word_index: None,
    };
    Draft {
        variant: u32::try_from(variant).ok(),
        ..Draft::new(prompt, body)
    }
}

pub(super) fn minimal_pair(drill: &DrillDef, rng: &mut ChaCha8Rng) -> Result<Draft, QuizError> {
    let DrillDef::MinimalPair {
        a,
        a_zh,
        b,
        b_zh,
        a_kana,
        b_kana,
        a_tts_text,
        b_tts_text,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    Ok(pair_draft(
        PairSide {
            option_id: OPTION_A,
            zh: a_zh,
            speech: pair_side_speech(a, a_kana.as_deref(), a_tts_text.as_deref()),
        },
        PairSide {
            option_id: OPTION_B,
            zh: b_zh,
            speech: pair_side_speech(b, b_kana.as_deref(), b_tts_text.as_deref()),
        },
        rng,
    ))
}

fn zh_options(choices: &[String]) -> Vec<ChoiceOption> {
    choices
        .iter()
        .enumerate()
        .map(|(index, text)| ChoiceOption {
            id: choice_id(index),
            text: text.clone(),
            ..ChoiceOption::default()
        })
        .collect()
}

pub(super) fn kana_word(drill: &DrillDef, rng: &mut ChaCha8Rng) -> Result<Draft, QuizError> {
    let DrillDef::KanaWord {
        word,
        mode,
        choices_zh,
        answer_index,
        ..
    } = drill
    else {
        return Err(wrong_kind(drill));
    };
    let base = Prompt {
        plain_text: Some(mixed_ja(word, word)),
        speech: Some(Speech {
            text: word.clone(),
            kana: word.clone(),
        }),
        ..Prompt::default()
    };
    match mode {
        KanaWordMode::Choice => {
            let answer = answer_index.ok_or_else(|| {
                QuizError::content(drill.id(), "kana_word choice 缺 answer_index")
            })?;
            let prompt = Prompt {
                instruction_zh: KANA_WORD_INSTRUCTION.to_owned(),
                ..base
            };
            let body = QuestionBody::Choice {
                options: shuffled(rng, zh_options(choices_zh)),
                correct_option_id: choice_id(answer as usize),
                blank_word_index: None,
            };
            Ok(Draft::new(prompt, body))
        }
        KanaWordMode::Typing => {
            let prompt = Prompt {
                instruction_zh: KANA_WORD_TYPING_INSTRUCTION.to_owned(),
                ..base
            };
            let body = QuestionBody::Typing {
                expected_reading: word.clone(),
                placeholder_zh: TYPING_PLACEHOLDER.to_owned(),
            };
            Ok(Draft::new(prompt, body))
        }
    }
}

pub(super) fn shadowing(content: &ContentStore, drill: &DrillDef) -> Result<Draft, QuizError> {
    let DrillDef::Shadowing { sentence, .. } = drill else {
        return Err(wrong_kind(drill));
    };
    let view = sentence_view(lookup_sentence(content, sentence)?, None);
    let prompt = Prompt {
        instruction_zh: SHADOW_INSTRUCTION.to_owned(),
        speech: Some(view.parsed.speech.clone()),
        text: Some(view.clone()),
        autoplay: true,
        ..Prompt::default()
    };
    let body = QuestionBody::Shadow {
        reveal: Box::new(view),
    };
    Ok(Draft::new(prompt, body))
}

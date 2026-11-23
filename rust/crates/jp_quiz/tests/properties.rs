//! 性質測試：相同種子相同結果、選項不重複、正解一定在選項內。

mod common;

use common::*;
use jp_content::ContentStore;
use jp_quiz::drill::drill_question;
use jp_quiz::grade::grade_answer;
use jp_quiz::model::{AnswerPayload, QuestionBody};
use jp_quiz::{Question, QuestionKey};
use proptest::prelude::*;
use std::sync::LazyLock;

static STORE: LazyLock<ContentStore> = LazyLock::new(content);

fn build(seed: u32, index: usize) -> Question {
    let store: &ContentStore = &STORE;
    let known = all_known(store);
    let context = with_seed(&ctx(store, &known), seed);
    let drill_def = &store.drills()[index % store.drills().len()];
    let key = QuestionKey::plain(drill_def.id());
    drill_question(&context, drill_def, key, None).unwrap()
}

proptest! {
    #[test]
    fn same_seed_same_question(seed in any::<u32>(), index in 0usize..100) {
        prop_assert_eq!(build(seed, index), build(seed, index));
    }

    #[test]
    fn choice_options_are_unique_and_contain_the_answer(seed in any::<u32>(), index in 0usize..100) {
        let question = build(seed, index);
        if let QuestionBody::Choice { options, correct_option_id, .. } = &question.body {
            let mut ids: Vec<_> = options.iter().map(|o| &o.id).collect();
            ids.sort();
            ids.dedup();
            prop_assert_eq!(ids.len(), options.len());
            prop_assert!(options.iter().any(|o| &o.id == correct_option_id));
        }
    }

    #[test]
    fn reorder_is_never_already_correct(seed in any::<u32>(), index in 0usize..100) {
        let question = build(seed, index);
        if let QuestionBody::Reorder { chunks, accept_orders } = &question.body {
            let presented: Vec<u32> = chunks.iter().map(|c| c.index).collect();
            prop_assert!(!accept_orders.contains(&presented));
        }
    }

    #[test]
    fn answering_with_the_stated_correct_option_grades_correct(seed in any::<u32>(), index in 0usize..100) {
        let question = build(seed, index);
        if let QuestionBody::Choice { correct_option_id, .. } = &question.body {
            let response = AnswerPayload::Choice { option_id: correct_option_id.clone() };
            let result = grade_answer(&STORE, &question.reference, &response).unwrap();
            prop_assert!(result.is_correct);
        }
    }
}

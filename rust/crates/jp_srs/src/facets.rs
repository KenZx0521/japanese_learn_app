//! 內容→卡片與 facet 解鎖（§6.1）。全部是純函式，寫入由呼叫端決定時機。

use chrono::{DateTime, Utc};
use jp_content::schema::{KanaDef, KanaKind, UseLevel, VocabDef};
use jp_content::ContentStore;
use jp_store::NewCard;

use crate::card_id::{CardId, Facet};

pub const LISTEN_UNLOCK_DAYS: i64 = 4;
pub const PRODUCE_UNLOCK_DAYS: i64 = 7;

pub(crate) const PRIORITY_MAIN: u8 = 0;
pub(crate) const PRIORITY_SECONDARY: u8 = 1;

fn new_card(content_id: &str, facet: Facet, priority: u8, now: DateTime<Utc>) -> NewCard {
    NewCard {
        card_id: CardId::new(content_id, facet).to_string(),
        content_id: content_id.to_string(),
        facet: facet.as_str().to_string(),
        priority,
        created_at: now,
    }
}

fn vocab_cards(def: &VocabDef, now: DateTime<Utc>) -> Vec<NewCard> {
    let recog = new_card(&def.id, Facet::Recog, PRIORITY_MAIN, now);
    if def.same_form_zh {
        let listen = new_card(&def.id, Facet::Listen, PRIORITY_MAIN, now);
        vec![recog, listen]
    } else {
        vec![recog]
    }
}

fn kana_cards(def: &KanaDef, now: DateTime<Utc>) -> Vec<NewCard> {
    if def.retired || def.kind == KanaKind::Mark {
        return Vec::new();
    }
    vec![new_card(&def.id, Facet::Read, PRIORITY_MAIN, now)]
}

/// 該項目第一次介紹時要建的卡。不建卡的內容（`mark` 等）回空。
pub fn cards_for_content(id: &str, content: &ContentStore, now: DateTime<Utc>) -> Vec<NewCard> {
    if let Some(kana) = content.kana_by_id(id) {
        return kana_cards(&kana.def, now);
    }
    if let Some(vocab) = content.vocab_by_id(id).filter(|v| !v.def.retired) {
        return vocab_cards(&vocab.def, now);
    }
    if content.grammar_by_id(id).is_some_and(|g| !g.retired) {
        return vec![new_card(id, Facet::Use, PRIORITY_MAIN, now)];
    }
    Vec::new()
}

fn kana_unlocks(
    id: &str,
    scheduled_days: i64,
    content: &ContentStore,
    now: DateTime<Utc>,
) -> Vec<NewCard> {
    let is_listenable = content.kana_by_id(id).is_some_and(|kana| {
        !kana.def.retired && kana.def.kind != KanaKind::Mark && !kana.def.listen_disabled
    });
    if !is_listenable || scheduled_days < LISTEN_UNLOCK_DAYS {
        return Vec::new();
    }
    vec![new_card(id, Facet::Listen, PRIORITY_SECONDARY, now)]
}

fn vocab_unlocks(def: &VocabDef, scheduled_days: i64, now: DateTime<Utc>) -> Vec<NewCard> {
    if def.retired {
        return Vec::new();
    }
    let unlocks_listen = !def.same_form_zh && scheduled_days >= LISTEN_UNLOCK_DAYS;
    let unlocks_produce =
        def.use_level != Some(UseLevel::RecognizeOnly) && scheduled_days >= PRODUCE_UNLOCK_DAYS;
    let secondary = |facet| new_card(&def.id, facet, PRIORITY_SECONDARY, now);
    unlocks_listen
        .then(|| secondary(Facet::Listen))
        .into_iter()
        .chain(unlocks_produce.then(|| secondary(Facet::Produce)))
        .collect()
}

/// 作答後依新的 `scheduled_days` 解鎖次要 facet。回傳值可能包含已存在的卡，
/// 由 `insert_cards` 略過。
pub fn unlocks(
    id: &CardId,
    scheduled_days: i64,
    content: &ContentStore,
    now: DateTime<Utc>,
) -> Vec<NewCard> {
    match id.facet() {
        Facet::Read => kana_unlocks(id.content_id(), scheduled_days, content, now),
        Facet::Recog => content
            .vocab_by_id(id.content_id())
            .map(|vocab| vocab_unlocks(&vocab.def, scheduled_days, now))
            .unwrap_or_default(),
        Facet::Listen | Facet::Produce | Facet::Use => Vec::new(),
    }
}

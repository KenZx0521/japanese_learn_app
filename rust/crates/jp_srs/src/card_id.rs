//! 卡片 ID：`<content_id>:<facet>`（§6.1）。

use std::fmt;

use crate::error::SrsError;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Facet {
    Read,
    Listen,
    Recog,
    Produce,
    Use,
}

impl Facet {
    /// 與 `srs_card.facet` 的 CHECK 相同。
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Read => "read",
            Self::Listen => "listen",
            Self::Recog => "recog",
            Self::Produce => "produce",
            Self::Use => "use",
        }
    }

    pub fn parse(text: &str) -> Option<Self> {
        match text {
            "read" => Some(Self::Read),
            "listen" => Some(Self::Listen),
            "recog" => Some(Self::Recog),
            "produce" => Some(Self::Produce),
            "use" => Some(Self::Use),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct CardId {
    content_id: String,
    facet: Facet,
}

impl CardId {
    pub fn new(content_id: impl Into<String>, facet: Facet) -> Self {
        Self {
            content_id: content_id.into(),
            facet,
        }
    }

    pub fn parse(text: &str) -> Result<Self, SrsError> {
        let (content_id, facet) = text.split_once(':').ok_or_else(|| invalid(text))?;
        let facet = Facet::parse(facet).ok_or_else(|| invalid(text))?;
        if content_id.is_empty() {
            return Err(invalid(text));
        }
        Ok(Self::new(content_id, facet))
    }

    pub fn content_id(&self) -> &str {
        &self.content_id
    }

    pub fn facet(&self) -> Facet {
        self.facet
    }
}

impl fmt::Display for CardId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}:{}", self.content_id, self.facet.as_str())
    }
}

fn invalid(text: &str) -> SrsError {
    SrsError::InvalidInput {
        field: "card_id".to_string(),
        reason: format!("not a card id: {text}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const ALL_FACETS: [Facet; 5] = [
        Facet::Read,
        Facet::Listen,
        Facet::Recog,
        Facet::Produce,
        Facet::Use,
    ];

    fn invalid_field(text: &str) -> String {
        match CardId::parse(text) {
            Err(SrsError::InvalidInput { field, .. }) => field,
            other => panic!("{text}: {other:?}"),
        }
    }

    #[test]
    fn parses_content_id_and_facet() {
        let id = CardId::parse("vo.taberu:recog").unwrap();

        assert_eq!(id.content_id(), "vo.taberu");
        assert_eq!(id.facet(), Facet::Recog);
    }

    #[test]
    fn every_facet_round_trips_through_its_text() {
        for facet in ALL_FACETS {
            let id = CardId::new("ka.hira.a", facet);

            assert_eq!(CardId::parse(&id.to_string()).unwrap(), id);
            assert_eq!(Facet::parse(facet.as_str()), Some(facet));
        }
    }

    #[test]
    fn displays_as_content_id_colon_facet() {
        assert_eq!(
            CardId::new("gr.masu", Facet::Use).to_string(),
            "gr.masu:use"
        );
    }

    #[test]
    fn rejects_malformed_ids_as_invalid_input() {
        for text in [
            "",
            "vo.taberu",
            ":recog",
            "vo.taberu:",
            "vo.taberu:sing",
            "a:b:recog",
        ] {
            assert_eq!(invalid_field(text), "card_id", "{text}");
        }
    }

    #[test]
    fn unknown_facet_text_is_none() {
        assert_eq!(Facet::parse("speak"), None);
        assert_eq!(Facet::parse("Recog"), None);
    }
}

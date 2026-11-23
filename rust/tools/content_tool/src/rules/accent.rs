//! A01：非空 `accent` 須與 Kanjium（或 UniDic）其中之一相符。

use super::{strip_spaces, strip_tilde, Finding, Input};

pub fn a01(input: &Input) -> Vec<Finding> {
    let Some(index) = input.data.accents.as_ref() else {
        return Vec::new();
    };
    input
        .scope
        .raw
        .vocab
        .iter()
        .filter_map(|vocab| {
            let accent = vocab.accent?;
            let surface = strip_tilde(&vocab.surface);
            let kana = strip_spaces(&vocab.kana);
            let known = index.accents(surface, &kana)?;
            (!known.contains(&accent)).then(|| {
                Finding::warning(
                    "A01",
                    &vocab.id,
                    format!("{surface}/{kana}"),
                    format!("accent {accent} 與 Kanjium 的 {known:?} 不符，請人工確認"),
                )
            })
        })
        .collect()
}

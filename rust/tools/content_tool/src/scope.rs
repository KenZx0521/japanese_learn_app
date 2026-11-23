//! B 層規則的輸入：階段過濾後的原始內容與全部 `t`。

use std::collections::HashSet;

use jp_content::disk::{borrow_files, ContentFiles};
use jp_content::load_content;
use jp_content::mixed::{validate_mixed, MixedSpan};
use jp_content::scan::{
    classify_field, filter_stage, parse_files, t_sites, visit_text_fields, FieldKind, RawContent,
};
use jp_content::schema::{ContentStage, NoteDef};
use jp_content::sentence::parse_t;
use jp_lang::kana::{Morph, Word};

/// `t` 解析後的語素。無法解析的 `t` 已由 A 層 R02 回報。
pub struct Site {
    pub owner: String,
    pub words: Vec<Word>,
}

impl Site {
    pub fn morphs(&self) -> impl Iterator<Item = &Morph> {
        self.words.iter().filter_map(word_morphs).flatten()
    }
}

fn word_morphs(word: &Word) -> Option<&Vec<Morph>> {
    match word {
        Word::Morphs(morphs) => Some(morphs),
        Word::Punct(_) => None,
    }
}

/// 中文或混合欄位的一筆內容。
pub struct ZhField<'a> {
    pub owner: &'a str,
    pub key: &'a str,
    pub kind: FieldKind,
    pub text: &'a str,
    /// `{ja:…}` 以外的文字；混合欄位語法錯誤時為全文。
    pub zh: String,
    /// `{ja:…}` 內的日文與讀音。
    pub ja: Vec<String>,
    /// 混合欄位的語法錯誤（`Z02` 回報）。
    pub markup_error: Option<String>,
}

pub struct Scope {
    pub stage: ContentStage,
    pub raw: RawContent,
    pub files: ContentFiles,
    pub sites: Vec<Site>,
    pub item_ids: HashSet<String>,
}

fn collect_item_ids(raw: &RawContent) -> HashSet<String> {
    let mut ids: HashSet<String> = HashSet::new();
    ids.extend(raw.kana.iter().map(|k| k.id.clone()));
    ids.extend(raw.confusables.iter().map(|c| c.id.clone()));
    ids.extend(raw.rule_cards.iter().map(|c| c.id.clone()));
    ids.extend(raw.sound_groups.iter().map(|s| s.id.clone()));
    ids.extend(raw.vocab.iter().map(|v| v.id.clone()));
    ids.extend(raw.grammar.iter().map(|g| g.id.clone()));
    ids.extend(raw.sentences.iter().map(|s| s.id.clone()));
    ids.extend(raw.drills.iter().map(|d| d.id().to_owned()));
    ids.extend(raw.dialogues.iter().map(|d| d.id.clone()));
    ids.extend(raw.notes.iter().map(|n| NoteDef::id(n).to_owned()));
    ids
}

impl Scope {
    /// `load_content` 失敗（含階段過濾後的驗證失敗）回內容錯誤訊息。
    pub fn build(files: ContentFiles, stage: ContentStage) -> Result<Self, String> {
        let borrowed = borrow_files(&files);
        load_content(&borrowed, stage).map_err(|err| err.to_string())?;
        let raw = filter_stage(
            parse_files(&borrowed).map_err(|err| err.to_string())?,
            stage,
        );
        let sites = t_sites(&raw)
            .0
            .into_iter()
            .filter_map(|site| {
                let words = parse_t(&site.text).ok()?;
                Some(Site {
                    owner: site.owner.to_owned(),
                    words,
                })
            })
            .collect();
        let item_ids = collect_item_ids(&raw);
        Ok(Self {
            stage,
            raw,
            files,
            sites,
            item_ids,
        })
    }

    /// 走訪中文與混合欄位，分離出中文部分與 `{ja:…}` 內的日文。
    pub fn visit_zh_fields(&self, mut visit: impl FnMut(&ZhField)) {
        let borrowed = borrow_files(&self.files);
        visit_text_fields(&borrowed, &self.raw.course, self.stage, &mut |field| {
            let Some(kind) = classify_field(field.file, field.key, field.parent_key) else {
                return;
            };
            visit(&zh_field(field.owner, field.key, kind, field.text));
        });
    }

    /// 走訪日文欄位（`surface`、`kana`、`char`…，見 F01 的定義），不含 `t` 與 `{ja:…}`。
    pub fn visit_ja_fields(&self, mut visit: impl FnMut(&str, &str, &str)) {
        let borrowed = borrow_files(&self.files);
        visit_text_fields(&borrowed, &self.raw.course, self.stage, &mut |field| {
            if is_ja_field(field.file, field.key, field.parent_key) {
                visit(field.owner, field.key, field.text);
            }
        });
    }
}

/// F01 定義的日文欄位（`t` 與 `{ja:…}` 另外處理）。
fn is_ja_field(file: &str, key: &str, parent_key: &str) -> bool {
    match key {
        "surface" | "kana" | "char" | "origin_kanji" | "word" | "a" | "b" | "a_kana" | "b_kana"
        | "beats" => true,
        "text" => {
            parent_key == "literals" || (parent_key == "examples" && file.starts_with("kana/"))
        }
        "ja" => file.starts_with("notes/shinjitai"),
        _ => false,
    }
}

fn zh_field<'a>(owner: &'a str, key: &'a str, kind: FieldKind, text: &'a str) -> ZhField<'a> {
    let mut field = ZhField {
        owner,
        key,
        kind,
        text,
        zh: String::new(),
        ja: Vec::new(),
        markup_error: None,
    };
    if kind != FieldKind::Mixed {
        field.zh = text.to_owned();
        return field;
    }
    match validate_mixed(text) {
        Ok(spans) => {
            for span in spans {
                match span {
                    MixedSpan::Zh { text } => field.zh.push_str(&text),
                    MixedSpan::Ja { text, ruby } => {
                        field.ja.push(text);
                        field.ja.extend(ruby.into_iter().filter_map(|r| r.ruby));
                    }
                }
            }
        }
        Err(err) => {
            field.markup_error = Some(err.to_string());
            field.zh = text.to_owned();
        }
    }
    field
}

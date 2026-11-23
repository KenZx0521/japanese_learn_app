//! 動詞與い形容詞的變化（rust-core.md §4.7）。
//!
//! `conjugate` 題型的答案與內容 lint R07 的合法語幹都由這裡產生，內容不手寫變化形。

use serde::Deserialize;

pub use super::stems::legal_stems;

pub(super) const SURU: &str = "する";
pub(super) const KURU: &str = "くる";
const KURU_KANJI: &str = "来る";
const ARU: &str = "ある";
const NAI: &str = "ない";
pub(super) const ADJ_I_ENDING: char = 'い';
const II: &str = "いい";
const YO_STEM: &str = "よ";
/// 一段命令形的語尾。
pub(super) const ICHIDAN_IMPERATIVE: &str = "ろ";
/// 特殊一段的命令形不接 ろ，就是語幹（くれる→くれ）。
const V1S_IMPERATIVE: &str = "";

/// 語幹以 いい 結尾且變化時換成 よ 的形容詞。かわいい 是一般形容詞，所以不能用字尾判斷。
const YOI_FAMILY: [&str; 2] = [II, "かっこいい"];

/// ます形為 り→い 的敬語動詞。
const HONORIFIC_MASU: [&str; 5] = ["いらっしゃる", "くださる", "おっしゃる", "なさる", "ござる"];

/// 命令形為 〜い 的敬語動詞。ござる 的命令形仍是規則的 ござれ。
const HONORIFIC_IMPERATIVE: [&str; 4] = ["いらっしゃる", "くださる", "おっしゃる", "なさる"];

#[rustfmt::skip]
const GODAN_ROWS: [[char; 5]; 9] = [
    ['わ', 'い', 'う', 'え', 'お'],
    ['か', 'き', 'く', 'け', 'こ'],
    ['が', 'ぎ', 'ぐ', 'げ', 'ご'],
    ['さ', 'し', 'す', 'せ', 'そ'],
    ['た', 'ち', 'つ', 'て', 'と'],
    ['な', 'に', 'ぬ', 'ね', 'の'],
    ['ば', 'び', 'ぶ', 'べ', 'ぼ'],
    ['ま', 'み', 'む', 'め', 'も'],
    ['ら', 'り', 'る', 'れ', 'ろ'],
];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Pos {
    N,
    Pron,
    Num,
    Counter,
    V5,
    V1,
    /// 特殊一段（JMdict `v1-s`，目前只有 くれる）：同 `v1`，只有命令形是語幹（くれ）。
    V1S,
    Vs,
    Vk,
    AdjI,
    AdjNa,
    Adv,
    Conj,
    Interj,
    Phrase,
}

impl Pos {
    /// 詞性大類：`v1_s` 歸入 `v1`，其餘是自己。「同 pos」的干擾項以此分組。
    pub const fn family(self) -> Self {
        match self {
            Self::V1S => Self::V1,
            other => other,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Form {
    Masu,
    Te,
    Ta,
    Nai,
    Potential,
    Volitional,
    Ba,
    Imperative,
    Passive,
    Causative,
}

/// 五十音的段，值是 `GODAN_ROWS` 的欄位。
#[derive(Clone, Copy)]
pub(super) enum Dan {
    A = 0,
    I = 1,
    U = 2,
    E = 3,
    O = 4,
}

/// て形、た形的音便：語幹尾與 て／た 是否濁化。
pub(super) struct Onbin {
    pub(super) ending: &'static str,
    voiced: bool,
}

/// 來る的變化拆成隨活用改變的假名，與接在後面的語尾；漢字 来 涵蓋前者。
pub(super) struct KuruForm {
    pub(super) mora: &'static str,
    pub(super) tail: &'static str,
}

/// 不可變化的詞性或不合語形的詞回傳 `None`。
pub fn conjugate_kana(kana: &str, pos: Pos, form: Form) -> Option<String> {
    if kana.is_empty() {
        return None;
    }
    match pos {
        Pos::V1 | Pos::V1S => kana
            .strip_suffix('る')
            .map(|stem| format!("{stem}{}", ichidan_ending(pos, form))),
        Pos::V5 => godan(kana, form),
        Pos::Vs => Some(format!("{}{}", suru_stem(kana), suru_ending(form))),
        Pos::Vk => kana.strip_suffix(KURU).map(|prefix| {
            let parts = kuru_form(form);
            format!("{prefix}{}{}", parts.mora, parts.tail)
        }),
        Pos::AdjI => adj_i(kana, form),
        _ => None,
    }
}

/// 比對 kana 與變化後 kana 的共同前綴，把 surface 尾端的送假名換掉，保留漢字。
pub fn conjugate_surface(surface: &str, kana: &str, pos: Pos, form: Form) -> Option<String> {
    match pos {
        Pos::Vs if !kana.is_empty() => Some(format!(
            "{}{}",
            suru_surface_stem(surface, kana),
            suru_ending(form)
        )),
        Pos::Vk if kana.ends_with(KURU) => kuru_surface(surface, kuru_form(form)),
        Pos::AdjI if is_yoi_family(kana) => {
            adj_i(kana, form).and_then(|conj| yoi_surface(surface, kana, &conj))
        }
        Pos::V5 if kana == ARU && form == Form::Nai => Some(NAI.to_owned()),
        _ => {
            conjugate_kana(kana, pos, form).and_then(|conj| rewrite_okurigana(surface, kana, &conj))
        }
    }
}

pub(super) fn split_last(text: &str) -> Option<(&str, char)> {
    let last = text.chars().last()?;
    Some((&text[..text.len() - last.len_utf8()], last))
}

/// 共同前綴之後的 kana 必須是 surface 的尾端，否則 surface 與 kana 對不上。
pub(super) fn rewrite_okurigana(surface: &str, kana: &str, conjugated: &str) -> Option<String> {
    let shared: usize = kana
        .chars()
        .zip(conjugated.chars())
        .take_while(|(a, b)| a == b)
        .map(|(a, _)| a.len_utf8())
        .sum();
    let head = surface.strip_suffix(&kana[shared..])?;
    Some(format!("{head}{}", &conjugated[shared..]))
}

fn ichidan_ending(pos: Pos, form: Form) -> &'static str {
    match form {
        Form::Imperative if pos == Pos::V1S => V1S_IMPERATIVE,
        Form::Masu => "ます",
        Form::Te => "て",
        Form::Ta => "た",
        Form::Nai => "ない",
        Form::Potential | Form::Passive => "られる",
        Form::Volitional => "よう",
        Form::Ba => "れば",
        Form::Imperative => ICHIDAN_IMPERATIVE,
        Form::Causative => "させる",
    }
}

pub(super) fn dan_kana(last: char, dan: Dan) -> Option<char> {
    GODAN_ROWS
        .iter()
        .find(|row| row[Dan::U as usize] == last)
        .map(|row| row[dan as usize])
}

fn godan(kana: &str, form: Form) -> Option<String> {
    let (stem, last) = split_last(kana)?;
    let shifted = |dan: Dan, ending: &str| {
        dan_kana(last, dan).map(|shifted| format!("{stem}{shifted}{ending}"))
    };
    match form {
        Form::Masu if HONORIFIC_MASU.contains(&kana) => Some(format!("{stem}います")),
        Form::Imperative if HONORIFIC_IMPERATIVE.contains(&kana) => Some(format!("{stem}い")),
        Form::Nai if kana == ARU => Some(NAI.to_owned()),
        Form::Masu => shifted(Dan::I, "ます"),
        Form::Nai => shifted(Dan::A, "ない"),
        Form::Potential => shifted(Dan::E, "る"),
        Form::Ba => shifted(Dan::E, "ば"),
        Form::Imperative => shifted(Dan::E, ""),
        Form::Volitional => shifted(Dan::O, "う"),
        Form::Passive => shifted(Dan::A, "れる"),
        Form::Causative => shifted(Dan::A, "せる"),
        Form::Te => onbin_form(kana, stem, last, "て", "で"),
        Form::Ta => onbin_form(kana, stem, last, "た", "だ"),
    }
}

fn onbin_form(kana: &str, stem: &str, last: char, plain: &str, voiced: &str) -> Option<String> {
    let onbin = onbin_of(kana, last)?;
    let suffix = if onbin.voiced { voiced } else { plain };
    Some(format!("{stem}{}{suffix}", onbin.ending))
}

pub(super) fn onbin_of(kana: &str, last: char) -> Option<Onbin> {
    if is_iku(kana) {
        return Some(Onbin {
            ending: "っ",
            voiced: false,
        });
    }
    match last {
        'う' | 'つ' | 'る' => Some(Onbin {
            ending: "っ",
            voiced: false,
        }),
        'む' | 'ぶ' | 'ぬ' => Some(Onbin {
            ending: "ん",
            voiced: true,
        }),
        'く' => Some(Onbin {
            ending: "い",
            voiced: false,
        }),
        'ぐ' => Some(Onbin {
            ending: "い",
            voiced: true,
        }),
        'す' => Some(Onbin {
            ending: "し",
            voiced: false,
        }),
        _ => None,
    }
}

/// 行く 與 〜ていく、〜でいく 的複合動詞。
fn is_iku(kana: &str) -> bool {
    kana == "いく" || kana.ends_with("ていく") || kana.ends_with("でいく")
}

/// `kana` 是語幹；容許連 する 一起寫的舊格式。
fn suru_stem(kana: &str) -> &str {
    kana.strip_suffix(SURU).unwrap_or(kana)
}

fn suru_surface_stem<'a>(surface: &'a str, kana: &str) -> &'a str {
    if suru_stem(kana).is_empty() {
        ""
    } else {
        surface.strip_suffix(SURU).unwrap_or(surface)
    }
}

fn suru_ending(form: Form) -> &'static str {
    match form {
        Form::Masu => "します",
        Form::Te => "して",
        Form::Ta => "した",
        Form::Nai => "しない",
        Form::Potential => "できる",
        Form::Volitional => "しよう",
        Form::Ba => "すれば",
        Form::Imperative => "しろ",
        Form::Passive => "される",
        Form::Causative => "させる",
    }
}

fn kuru_form(form: Form) -> KuruForm {
    let (mora, tail) = match form {
        Form::Masu => ("き", "ます"),
        Form::Te => ("き", "て"),
        Form::Ta => ("き", "た"),
        Form::Nai => ("こ", "ない"),
        Form::Potential | Form::Passive => ("こ", "られる"),
        Form::Volitional => ("こ", "よう"),
        Form::Ba => ("く", "れば"),
        Form::Imperative => ("こ", "い"),
        Form::Causative => ("こ", "させる"),
    };
    KuruForm { mora, tail }
}

pub(super) fn kuru_surface(surface: &str, form: KuruForm) -> Option<String> {
    if let Some(head) = surface
        .strip_suffix('る')
        .filter(|_| surface.ends_with(KURU_KANJI))
    {
        return Some(format!("{head}{}", form.tail));
    }
    surface
        .strip_suffix(KURU)
        .map(|head| format!("{head}{}{}", form.mora, form.tail))
}

pub(super) fn is_yoi_family(kana: &str) -> bool {
    YOI_FAMILY.contains(&kana)
}

pub(super) fn adj_i_stem(kana: &str) -> Option<String> {
    if is_yoi_family(kana) {
        return kana
            .strip_suffix(II)
            .map(|prefix| format!("{prefix}{YO_STEM}"));
    }
    kana.strip_suffix(ADJ_I_ENDING).map(str::to_owned)
}

fn adj_i_ending(form: Form) -> Option<&'static str> {
    match form {
        Form::Nai => Some("くない"),
        Form::Te => Some("くて"),
        Form::Ta => Some("かった"),
        Form::Ba => Some("ければ"),
        _ => None,
    }
}

fn adj_i(kana: &str, form: Form) -> Option<String> {
    Some(format!("{}{}", adj_i_stem(kana)?, adj_i_ending(form)?))
}

/// いい 的 surface：kana 寫的 いい 換成 よ，漢字寫的 良い 由漢字涵蓋 よ。
pub(super) fn yoi_surface(surface: &str, kana: &str, conjugated: &str) -> Option<String> {
    if surface.ends_with(II) {
        return rewrite_okurigana(surface, kana, conjugated);
    }
    let prefix = kana.strip_suffix(II)?;
    let tail = conjugated.strip_prefix(prefix)?.strip_prefix(YO_STEM)?;
    let head = surface.strip_suffix(ADJ_I_ENDING)?;
    Some(format!("{head}{tail}"))
}

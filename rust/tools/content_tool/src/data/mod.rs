//! B 層的外部資料：放在 gitignored 的 `.verify-cache/`，不進 repo、不進 App（reuse-and-verification.md §2.4）。

use std::collections::{BTreeSet, HashSet};
use std::fs;
use std::path::{Path, PathBuf};

pub mod jmdict;
pub mod kanjidic;
pub mod lists;

use jmdict::JmdictIndex;
use lists::{AccentIndex, FreqEntry, FuriganaIndex, JlptLists};

/// 規則宣告自己需要的資料，只有被選中的規則用到的資料才載入。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Need {
    Jmdict,
    Kanjidic,
    Furigana,
    Jlpt,
    Freq,
    Accents,
}

const JMDICT_FILE: &str = "jmdict-eng.json";
const KANJIDIC_FILE: &str = "kanjidic2-en.json";
const FURIGANA_FILE: &str = "JmdictFurigana.json";
const JLPT_N5_FILE: &str = "jlpt_n5.csv";
const JLPT_N4_FILE: &str = "jlpt_n4.csv";
const FREQ_FILE: &str = "frequency-subtitles.json";
const ACCENTS_FILE: &str = "accents.txt";

impl Need {
    fn files(self) -> &'static [&'static str] {
        match self {
            Self::Jmdict => &[JMDICT_FILE],
            Self::Kanjidic => &[KANJIDIC_FILE],
            Self::Furigana => &[FURIGANA_FILE],
            Self::Jlpt => &[JLPT_N5_FILE, JLPT_N4_FILE],
            Self::Freq => &[FREQ_FILE],
            Self::Accents => &[ACCENTS_FILE],
        }
    }
}

#[derive(Default)]
pub struct Data {
    pub jmdict: Option<JmdictIndex>,
    pub joyo: Option<HashSet<char>>,
    pub furigana: Option<FuriganaIndex>,
    pub jlpt: Option<JlptLists>,
    pub freq: Option<Vec<FreqEntry>>,
    pub accents: Option<AccentIndex>,
}

/// 資料缺失時的說明（`verify` 結束代碼 2）。
pub fn missing_data_help(cache_dir: &Path, missing: &[PathBuf]) -> String {
    let files = missing
        .iter()
        .map(|path| format!("  - {}", path.display()))
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "找不到驗證資料（{cache}）：\n{files}\n\n\
         這些資料受 CC BY-SA 等授權，不進 repo，放在 gitignored 的 .verify-cache/。\n\
         請在 repo 根目錄執行：\n\n    tools/verify/fetch_data.sh\n\n\
         腳本依 tools/verify/data.lock.toml 下載 JMdict、KANJIDIC2、JmdictFurigana、\
         JLPT 清單、字幕詞頻與 Kanjium，並校驗 sha256。\n\
         也可用 --cache-dir 指定其他目錄。不需外部資料的規則可單獨執行：\
         --only J01b,J04,J08,Z01,Z02,C05,L01,L02,L04,F01,F02,F03,F04,F05",
        cache = cache_dir.display()
    )
}

pub fn missing_files(cache_dir: &Path, needs: &BTreeSet<Need>) -> Vec<PathBuf> {
    needs
        .iter()
        .flat_map(|need| need.files().iter())
        .map(|name| cache_dir.join(name))
        .filter(|path| !path.exists())
        .collect()
}

/// `missing_files` 已確認檔案存在；這裡的錯誤是檔案損毀，由呼叫端以環境問題回報。
pub fn load(cache_dir: &Path, needs: &BTreeSet<Need>) -> Result<Data, String> {
    let mut data = Data::default();
    let jlpt = if needs.contains(&Need::Jlpt) {
        Some(JlptLists::load(
            &cache_dir.join(JLPT_N5_FILE),
            &cache_dir.join(JLPT_N4_FILE),
        )?)
    } else {
        None
    };
    if needs.contains(&Need::Jmdict) {
        let keep = jlpt.as_ref().map(JlptLists::ids).unwrap_or_default();
        let file = open(&cache_dir.join(JMDICT_FILE))?;
        data.jmdict = Some(JmdictIndex::parse(file, &keep)?);
    }
    data.jlpt = jlpt;
    if needs.contains(&Need::Kanjidic) {
        data.joyo = Some(kanjidic::load_joyo(&cache_dir.join(KANJIDIC_FILE))?);
    }
    if needs.contains(&Need::Furigana) {
        data.furigana = Some(FuriganaIndex::load(&cache_dir.join(FURIGANA_FILE))?);
    }
    if needs.contains(&Need::Freq) {
        data.freq = Some(lists::load_freq(&cache_dir.join(FREQ_FILE))?);
    }
    if needs.contains(&Need::Accents) {
        data.accents = Some(AccentIndex::load(&cache_dir.join(ACCENTS_FILE))?);
    }
    Ok(data)
}

fn open(path: &Path) -> Result<std::io::BufReader<fs::File>, String> {
    let file = fs::File::open(path).map_err(|err| format!("{}：{err}", path.display()))?;
    Ok(std::io::BufReader::with_capacity(1 << 20, file))
}

fn read_text(path: &Path) -> Result<String, String> {
    let text = fs::read_to_string(path).map_err(|err| format!("{}：{err}", path.display()))?;
    Ok(text
        .strip_prefix('\u{feff}')
        .map_or_else(|| text.clone(), str::to_owned))
}

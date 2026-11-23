# 可重用資源調查與內容驗證方案（reuse-and-verification.md）

調查日期：2026-11-09。本文件回答兩件事：哪些外部資源可以用、怎麼用才合乎授權；以及內容要怎麼機械驗證。

**閱讀方式**

- 標「實測」的數字都實際下載資料、跑過程式取得。實驗檔在本次工作階段的暫存區，之後可能被清除，所以關鍵演算法都寫在本文。
- 標「間接」的表示未取得第一手來源，只能由第三方引述，已註明原因。
- 授權分析是工程判斷，不是法律意見。商業上架前，建議請律師看 §2.4、§3.3 與 §10。

本文的 R01–R25 指 `curriculum.md` §13 的 lint 規則，RC1–RC10 指 `rust-core.md` §11.3 的追加規則，內容格式以 `curriculum.md` §12 為準。驗證工具、B 層規則代碼與字型子集流程以本文為準。`CONTENT_STAGE`（`p0a`、`p0`、`full`）的範圍定義見 `curriculum.md` §14。

---

## 1. 結論總表

| 資源 | 授權 | 結論 | 我們的用法 |
|---|---|---|---|
| JMdict（jmdict-simplified JSON） | CC BY-SA 4.0（EDRDG 授權） | **僅開發時使用** | 驗證漢字＋假名、詞性；資料不進 repo、不進 App |
| KANJIDIC2 | CC BY-SA 4.0 | **僅開發時使用** | 產生常用漢字表，供字型子集與字形檢查 |
| JmdictFurigana | 資料 CC BY-SA（GitHub 標 MIT 僅指程式碼） | **僅開發時使用** | 校對振假名對齊 |
| Waller JLPT 清單（經 yomitan-jlpt-vocab） | Waller 為 CC BY（間接）；此整理版 CC BY-SA 4.0 | **僅開發時使用** | 涵蓋率報告與 `jlpt` 欄位的基準 |
| open-anki-jlpt-decks | MIT（資料源自 Tanos，並非獨立來源） | **僅開發時使用** | 第二份清單，只比對差異 |
| Japanese Language Data（grammar.json） | CC BY-SA 4.0，全部標 draft | **僅開發時使用** | 文法檢核清單的參考 |
| Tatoeba | CC BY 2.0 FR；部分 CC0；語音依貢獻者 | **不採用** | 全部例句自行撰寫（§4） |
| Klee One | OFL 1.1 | **可用（打包）** | 日文主字型，Regular＋SemiBold，字元集為常用漢字聯集內容用字（§5.3） |
| Noto Sans TC | OFL 1.1 | **可用（打包）** | 繁中介面與內文，400、700，字元集為 Big5 一級聯集內容與 `lib` 用字（§5.4） |
| Noto Serif TC | OFL 1.1 | **可用（打包）** | 繁中標題，800，依 `lib` 實際用字加 ASCII 子集（§5.3、§5.4） |
| Zen Maru Gothic、BIZ UDPGothic、Noto Sans JP | OFL 1.1 | 可用（備選） | 視覺方向改變時替換 |
| 系統繁中字型 | 無需授權 | 備案 | 字型總量超過預算時，才把 `NotoSansTC` 換成系統字型 |
| LXGW WenKai TC | OFL 1.1 | 不採用 | 傳承字形，不得用於字形對照內容（§5.4） |
| UniDic 2.1.2 | GPL／LGPL／BSD 三選一 | **可用**（選 BSD，附聲明） | `accent` 欄位的主要來源 |
| Kanjium accents.txt | CC BY-SA 4.0，原始出處不明 | **僅開發時使用** | 音調交叉核對 |
| OJAD、NHK 音調辭典 | 未開放（未逐條查證） | **不可用** | 不使用 |
| wana_kana 5.0.0 | MIT | **僅開發時使用** | 羅馬字差分比對，不取代自寫模組（§7.1） |
| kana_kit、ruby_text | MIT | 不採用 | Rust 已負責假名邏輯；振假名需自製元件 |
| jidoujisho、Nihonoari | GPL-3.0 | **不可用** | 授權不相容且架構不同 |
| KanjiVG（假名部分） | CC BY-SA 3.0 | **可用（P1）** | 假名筆順／描紅 |
| AnimCJK | SVG 為 Arphic PL（假名可選 LGPL） | 備選 | 不優先 |
| VOICEVOX 預生成音檔 | 可商用，需標示 | 可用（P1 再評估） | v1 維持裝置 TTS |
| Forvo、JapanesePod101 等音檔 | 未開放（未逐條查證） | **不可用** | 不使用 |

---

## 2. JMdict

### 2.1 下載

- 來源：<https://github.com/scriptin/jmdict-simplified/releases/latest>
- 檔案：`jmdict-eng-<版本>.json.tgz`（實測 11.5 MB，解壓 118 MB）
- 實測版本：`3.6.2+20261102210542`，`dictDate` 為 2026-11-02，共 219,009 詞條
- 不要用 `jmdict-eng-common`（1.4 MB）：驗證時需要連罕用與舊形都查得到，才能區分「拼錯」和「形式不佳」
- 歷史 release 保留超過 200 版，鎖定特定版本是安全的（實測 API 分頁）

KANJIDIC2 在同一個 release：`kanjidic2-en-<版本>.json.tgz`。

### 2.2 查詢規則（由實測修正而來）

1. **配對要遵守 `appliesToKanji`**。假名的 `appliesToKanji` 為 `["*"]` 時對應全部漢字形，否則只對應列出的漢字形。實測有 16,534 組「漢字與假名在同一詞條、但不成立」的配對，其中 16,528 組在別處也不成立；只查「同詞條內都有」會全部放行（例：`馬酔木／アセビ`）。
2. **純假名的詞查「任一詞條的假名」**，不是查 `noKanji`。ありがとう、とても、すし 都掛在有漢字的詞條下。最初的原型用 noKanji 判定，因此把 ありがとう 和 コーヒー 誤報為錯誤。
3. **`kana` 欄位先去空白再查**（`こんにち は` 查 `こんにちは`），`surface` 前後的 `〜` 也要去掉。
4. **「查得到」不等於「能用」**。必須看形式標記。`sK` 搜尋專用、`oK` 舊字形、`iK` 不規則、`rK` 罕用等都要警告。`gikun`（今日／きょう）與 `ateji` 是正常用法，不警告。
5. **`uk`（通常寫假名）只看第一個義項**。`uk` 是義項層級的標記；只要任一義項有就算的話，行く、犬、猫 都會被誤報（實測 N5 列漢字的 547 詞中，任一義項有 uk 的 57 詞、第一義項有 uk 的 33 詞）。

```rust
// 核心索引：key 為 (漢字形, 假名)。假名另存一份供純假名查詢。
for word in jmdict.words {
    let uk = word.sense.first().is_some_and(|s| s.misc.iter().any(|m| m == "uk"));
    let pos: Vec<String> = word.sense.iter().flat_map(|s| s.part_of_speech.clone()).collect();
    for reading in &word.kana {
        kana_index.entry(reading.text.clone()).or_default().extend(pos.clone());
        let applies_all = reading.applies_to_kanji.iter().any(|a| a == "*");
        for kanji in &word.kanji {
            if applies_all || reading.applies_to_kanji.contains(&kanji.text) {
                let tags = kanji.tags.iter().chain(&reading.tags).cloned().collect();
                pairs.entry((kanji.text.clone(), reading.text.clone()))
                     .or_default().push(Hit { tags, uk, pos: pos.clone() });
            }
        }
    }
}
```

serde 結構只需宣告上述欄位。效能實測：release 建置載入 0.34 秒、建索引 0.27 秒、全部檢查 0.63 秒、尖峰記憶體 285 MB；debug 建置載入 3.7 秒。所以 CI 一律用 `--release`。

### 2.3 實測案例

Rust 原型（159 行）跑 `curriculum.md` §12 的 `t` 格式 fixture：

| 測試內容 | 結果 |
|---|---|
| 正確範本（學校、食べる、帰る v5、勉強 vs、いい adj_i、コーヒー、こんにち は 等 14 詞＋句子） | 0 錯誤，2 警告（皆為預期），exit 0 |
| `学校／がこう` | J01 錯誤 |
| `學校／がっこう` | J02 錯誤（**JMdict 查得到，標 `sK`，只靠 J01 擋不住**） |
| `說明／せつめい`（繁中字形） | J01＋J02 錯誤 |
| `帰る` 標成 `v1` | J05 錯誤（中文母語者最常犯的動詞分類錯） |
| `馬酔木／アセビ`（`appliesToKanji` 排除） | J01 錯誤 |
| `こおひい`、`ゃま`、半形 `ｺｰﾋｰ` | J01／J04 錯誤 |
| `surface: たべる`、`kana: たべり` | J01b＋J01 錯誤 |
| `御茶／おちゃ`（`sK`）、`有難う`（第一義項 uk） | J03／J03b 警告 |
| 重複 ID、未知 ref、課序違反、壞掉的 morph | R01／R03／R04／R02 錯誤 |
| 中文欄位夾未標記的假名 | Z02 錯誤 |
| 字型缺字（學、說、半形假名） | F01 錯誤 |

壞範本共 18 個錯誤、3 個警告，exit 1。

其他實測：

- 47 個常用問候語、日劇語、歌詞詞彙中 42 個直接查到。查不到的 5 個（お疲れ様です、マジで、ちょっと待って、よかった、会いたい）都是變化形或片語，所以 **`pos: phrase` 查不到時只警告**。
- N5／N4 共 1,324 筆清單項目，全部的 JMdict ID 都存在、配對全部成立、假名驗證 0 誤報。

### 2.4 授權分析：只在開發時驗證，是否就不需標示？

**結論：嚴格依條文，開發時驗證不觸發標示義務。但我們仍主動標示，並用機制防止資料滲入 App。**

依據：

- CC BY-SA 4.0 §3 的標示與相同方式分享條件都以 "If You Share" 為前提（實際查閱 LICENSE 全文）。在本機或私有 CI 上讀取資料、比對拼寫，沒有散布 Licensed Material，也沒有產出並散布 Adapted Material。
- EDRDG 授權第 3、4 節的標示與定期更新義務，適用對象是 "a software package, WWW server, smartphone app, etc. which uses the files or incorporates data from the files"。App 執行時既不使用這些檔案，也不含其資料，因此不適用。
- 同一授權明文表示，使用這些檔案的軟體 "does not have to be under any form of open-source licence"。所以即使未來打包資料，也只影響資料本身，不影響 App 程式碼。

**會讓結論翻轉的情況，以及對應的防線：**

| 風險 | 為什麼危險 | 防線 |
|---|---|---|
| 把 JMdict 英文釋義翻成中文當 `zh` 欄位 | 翻譯屬改作，觸發 ShareAlike | `zh` 必須自行撰寫；驗證工具**不輸出 gloss**，不給撰寫者抄的機會 |
| 內容 JSON 裡放 JMdict ID | 會被嵌入 App 二進位檔，形成「併入資料」的論點 | 比對一律用 `(surface, kana)`；L01 禁止 `rust/content/` 出現 `jmdict`、`seq` 等鍵 |
| 把快取或報告 commit 進公開 repo | 構成 Share | 資料放 `.verify-cache/`、報告放 `build/verify/`，兩者都 gitignore |
| 驗證工具開源並附資料 | 成為「使用該檔案的軟體套件」 | 工具不附資料，由腳本從上游下載；README 附來源聲明 |
| 日後加入 App 內字典 | 全部義務生效：獨立授權頁、附授權檔、定期更新資料 | 屆時重新評估。EDRDG 明言未更新版本屬違反授權，等於綁定 App 的發版週期 |

**主動標示**（無義務但成本近乎零，避免日後爭議）。放在「關於」的授權頁，EDRDG 要求獨立畫面而非啟動頁，我們照做：

> 單字拼寫與讀音於開發時參照 JMdict 校對。JMdict 由 Electronic Dictionary Research and Development Group 製作，以 CC BY-SA 4.0 授權（https://www.edrdg.org/jmdict/j_jmdict.html）。本 App 未收錄 JMdict 資料。

這段話明確說「未收錄」，避免被誤解成本 App 內容也以 CC BY-SA 授權。

**維護**：雖無定期更新義務，資料鎖定檔超過 90 天未更新時，工具仍發出警告（§9.5）。

---

## 3. JLPT N5／N4 清單

### 3.1 先講清楚：沒有官方清單

JLPT 官方 FAQ 明言 2010 改制後不再公布 "Test Content Specifications"（內含字彙、漢字、文法清單），理由是公布清單 "was not necessarily appropriate"。同一頁把舊制 4 級、3 級對應到 N5、N4（需由上下文推論，並非同一句明說）。

因此市面上所有 N5／N4 清單都是推估。多數源自 Jonathan Waller 整理、以舊制規格與考古題為基礎的清單。`curriculum.md` §1.2 已要求介面寫「參考 N5」，本文沿用這個要求。

### 3.2 來源比較

| 來源 | 筆數（實測） | 授權 | 可信度與用途 |
|---|---|---|---|
| [stephenmk/yomitan-jlpt-vocab](https://github.com/stephenmk/yomitan-jlpt-vocab) `original_data/n5.csv`、`n4.csv` | N5 684 列（667 個不重複 ID）；N4 640 列（635） | CC BY-SA 4.0；Waller 部分 CC BY | **主要基準**。逐筆附 JMdict ID，且人工修過罕見拼寫（歯磨→歯磨き）。作者自述「essentially an educated guess」 |
| [jamsinclair/open-anki-jlpt-decks](https://github.com/jamsinclair/open-anki-jlpt-decks) `src/n5.csv`、`n4.csv` | N5 718；N4 668 | MIT（repo） | 同樣源自 Tanos，**不是獨立來源**；格式髒（`～`、`;`、`(する)`），直接解析 N5 652/718、N4 593/668 |
| [Bluskyo/JLPT_Vocabulary](https://github.com/Bluskyo/JLPT_Vocabulary) | 未計 | 程式 MIT；資料自述 Waller CC BY | Waller 原始資料的 CC BY 鏡像，由 PDF 解析 |
| [jkindrix/japanese-language-data](https://github.com/jkindrix/japanese-language-data) `data/grammar/grammar.json` | 文法 N5 77、N4 89 | CC BY-SA 4.0 | 目前找到**唯一可取得、結構化、授權清楚**的文法清單；595 筆全為 `draft`，未經母語者審閱 |
| 本田ゆかり（2019）〈初級日本語教科書共通語彙リスト〉 | 617 詞（四套教科書共通） | 未標示利用條款（© 2019） | 真正獨立於 Waller 的學術來源；**僅供人工參考**，未確認清單本體可取得 |
| [NINJAL 映像教材](https://mmsrv.ninjal.ac.jp/evmds/en/index.html) 語彙表 | 初級編 7,903 列用例 | CC BY 4.0 | 授權乾淨，但為 1997 年影片的用例表，太舊也不是詞表，不採用 |

**Waller 的第一手來源無法驗證**：`www.tanos.co.uk` 在 2026-11-09 從本機 DNS 解析失敗，一個鏡像 repo 也描述該站 "now defunct"。CC BY 這項資訊來自 yomitan-jlpt-vocab、japanese-language-data、Bluskyo 三方引述（間接）。

兩份清單以 JMdict ID 比對（`open-anki` 用拼寫反查）：N5 共同 651、僅 yomitan 16、僅 open-anki 47；N4 共同 615、僅 yomitan 20、僅 open-anki 34。部分差異來自解析（`けっこん (する)` 這類寫法）。**清單間的高度一致不代表正確，因為它們同源。**

### 3.3 結論與用法

1. 資料只在開發時使用，不進 App，下載規則同 JMdict。
2. 詞彙涵蓋率以 yomitan-jlpt-vocab 為基準，比對鍵用 `(surface, kana)` 而非 ID（內容不存 JMdict ID）。分母維持實測清單的列數（N5 684、N4 640），`curriculum.md` §4.2 的欄位是課程階段，不是 JLPT 級別，不影響分母。
3. 刻意不收的詞（`curriculum.md` §4.1 提到的万年筆）列入 `rust/content/lint/coverage_skip.toml` 並寫明原因，不計入分母。
4. **文法涵蓋率用自建清單**：`tools/verify/grammar_checklist.toml`，以 jkindrix 的 N5／N4 共 166 項為起點人工改寫成 `curriculum.md` §5 的 `gr.*` 對應。清單項目本身是語法事實，個別項目不具原創性；但為保守起見，不原樣複製其說明文字。
5. **App 內的 `jlpt` 欄位依基準清單填寫**：清單內標 `n5`、`n4`，不在清單者標 `beyond`，由 C06 強制。`jlpt` 是使用者看得到的資料，授權頁加上：「參考級別參照 Jonathan Waller 的 JLPT Resources（CC BY）整理，非官方資料。」級別來自 Waller；yomitan 整理版 CC BY-SA 的部分是 ID 對應與拼寫修正，App 只散布 `n5`／`n4`／`beyond` 三種標籤，不含這些內容。

### 3.4 JLPT 涵蓋率測不到口語高頻詞

JLPT 清單收的口語高頻詞不多。實測 OpenSubtitles 2018 字幕詞頻（hermitdave/FrequencyWords，CC BY-SA 4.0，經 japanese-language-data 比對 JMdict 的 8,598 筆）：

| 字幕頻率前 N | N5 | N4 | 兩者皆非 |
|---|---:|---:|---:|
| 200 | 56 | 43 | 101 |
| 500 | 88 | 81 | 331 |
| 1,000 | 109 | 110 | 781 |
| 2,000 | 132 | 148 | 1,720 |

要打折扣看：這是表層比對，未還原活用形（教え、生き、連れ 其實是動詞語幹），且語料偏翻譯的犯罪片（捜査、殺人、犯人）。但方向很清楚：**あんた、お前、あいつ、まあ、絶対、了解 這類口語高頻詞都不在 N5／N4 清單**。原本依此另設的 200 字專區字彙已隨專區移除（RULINGS O13）；報告 C04 仍列出「字幕前 500 且未收錄」的詞，**只供選字參考，不設門檻**。

---

## 4. 例句來源：全部自行撰寫

**建議：不採用 Tatoeba，例句全部自行撰寫。**

實測（248,970 句日文，使用 fugashi＋unidic-lite 分析，僅取 20 字內的 180,635 句）：

| 只用最常見的 N5 詞 | 實詞全在範圍內 | 再限制為敬體且只用基本助詞、助動詞 |
|---:|---:|---:|
| 前 50 詞 | 1,800 | 198 |
| 前 100 詞 | 3,966 | 483 |
| 前 200 詞 | 7,381 | 936 |
| 前 300 詞 | 10,637 | 1,450 |

表面上不少，實際不適合：

1. **過濾只保證用字，保證不了文法**。只用前 100 詞的句子裡有「人が何を言おうと気にしない」「今日は食べたいだけ食べていいよ」，文法遠超初級。第三欄的過濾也還沒有依 `curriculum.md` 的課序（R04、R06）檢查，實際可用量更少。
2. **自然度參差**。抽樣有「誰があなたの奥様ですか」「貴方はよくそこへ行きますか」，形式正確但不像會話。
3. **語體不合**。N5 範圍內的 14,549 句中，敬體結尾只有 3,938 句（27%），常體或口語結尾 6,365 句，而本課程 S1 先教敬體。全庫 6.3% 含「トム」。
4. **沒省到工**。`t` 格式要求每個語素帶 ref（R02），仍得逐句人工標註。
5. **翻譯仍要自己寫**。jpn–cmn 連結只有 16,275 組，且 cmn 語料不分簡繁，也不是台灣用語。
6. **署名負擔**。CC BY 2.0 FR 要求署名作者，需要每句保存使用者名稱（Detailed Sentences 匯出檔有此欄）。CC0 子集可免署名，但 1～5 點依然成立。

例句自行撰寫時，防止誤用的機制是 R04／R06／R11（已學範圍）與人工抽查（`curriculum.md` §14 批次 9）。

---

## 5. 日文字型

### 5.1 大小與涵蓋率（實測）

下載自 <https://github.com/google/fonts> 的 `ofl/<名稱>/`。子集參數：`--layout-features='kern,palt,liga,ccmp,locl,mark,mkmk' --no-hinting --desubroutinize --name-IDs='*' --notdef-outline --recalc-bounds`。「假名」包含全部平假名、片假名與基本標點。

單位 MB，格式為 TTF／gzip。

| 字型 | 原檔 | 僅假名 | ＋教育漢字 1,026 | ＋常用漢字 2,136 | ＋JIS 第一水準 2,965 | ＋JIS 一水準＋常用 |
|---|---:|---:|---:|---:|---:|---:|
| **Klee One Regular** | 8.72 | 0.10／0.05 | 0.68／0.41 | **1.46／0.86** | 2.00／1.19 | 2.07／1.22 |
| **Klee One SemiBold** | 8.91 | 0.11／0.05 | 0.70／0.42 | **1.49／0.89** | 2.05／1.23 | 2.11／1.26 |
| Zen Maru Gothic Regular | 3.83 | 0.07／0.04 | 0.50／0.30 | 1.06／0.62 | 1.49／0.86 | 1.51／0.87 |
| Zen Maru Gothic Bold | 3.78 | 0.07／0.04 | 0.50／0.30 | 1.05／0.63 | 1.47／0.88 | 1.49／0.88 |
| Noto Sans JP（釘住 wght 400） | 9.59 | 0.09／0.05 | 0.36／0.23 | 0.73／0.46 | 0.98／0.61 | 1.02／0.63 |
| BIZ UDPGothic Regular | 4.67 | 0.05／0.04 | 0.29／0.21 | 0.62／0.43 | 0.83／0.58 | 0.87／0.61 |
| M PLUS Rounded 1c Regular | 3.39 | 0.08／0.05 | 0.54／0.28 | 1.15／0.58 | 1.59／0.79 | 1.64／0.81 |

涵蓋率：所有候選字型的教育漢字與 JIS 第一水準都是 100%。差異在：

- Klee One 常用漢字 2136/2136；平假名只缺組合用濁點 U+3099、U+309A；片假名只缺 `゠`、`ヿ`。實際都用不到。
- **Zen Maru Gothic 缺 4 個常用漢字**：剝、塡、頰、𠮟，也缺 `―`、`＄`。
- 常用漢字有 34 字不在 JIS 第一水準（丼、傲、喩、嘲……），**所以子集基準應該用常用漢字，不是 JIS 第一水準**。

### 5.2 建議

**日文字型：Klee One Regular＋SemiBold，字元集為常用漢字聯集內容用字（§5.3）。** 只算常用漢字時合計 TTF 2.94 MB、gzip 約 1.75 MB，內容用字只再多出常用漢字以外的少數字。

- 實際渲染比對：Klee One 的 さ、き、ふ、り 筆畫分離，字形接近手寫範本，與教科書一致。Zen Maru、Noto 的 さ き 連筆，初學者照著寫會學成印刷體的形狀。對初學者這是實質差異。
- 振假名用 SemiBold。目視比對，Regular 在 16px 偏細。
- 視覺方向已定案為 Klee One（`flutter-app.md` §4.3）。Zen Maru Gothic 僅作備選，替換時 F01 會擋下缺字。
- **陷阱**：`NotoSansJP[wght].ttf` 可變字型的預設實例是 Thin（實測渲染極細）。若改用 Noto，必須先釘住字重，或用 `FontVariation`。

### 5.3 字元集與子集產生流程

三種字型各有一份字元集，由 `tools/fonts/make_charset.py` 產生。字元集檔與子集成品都 commit 進 repo（App 建置不應依賴 Python）。

| 字元集檔 | 組成 | 用於 |
|---|---|---|
| `tools/fonts/charset_ja.txt` | 常用漢字（KANJIDIC2 的 grade 1-6 與 8）＋假名＋標點（含 U+301C `〜`），實測 2,573 字；再聯集 `chars_ja.txt` | Klee One 400、600 |
| `tools/fonts/charset_noto_sans.txt` | Big5 一級（0xA440–0xC67E，5,401 字）＋全形標點＋ASCII 0x20–0x7E；再聯集 `chars_zh.txt`、`lib` 用字與 Rust 字串用字 | Noto Sans TC 400、700 |
| `tools/fonts/charset_noto_serif.txt` | `lib` 用字＋ASCII 0x20–0x7E | Noto Serif TC 800 |

`chars_*.txt` 由 `content_tool charset` 輸出到 `build/verify/`：`chars_ja.txt` 是日文內容的字元（定義見 F01），`chars_zh.txt` 是中文內容的字元。`lib` 用字指 `lib/**/*.dart` 去掉 `//` 註解後的 CJK 漢字與全形標點（U+3000–303F、U+3400–4DBF、U+4E00–9FFF、U+FF00–FFEF），排除生成碼 `lib/src/rust/` 與假名。Rust 字串用字指 `rust/src`、`rust/crates/*/src` 的字串常值（題幹、題型說明等 Rust 組出的介面字串，同一組字元範圍，測試碼與 `frb_generated.rs` 除外），這些字串不經 `lib` 也不在內容 JSON。`lib` 用字不含 ASCII，所以 `make_charset.py` 依上表把 ASCII 0x20–0x7E 直接加進兩份 Noto 字元集。`romaji` token、數字與拉丁字走 Noto Sans TC，少了 ASCII 會靜默落到系統字型。

內容用字一律取全部階段，所以子集不隨 `CONTENT_STAGE` 改變，內容增加後重跑一次即可。`full` 的內容還沒寫，`$CT charset --stage full` 目前會失敗（`content corrupt: le.l31: R03 dialogue 指向不存在的項目（di.can_you_speak）`），所以現在能取到的最大範圍是預設的 `p0`。2026-11-10 實測：`$CT --stage p0 charset` 輸出 944 字（`chars_ja.txt`）、1,920 字（`chars_zh.txt`），全部已在 `tools/fonts/charset_ja.txt`、`charset_noto_sans.txt` 內（這兩個字元集檔與 `assets/fonts/*.subset.ttf` 的修改時間都是 2026-11-10 09:59），`$CT --stage p0 verify` 的 F01–F05 沒有錯誤。

```bash
CT="cargo run --release --manifest-path rust/Cargo.toml -p content_tool --"
$CT charset --stage full
python3 tools/fonts/make_charset.py   # 讀 .verify-cache 的 KANJIDIC2、build/verify/chars_*.txt、lib/**/*.dart、rust/**/*.rs

# Noto 的上游是可變字型，先釘成靜態字重（實測 Noto Serif TC 800 輸出 10.0 MB，約 6 秒）
fonttools varLib.instancer 'NotoSansTC[wght].ttf' wght=400 -o build/fonts/NotoSansTC-Regular.ttf
fonttools varLib.instancer 'NotoSansTC[wght].ttf' wght=700 -o build/fonts/NotoSansTC-Bold.ttf
fonttools varLib.instancer 'NotoSerifTC[wght].ttf' wght=800 -o build/fonts/NotoSerifTC-ExtraBold.ttf

FLAGS=(--layout-features='kern,palt,liga,ccmp,locl,mark,mkmk' --no-hinting --desubroutinize --name-IDs='*' --notdef-outline --recalc-bounds)
sub() { pyftsubset "$1" --text-file="tools/fonts/$2" "${FLAGS[@]}" --output-file="assets/fonts/$3.subset.ttf"; }
sub KleeOne-Regular.ttf                   charset_ja.txt         KleeOne-Regular
sub KleeOne-SemiBold.ttf                  charset_ja.txt         KleeOne-SemiBold
sub build/fonts/NotoSansTC-Regular.ttf    charset_noto_sans.txt  NotoSansTC-Regular
sub build/fonts/NotoSansTC-Bold.ttf       charset_noto_sans.txt  NotoSansTC-Bold
sub build/fonts/NotoSerifTC-ExtraBold.ttf charset_noto_serif.txt NotoSerifTC-ExtraBold
```

實測輸出（Klee One，只含常用漢字＋假名＋標點的 2,573 字）：Regular 1,454,504 位元組，SemiBold 1,485,504 位元組，常用漢字與假名無缺字，name table 的著作權與 OFL 字串保留。缺字的只有 U+3000–303F 區段裡的少用符號（`〖`、`〡` 等），pyftsubset 預設會略過。

Klee One 原檔（cmap 10,178 碼位）實測收有常用漢字外的內容字 嘘 綺 絆 儚 呟 涙 瞳 煌 囁 癒、全部假名的 `origin_kanji`（含 无、祢、尓）與 U+301C，所以聯集內容用字不會卡在原檔缺字。真的遇到原檔缺字時 F01 報錯，處理方式是改寫該內容，不准 fallback。

`layout-features` 不要用 `*`：Klee One 的全部 feature 會讓檔案膨脹到 3.73 MB。

常用漢字表本身來自日本內閣告示，字元清單不含 KANJIDIC2 的受保護內容；內容用字是自家內容的字元。

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: KleeOneJP
      fonts:
        - asset: assets/fonts/KleeOne-Regular.subset.ttf
        - asset: assets/fonts/KleeOne-SemiBold.subset.ttf
          weight: 600
    - family: NotoSansTC
      fonts:
        - asset: assets/fonts/NotoSansTC-Regular.subset.ttf
        - asset: assets/fonts/NotoSansTC-Bold.subset.ttf
          weight: 700
    - family: NotoSerifTC
      fonts:
        - asset: assets/fonts/NotoSerifTC-ExtraBold.subset.ttf
          weight: 800
```

```dart
const jaStyle = TextStyle(fontFamily: 'KleeOneJP', locale: Locale('ja', 'JP'));
```

字型缺字時 Flutter 會靜默走系統 fallback，字形就不再受控，正好違反已定案的決策 7。所以 F01（日文內容的每個字都要在 Klee 子集內）與 F03、F04（中文）是必要檢查，不是加分項。

### 5.4 繁中字型

| 做法 | 大小（每字重） | 優點 | 缺點 |
|---|---|---|---|
| 系統字型＋`zh-Hant-TW` locale | 0 | Android 為 Noto Sans CJK TC、iOS 為 PingFang TC，皆為台灣標準字形 | 跨平台字寬、行高不同；手機沒有內建繁中明體 |
| **Noto Sans TC 子集（Big5 一級 5,401 字）** | 1.88 MB／gzip 1.19（`flutter-app.md` 實測 400、700 靜態實例各 1.98 MB） | 跨平台一致，golden 代表實際版面 | 比系統字型多約 4 MB |
| **Noto Serif TC 800（`lib` 用字子集）** | 實測 400 字子集 95,512 位元組，約 0.24 KB／字 | 編輯風格標題的來源，手機沒有內建 | 改文案要重建；Big5 子集是 2.77 MB，所以不用 Big5 |
| LXGW WenKai TC（Big5 一級） | 3.78 MB／gzip 2.25 | 由 Klee One 衍生，與日文字型視覺一體 | 太大 |
| LXGW WenKai TC（依內容子集，抽樣 800 字） | 0.46 MB／gzip 0.29 | 視覺一體，體積可接受 | 每次改文案要重建；字形問題見下 |

**定案：打包 Noto Sans TC（400、700）與 Noto Serif TC（800），family 名 `NotoSansTC`、`NotoSerifTC`，理由見 `flutter-app.md` §4.3。** Noto Serif TC 的字元集只收 `lib` 實際用字與 ASCII 0x20–0x7E（`flutter-app.md` §4.2 規定內容字串不用此字型），1,500 字約 0.36 MB（估計）。三種字型合計預算 12 MB，由 F05 警告；超預算時的單點退路是把 token 的 `NotoSansTC` 換成系統字型並設定 `Locale('zh', 'TW')`。

LXGW WenKai TC 不採用。實際排版雖與 Klee One 很搭，但有一個硬限制：該字型**把異碼字合併、採傳承字形**（README 明言 真→眞、為→爲、緒→緖，並說明不適用於需區分字形的場合）。本 App 的 `no.sj.*` 字形對照筆記教的正是字形差異，**這類內容絕不能用 LXGW 顯示**。

### 5.5 授權要求（OFL 1.1）

- 子集化屬於修改（OFL FAQ 2.6："Removing any parts of the font...is considered modification"）。修改版仍須維持 OFL。
- 打包進 App 時，最低要求是附上著作權聲明、授權聲明與授權全文（FAQ 1.20）。App 本身不受影響（FAQ 1.3）。
- Reserved Font Name：Klee One、Zen Maru、BIZ UD、LXGW、Noto Serif TC 的 OFL.txt 均未保留字型名；Noto Sans TC 只保留 'Source'，family 名不含該字。所以子集可沿用原名，不必改名。
- 上游 OFL.txt 的著作權行（2026-11-09 實際讀取）：Klee One 為 "Copyright 2020 The Klee Project Authors"；Noto Sans TC 為 "Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'"；Noto Serif TC 為 "Copyright 2012 Google Inc. All Rights Reserved."。授權檔整份照抄，不改字。
- 實作：把上游 `OFL.txt` 放在 `assets/fonts/licenses/OFL-KleeOne.txt`、`OFL-NotoSansTC.txt`、`OFL-NotoSerifTC.txt`，並註冊到 Flutter 授權頁：

```dart
const fontLicenses = {
  'Klee One': 'OFL-KleeOne.txt',
  'Noto Sans TC': 'OFL-NotoSansTC.txt',
  'Noto Serif TC': 'OFL-NotoSerifTC.txt',
};
LicenseRegistry.addLicense(() async* {
  for (final MapEntry(key: name, value: file) in fontLicenses.entries) {
    final text = await rootBundle.loadString('assets/fonts/licenses/$file');
    yield LicenseEntryWithLineBreaks(['$name（已子集化）'], text);
  }
});
```

---

## 6. 音調重音

| 資料集 | 授權 | 涵蓋（實測，N5 684 列／N4 640 列中有值者） | 評估 |
|---|---|---|---|
| **UniDic 2.1.2**（unidic-lite 1.0.8 的 `aType`） | GPL／LGPL／BSD 三選一，選 BSD（實際讀到 BSD 全文） | N5 598、N4 571（只計分詞後為單一語素的詞） | **首選**。授權最寬，學術機構製作；115/1,169 詞有多值（如 `0,1`） |
| Kanjium `accents.txt` | CC BY-SA 4.0，另要求標示作者 | 全檔 124,137 列；N5 539、N4 510 | 僅交叉核對。README 只說來自 "Uros O. through his free database"，**原始出處不明** |
| Wiktionary（kaikki.org） | CC BY-SA 4.0 | 約 12,788 筆補充（間接） | 不需要 |
| tdmelodic | BSD-3-Clause | 生成器，非資料 | 用於大量新詞才需要 |
| OJAD、NHK 音調辭典 | 未開放 | — | 不可用（未逐條查證授權，按未授權處理） |

**交叉核對**：UniDic 與 Kanjium 都有資料且讀音相符時，N5 445/447 一致、N4 458/459 一致。不一致只有 3 筆：結構、所、大体。`curriculum.md` §4.4 的最小對立例（雨／飴、箸／橋／端、柿／牡蠣、花／鼻、神／紙、酒／鮭，共 13 筆）實測在兩個資料集都與課綱一致。

**建議**：

1. 維持 `curriculum.md` §4.4 的決定：`accent` 可空，不全面匯入。
2. 要填 `accent` 時以 UniDic 為來源（授權負擔最低），Kanjium 僅作開發時核對，兩者不一致就人工裁決（A01）。
3. 擷取時**不要信任分詞器選的讀音**：`私` 會被標成 ワタクシ。必須比對 `kana`，對不上的人工處理。全面擷取需要 UniDic 完整版的 lex.csv，因為 unidic-lite 只有編譯後的字典（約 260 MB）。
4. 這些資料只有辭書形。活用形的音調變化不在範圍內，TTS 的音調也不保證正確，兩點都應照 `curriculum.md` §10.3 在介面說明。

---

## 7. 開源專案與 kana crate

### 7.1 wana_kana：不取代自寫模組，只當差分比對

版本 5.0.0、MIT、2026-05 發布、累計下載 71 萬。實測兩組案例：

**一般案例（67 個）44 個符合規則。** 全部正確的部分：長音（ookii、toukyou、koohii）、促音（matcha、zasshi）、撥音（shinbun、zen'in、**hon'ya**、kin'youbi）、基本赫本式。

**23 個不符，主要分三類**（其餘為舊假名 `ゐ ゑ` 與括號標點的表示法，屬本專案自訂）**：**

1. 助詞與固定語：`は`→ha、`へ`→he、`を`→wo，`こんにちは`→konnichiha。這可以用分詞包裝解決。
2. **外來語擴充假名**（另外跑 35 個擴充假名與長音符的專項案例，只有 5 個正確）：

   | 輸入 | wana_kana | 應為 |
   |---|---|---|
   | ティー | teii | tii |
   | ディズニー | deizunii | dizunii |
   | ファン | fuan | fan |
   | フォーク | fuooku | fooku |
   | フィ／フェ | fyi／fye | fi／fe |
   | ウィスキー | uisukii | wisukii |
   | ヴァイオリン | voaiorin | vaiorin |
   | ツァ／トゥ／ドゥ | tsua／tou／dou | tsa／tu／du |
   | テュ／デュ | teyu／deyu | tyu／dyu |

3. 平假名接長音符：`げーむ`→ge-mu、`すげー`→suge-、`ほんとー`→honto-。這些是**日劇與歌詞常見的口語寫法**。另外 `ヵ`、`ヶ` 未轉換。

**結論：不採用作為產品依賴。**

要修好第 2 類，需要在前面套一張約 30 項的擴充假名表，再處理長音符與助詞。這些加起來幾乎等於自己寫一個最長匹配轉換器（估計一張約 190 項的表加上促音、撥音、長音規則，約 100 行），還多帶 `lazy_static`、`itertools`、`fnv` 依賴。

**但值得放進開發工具**，規則 J09：對所有內容同時跑自寫模組與 wana_kana，把差異分類。已知類別（助詞、擴充假名、長音符）之外的差異才報告。這是免費的第二意見，能抓出自寫表的錯字。

其他候選：`ib-romaji`（MIT）README 表明使用 JMdict，資料的 CC BY-SA 不會因 crate 標 MIT 而消失，**不採用**。`lindera`、`vibrato` 等分詞器不需要，內容已人工分詞。

### 7.2 羅馬字模組要處理的邊界

`ん`＋y 與尾端促音已定案（`curriculum.md` §12.7：`ほんや`→hon'ya、`あっ`→a），wana_kana 亦輸出 hon'ya 與 a，兩邊一致。

`歯` 與 `葉` 的假名就是 `は`（N5 有 歯、N4 有 葉）。決策 3 說的是「單獨成詞的**助詞**」，所以模組不能只看分詞假名，否則 `歯|は|vo.ha_tooth が|gr.ga_subject` 會變成 `wa ga`。規則由 `rust-core.md` §4.1–§4.3 實作：

| 情境 | 介面 | は／へ／を 的讀音 |
|---|---|---|
| `t` 內，單一語素且 surface 為假名、詞等於 は／へ／を（助詞，以及 `こんにち は` 的 は） | `romanize_words` | wa／e／o |
| `t` 內，surface 含漢字（歯、葉） | `romanize_words` | ha |
| 單字 `kana` 無空白（歯、葉的 `は`、`へ`） | `reading_mode_of` 回 `Word` | ha／he |
| 單字 `kana` 含空白（`こんにち は`） | `reading_mode_of` 回 `Sentence` | wa |

`typed_answer_matches` 與羅馬字顯示走同一個 `mode`，所以答 歯 時輸入 ha 通過、wa 失敗。J08 用同一組函式驗證內容，測試資料包含 `歯|は|vo.ha_tooth が|gr.ga_subject`→`ha ga`。

### 7.3 其他專案

| 專案 | 授權 | 結論 |
|---|---|---|
| arianneorpilla/jidoujisho（1,786★） | GPL-3.0 | 不可用。沉浸式閱讀器，定位不同；GPL 與 App Store 分發也有衝突 |
| aeri/Nihonoari-App（113★） | GPL-3.0 | 不可用。僅假名練習 |
| Maadhu938/Minnalearn-app 等小型專案 | MIT／無授權 | 不採用。規模小，內容來源未經確認（repo 標 MIT 不代表教材內容有授權），**不得取用其資料** |
| jeroen-meijer/kana_kit（Dart，2.1.1） | MIT | 不需要。與 wana_kana 同源，假名邏輯已在 Rust |
| ruby_text（3.0.3，最後發布 2023-06） | MIT | 參考實作即可。我們需要逐語素可點擊與 ja locale，自製元件較合適 |
| flutter_tts（4.2.5，2026-01） | 依 pub.dev 標示 | 已定案使用 |

結論：**沒有值得當基底 fork 的專案**。可重用的是資料與字型，不是 App 程式碼。

---

## 8. 筆順與音檔（僅評估）

### 8.1 筆順

手寫描紅與筆順列為暫不實作（`curriculum.md` §14，P1）。調查結果是**屆時有可用的資料**：

| 資料 | 授權 | 實測 | 評估 |
|---|---|---|---|
| [KanjiVG](https://github.com/KanjiVG/kanjivg) `r20260714`，`kanjivg-*-main.zip` | CC BY-SA 3.0 | 平假名 86/86、片假名 90/90 全收；假名 180 檔共 0.40 MB；全部 6,703 檔 29 MB | **值得，僅取假名**。每筆一條 path，可做動畫 |
| [AnimCJK](https://github.com/parsimonhi/animCJK) | SVG 為 Arphic Public License；假名與筆畫 SVG 可選 LGPL | 假名 177 字 | 備選。內建動畫，但授權較複雜 |

採用 KanjiVG 時要標示作者與連結（檔案標頭要求 "stating your use of KanjiVG...and linking to KanjiVG's website"），SVG 檔本身須維持 CC BY-SA，但不影響 App 其他部分。漢字筆順依 `curriculum.md` §1.3 不做，不需納入。

### 8.2 發音音檔

v1 維持已定案的裝置 TTS，不打包音檔。評估結果供 P1 參考：

| 來源 | 授權 | 評估 |
|---|---|---|
| VOICEVOX 預生成 | 官方條款：「商用・非商用問わず利用することができます」，需標示；生成音檔另依各聲音函式庫條款 | **唯一值得考慮的方案**。可用於假名與高頻詞，解決 `curriculum.md` §10 提到的單一假名 TTS 不穩定。每個角色條款不同，採用時需逐一確認 |
| Tatoeba 語音 | 依貢獻者；授權欄空白者 "you may not reuse the audio outside the Tatoeba project" | 不採用，逐檔查授權不划算 |
| Wikimedia Commons、Lingua Libre | 依檔案（本次未查證） | P1 若需要再查 |
| Forvo、JapanesePod101、Tofugu 音檔 | 無開放授權（未逐條查證） | 不可用 |

---

## 9. 內容驗證管線

### 9.1 分層

| 層 | 內容 | 執行方式 | 需要外部資料 |
|---|---|---|---|
| A | R01–R25、RC1–RC10（結構、ID、交叉引用、已學範圍） | `cargo test -p jp_content --test content_lint`，即 `rust/crates/jp_content/tests/content_lint.rs`（不加 `-p jp_content` 會找不到這個 test target） | 否（`rust/content/lint/*.txt` 隨 repo） |
| B | 本文的 J／F／C／Z／A／T 規則與 L01、L02、L04 | `content_tool verify` | 是（`.verify-cache/`） |
| O | 離線保證 L03、L05–L08 | `tools/verify/check_offline.py` | 否（需 cargo、flutter） |
| H | 語意、自然度、原創性、實機語音 | 人工（`curriculum.md` §14、§9.13） | — |

A 層規格在 `curriculum.md` §13，本文不重複定義。B 層只做 A 層做不到的事。分層的好處：寫內容時 `cargo test` 幾秒內回饋，也不需要網路。

R15 的 `rust/content/lint/zh_simplified_chars.txt` 不依賴 OpenCC：它是「GB2312 有、Big5 沒有」的 2,380 個漢字，由 `tools/verify/make_zh_simplified.py` 只用 Python 內建編碼表產生並 commit，沒有外部資料也沒有授權問題。實測對 `curriculum.md` 的中文欄位範例（604 字）0 誤報。限制：里、后、干、面 這類兩岸共用字形的誤用查不出來，由 `zh_tw_denylist.txt` 與人工抽查補足。

### 9.2 B 層規則

等級：**E** 錯誤（CI 失敗）、**W** 警告、**I** 僅報告。「實測」欄表示原型已驗證。

**日文正確性（J）**

| ID | 等級 | 檢查 | 資料 | 實測 |
|---|---|---|---|---|
| J01 | E（`phrase` 為 W） | `surface` 含漢字時 `(surface, kana 去空白)` 配對成立；純假名時 `kana` 存在於 JMdict。對象：`vo.*`、`ka.*` 的 `example_words[].surface` | JMdict | 是 |
| J01b | E | 純假名的 `surface` 必須等於去空白的 `kana` | — | 是 |
| J02 | E | 日文欄位與 `{ja:…}` 標記內的漢字必須屬於常用漢字（擋下 學、說 這類繁中字形）。`origin_kanji`、`no.sj.*` 的 `zh_tw`、`no.rd.*` 的 `hanzi` 不適用。人名與常用漢字外的必要用字走覆寫清單（§9.6，例如 `ka.sg.accent_ame` 的 飴） | KANJIDIC2 | 是 |
| J03 | W | 配對只以 `sK sk oK ok iK ik io rK rk` 形式存在 | JMdict | 是 |
| J03b | W | `surface` 含漢字，但第一義項標 `uk` | JMdict | 是 |
| J04 | E | 假名合法性（見下） | — | 是 |
| J05 | E | `pos` 與 JMdict 詞性相容（見下） | JMdict | 是 |
| J06 | W | `@new:` 語素的配對存在；活用形查不到屬正常所以只警告 | JMdict | 是 |
| J07 | W | 振假名對齊與 JmdictFurigana 一致 | JmdictFurigana | 資料已驗證 |
| J08 | E | `kana` 為 `は`／`へ` 的 `vo.*`，`to_romaji_reading(kana, reading_mode_of(kana))` 必須是 ha／he，且 `typed_answer_matches` 接受 ha、拒絕 wa（§7.2）；其他以 は／へ 結尾且無空白的 `vo.*`（では、または）為 W | — | 偵測已驗證 |
| J09 | I | 羅馬字模組與 wana_kana 差分，列出已知類別外的差異 | wana_kana | 差異類別已驗證 |
| J10 | W | 兩拍以上的 `kana_word.word`、`minimal_pair` 與 `ka.sg.*` 的 `a`／`b` 存在於 JMdict；活用形（きて）查不到屬正常，所以只警告 | JMdict | 否 |

J04 假名合法性：

- 對象：`vo.*` 的 `surface`（純假名時）與 `kana`、`t` 內語素的 surface 與讀音、`example_words[].surface`、`kana_word.word`、`minimal_pair` 與 `ka.sg.*` 的 `a`／`b`／`a_kana`／`b_kana`、所有 `tts_text`。`ka.*` 的 `char`、規則卡的 `beats` 本來就會單獨出現小字，不適用。
- 比照 `rust-core.md` §4.2，只允許平假名 U+3041–3096、片假名 U+30A1–30F6、`ー・`。疊字符 `ゝゞヽヾ` 與 ヷ 系（U+30F7–30FA）為 E，因為羅馬字模組回 `InvalidChar`
- E：小字開頭、`ー` 開頭、`ん／っ` 開頭（`gr.*` 語素除外，因為 んです、んだ 是合法的）、拗音接在非い段之後（テュ、デュ、フュ、ヴュ 除外）、`っ` 接母音／`ん`／`ー`、`ん` 接小字或 `ー`、內容中的波浪號不是 U+301C `〜`（U+FF5E、ASCII `~`）
- W：小寫母音用於口語（`ねぇ`、`へぇ`）、連續長音符、`ゐ ゑ` 舊假名

對 JMdict 全部 260,866 個假名實測：E 僅 151 個（0.058%），W 104 個；N5／N4 清單 0 誤報。該次實測尚未把疊字符與 ヷ 系列為 E；同一版 JMdict 中含這些字元的假名表示只有 6 筆（ヽ、ヾ、ゝ、ゞ、いすゞ、こゝろ），結論不變。

J05 詞性對應（`pos` → JMdict 前綴，比對所有義項任一符合）：`v5`→`v5`、`v1`→`v1`（完全相等，不含 `v1-s`）、`v1_s`→`v1-s`（完全相等）、`vs`→`vs`、`vk`→`vk`、`adj_i`→`adj-i`（含 `adj-ix`）、`adj_na`→`adj-na`、`n`→`n`、`pron`→`pn`、`num`→`num`、`counter`→`ctr`、`adv`→`adv`、`conj`→`conj`、`interj`→`int`；`phrase` 不檢查。N5／N4 實際出現的動詞類別有 `v1`、`v1-s`、`v5{u,k,k-s,g,s,t,n,b,m,r,r-i,aru}`、`vk`、`vs`、`vs-i`，對應表足以涵蓋。`v1-s`（くれる）的命令形是 くれ，不是一般 `v1` 的 〜ろ，所以 `v1` 不接受 `v1-s`：くれる 標成 `v1` 時，漢字寫法（呉れる）會被 J05 擋下；只寫假名時，同音的 暮れる（`v1`）會讓比對通過，要靠撰寫時標對。

這條規則的價值在於：R07 的活用檢查以 `pos` 為前提，若 `帰る` 被標成 `v1`，引擎會一致地算出錯誤語幹，R07 反而通過。J05 用外部資料打破這個循環。

**字型（F）**

日文內容指：`surface`、`kana`、所有 `t`（含 `frame`、`rows`、`choices`、干擾項）的 surface 與讀音、`char`、`origin_kanji`、`example_words[].surface`、`word`、`a`／`b`／`a_kana`／`b_kana`、`literals[].text`、`beats`、`no.sj.*` 的 `ja`、所有 `{ja:…}` 標記內的文字與讀音。中文內容指其餘的 `zh`、`*_zh`、`zh_tw`、`hanzi` 在 `{ja:…}` 以外的字元。

| ID | 等級 | 檢查 | 實測 |
|---|---|---|---|
| F01 | E | 所有日文內容的字元都在 `KleeOne-Regular`、`KleeOne-SemiBold` 兩個子集的 cmap 內 | 是（用 `ttf-parser`） |
| F02 | E | `pubspec.yaml` 引用的每個字型都有對應的 `assets/fonts/licenses/OFL-*.txt`（`KleeOne-*`→`OFL-KleeOne.txt`、`NotoSansTC-*`→`OFL-NotoSansTC.txt`、`NotoSerifTC-*`→`OFL-NotoSerifTC.txt`） | 否 |
| F03 | E | 所有中文內容、`lib` 用字（§5.3）與 ASCII 0x20–0x7E 都在 `NotoSansTC` 兩個字重的 cmap 內 | 否 |
| F04 | E | `lib` 用字與 ASCII 0x20–0x7E 都在 `NotoSerifTC` 的 cmap 內 | 否 |
| F05 | W | `assets/fonts/*.subset.ttf` 合計超過 12 MB | 否 |

**涵蓋率報告（C）**：C05、C06 一律是錯誤。C01–C03 平常只報告，加 `--strict` 時才以下表當前階段的門檻擋 CI。

| ID | 內容 | `p0a` | `p0` | `full` |
|---|---|---|---|---|
| C01 | N5 單字涵蓋率（分母 684 列，扣除 `coverage_skip.toml`） | 報告 | ≥ 85% | ≥ 95% |
| C02 | N4 單字涵蓋率（分母 640 列，扣除同上） | 報告 | 報告 | ≥ 85% |
| C03 | N5／N4 文法涵蓋率（`grammar_checklist.toml`） | 報告 | N5 ≥ 95% | N5 100%，N4 ≥ 85% |
| C04 | 字幕前 500 詞未收錄清單 | 報告 | 報告 | 報告 |
| C05 | 假名完整性：平假名 104（46＋25＋33）、片假名 125（104＋擴充 21）、`kind: mark` 符號 9 | 100%（E） | 100%（E） | 100%（E） |
| C06 | `jlpt` 欄位與基準清單不符 | E | E | E |

C01 實測輸出格式：`N5 coverage 10/684 missing-sample ["会う/あう", ...]`。門檻是建議值，等內容到位後依實際結果調整。

C06 的比對：清單每列的 JMdict ID 只在工具記憶體內使用，用來展開該詞條所有成立的 `(漢字形, 假名)`（遵守 §2.2-1）。`(surface, kana 去空白)` 命中 N5 列標 `n5`，只命中 N4 列標 `n4`，兩者都命中以 `n5` 為準，都沒命中標 `beyond`。純假名的 `surface` 比對詞條的任一假名。

**繁中欄位（Z）**，補充 R15：

| ID | 等級 | 檢查 | 實測 |
|---|---|---|---|
| Z01 | W | 中文欄位不得含非 Big5 字元，抓日文新字體混入（實測 学 気 円 図 駅 発 説 読 楽 国 皆不在 Big5）。`{ja:...}` 標記內除外 | 字元集已驗證 |
| Z02 | E | 中文欄位內的假名必須包在 `{ja:...}` 標記內；`zh`、`example_words[].zh`、`literals[].zh`、`examples[].zh` 不走 MixedText，不得含假名，也不開放標記 | 是 |

標記語法由 `curriculum.md` §12.2 定義，`MixedText` 只依標記切分，不做自動判定（R19）。Z02 與 R19 的假名檢查共用 `content::mixed`；Z02 留在 B 層是為了併入 `report.json` 與覆寫清單流程，是 §9.1「B 層只做 A 層做不到的事」的唯一例外。

**音調（A）、授權與離線防呆（L）、實機清單（T）**

| ID | 等級 | 檢查 | 實測 |
|---|---|---|---|
| A01 | W | 非空 `accent` 須與 UniDic 或 Kanjium 其中之一相符 | 資料已比對 |
| L01 | E | `rust/content/` 不得出現鍵 `jmdict`、`jmdict_id`、`seq`、`tatoeba_id`、`source` | 否 |
| L02 | E | 打包進 App 的第三方素材都登錄在 `THIRD_PARTY_NOTICES.md`（§10） | 否 |
| L03 | E | `jp_core` 依賴樹（含所有目標平台）不含 HTTP／TLS client、`wana_kana`、`content_tool`（§9.12） | 是 |
| L04 | E | `.verify-cache/`、`build/verify/`、`build/fonts/` 已列入 `.gitignore` | 否 |
| L05 | E | release 會合併的 AndroidManifest 沒有宣告 `INTERNET`（§9.12） | 是 |
| L06 | E | Dart release 相依不含網路套件（§9.12） | 是 |
| L07 | E | release APK 沒有 `INTERNET`（§9.12，需 Android SDK） | 否 |
| L08 | E | App 原始碼不使用 `dart:io` 網路類別與 `std::net`（§9.12） | 是 |
| T01 | E | `docs/TTS_DEVICE_CHECKLIST.md` 的項目與送出文字和當前內容一致（§9.13）；空白結果不算失敗。**未實作**，`verify` 目前不跑 | 否 |
| T02 | W | 清單標 `bad` 的項目，內容尚未回寫 `listen_disabled`。**未實作**，`verify` 目前不跑 | 否 |

`content_tool verify` 目前實作 29 條規則：J01、J01b、J02、J03、J03b、J04–J10、F01–F05、C01–C06、Z01、Z02、A01、L01、L02、L04。L03、L05–L08 由 `tools/verify/check_offline.py` 檢查（§9.12），T01、T02 尚未實作。

### 9.3 需求項目對照

| 要求的檢查 | 規則 | 層 |
|---|---|---|
| 漢字＋假名存在於 JMdict | J01、J03、J10 | B |
| 假名合法性 | J04 | B |
| 已學範圍、切片日有例句 | R04、R06、R11、R12、R18 | A |
| ID 唯一 | R01 | A |
| 交叉引用 | R03 | A |
| `lesson_order` 連號、禁用 `seq` | R20、L01 | A／B |
| 假名課結構 | R24 | A |
| 混合文字標記 `{ja:…}` | R19、Z02 | A／B |
| 同形異義標記 | R25 | A |
| JLPT 涵蓋率與級別 | C01、C02、C03、C06 | B |
| 繁中字形混入 | J02、Z01、R15 | B／A |
| 詞性正確 | J05 | B |
| 字型涵蓋與授權檔 | F01–F05 | B |
| 版權與資料滲入 | L01、L02 | B |
| 離線保證 | L03、L05–L08 | O |
| TTS 誤讀與實機清單 | R16、T01、T02（T01、T02 未實作，清單手動同步） | A／B |

### 9.4 工具形態

| 工具 | 語言 | 位置 | 職責 |
|---|---|---|---|
| `content_tool` | Rust | `rust/tools/content_tool/`，workspace 成員 | B 層規則（`verify`、`coverage`）、`available`、`lint`、`stats`、`charset`；規劃中的 `tts-checklist` 未實作 |
| `fetch_data.sh` | bash | `tools/verify/` | 下載資料並校驗雜湊，是唯一碰網路的步驟 |
| `check_offline.py`、`make_zh_simplified.py` | Python 3，僅標準函式庫 | `tools/verify/` | O 層檢查（§9.12）、產生 R15 字表 |
| `make_charset.py` | Python 3，僅標準函式庫 | `tools/fonts/` | 產生字元集（§5.3） |

`rust/Cargo.toml` 同時是 workspace 根與 `jp_core` package，workspace 成員是 `rust/crates/` 下的六個領域 crate 與 `tools/content_tool`（`rust-core.md` §1.2、§1.3）。**依賴方向是工具→App 的內容與語言 crate**：工具依賴 `jp_lang` 與開啟 `tooling` feature 的 `jp_content`，重用內容型別、`t` 解析器、羅馬字模組；App 不依賴工具，也不開 `tooling`，工具的依賴不會進入 App（L03 把關）。

```toml
# rust/tools/content_tool/Cargo.toml（節錄，版本都在 workspace 根定義）
[package]
name = "content_tool"
version.workspace = true
edition.workspace = true
publish.workspace = true

[dependencies]
jp_lang.workspace = true
jp_content = { workspace = true, features = ["tooling"] }
clap.workspace = true
chrono.workspace = true
encoding_rs.workspace = true
serde.workspace = true
serde_json.workspace = true
sha2.workspace = true
toml.workspace = true
ttf-parser.workspace = true
wana_kana.workspace = true
```

工具從 repo 根目錄執行，從磁碟讀 `rust/content/**`，以 `jp_content::load_content(files, stage)` 載入後逐條檢查。階段取 `--stage`，否則取環境變數 `CONTENT_STAGE`，預設 `p0`（`jp_content::disk::DEFAULT_STAGE`，與 `jp_content/build.rs` 的預設由單元測試保持一致），無效值 exit 2；與 `jp_core` 建置時的 `CONTENT_STAGE_NAME` 常數無關，所以換階段不用重新編譯工具。

```text
rust/tools/content_tool/src/
  main.rs            指令解析（available、lint、stats、verify、coverage、charset）
  commands.rs        各子指令的實作
  scope.rs           規則的輸入：階段過濾後的原始內容與全部 t
  verify.rs          B 層流程、覆寫清單（§9.6）
  data/jmdict.rs     載入與索引（§2.2）
  data/kanjidic.rs   常用漢字集合
  data/lists.rs      JLPT 清單、字幕詞頻、Kanjium 音調、JmdictFurigana
  rules/{jmdict,kana,zh,font,license,jlpt,accent}.rs   每條規則一個函式
  charset.rs         輸出 build/verify/chars_*.txt
  available.rs       撰寫用的可用項目清單
  report.rs          終端、JSON、Markdown 輸出
```

規劃中的 `checklist.rs`（產生與合併 `docs/TTS_DEVICE_CHECKLIST.md`）與 `rules/tts.rs`（T01、T02）還沒實作。

每條規則的簽章相同，便於單獨測試（`rules/mod.rs` 的 `RULES` 表登錄規則 ID、需要的外部資料與函式）：

```rust
pub struct Finding { pub rule: &'static str, pub level: Level, pub item: String, pub token: String, pub message: String }
pub type RuleFn = fn(&Input) -> Vec<Finding>;   // Input = 範圍（Scope）＋外部資料（Data）＋環境（Env）
```

指令（`$CT` 的定義見 §5.3）：

```bash
tools/verify/fetch_data.sh        # 依鎖定檔下載並校驗雜湊
$CT verify                        # 全部 B 層規則，範圍依 CONTENT_STAGE
$CT verify --only J01,J05
$CT verify --stage p0             # 覆寫環境變數
$CT verify --strict               # 警告也算失敗，且啟用當前階段的 C 門檻
$CT verify --content-root rust/crates/jp_content/tests/fixtures/full --stage full --only J04,Z01,Z02,F01,F03
$CT coverage                      # 只產生涵蓋率報告
$CT available le.l05              # 列出到該課為止可用的項目
$CT charset --stage full          # 輸出字元集素材（§5.3）；full 內容還不存在，目前會失敗，先用預設 p0
$CT tts-checklist                 # 規劃：產生或更新 docs/TTS_DEVICE_CHECKLIST.md（§9.13），尚未實作
```

`available` 輸出 TSV，欄位為 `id`、`surface`、`kana`、`lesson`，依 `pos(lesson)`、`lesson_order` 排序，涵蓋 `ka.*`、`vo.*`、`gr.*`。

結束代碼：`0` 通過、`1` 有內容錯誤（含 `load_content` 失敗）、`2` 環境問題（資料缺失、雜湊不符或階段無效）。區分 1 與 2，CI 才知道是內容壞了還是環境壞了。

下載用獨立的 shell 腳本，不寫進 Rust 工具，讓工具本身完全不需網路能力。

實作備註：

- 外部資料放在 `.verify-cache/`，檔名固定為 `jmdict-eng.json`、`kanjidic2-en.json`、`JmdictFurigana.json`、`jlpt_n5.csv`、`jlpt_n4.csv`、`frequency-subtitles.json`、`accents.txt`，由 `fetch_data.sh` 依鎖定檔的 `output` 建立，原始下載檔保留在 `.verify-cache/downloads/`。資料缺失時 `verify` exit 2，並列出缺檔與取得方式。
- 全域選項 `--repo-root`（預設 `.`，報告、`pubspec.yaml`、`.gitignore`、字型路徑的基準）；`verify` 另有 `--cache-dir`、`--font-dir`。
- F01／F03／F04 只檢查實際存在的字型檔，缺檔時回一筆警告（訊息含「未執行」），`--strict` 下視同失敗；字型打包後自動生效。
- L01 只看 JSON 鍵，在 `load_content` 前執行，否則 `deny_unknown_fields` 會先拒絕載入。
- `rust/content/lint/coverage_skip.toml` 格式：`[[skip]]` 內填 `surface`、`kana`、`reason`。`tools/verify/grammar_checklist.toml` 由 §5 的 `gr.*` 機械產生（S1／S2 計 n5，S3 計 n4），`p0` 門檻啟用前需人工校對分界。

### 9.5 資料鎖定檔

`tools/verify/data.lock.toml`。以下為本次實測的真實值：

```toml
[jmdict]
version = "3.6.2+20261102210542"
url = "https://github.com/scriptin/jmdict-simplified/releases/download/3.6.2%2B20261102210542/jmdict-eng-3.6.2+20261102210542.json.tgz"
sha256 = "bc1c5240dbdb755a00db488dc74ebfc6c33ffc014d261d64b605fd45cc1dbbb5"
license = "CC-BY-SA-4.0 (EDRDG)"
fetched = "2026-11-09"

[kanjidic2]
version = "3.6.2+20261102210542"
url = "https://github.com/scriptin/jmdict-simplified/releases/download/3.6.2%2B20261102210542/kanjidic2-en-3.6.2%2B20261102210542.json.tgz"
sha256 = "6ee47e719401bee69fe6b853344383031b3644cef477a8c784bc4d49e7b9a082"
license = "CC-BY-SA-4.0"

[jlpt_n5]
url = "https://raw.githubusercontent.com/stephenmk/yomitan-jlpt-vocab/b062d4e38c4bdd0950ae1d4ec55f04b176182e03/original_data/n5.csv"
sha256 = "07dc6f197b51cc076c65c3c9f23218d10c2b67f76545f5c1c4d9e3750495533a"
license = "CC-BY-SA-4.0"

[jlpt_n4]
url = "https://raw.githubusercontent.com/stephenmk/yomitan-jlpt-vocab/b062d4e38c4bdd0950ae1d4ec55f04b176182e03/original_data/n4.csv"
sha256 = "a14dcc7fdc02259b22331a486c6ff66df74c16472c8aeb5a0ebe7e5fa8ee8eb4"
license = "CC-BY-SA-4.0"
```

JmdictFurigana（`2.3.1+2026-10-25`）、Kanjium（commit `9ebca45`）、字幕詞頻（jkindrix commit `04014e0`）依相同格式加入。`fetched` 超過 90 天時發出警告。下載前請確認 raw URL 的 commit 仍存在。

### 9.6 覆寫清單

機器誤報時不要改規則，登錄到 `rust/content/lint/verify_allow.toml`，理由必填：

```toml
[[allow]]
rule = "J02"
item = "ka.sg.accent_ame"
reason = "飴 為常用漢字外的標準日文用字；curriculum.md 指定 ka.sg.accent_ame 為 雨／飴"
```

可加 `token` 只放行單一違規字串；省略時放行該項目在此規則下的全部 Finding。`item = "lib"` 時 `token` 必填，不可整個 `lib` 放行。

條目失效（該項目已不再觸發該規則）時工具回報錯誤，避免清單腐化。只檢查本次有執行的規則，且 `item` 存在於本次載入範圍的條目；`p0` 才出現的項目在 `p0a` 不算失效。

### 9.7 報告

輸出到 `build/verify/`（gitignore）：

- `report.json`：機器讀取，含每條 Finding。
- `coverage.md`：人類閱讀。含缺字清單。**因為含 JLPT 清單內容，不得公開**，CI 僅以私有 artifact 保存。
- `chars_ja.txt`、`chars_zh.txt`：字元集素材（§5.3）。

錯誤訊息比照 `curriculum.md` §13 要求，列出項目 ID、違規內容，並附修正方向。

### 9.8 CI

目前專案不是 git repo，也還沒有任何 workflow 檔。建立 repo 後，內容與離線檢查分兩個 job；階段門檻在該階段內容就緒後換 `CONTENT_STAGE`。`p0` 內容已就緒（2026-11-10 `content_tool --stage p0` 的 lint、verify 都是 0 錯誤，`content_lint` 測試通過），也是建置預設，所以下例用 `p0`；`full` 就緒後再換：

```yaml
# .github/workflows/content.yml
on:
  push: { paths: ["rust/**", "tools/**", "assets/fonts/**", "lib/**", "android/**", "pubspec.*", "docs/TTS_DEVICE_CHECKLIST.md"] }
  pull_request: { paths: ["rust/**", "tools/**", "assets/fonts/**", "lib/**", "android/**", "pubspec.*", "docs/TTS_DEVICE_CHECKLIST.md"] }
env: { CONTENT_STAGE: p0 }
jobs:
  content:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: rustup default 1.99.1
      - uses: actions/cache@v4
        with:
          path: .verify-cache
          key: verify-${{ hashFiles('tools/verify/data.lock.toml') }}
      - run: tools/verify/fetch_data.sh
      - run: cargo test --manifest-path rust/Cargo.toml -p jp_content --test content_lint
      - run: cargo run --release --manifest-path rust/Cargo.toml -p content_tool -- verify
      - run: cargo run --release --manifest-path rust/Cargo.toml -p content_tool -- verify --content-root rust/crates/jp_content/tests/fixtures/full --stage full --only J04,Z01,Z02,F01,F03
  offline:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: rustup default 1.99.1
      - uses: subosito/flutter-action@v2
        with: { flutter-version: 3.47.9, channel: stable }
      - run: flutter pub get
      - run: flutter build apk --release
      - run: python3 tools/verify/check_offline.py --apk build/app/outputs/flutter-apk/app-release.apk --require-apk
```

若 repo 為公開，`coverage.md` 不上傳為 artifact（公開 repo 的 artifact 視同散布）。Action 版本請於建立時固定到當時的版本。

### 9.9 工具本身的測試

規則測試在 `rust/tools/content_tool/tests/verify_rules.rs`：以完整夾具 `rust/crates/jp_content/tests/fixtures/full/` 加字串替換造出好、壞兩種內容，配上 `tests/common/mod.rs` 在記憶體建的小型假 JMdict，不依賴真實資料，先寫測試再實作（原本規劃的每條規則一組 `tests/fixtures/<rule>/` 沒有採用）。本次 §2.3 的案例可直接作為第一批測試。另加一個 `#[ignore]` 的整合測試跑真實 JMdict，在 CI 的 verify 步驟之後執行。筆記的 App 行為由 `rust/crates/jp_content/tests/fixtures/full/` 另外驗證（§9.11），兩組夾具用途不同。

### 9.10 機器檢查不到的事

必須明講，避免全綠造成錯誤的安心感：

- **語意**：`箸／はし` 與 `橋／はし` 配對都成立，釋義寫反抓不到。`zh` 欄位完全無法機器驗證。
- **自然度**：語法正確但沒人這樣講的句子。
- **原創性**：沒有機械檢查（原本只比對拒絕清單的 R14 已移除，RULINGS O13），例句是不是既有的歌詞或台詞只能靠人工抽查。
- **已學範圍的前提**：R04 只能相信 `t` 裡標的 ref。標錯 ref 就檢查不到。
- **TTS 實際讀音**：只能實機確認，流程見 §9.13。

因此 `curriculum.md` §14 的人工抽查不可省略，並隨階段進行：`p0a` 由日語母語者看過 L01–L07 的 266 句主線例句與 7 篇對話；`p0` 看過全部 S1 句子。內容先在 `p0a` 端到端跑通，再量產。

### 9.11 階段與 `p0a` 流程

`CONTENT_STAGE` 只決定範圍，規則本身不因階段放寬。`p0a` 是第一個必須端到端跑通的版本，流程從這裡開始：

```bash
export CONTENT_STAGE=p0a
tools/verify/fetch_data.sh
cargo test --manifest-path rust/Cargo.toml -p jp_content --test content_lint   # A 層，R17 比對 curriculum §14 的 p0a 欄
$CT verify                                                       # B 層 29 條規則（T01、T02 未實作，見 §9.2）
$CT verify --content-root rust/crates/jp_content/tests/fixtures/full --stage full --only J04,Z01,Z02,F01,F03
python3 tools/verify/check_offline.py                            # O 層
```

| 項目 | `p0a` 的處理 |
|---|---|
| 檢查範圍 | 所有規則只看 `load_content(files, stage)` 留下的內容：全部假名與規則卡、L01–L07、`ms.hira`、`ms.kata`、`ms.survive`、全部計畫預設 |
| 涵蓋率 | C01–C04 只報告，不設門檻；C05、C06 照常是錯誤 |
| 字型 | F01–F05 照常；字元集原本規劃固定取 `--stage full`（§5.3），後續階段不用重新選字型。`full` 內容還不存在，目前取到的最大範圍是 `p0` |
| TTS 實機清單 | T01、T02 未實作；`docs/TTS_DEVICE_CHECKLIST.md` 手動同步，2026-11-10 已補上 `p0` 的 H 區（§9.13；I–K 區已隨專區移除） |
| 筆記 | `p0a` 的正式內容沒有筆記，UI 與 API 用夾具驗證（`rust/crates/jp_content/tests/fixtures/full/`，見下方「夾具路徑」）。夾具的目錄結構與 `rust/content/` 相同，能通過 `load_content`，也要過上面那行 `verify`，因為 golden 測試會實際渲染這些字；夾具允許假例句，所以不跑 J01、J05 |
| 新階段 | 內容就緒後換 `CONTENT_STAGE`，指令不變；`--strict` 用於發布前 |

`p0` 已照這個流程換過，也是目前的建置預設（`CONTENT_STAGE` 未設時即為 `p0`）。2026-11-11 實測（第三輪內容修正後）：`$CT --stage p0 lint` 0 錯誤、0 警告（R10 時間窗改為只算主線 L 課，`vo.miru` 因此不再警告；`vo.otearai` 由 L06 的代換演練重現；一〜万 13 張數字字卡登錄在 `rust/content/lint/r10_allow.txt`，每行有理由；原本 10 個整句 `{ja:S|K}` 多解已拆成逐詞標記，R19 多解為 0）；`$CT --stage p0 verify` 29 條規則 0 錯誤、0 警告、5 則報告，`--strict` 結束碼 0（第二輪的 18 個警告逐一查過 JMdict 或規格，登錄在 `rust/content/lint/verify_allow.toml`，每筆有 `token` 與 `reason`）；`--stage p0a` lint 0 錯誤、0 警告（第二輪多出的 18 個都是教在 L07、後面只剩 KK 課，現在最後一個主線課不報），verify `--strict` 結束碼 0；`cargo test -p jp_content --test content_lint` 66 個測試通過。筆記另由真實內容驗證（`rust-core.md` §11.2 的 `real_content_p0*.rs`、整合測試 J4）。2026-11-15 移除專區（RULINGS O13）後重跑：`--stage p0`、`--stage p0a` 的 lint 都是 0 錯誤、0 警告，`verify --strict` 都是 29 條規則 0 錯誤、0 警告、5 則報告，結束碼 0；`content_lint` 剩 61 個測試（只驗已移除規則的測試隨規則刪除），全部通過。

夾具路徑：Rust 測試經 `jp_content::test_support::load_full_fixture` 讀 `rust/crates/jp_content/tests/fixtures/full/`，上面那行與 §5.4、§9.8 都用這個路徑。F03 也掃 `lib/` 的介面用字，`暦`、`済`、`聴` 這三個圖示字經 `JaText` 以 Klee One 渲染、Noto Sans TC 上游沒有字形，所以夾具與 `rust/content/` 一樣在 `lint/verify_allow.toml` 登錄這三字的 `lib` 覆寫。2026-11-10 實測該行結束碼 0（5 條規則，0 錯誤、0 警告），由 `rust/tools/content_tool/tests/verify_cli.rs` 的 `documented_fixture_verify_passes_with_the_bundled_fonts_and_lib` 以打包字型與真正的 `lib/` 固定。

### 9.12 離線保證（RULINGS O8）

App 不連網：release 建置不得有 `INTERNET` 權限，相依樹不得有 HTTP／TLS client。`tools/verify/check_offline.py` 是單一入口，本機與 CI 跑同一支。

| 規則 | 檢查方式 | 需要 |
|---|---|---|
| L03 | `cargo tree -p jp_core -e normal,build --prefix none --no-dedupe --target all` 的 crate 名稱不在黑名單 | cargo |
| L05 | `android/app/src/{main,release}/AndroidManifest.xml` 與 release 相依外掛的 `android/src/main/AndroidManifest.xml` 沒有 `INTERNET`；用 XML 解析，註解不算。`src/debug`、`src/profile` 的 `INTERNET` 是熱重載需要，不檢查 | `flutter pub get` |
| L06 | `flutter pub deps --no-dev --style=compact` 的套件不在黑名單 | flutter |
| L07 | `aapt dump permissions` 檢查 release APK | Android SDK |
| L08 | `lib/**/*.dart`、`rust/src/**/*.rs` 不用網路類別。相依掃描看不到標準函式庫，iOS 又沒有權限開關 | 無 |

兩個容易寫錯的地方（皆實測，2026-11-09，相依取 `rust-core.md` §1.2 與 `flutter-app.md` §1）：

- `cargo tree` 不加 `--target all` 只看建置機平台：Linux 上 80 個 crate，加上後 118 個，Android、iOS 專屬相依才看得到。兩者都 0 命中。`tokio` 由 FRB 帶入，只作 async runtime，不在黑名單，且未解析出 `mio`、`socket2`。
- 不能直接掃 `pubspec.lock`：它含 `shelf`、`http_multi_server`、`web_socket`、`web_socket_channel`，全部來自 `build_runner` 等 dev 相依。`--no-dev` 的結果 0 命中。

```python
#!/usr/bin/env python3
"""O8 離線保證（reuse-and-verification.md §9.12）。只用標準函式庫。exit：0 通過、1 違規、2 環境問題。"""
import argparse, glob, json, os, pathlib, re, shutil, subprocess, sys
from urllib.parse import urlparse
from xml.etree import ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
PERM, NAME = "android.permission.INTERNET", "{http://schemas.android.com/apk/res/android}name"
RUST_DENY = set("""reqwest ureq hyper hyper-util hyper-rustls hyper-tls h2 rustls native-tls openssl openssl-sys curl curl-sys
  isahc surf attohttpc tungstenite tokio-tungstenite tokio-rustls tokio-native-tls quinn wana_kana content_tool""".split())
DART_DENY = set("""http http2 dio web_socket web_socket_channel grpc shelf http_multi_server socket_io_client cronet_http
  cupertino_http rhttp chopper retrofit graphql connectivity_plus google_fonts cached_network_image
  flutter_cache_manager webview_flutter""".split())
SOURCES = [("lib/**/*.dart", r"\b(HttpClient|WebSocket|RawSocket|SecureSocket|Socket\.connect)\b"),
           ("rust/src/**/*.rs", r"\b(std::net|TcpStream|UdpSocket)\b")]

def run(cmd, cwd=ROOT):
    try:
        return subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, text=True).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        sys.exit(print(f"[環境] {' '.join(cmd)}: {getattr(e, 'stderr', e)}", file=sys.stderr) or 2)

def has_internet(path):
    return any(e.get(NAME) == PERM for e in ET.parse(path).iter() if e.tag.startswith("uses-permission"))

def plugin_manifests(pkgs):
    for p in json.loads((ROOT / ".dart_tool/package_config.json").read_text())["packages"]:
        if p["name"] in pkgs:
            uri = p["rootUri"]
            root = pathlib.Path(urlparse(uri).path) if uri.startswith("file:") else (ROOT / ".dart_tool" / uri).resolve()
            yield root / "android/src/main/AndroidManifest.xml"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apk")
    ap.add_argument("--require-apk", action="store_true")
    args, errors = ap.parse_args(), []
    tree = run(["cargo", "tree", "-p", "jp_core", "-e", "normal,build", "--prefix", "none", "--no-dedupe", "--target", "all"], ROOT / "rust")
    errors += [f"L03 Rust 相依含 {n}" for n in sorted({l.split()[0] for l in tree.splitlines() if l.strip()} & RUST_DENY)]
    pkgs = set(re.findall(r"^- (\S+)", run(["flutter", "pub", "deps", "--no-dev", "--style=compact"]), re.M))
    errors += [f"L06 Dart release 相依含 {p}" for p in sorted(pkgs) if p in DART_DENY or p.startswith("firebase_")]
    app = [ROOT / f"android/app/src/{v}/AndroidManifest.xml" for v in ("main", "release")]
    errors += [f"L05 {m} 宣告 INTERNET" for m in [*app, *plugin_manifests(pkgs)] if m.exists() and has_internet(m)]
    for pattern, rx in SOURCES:
        for f in ROOT.glob(pattern):
            if m := re.search(rx, f.read_text(encoding="utf-8")):
                errors.append(f"L08 {f.relative_to(ROOT)} 使用 {m.group(1)}")
    aapt = shutil.which("aapt") or max(glob.glob(os.path.expandvars("$ANDROID_HOME/build-tools/*/aapt")), default=None)
    if aapt and args.apk and pathlib.Path(args.apk).exists():
        errors += [f"L07 {args.apk} 含 INTERNET"] if PERM in run([aapt, "dump", "permissions", args.apk]) else []
    elif args.require_apk:
        sys.exit(print("[環境] 找不到 aapt 或 APK", file=sys.stderr) or 2)
    else:
        print("SKIP L07：沒有 aapt 或 APK，只完成靜態檢查")
    print("\n".join(errors) or "離線檢查通過")
    sys.exit(1 if errors else 0)

main()
```

實測：目前的 repo 與規劃相依 exit 0；main manifest 加 `INTERNET` 回報 L05，只在 XML 註解提到則通過；`jp_core` 加 `reqwest` 命中 9 個 crate；`pubspec.yaml` 加 `http` 命中 L06；`lib/` 出現 `HttpClient` 命中 L08；`flutter_tts` 的 manifest 沒有權限宣告。本環境沒有 Android SDK，L07 尚未實跑；沒有 `aapt` 時印 SKIP，CI 加 `--require-apk` 讓略過變成 exit 2。

iOS 沒有對應的權限宣告，靠 L03、L06、L08 把關。

### 9.13 TTS 實機清單（`docs/TTS_DEVICE_CHECKLIST.md`）

本環境沒有 Android SDK、iOS 工具鏈與音效輸出，實機驗證不是開發前置條件。內容先用保守預設（`curriculum.md` §10.1），清單由 `$CT tts-checklist` 依當前 `CONTENT_STAGE` 產生並 commit，專案擁有者有裝置時再填結果，CI 不要求結果已填。現況：`tts-checklist` 與 T01、T02 都還沒實作，清單是手動維護的；2026-11-10 依 `p0` 內容補上 L08 以後例句的代表性項目，ID 與送出文字以腳本比對過 `rust/content/`；當時一併補上的日劇與歌曲專區、短劇項目已隨專區移除（RULINGS O13）。

檔案開頭記錄測試裝置與語音引擎（至少 Pixel、一款三星、iPhone 各一），之後每列一項：

```markdown
| ID | 送出文字 | Android | iOS | 備註 |
| ka.hira.n | ん | ok | bad | iOS 念成 N |
```

| 區段 | 列出內容 | 結果不佳時回寫 |
|---|---|---|
| A 單音（必測） | `ka.hira.n`、`ka.kata.n` 排最前，接著其餘 `kind` 不為 `mark` 的假名（229 字）；送出 `tts_text`，省略時 `char` | 先換 `tts_text`；仍不佳設 `listen_disabled: true`，不出 `kana_listen`，改出 `kana_read` |
| B 不測項 | `kind: mark` 的 9 項（っ ゃ ゅ ょ ッ ー ャ ュ ョ），`listen_disabled: true`，只列出，無結果欄 | 維持 |
| C 音調配對（必測） | `kind: accent` 的 4 組 `ka.sg.*`（雨／飴、箸／橋／端、花／鼻、神／紙）的全部配對 | 聽不出差別的配對設 `listen_disabled: true` |
| D 其他配對（抽聽） | 其餘 12 組 `ka.sg.*` 每組第一對、`minimal_pair` 每課一題 | 同 C。`minimal_pair` 設在該題（該題不再出現），`ka.sg.*` 設在該配對（S2 不再播放）；同一組詞兩處都有時兩處都設 |
| E 音調單字 | 階段內 `tts: auto` 的單字（完整版約 40 筆） | 改 `tts: kana` |
| F `tts_risky` 抽聽 | `tts_risky.txt` 全部詞，加上尚未收錄的 何、人 各 3 個短句 | 確定誤讀者加入 `tts_risky.txt`，受影響的 `t` 標 `tts: kana`（R16 會列出） |
| G 空白處理 | 3 個 `kana` 模式句子，帶空白與去空白各送一次 | 只改 `content/sentence.rs` 的 `speech_kana`，這是唯一需要動程式的項目（`rust-core.md` §3.3） |

重新產生時，依 ID 保留結果欄；送出文字變了的列清空結果，因為要重測。回寫都在內容 JSON 或 `tts_risky.txt`，A–F 不需改程式。

---

## 10. 授權落地清單

建立 `THIRD_PARTY_NOTICES.md`，內容同步呈現在 App 的「關於→授權」獨立頁面（`showLicensePage`）。

**必須（已打包）**

| 素材 | 動作 |
|---|---|
| Klee One 子集 | 附 OFL 全文，著作權 "Copyright 2020 The Klee Project Authors"，註明已子集化，註冊到 LicenseRegistry |
| Noto Sans TC 子集 | 附 OFL 全文，著作權照上游 OFL.txt（§5.5），註明已子集化，註冊到 LicenseRegistry |
| Noto Serif TC 子集 | 同上 |
| `jlpt` 欄位（依 Waller 清單） | 標示 Jonathan Waller，CC BY，文字見 §3.3-5 |
| Rust 依賴 | Flutter 授權頁**只收 Dart 套件，不含 Rust crate**。用 `tools/licenses/make_rust_crates.py` 產生 `assets/licenses/rust_crates.txt`（名稱、版本、SPDX，`--check` 比對是否過期），App 的授權頁顯示；用 `cargo deny check licenses` 在 CI 阻擋不相容授權 |
| Dart 套件 | Flutter 自動處理 |

**依採用情況**

| 條件 | 動作 |
|---|---|
| `accent` 取自 UniDic | 附 BSD 授權文字與 "Copyright (c) 2011-2013, The UniDic Consortium" |
| 採用 KanjiVG 假名筆順（P1） | 標示作者與連結，SVG 維持 CC BY-SA 3.0 |
| 採用 VOICEVOX 音檔（P1） | 依各角色條款標示 |

**主動標示（無義務）**：JMdict 校對聲明，文字見 §2.4。

**撰寫規則**（放進內容撰寫指引）：

1. `zh`、`explain_zh` 等說明文字必須自己寫，不得翻譯 JMdict、Tae Kim（CC BY-NC-SA，不相容）、Bunpro、JLPT Sensei 或任何教科書的內容。
2. 不得從小型開源學習 App 複製內容資料。
3. 歌詞與日劇台詞的限制依決策 6（R14 已移除，RULINGS O13）。

---

## 11. 與其他文件的介面

| 項目 | 定案 | 權威位置 |
|---|---|---|
| 羅馬字輸入 | `t` 用解析後的語素，單字依 `reading_mode_of` 分流 | `rust-core.md` §4；本文 §7.2 |
| 中文欄位裡的日文 | `{ja:日文}` 或 `{ja:日文\|讀音}`，純假名也要包 | `curriculum.md` §12.2；R19、Z02 |
| 字幕與口語的選字 | 選字參考 C04 | §3.4 |
| `content_tool` 位置 | `rust/tools/content_tool/`，`rust/Cargo.toml` 設 workspace | 本文 §9.4；`rust-core.md` §1.2 |
| 字型 | 打包 Klee One、Noto Sans TC、Noto Serif TC | 本文 §5；`flutter-app.md` §4.3 |
| 假名合法性與波浪號 | 比照 `rust-core.md` §4.2；內容一律 U+301C | J04；`curriculum.md` §12.2 |
| 離線保證 | `check_offline.py`，`rust-core.md` §1.4、§11.5 與 `flutter-app.md` §1 引用它 | 本文 §9.12 |
| TTS 實機檢查 | 保守預設＋清單回寫 | `curriculum.md` §10.1；本文 §9.13 |

---

## 12. 來源

- JMdict 授權：<https://www.edrdg.org/edrdg/licence.html>
- jmdict-simplified：<https://github.com/scriptin/jmdict-simplified>
- JmdictFurigana：<https://github.com/Doublevil/JmdictFurigana>
- JLPT FAQ：<https://www.jlpt.jp/e/faq/index.html>
- Waller（無法連線）：<http://www.tanos.co.uk/jlpt/>
- 共通語彙リスト：<https://www.jstage.jst.go.jp/article/jlem/25/2/25_130/_article/-char/ja>
- Tatoeba：<https://tatoeba.org/en/downloads>、<https://tatoeba.org/en/terms_of_use>
- FrequencyWords：<https://github.com/hermitdave/FrequencyWords>
- OFL FAQ：<https://openfontlicense.org/ofl-faq/>
- Google Fonts 字型檔：<https://github.com/google/fonts>
- LXGW WenKai TC：<https://github.com/lxgw/LxgwWenkaiTC>
- Kanjium：<https://github.com/mifunetoshiro/kanjium>
- unidic-lite：<https://github.com/polm/unidic-lite>
- tdmelodic：<https://github.com/PKSHATechnology-Research/tdmelodic>
- wana_kana：<https://github.com/PSeitz/wana_kana_rust>
- KanjiVG：<https://github.com/KanjiVG/kanjivg>
- AnimCJK：<https://github.com/parsimonhi/animCJK>
- VOICEVOX 條款：<https://voicevox.hiroshiba.jp/term/>

# TTS 實機檢查清單

開發環境已用 Android SDK 完成三 ABI release APK 建置，但沒有 iOS 工具鏈、實機與音效輸出，App 的語音到現在都還沒有人耳聽過（`docs/design/RULINGS.md` O3）。內容先用保守預設，這份清單交給有實機的人照著聽，結果回寫到內容檔。除了標明「要改程式」的項目，都不需要動程式。

**狀態：尚未開始，所有結果欄都是空的。**

優先項目與 A–D、F、G 區最初在 `p0a` 時期整理，項目都在假名課與 L01–L03，2026-11-10 核對過 ID 與送出文字在預設的 `p0` 仍然相同；E 區已同步成 `p0`（6 筆 `tts: auto` 單字，都在 L08 以後）。H 區是 2026-11-10 依 `rust/content/` 的 `p0` 內容補上的代表性項目：L08 以後的主線例句。原本的 I、J、J2、K 區（日劇專區、歌曲專區、韻律型項目、短劇）已隨專區移除（`docs/design/RULINGS.md` O13）。表中每個 ID 都存在於 `rust/content/`，「送出文字」照 `jp_content::sentence::analyze_t` 的規則算出（`auto` 送畫面文字；`kana` 送分詞假名、獨立的 は／へ 換成 わ／え；含 `@name` 一律送假名）。`reuse-and-verification.md` §9.13 規劃的 `content_tool tts-checklist` 子指令與 T01、T02 檢查還沒實作，所以內容改動後，這裡的列要手動同步。

## 怎麼做

1. 從 CI artifact 取得 Android release APK 並裝上實機；APK 建置已驗證，但實機啟動尚未驗證。iOS 建置仍待有 macOS／iOS SDK 的環境驗證（見 `docs/TASKS.md`）。
2. 填好下面的裝置表。至少一台 Pixel、一台三星、一支 iPhone。
3. 先做「裝置流程」與「優先項目」。這兩段有問題的話，全表聽了也沒有意義。
4. 再依 A–H 逐項聽。結果欄填 `ok` 或 `bad`，`bad` 的請在備註寫實際聽到的音，例如「念成 N」。
5. 依「結果怎麼回寫」修改內容，重新建置後複聽 `bad` 的項目。

| 要聽的內容 | 在 App 哪裡 |
|---|---|
| 單假名（A、ん、ン、ゃ） | 學習 › 假名表，點格子就發音，不會因為還沒學而鎖定。小字在最下面的「符號」區 |
| 音調組（C）與其他語音示範組（D） | 聽說 › 語音示範，也可從假名表的「語音示範」進入 |
| 音調入門的例字 | 學習 › 課程列表的「音調入門與平假名畢業考」› 規則卡「音調入門：高低，不是四聲」 |
| `minimal_pair`（D） | 該假名課的練習；遇不到時用語音示範裡的同組配對比對 |
| 例句（優先項目、F、G、H） | 學習 › 單字，打開該字，例句旁有播放鈕。未學的字也能查。H 區標「文法」的在 學習 › 文法，文法點都可點開，不鎖定 |

## 測試裝置

| 裝置 | 系統版本 | 語音引擎與版本 | 日語語音名稱 | 測試日期 |
|---|---|---|---|---|
| Pixel | | | | |
| 三星 | | | | |
| iPhone | | | | |

## 平台差異

| 項目 | Android | iOS | Linux（開發用） |
|---|---|---|---|
| 引擎 | 系統 TTS，經 flutter_tts | `AVSpeechSynthesizer`，經 flutter_tts | `spd-say`，優先 openjtalk，其次 espeak-ng |
| 送出的文字 | `SpeechDto.text`：`tts: auto` 送漢字原文，`tts: kana` 送假名 | 同 Android | 一律送 `SpeechDto.kana` |
| 語音來源 | 需要已下載日語語音資料；需要連網的語音會被排除 | 系統的日文聲音 | 需安裝 speech-dispatcher 與日語模組 |
| 播放失敗時 | 有錯誤回呼 | 沒有錯誤回呼，靠 5 秒看門狗轉成失敗 | 靠耗時判斷，結束碼不可靠 |
| 語速（正常／慢） | 0.5／0.35 | 0.5／0.42 | `-r` 0／-50 |
| 對話第二角色 | 有第二個日語語音就換人，否則音高 1.15 倍 | 同 Android | 音高 `-p 15` |

**Linux 的結果不能算數。** 只能驗證流程與時序：

- 音調配對兩側的假名相同（雨、飴 都送 あめ），在 Linux 上必然聽起來一樣。
- 音調入門規則卡的例字不經假名轉換，送的是漢字。espeak-ng 會把漢字念成「Chinese letter」。
- 音質不代表手機上的結果。

## 裝置流程

| # | 項目 | 預期 | Pixel | 三星 | iPhone | 備註 |
|---|---|---|---|---|---|---|
| 1 | 新手引導的語音檢查 | 有日語語音時直接通過 | | | | |
| 2 | Android 未下載語音資料 | 顯示「手機還沒下載日語語音」，畫面上的設定路徑與實機相符。**路徑不符要改文案** | | | — | |
| 3 | 沒有語音引擎 | 顯示「手機沒有語音引擎」，步驟可行 | | | — | |
| 4 | iOS 找不到日語語音 | 顯示「找不到日語語音」，設定路徑與實機相符 | — | — | | |
| 5 | 引導中選「先用無聲模式」 | 可以繼續，今日與聽說頁有常駐說明，聽力題不出現 | | | | |
| 6 | 裝好語音後回到 App | 自動重新偵測，不必重開 | | | | |
| 7 | iPhone 靜音開關打開 | 按播放仍有聲音 | — | — | | |
| 8 | 背景有音樂時播放 | 音樂只是變小，播完恢復 | | | | |
| 9 | 飛航模式 | 語音照常播放，日語語音沒有偷偷走網路 | | | | |
| 10 | 連續快速點不同格子 | 只播最後一個，前一個立刻停，沒有疊音 | | | | |
| 11 | 慢速 | 慢速約正常的 1.4 倍時長（0.7 倍速）。**偏差太大要改程式** | | | | |
| 12 | 規則卡的拍感（促音、長音） | 格子亮起的節奏大致跟得上語音 | | | | |

## 優先項目

### 單假名：ん、ン、ゃ

`ん`、`ン` 目前以本字送出（O3），是最可能出問題的字。

| ID | 操作 | 預期 | Android | iOS | 備註 |
|---|---|---|---|---|---|
| ka.hira.n | 點 ん | 短促的鼻音。不是字母名（N、エヌ），不是無聲，也不是「うん」 | | | |
| ka.kata.n | 點 ン | 同上 | | | |
| ka.hira.small_ya | 點符號區的 ゃ | 不發音，詳情條顯示「單獨唸不準，看例字」 | | | |
| ka.hira.small_ya 例字 | 詳情條的 おちゃ | 「お・ちゃ」兩拍，不是「お・ち・や」 | | | |
| ka.hira.kya | 點拗音區的 きゃ | 一拍，不是「き・や」 | | | |

`ゃ` 不單獨成音，所以預設 `listen_disabled: true`。即使某台裝置念得出來也維持這個設定：符號不出題、不建卡，lint R24 也會對沒設定的符號發出警告。

### 改成假名送出的六個句子

這幾句有 何語 或數字，引擎容易念錯讀音，所以標了 `tts: kana`。要確認的是：讀音對，而且假名模式的停頓和音調還能聽。

| ID | 畫面文字 | 實際送出（假名） | Android | iOS | 備註 |
| --- | --- | --- | --- | --- | --- |
| se.l02.066 | その本は何語ですか。 | その ほん わ なにご です か。 |  |  |  |
| se.l02.067 | あの新聞は何語ですか。 | あの しんぶん わ なにご です か。 |  |  |  |
| se.l03.003 | 一、二、三。 | いち、 に、 さん。 |  |  |  |
| se.l03.004 | 四、五、六。 | よん、 ご、 ろく。 |  |  |  |
| se.l03.005 | 七、八、九、十。 | なな、 はち、 きゅう、 じゅう。 |  |  |  |
| se.l03.092 | この雑誌は何語ですか。 | この ざっし わ なにご です か。 |  |  |  |

- 預期讀音：何語＝なにご；四＝よん、七＝なな、九＝きゅう、十＝じゅう。
- `se.l03.003`、`.004`、`.005` 可從單字 一、四、七 的例句播放；`se.l02.066`、`.067` 在單字 何 的例句。
- `se.l03.092` 沒有掛在單字例句上，只會在聽力或演練出現。遇不到時比對 `se.l02.066`，句型相同。
- 假名模式念得不自然：把該句改成 `tts: auto` 重聽。`auto` 讀音又錯的話，維持 `kana`，在備註記下。

### 音調組

聽兩側是否分得出來，高低方向是否正確。**分不出來或方向錯，就設 `listen_disabled`**，不要讓學習者學到錯的音調。畫面上固定標示「由裝置合成，僅供參考」，但這不能當作保留錯誤示範的理由。

| ID#配對 | 送出文字 | 意思 | Android | iOS | 備註 |
| --- | --- | --- | --- | --- | --- |
| ka.sg.accent_ame#0 | 雨／飴 | 雨／糖果 |  |  |  |
| ka.sg.accent_hashi#0 | 箸／橋 | 筷子／橋 |  |  |  |
| ka.sg.accent_hashi#1 | 橋が／端が | 橋（後面接助詞）／邊緣（後面接助詞） |  |  |  |
| ka.sg.accent_hana#0 | 花が／鼻が | 花（後面接助詞）／鼻子（後面接助詞） |  |  |  |
| ka.sg.accent_kami#0 | 神／紙 | 神／紙 |  |  |  |

| 配對 | 該聽到的差別 |
|---|---|
| 雨／飴 | 雨 第一拍高；飴 第二拍起高 |
| 箸／橋 | 箸 第一拍高；橋 第二拍高 |
| 橋が／端が | 橋が 的 が 掉下來；端が 不掉 |
| 花が／鼻が | 花が 的 が 掉下來；鼻が 不掉 |
| 神／紙 | 神 第一拍高；紙 第二拍高 |

單獨念的 花／鼻 幾乎相同，內容上本來就只收接助詞的版本。

## 結果怎麼回寫

路徑都在 `rust/content/` 底下。內容在編譯時嵌入，改完要重新建置；不需要改程式。

| 聽到的問題 | 檔案與欄位 | 效果 |
|---|---|---|
| 單假名念錯 | `kana/hiragana.json`、`kana/katakana.json` 該字的 `tts_text`，例如 を 改送 お | 全平台改送新文字 |
| 換了 `tts_text` 仍不佳 | 同一筆加 `"listen_disabled": true` | 假名表不發音並顯示「單獨唸不準，看例字」；不再出聽音選字，改出看字選音 |
| 音調或語音示範的配對聽不出差別 | `kana/sound_groups.json` 該配對（`pairs[]` 內）加 `"listen_disabled": true` | 語音示範頁該對只顯示文字。不影響 `minimal_pair` |
| `minimal_pair` 聽不出差別 | `drills/k_minimal_pair.json` 該題加 `"listen_disabled": true` | 該題不再出現。同一組詞兩邊都有時，兩邊都要設 |
| 句子讀音錯 | `sentences/lNN.json` 該句的 `tts` 改 `"kana"` | 改送假名 |
| 假名模式不自然 | 同一欄改 `"auto"` | 改送漢字原文。含 `tts_risky.txt` 的詞時 lint R16 會擋下 |
| 單字讀音或音調錯 | `vocab/<主題>.json` 該字的 `tts` | E 區的字改 `"kana"` |
| 某個詞確定會誤讀 | `lint/tts_risky.txt` 加一行 | lint R16 會列出所有要改成 `kana` 的句子 |

例子：

```json
{"id": "ka.hira.wo", "char": "を", "tts_text": "お"}
{"id": "ka.hira.n", "char": "ん", "tts_text": "ん", "listen_disabled": true}
{"a": "雨", "a_zh": "雨", "b": "飴", "b_zh": "糖果", "a_kana": "あめ", "b_kana": "あめ", "listen_disabled": true}
```

（只列出相關欄位，其他欄位保持原樣。）

**已知缺口：**

- `ん`、`ン` 的 `tts_text` 目前換不了別的字。`verify` 的 J04 只放行與 `char` 相同的單字元，換成 `ン` 這類以 ん 開頭的文字會被判錯（實測）。ん 念不好時請直接設 `listen_disabled`；若想保留聲音，要先調整 J04。
- 音調入門規則卡的例字（`kana/rules.json` 的 `ka.rule.accent_intro.examples`，含 雨、飴、箸、橋）沒有 `listen_disabled` 欄位。語音示範頁關掉配對後，規則卡仍會播。要連這裡一起停用，請把那幾筆從 `examples` 移除；至少要留一筆，否則 lint RC10 會擋下。

改完後驗證：

```bash
cargo run -q --manifest-path rust/Cargo.toml -p content_tool -- --stage p0 lint
cargo run -q --manifest-path rust/Cargo.toml -p content_tool -- --stage p0 verify
cargo test --manifest-path rust/Cargo.toml --workspace
flutter test --no-pub
```

**要改程式的只有這幾項：**

| 項目 | 位置 |
|---|---|
| G 區：假名模式的空白處理 | `rust/crates/jp_content/src/sentence.rs` 的 `speech_kana` |
| 語速校準 | `lib/core/tts/flutter_tts_engine.dart` 的 `TtsRateProfile` |
| 語音設定的路徑文案 | `lib/core/tts/voice_help.dart` 的 `voiceHelpCopy`；同時更新 `docs/design/flutter-app-tts.md` §6.4 |

## 全表

### A 單音（必測，229 字）

`ん`、`ン` 排最前。結果不佳時先換 `tts_text`，仍不佳再設 `listen_disabled`。

| ID | 送出文字 | Android | iOS | 備註 |
| --- | --- | --- | --- | --- |
| ka.hira.n | ん |  |  |  |
| ka.kata.n | ン |  |  |  |
| ka.hira.a | あ |  |  |  |
| ka.hira.i | い |  |  |  |
| ka.hira.u | う |  |  |  |
| ka.hira.e | え |  |  |  |
| ka.hira.o | お |  |  |  |
| ka.hira.ka | か |  |  |  |
| ka.hira.ki | き |  |  |  |
| ka.hira.ku | く |  |  |  |
| ka.hira.ke | け |  |  |  |
| ka.hira.ko | こ |  |  |  |
| ka.hira.sa | さ |  |  |  |
| ka.hira.shi | し |  |  |  |
| ka.hira.su | す |  |  |  |
| ka.hira.se | せ |  |  |  |
| ka.hira.so | そ |  |  |  |
| ka.hira.ta | た |  |  |  |
| ka.hira.chi | ち |  |  |  |
| ka.hira.tsu | つ |  |  |  |
| ka.hira.te | て |  |  |  |
| ka.hira.to | と |  |  |  |
| ka.hira.na | な |  |  |  |
| ka.hira.ni | に |  |  |  |
| ka.hira.nu | ぬ |  |  |  |
| ka.hira.ne | ね |  |  |  |
| ka.hira.no | の |  |  |  |
| ka.hira.ha | は |  |  |  |
| ka.hira.hi | ひ |  |  |  |
| ka.hira.fu | ふ |  |  |  |
| ka.hira.he | へ |  |  |  |
| ka.hira.ho | ほ |  |  |  |
| ka.hira.ma | ま |  |  |  |
| ka.hira.mi | み |  |  |  |
| ka.hira.mu | む |  |  |  |
| ka.hira.me | め |  |  |  |
| ka.hira.mo | も |  |  |  |
| ka.hira.ya | や |  |  |  |
| ka.hira.yu | ゆ |  |  |  |
| ka.hira.yo | よ |  |  |  |
| ka.hira.ra | ら |  |  |  |
| ka.hira.ri | り |  |  |  |
| ka.hira.ru | る |  |  |  |
| ka.hira.re | れ |  |  |  |
| ka.hira.ro | ろ |  |  |  |
| ka.hira.wa | わ |  |  |  |
| ka.hira.wo | を |  |  |  |
| ka.hira.ga | が |  |  |  |
| ka.hira.gi | ぎ |  |  |  |
| ka.hira.gu | ぐ |  |  |  |
| ka.hira.ge | げ |  |  |  |
| ka.hira.go | ご |  |  |  |
| ka.hira.za | ざ |  |  |  |
| ka.hira.ji | じ |  |  |  |
| ka.hira.zu | ず |  |  |  |
| ka.hira.ze | ぜ |  |  |  |
| ka.hira.zo | ぞ |  |  |  |
| ka.hira.da | だ |  |  |  |
| ka.hira.di | ぢ |  |  |  |
| ka.hira.du | づ |  |  |  |
| ka.hira.de | で |  |  |  |
| ka.hira.do | ど |  |  |  |
| ka.hira.ba | ば |  |  |  |
| ka.hira.bi | び |  |  |  |
| ka.hira.bu | ぶ |  |  |  |
| ka.hira.be | べ |  |  |  |
| ka.hira.bo | ぼ |  |  |  |
| ka.hira.pa | ぱ |  |  |  |
| ka.hira.pi | ぴ |  |  |  |
| ka.hira.pu | ぷ |  |  |  |
| ka.hira.pe | ぺ |  |  |  |
| ka.hira.po | ぽ |  |  |  |
| ka.hira.kya | きゃ |  |  |  |
| ka.hira.kyu | きゅ |  |  |  |
| ka.hira.kyo | きょ |  |  |  |
| ka.hira.sha | しゃ |  |  |  |
| ka.hira.shu | しゅ |  |  |  |
| ka.hira.sho | しょ |  |  |  |
| ka.hira.cha | ちゃ |  |  |  |
| ka.hira.chu | ちゅ |  |  |  |
| ka.hira.cho | ちょ |  |  |  |
| ka.hira.nya | にゃ |  |  |  |
| ka.hira.nyu | にゅ |  |  |  |
| ka.hira.nyo | にょ |  |  |  |
| ka.hira.hya | ひゃ |  |  |  |
| ka.hira.hyu | ひゅ |  |  |  |
| ka.hira.hyo | ひょ |  |  |  |
| ka.hira.mya | みゃ |  |  |  |
| ka.hira.myu | みゅ |  |  |  |
| ka.hira.myo | みょ |  |  |  |
| ka.hira.rya | りゃ |  |  |  |
| ka.hira.ryu | りゅ |  |  |  |
| ka.hira.ryo | りょ |  |  |  |
| ka.hira.gya | ぎゃ |  |  |  |
| ka.hira.gyu | ぎゅ |  |  |  |
| ka.hira.gyo | ぎょ |  |  |  |
| ka.hira.ja | じゃ |  |  |  |
| ka.hira.ju | じゅ |  |  |  |
| ka.hira.jo | じょ |  |  |  |
| ka.hira.bya | びゃ |  |  |  |
| ka.hira.byu | びゅ |  |  |  |
| ka.hira.byo | びょ |  |  |  |
| ka.hira.pya | ぴゃ |  |  |  |
| ka.hira.pyu | ぴゅ |  |  |  |
| ka.hira.pyo | ぴょ |  |  |  |
| ka.kata.a | ア |  |  |  |
| ka.kata.i | イ |  |  |  |
| ka.kata.u | ウ |  |  |  |
| ka.kata.e | エ |  |  |  |
| ka.kata.o | オ |  |  |  |
| ka.kata.ka | カ |  |  |  |
| ka.kata.ki | キ |  |  |  |
| ka.kata.ku | ク |  |  |  |
| ka.kata.ke | ケ |  |  |  |
| ka.kata.ko | コ |  |  |  |
| ka.kata.sa | サ |  |  |  |
| ka.kata.shi | シ |  |  |  |
| ka.kata.su | ス |  |  |  |
| ka.kata.se | セ |  |  |  |
| ka.kata.so | ソ |  |  |  |
| ka.kata.ta | タ |  |  |  |
| ka.kata.chi | チ |  |  |  |
| ka.kata.tsu | ツ |  |  |  |
| ka.kata.te | テ |  |  |  |
| ka.kata.to | ト |  |  |  |
| ka.kata.na | ナ |  |  |  |
| ka.kata.ni | ニ |  |  |  |
| ka.kata.nu | ヌ |  |  |  |
| ka.kata.ne | ネ |  |  |  |
| ka.kata.no | ノ |  |  |  |
| ka.kata.ha | ハ |  |  |  |
| ka.kata.hi | ヒ |  |  |  |
| ka.kata.fu | フ |  |  |  |
| ka.kata.he | ヘ |  |  |  |
| ka.kata.ho | ホ |  |  |  |
| ka.kata.ma | マ |  |  |  |
| ka.kata.mi | ミ |  |  |  |
| ka.kata.mu | ム |  |  |  |
| ka.kata.me | メ |  |  |  |
| ka.kata.mo | モ |  |  |  |
| ka.kata.ya | ヤ |  |  |  |
| ka.kata.yu | ユ |  |  |  |
| ka.kata.yo | ヨ |  |  |  |
| ka.kata.ra | ラ |  |  |  |
| ka.kata.ri | リ |  |  |  |
| ka.kata.ru | ル |  |  |  |
| ka.kata.re | レ |  |  |  |
| ka.kata.ro | ロ |  |  |  |
| ka.kata.wa | ワ |  |  |  |
| ka.kata.wo | ヲ |  |  |  |
| ka.kata.ga | ガ |  |  |  |
| ka.kata.gi | ギ |  |  |  |
| ka.kata.gu | グ |  |  |  |
| ka.kata.ge | ゲ |  |  |  |
| ka.kata.go | ゴ |  |  |  |
| ka.kata.za | ザ |  |  |  |
| ka.kata.ji | ジ |  |  |  |
| ka.kata.zu | ズ |  |  |  |
| ka.kata.ze | ゼ |  |  |  |
| ka.kata.zo | ゾ |  |  |  |
| ka.kata.da | ダ |  |  |  |
| ka.kata.di | ヂ |  |  |  |
| ka.kata.du | ヅ |  |  |  |
| ka.kata.de | デ |  |  |  |
| ka.kata.do | ド |  |  |  |
| ka.kata.ba | バ |  |  |  |
| ka.kata.bi | ビ |  |  |  |
| ka.kata.bu | ブ |  |  |  |
| ka.kata.be | ベ |  |  |  |
| ka.kata.bo | ボ |  |  |  |
| ka.kata.pa | パ |  |  |  |
| ka.kata.pi | ピ |  |  |  |
| ka.kata.pu | プ |  |  |  |
| ka.kata.pe | ペ |  |  |  |
| ka.kata.po | ポ |  |  |  |
| ka.kata.kya | キャ |  |  |  |
| ka.kata.kyu | キュ |  |  |  |
| ka.kata.kyo | キョ |  |  |  |
| ka.kata.sha | シャ |  |  |  |
| ka.kata.shu | シュ |  |  |  |
| ka.kata.sho | ショ |  |  |  |
| ka.kata.cha | チャ |  |  |  |
| ka.kata.chu | チュ |  |  |  |
| ka.kata.cho | チョ |  |  |  |
| ka.kata.nya | ニャ |  |  |  |
| ka.kata.nyu | ニュ |  |  |  |
| ka.kata.nyo | ニョ |  |  |  |
| ka.kata.hya | ヒャ |  |  |  |
| ka.kata.hyu | ヒュ |  |  |  |
| ka.kata.hyo | ヒョ |  |  |  |
| ka.kata.mya | ミャ |  |  |  |
| ka.kata.myu | ミュ |  |  |  |
| ka.kata.myo | ミョ |  |  |  |
| ka.kata.rya | リャ |  |  |  |
| ka.kata.ryu | リュ |  |  |  |
| ka.kata.ryo | リョ |  |  |  |
| ka.kata.gya | ギャ |  |  |  |
| ka.kata.gyu | ギュ |  |  |  |
| ka.kata.gyo | ギョ |  |  |  |
| ka.kata.ja | ジャ |  |  |  |
| ka.kata.ju | ジュ |  |  |  |
| ka.kata.jo | ジョ |  |  |  |
| ka.kata.bya | ビャ |  |  |  |
| ka.kata.byu | ビュ |  |  |  |
| ka.kata.byo | ビョ |  |  |  |
| ka.kata.pya | ピャ |  |  |  |
| ka.kata.pyu | ピュ |  |  |  |
| ka.kata.pyo | ピョ |  |  |  |
| ka.kata.x_wi | ウィ |  |  |  |
| ka.kata.x_we | ウェ |  |  |  |
| ka.kata.x_wo | ウォ |  |  |  |
| ka.kata.x_she | シェ |  |  |  |
| ka.kata.x_je | ジェ |  |  |  |
| ka.kata.x_che | チェ |  |  |  |
| ka.kata.x_ti | ティ |  |  |  |
| ka.kata.x_di | ディ |  |  |  |
| ka.kata.x_dyu | デュ |  |  |  |
| ka.kata.x_tu | トゥ |  |  |  |
| ka.kata.x_du | ドゥ |  |  |  |
| ka.kata.x_tsa | ツァ |  |  |  |
| ka.kata.x_fa | ファ |  |  |  |
| ka.kata.x_fi | フィ |  |  |  |
| ka.kata.x_fe | フェ |  |  |  |
| ka.kata.x_fo | フォ |  |  |  |
| ka.kata.x_vu | ヴ |  |  |  |
| ka.kata.x_va | ヴァ |  |  |  |
| ka.kata.x_vi | ヴィ |  |  |  |
| ka.kata.x_ve | ヴェ |  |  |  |
| ka.kata.x_vo | ヴォ |  |  |  |

### B 不測項（9 項）

無法單獨成音，只列出來，不必聽。

| ID | 字 | listen_disabled |
| --- | --- | --- |
| ka.hira.small_ya | ゃ | true |
| ka.hira.small_yu | ゅ | true |
| ka.hira.small_yo | ょ | true |
| ka.hira.sokuon | っ | true |
| ka.kata.sokuon | ッ | true |
| ka.kata.chouon | ー | true |
| ka.kata.small_ya | ャ | true |
| ka.kata.small_yu | ュ | true |
| ka.kata.small_yo | ョ | true |

### C 音調配對

見上方「優先項目」的音調組，結果填在那裡。

### D 其他配對（抽聽）

語音示範組每組第一對：

| ID#配對 | 送出文字 | Android | iOS | 備註 |
| --- | --- | --- | --- | --- |
| ka.sg.voicing_k#0 | か／が |  |  |  |
| ka.sg.voicing_s#0 | さ／ざ |  |  |  |
| ka.sg.voicing_t#0 | た／だ |  |  |  |
| ka.sg.voicing_h#0 | は／ば |  |  |  |
| ka.sg.length_vowel#0 | おばさん／おばあさん |  |  |  |
| ka.sg.length_ei_ou#0 | せき／せいき |  |  |  |
| ka.sg.length_kata#0 | ビル／ビール |  |  |  |
| ka.sg.sokuon_basic#0 | きて／きって |  |  |  |
| ka.sg.sokuon_kata#0 | バグ／バッグ |  |  |  |
| ka.sg.yoon_shu_su#0 | しゅみ／すみ |  |  |  |
| ka.sg.yoon_chu_tsu#0 | ちゅうしん／つうしん |  |  |  |
| ka.sg.yoon_ja_za#0 | じゃま／ざま |  |  |  |

`minimal_pair` 每課一題：

| ID | 送出文字 | Android | iOS | 備註 |
| --- | --- | --- | --- | --- |
| dr.k11.mpr.001 | かき／かぎ |  |  |  |
| dr.k12.mpr.001 | たいがく／だいがく |  |  |  |
| dr.k13.mpr.001 | はん／ばん |  |  |  |
| dr.k14.mpr.001 | きゃく／きやく |  |  |  |
| dr.k15.mpr.001 | じゃま／ざま |  |  |  |
| dr.k16.mpr.001 | きて／きって |  |  |  |
| dr.k17.mpr.001 | おばさん／おばあさん |  |  |  |
| dr.kk06.mpr.001 | バス／パス |  |  |  |
| dr.kk07.mpr.001 | バグ／バッグ |  |  |  |

### E 音調單字

`p0` 內容有 6 筆 `tts: auto` 的單字（2026-11-10 依 `rust/content/vocab/*.json` 同步，依課序排列；原本另有 1 筆預告語塊，已移除）。花／鼻、箸／橋 同音只差音調，聽的時候對照著聽。

| ID | 送出文字 | 讀音 | Android | iOS | 備註 |
| --- | --- | --- | --- | --- | --- |
| vo.ame_rain | 雨 | あめ |  |  |  |
| vo.hashi_chopsticks | 箸 | はし |  |  |  |
| vo.hashi_bridge | 橋 | はし |  |  |  |
| vo.kami_paper | 紙 | かみ |  |  |  |
| vo.hana_flower | 花 | はな |  |  |  |
| vo.hana_nose | 鼻 | はな |  |  |  |

### F 誤讀風險詞（抽聽）

`lint/tts_risky.txt` 目前收錄 今日、一日、方、辛い、行った，命中的句子都已強制送假名。確認實際出現時念對就好，遇到時順手記錄。

何、人 太常見，刻意沒有收進風險詞，下面是實際用 `tts: auto` 送漢字的句子。這幾句聽錯的話，把該詞加入 `tts_risky.txt`。

| ID | 送出文字 | 該讀成 | Android | iOS | 備註 |
| --- | --- | --- | --- | --- | --- |
| se.l02.003 | これは何ですか。 | なん |  |  |  |
| se.l02.038 | これは何の写真ですか。 | なんの |  |  |  |
| se.l02.061 | あの人の名前は何ですか。 | なん |  |  |  |
| se.l01.025 | 日本の人ですか。 | ひと |  |  |  |
| se.l02.014 | あの人は誰ですか。 | ひと |  |  |  |
| se.l02.062 | 私の友達はあの人です。 | ひと |  |  |  |

### G 假名模式的空白（要改程式才生效）

App 在假名模式下，詞與詞之間帶空白送出。要比較「去空白」，請把下表文字貼到備忘錄，用系統的朗讀功能試聽（iOS「朗讀所選範圍」、Android「隨選朗讀」）。

| ID | 帶空白（App 目前的做法） | 去空白 | Android | iOS | 備註 |
| --- | --- | --- | --- | --- | --- |
| se.l01.003 | りん です。 よろしく おねがいします。 | りんです。よろしくおねがいします。 |  |  |  |
| se.l02.066 | その ほん わ なにご です か。 | そのほんわなにごですか。 |  |  |  |
| se.l03.005 | なな、 はち、 きゅう、 じゅう。 | なな、はち、きゅう、じゅう。 |  |  |  |

### H `p0` 主線例句（L08 以後，抽聽）

L08–L30 的主線例句共 1,447 句，送假名 157 句、送漢字原文 1,290 句（2026-11-10 依 `rust/content/sentences/l08.json`–`l30.json` 計算）。這裡只抽代表性的句子。

**H1 已強制送假名的句子**：命中 `lint/tts_risky.txt` 的 今日、一日、方、辛い、行った，以及含人名（`@name`）的句子。要確認的是讀音對、假名模式還聽得懂。

| ID | 畫面文字 | 實際送出（假名） | 在 App 哪裡 | Android | iOS | 備註 |
| --- | --- | --- | --- | --- | --- | --- |
| se.l09.008 | 今日は暑いです。 | きょう わ あつい です。 | 單字 暑い |  |  |  |
| se.l26.001 | 四月一日に日本に来ました。 | しがつ ついたち に にほん に きました。 | 單字 一日（ついたち） |  |  |  |
| se.l26.050 | 八日は一日中暇です。 | ようか わ いちにちじゅう ひま です。 | 單字 八日 |  |  |  |
| se.l24.038 | この漢字の読み方を教えてください。 | この かんじ の よみかた を おしえて ください。 | 文法 〜方（〜かた） |  |  |  |
| se.l24.040 | あの男の方は、どなたですか。 | あの おとこ の かた わ、 どなた です か。 | 單字 方 |  |  |  |
| se.l30.035 | このカレーはちょっと辛いです。 | この カレー わ ちょっと からい です。 | 單字 辛い |  |  |  |
| se.l20.006 | 京都に行ったことがありますか。 | きょうと に いった こと が あります か。 | 單字 京都 |  |  |  |
| se.l13.058 | こちらは田中さんです。 | こちら わ たなか さん です。 | 單字 こちら |  |  |  |

**H2 送漢字原文的日期、數字與多音字**：這些句子是 `tts: auto`，引擎要自己判斷讀音。念錯的話，把該句的 `tts` 改成 `"kana"`；同一個詞在多句都錯，就加進 `tts_risky.txt`。

| ID | 送出文字 | 該讀成 | 在 App 哪裡 | Android | iOS | 備註 |
| --- | --- | --- | --- | --- | --- | --- |
| se.l26.005 | 二十日は母の誕生日です。 | はつか | 單字 二十日 |  |  |  |
| se.l26.004 | 本は十日に返してください。 | とおか | 單字 十日 |  |  |  |
| se.l26.002 | 誕生日は三月二日です。 | さんがつ ふつか | 單字 二日 |  |  |  |
| se.l14.026 | 毎朝7時半に家を出ます。 | しちじはん | 單字 出る |  |  |  |
| se.l14.042 | 三人ずつ座りましょう。 | さんにん | 單字 人（にん） |  |  |  |
| se.l19.034 | 大人は800円です。 | おとな、はっぴゃくえん | 單字 大人 |  |  |  |
| se.l17.039 | バスを降りて、5分歩きます。 | ごふん | 文法 〜て（先後） |  |  |  |
| se.l18.019 | 明日は学校に来ないでください。 | こない | 文法 〜ないでください |  |  |  |
| se.l12.024 | なぜこの町に来ましたか。 | きました | 單字 なぜ |  |  |  |
| se.l10.015 | 趣味は何ですか。 | なん | 單字 趣味 |  |  |  |
| se.l08.012 | そこに何がありますか。 | なに | 文法 に（存在） |  |  |  |
| se.l08.014 | あそこに人がいます。 | ひと | 文法 が（主角） |  |  |  |
| se.l08.007 | お弁当は中にあります。 | なか | 單字 中 |  |  |  |
| se.l25.004 | 熱がありますから、病院に行かなければなりません。 | ねつ | 單字 熱 |  |  |  |

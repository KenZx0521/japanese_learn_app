# Flutter App 架構與體驗設計（flutter-app.md）

本文件是 `lib/` 實作的規格，也是 **UI 流程與 design tokens 的權威來源**。其他權威範圍（`RULINGS.md` O5）：內容欄位以 `curriculum.md` 為準（以下寫作「課綱 §x」），函式簽章與 DTO 以 `rust-core.md` §9 為準，驗證工具與字型子集流程以 `reuse-and-verification.md` 為準，衝突時以 `RULINGS.md` 為最高依據。

拆出的章節：§5 程式結構在 [flutter-app-architecture.md](flutter-app-architecture.md)，§6 TTS 服務在 [flutter-app-tts.md](flutter-app-tts.md)，§8 測試策略在 [flutter-app-testing.md](flutter-app-testing.md)。章節編號沿用，文中的 §5、§6、§8 都指這三份，它們與本文件同屬 flutter-app 規格。

標記：**【實測】** 本機以 Flutter 3.47.9 跑過或讀過原始碼；**【待實機】** 需要 Android／iOS 實機或音效輸出才能驗證。

---

## 0. 實證紀錄

Spike 位於 scratchpad 的 `flutter-spike/`，下列都是實際結果，後文的規則由此而來。

| # | 問題 | 實測結果 | 造成的設計規則 |
|---|---|---|---|
| 1 | 相依能否解析與編譯 | `flutter_riverpod 3.5.0`、`go_router 18.1.3`、`flutter_tts 4.2.5`、`path_provider 2.1.6`、`flutter_rust_bridge 2.13.0`、`material_ui 1.10.0` 解析成功，`flutter build linux` debug 與 release 皆通過 | §1 的版本 |
| 2 | go_router 與 `flutter/material.dart` 的相容性 | `flutter/material.dart` 與 `material_ui` 的 `MaterialApp` 是**兩個不同類別**。go_router 18 只認 `material_ui` 的：用 SDK 版 `MaterialApp.router` 時頁面型別變成 `NoTransitionPage`（靜默失去轉場），用 `material_ui` 版則是 `MaterialPage` | 全專案只 import `material_ui`，CI 擋 `flutter/material.dart`；所有路由用自訂 `pageBuilder` |
| 3 | 沒有 Material 祖先的文字 | `Text` 會套用黃色雙底線的除錯樣式 | 每個畫面都經過 `PaperScaffold` |
| 4 | Riverpod 3 失敗行為 | 預設會自動重試 `Exception`：3 秒內 provider 被呼叫 5 次（最多 10 次）。`ProviderScope(retry: (_, _) => null)` 時只呼叫 1 次 | 全域關閉重試，由使用者按「重試」 |
| 5 | flutter_tts 在 Linux | 套件未宣告 Linux。建構子不會拋錯，但 `setLanguage`、`isLanguageAvailable`、`getVoices`、`speak`、`stop` 等全部拋 `MissingPluginException` | Linux 一律不建立 `FlutterTts` |
| 6 | flutter_tts 的 hang | 讀原始碼：`awaitSpeakCompletion(true)` 時 Android 出錯、iOS 被 `stop()` 取消都不會完成 Future。Android 引擎初始化失敗時 `speak` 會把呼叫放回 pending 佇列，Future 永遠不回 | 不用 `awaitSpeakCompletion`，每個呼叫都加 timeout，起播加看門狗（§6） |
| 7 | spd-say 能否當備援 | 可以。`Process.start('spd-say', ['-o','espeak-ng','-l','ja','-w',text])` 在播完後結束；`spd-say -C` 後 55ms 內 `-w` 行程結束；`kill()` 只殺 client | 停止用 `-C`，結束事件用 `exitCode` |
| 8 | spd-say 的失敗訊號 | **結束碼不代表成功**：不存在的 module、未知語言都回 0。本機 `openjtalk` 模組在 `-L` 列出 `ja`，但字典與語音檔不存在，`-w` 7–22ms 就回 0 且沒有聲音；espeak-ng 同樣指令約 500–1100ms | 用「音量 -100 探測＋耗時 ≥150ms」判定模組真的能用 |
| 9 | espeak-ng 能否念漢字 | 以 libespeak-ng 取音素：`猫` → 英文的「Chinese letter」；`こんにちは` 正確；`わたしは` 的 は 念 ha；を 念 o | Linux 引擎一律送假名 |
| 10 | 本機語音 | `aplay -l` 無音效卡，只能驗證流程與時間，**沒有人耳確認音質** | 音質列入【待實機】 |
| 11 | 漢字字形 | 見 §7.1 的像素比對 | `JaText` 同時指定字型與 locale |
| 12 | 語意語言標註 | `Text(locale:)` 同時影響字形與螢幕報讀語言；`TextStyle(locale:)` 只影響字形；`TextSpan(locale:)` 只影響螢幕報讀語言 | 混排的 span 兩者都要設 |
| 13 | 字型子集 | Noto Sans TC 400/700 與 Noto Serif TC 800 的 Big5 常用字子集為 1.98×2＋2.77MB；pubspec `weight:` 對應靜態字重有效。常用字或 JIS 第一水準都不足以涵蓋內容：綺（綺麗）、呟 不在 JIS 第一水準 | §4.3 |
| 14 | 截圖 | `binding.takeScreenshot` 在 Linux 拋 `MissingPluginException`。`RepaintBoundary.toImage` 可用。`matchesGoldenFile` 在 `flutter test` 與 `integration_test -d linux` 都能用，但兩者像素不同（同頁差 21,369 px） | 回歸基準只用 `flutter test`；Linux 實跑只存截圖 |
| 15 | 無障礙檢查工具 | `textContrastGuideline` 對 11px 拉丁字誤報（宣告對比 6.61，量到 1.25），因為細筆畫取樣不到實色 | 對比度改在 token 層用公式測；romaji 最小 12px |
| 16 | FRB 產生的型別 | 用 rust-spike 產生的 `ReviewDto`、`CoreError` 在未載入原生函式庫的 `flutter test` 可直接建構 | Repository 只包函式，DTO 直接用 |
| 17 | 錄音回放相依 | `audioplayers_linux` 需要 gstreamer 開發套件，本機沒有，CMake 失敗，會弄壞 Linux 驗證建置 | 跟讀的錄音回放列為 P1（§3.7） |

---

## 1. 相依與平台設定

```yaml
dependencies:
  flutter: {sdk: flutter}
  material_ui: ^1.10.0          # 只用 MaterialApp、Scaffold 等基礎設施，外觀全部自訂
  flutter_riverpod: ^3.5.0
  go_router: ^18.1.3
  flutter_tts: 4.2.5            # 鎖定版本，§6 依賴其內部行為
  path_provider: ^2.1.6
  flutter_rust_bridge: 2.13.0
  freezed_annotation: ^3.1.0    # FRB 為 Rust enum 產生 sealed class 時需要
dev_dependencies:
  flutter_test: {sdk: flutter}
  integration_test: {sdk: flutter}
  flutter_lints: ^6.0.0
  freezed: ^4.0.3
  build_runner: any
```

不加 `flutter_localizations`：`material_ui` 匯出的 `GlobalMaterialLocalizations.delegates` 已足夠（【實測】）。介面只有繁體中文，字串直接寫在 widget 旁，不引入 ARB。不加 `cupertino_icons`。圖示用自製的 `CustomPainter` 或漢字。不用 riverpod_generator，少一層產生碼。

**Android**：`android/app/src/main/AndroidManifest.xml` 的 `<queries>` 內加入 `<intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>`（Android 11+ 查詢 TTS 服務必需，flutter_tts README 明載）。

- flutter_tts `minSdkVersion 24`，與 Flutter 預設相同。模板的 `INTERNET` 權限只在 `src/debug/AndroidManifest.xml`（供熱重載），main 沒有。flutter_tts 的 manifest 是空的。2026-11-23 以 `check_offline.py` 的 L07 實測 release APK 沒有 `INTERNET`【實測】。

**離線保證（O8）**：release 建置不得有 `INTERNET` 權限，相依樹不得有 HTTP／TLS client。檢查一律用 `python3 tools/verify/check_offline.py`，規則與黑名單見 `reuse-and-verification.md` §9.12（【實測】spike 的 Dart 相依在 `flutter pub deps --no-dev` 下無命中）。`dev_dependencies` 的 `build_runner` 只在開發機執行，不進 release，所以 L06 用 `--no-dev`。列入 CI（§8）；Android 建置後加 `--apk build/app/outputs/flutter-apk/app-release.apk --require-apk`。

**iOS**：TTS 不需權限。首次探測時設定音訊類別（§6.3）。**Linux**：執行期需要 `spd-say`，編譯期無額外相依。

**路徑**：DB 放 `getApplicationSupportDirectory()`，不放 Documents，避免使用者在檔案 App 看到。

---

## 2. 資訊架構與導覽

### 2.1 底部導覽

| 分頁 | 圖示字 | 標籤 | 內容 |
|---|---|---|---|
| 0 | 今 | 今日 | 今日任務清單 |
| 1 | 学 | 學習 | 課程路線、50 音、單字、文法、句型、漢字陷阱（內容就緒才露出） |
| 2 | 聴 | 聽說 | 語音示範、情境對話 |
| 3 | 暦 | 計畫 | 里程碑、月曆、調整 |
| 4 | 設 | 設定 | 語音、顯示、無障礙、資料、關於 |

圖示字是裝飾（`ExcludeSemantics`），螢幕報讀唸中文標籤。標籤永遠顯示。寬度 ≥1024 改為左側 88px 直欄。

學習階段（session）推到 root navigator，隱藏導覽列。

筆記的入口由 `CourseOverviewDto.notes_available` 決定，內容就緒才露出。`p0a` 為 false，使用者看不到這個入口；這個畫面在 `p0a` 用測試夾具驗證（§8）。預設的 `p0` 為 true（`rust/tests/real_content_p0.rs`），整合測試 J4 用真實內容走過這個畫面（`integration_test/README.md`）。

### 2.2 路由表

一律 `pageBuilder: paperPage`（淡入＋上移 2%，280ms，reduced motion 時無動畫）。`/` 不存在實體頁，由 redirect 決定。

| 路徑 | 畫面 | Navigator |
|---|---|---|
| `/welcome`、`/welcome/:step` | O1、O3–O5 新手引導（`:step` 為 `o3`、`o4`、`o5`），`/welcome/placement` 為平假名畢業考 | root |
| `/today` | T1 今日 | shell 0 |
| `/session/today?start=` | T2 今日連續流程，L3 新內容學習在其中 | root |
| `/session/done` | T3 完成頁 | root |
| `/session/expectation` | O6 誠實預期（第一次學習完成後） | root |
| `/learn` | L1 學習首頁 | shell 1 |
| `/learn/lesson/:lessonId` | L2 課程詳情 | shell 1 |
| `/learn/kana` | K1 五十音表 | shell 1 |
| `/learn/kana/session/:lessonId` | K2 假名自由練習 | root |
| `/learn/kana/rule/:ruleId` | K3 規則卡 | shell 1 |
| `/learn/vocab`、`/learn/vocab/list?topic=&only_introduced=&only_starred=&srs=`、`/learn/vocab/word/:wordId` | V1 主題與搜尋、V2 列表、V3 詳情 | shell 1 |
| `/session/cards` | V4 字卡複習 | root |
| `/learn/grammar?q=`、`/learn/grammar/:grammarId` | G1 列表、G2 文法點 | shell 1 |
| `/learn/notes?kind=` | N1 漢字陷阱（筆記） | shell 1 |
| `/learn/drills` | D1 句型演練入口 | shell 1 |
| `/session/drill?lesson=&target=&drills=` | D2 演練（`drills` 以逗號分隔） | root |
| `/session/checkpoint/:milestoneId` | D3 里程碑檢定 | root |
| `/listen`、`/listen/sounds`、`/listen/dialogues` | S1 聽說首頁、S2 語音示範、S3 對話列表 | shell 2 |
| `/session/dialogue/:dialogueId` | S4 對話播放 | root |
| `/plan`、`/plan/about-level` | P1 計畫總覽、P2 關於程度 | shell 3 |
| `/settings`、`/settings/voice`、`/settings/licenses` | X1 設定、X2 語音與說明、X3 授權 | shell 4 |

L3 沒有獨立路由：`new_content_session` 的 `task_key` 只存在今日快照，L3 只能由 T2 進入。`start` 是 `TaskDto` 的 key，用 `Uri.encodeQueryComponent` 編碼（key 含 `:`）。

Redirect 只看 `onboardingDone`（`ValueListenable<bool>`）。不另存旗標：啟動時呼叫 `plan_view`，拋 `CoreError.NoActivePlan` 就是尚未完成引導，`create_plan` 成功後設為 true。啟動時已載入，所以不會閃頁。

### 2.3 畫面清單與狀態

共通：載入超過 200ms 才顯示骨架（文字行高的 `paper.sunken` 細條，不用轉圈）。錯誤一律用 `ErrorSlip`（§5.4）。

**中途離開**：FSRS 與假名熟練在作答當下寫入，不會遺失。V4 由 Rust 決定下一張，L3 依 `first_card` 從斷點繼續（§3.10）。D2、K2、S4 不記題目歷史，離開後以同 seed 重做（`rust-core.md` §8.1）。離開都不需確認。

| ID | 目的 | 載入 | 空 | 錯誤 |
|---|---|---|---|---|
| O1、O3–O5 | 建立程度、時間、語音檢查（O2 已移除，見 RULINGS O13） | 語音探測中顯示「正在確認語音」 | 無 | 語音失敗時停在 O5，明確選擇（§3.1） |
| O6 | 第一次學習完成後的誠實預期 | 無 | 無 | 無 |
| T1 今日 | 一眼看到今天做什麼、多久 | 骨架列 | 今天是休息日：「今天休息」＋自由練習入口；任務全完成：顯示完成章與「再學一批」 | `ErrorSlip`＋重試 |
| T2 連續流程 | 依序跑完任務，不必回清單 | 任務間的過場 | 無 | 單項載入失敗可略過，其餘繼續 |
| T3 完成頁 | 給完成感與本日數據 | 無 | 無 | 無（資料已寫入） |
| L1 學習首頁 | 目前課程與各資料庫入口 | 骨架 | 無（課綱內嵌） | 內容損毀 `ErrorSlip` |
| L2 課程詳情 | 本課 can-do、新字、文法、規則卡、對話 | 骨架 | 無 | 同上 |
| L3 新內容學習 | 先呈現、播音、立即一題 | 骨架 | 無步驟：直接呼叫 `complete_task` | 單步失敗顯示 `ErrorSlip`，重試同一步 |
| K1 五十音表 | 查閱、聽音、看進度 | 假名靜態可先畫，進度後補 | 進度全空時為「尚未開始」的淡色格，加第一課按鈕 | 進度失敗仍顯示表，標「進度暫時讀不到」 |
| K2 假名自由練習 | 先呈現未學字，再測驗 | 無 | 無題可出：「這批都熟了」 | 回上一頁＋`ErrorSlip` |
| K3 規則卡 | 促音、長音、助詞讀音、音調的說明與拍感示範 | 骨架 | 無 | `ErrorSlip` |
| V1 主題與搜尋 | 依主題瀏覽、搜尋 | 骨架 | 搜尋無結果：「找不到，試試中文、假名或羅馬字」 | `ErrorSlip` |
| V2 單字列表 | 列出單字與狀態，可篩選 | 骨架 | 篩選無結果：「沒有符合的單字」 | `ErrorSlip` |
| V3 單字詳情 | 意思、音調、例句、陷阱、標記 | 骨架 | 無例句時隱藏該區 | `ErrorSlip` |
| V4 字卡 | FSRS 複習 | 第一張顯示骨架 | 「目前沒有到期卡片」＋下次到期時間 | 寫入失敗保留在本卡並提示重試 |
| G1、G2 文法 | 閱讀、搜尋與小測驗 | 骨架 | 搜尋無結果：「找不到，試試中文或假名」 | `ErrorSlip` |
| N1 漢字陷阱 | 同形異義、字形、讀音、轉移、術語筆記 | 骨架 | 該類沒有筆記：「這一版還沒有這類筆記」 | `ErrorSlip` |
| D1、D2、D3 演練 | 題型與檢定 | 無 | 無題：「這課目前沒有題目」 | 同 V4 |
| S1 聽說首頁 | 入口與語音狀態 | 無 | 無 | 語音不可用時頂部顯示 `VoiceBanner` |
| S2 語音示範 | 清濁、長短、促音、拗音、音調 | 骨架 | 無 | 語音不可用：按鈕改為說明 |
| S3、S4 對話 | 四階段聽說 | 骨架 | 還沒學到的對話顯示課次，仍可點 | `ErrorSlip` |
| S5、S6 | 已移除（見 RULINGS O13），代號留空 | | | |
| P1 計畫 | 進度、月曆、調整 | 骨架 | 無 | `ErrorSlip` |
| X1–X3 | 偏好與授權 | 無 | 無 | 清除失敗時保留資料並提示 |

---

## 3. 互動流程

### 3.1 新手引導（第一次開啟）

目標：90 秒內開始學第一個假名，第一次成功之後才談成果的邊界。

1. **O1 歡迎**：「從五十音開始。全程離線，資料只存在這台裝置。」一個按鈕。
2. **O2**：已移除（見 RULINGS O13）。O1 的按鈕直接進 O3；步驟代號與路徑不重新編號（`/welcome/o3`、`o4`、`o5`），左上的步驟格為 4 格（O1、O3、O4、O5 依序是第 1 到 4 步）。
3. **O3 程度**：完全沒學過／會一點假名／平假名都會。

   | 選項 | `PlanInputDto` |
   |---|---|
   | 完全沒學過 | `start_level = Zero`，`known_kana_lessons = []` |
   | 會一點假名 | `start_level = Zero`，展開可複選的行清單（`le.k01`–`le.k09`、`le.k11`–`le.k15`，標題用 `title_zh`），勾選的課放進 `known_kana_lessons`。K10、K16–K19 沒有新字，不列入 |
   | 平假名都會 | 進 `/welcome/placement`，用 D3 元件考 `ms.hira`：`checkpoint_start("ms.hira", 0, false)`。尚未確認語音，所以 `audio_available` 固定 false。`CheckpointResultDto.passed` 為真時 `start_level = Hiragana`；未過用 `Zero`，並提示可回上一步改選「會一點假名」，不扣任何進度 |

4. **O4 每天多久**：10／20（預設）／30／45 分鐘，學習日（`weekdays`，1＝週一到 7＝週日，預設全選）。目標日期選填。即時呼叫 `plan_preview` 顯示粗估完成日：一律標明「粗估」，範圍依 `course_overview.content_stage` 寫（§3.8 的文案表）。文案與 P1 共用 `scope_copy.dart` 的 `forecastLine`（`plan_estimate_copy.dart` 只組合）；階段還沒載入時只寫「約在 M/D 完成（粗估）」。
5. **O5 語音檢查**：自動探測後播「こんにちは」。兩個按鈕「聽得到」「聽不到」。
   - 探測失敗或按「聽不到」時**停在本步**，展開 §6.4 的說明，必須明確選一個：「現在設定」（開 `VoiceHelpSheet`，回到 App 時重新探測，成功就回到試聽）或「先用無聲模式」（`update_settings(silent_mode: true)`）。
   - 無聲模式的說明要寫清楚：聽力題暫時不出現，之後隨時可以在設定開回來。
6. **開始**：按「開始第一課」依序呼叫 `create_plan`、`today_view(audio_available)`，進 `/session/today?start=<第一個 NewContent 的 key>`，走任務模型，不經過 T1。`create_plan` 成功時建立 `FirstRunMarker`（`core/backend/first_run_marker.dart`：Application Support 目錄下的旗標檔 `pending_expectation`，介面可注入假實作）。

**O6 誠實預期**（`/session/expectation`）：第一個 `NewContent` 完成、`complete_task` 回來後，T2 檢查 `FirstRunMarker`，有旗標就推入本頁，看完刪除旗標，再回 T2 接下一項。「知道了，繼續」處理中忽略再次點擊，連點只離開一次，不會把 T2 一起關掉。處理中「關於程度」也不能按，否則之後的返回會作用在錯的頁面。中途關閉 App 時旗標留著，下次完成 `NewContent` 仍會顯示。內容依 `content_stage`，三行以內，附 P2 連結：

| `content_stage` | 開頭 | 能做到 | 做不到 |
|---|---|---|---|
| `P0a` | 「這一版涵蓋假名與入門七課。」 | 讀出全部假名、聽辨清濁長短；用背好的句型打招呼、自我介紹、約人 | 沒有真人對話對象，口說只有跟讀與選擇回應；語音由裝置合成 |
| `P0` | 「本版到 L30，涵蓋參考 N5 範圍。」 | 課綱 §1.3「本版」欄 | 課綱 §1.3「做不到的部分」 |
| `Full` | 「完整版到 L48。」 | 課綱 §1.3「完整版」欄 | 同上 |

**範圍文案規則（O7）**：`P0a` 的任何畫面都只能說「假名與入門七課」，不得出現 N4，不得承諾看懂日劇。`P0` 不得宣稱含 N4 或 L31 以後的內容。文案集中在 `features/plan/scope_copy.dart`，測試逐字檢查（§8）。

### 3.2 今日任務

T1 的結構是一張由上而下的稿紙清單，不是卡片：

```text
第 12 日            [完成章位置]
今天，先把か行認熟。              ← Dart 依第一個 NewContent 的 title_zh 組句，MixedText 顯示
約 17 分鐘 · 本週已學 4 天        ← TodayViewDto.estimated_minutes 無條件進位到整數
────────────────────────
一  複習        18 張 · 2.5 分  [開始] ← 當前項展開
二  新內容 か行  5 字 · 14 分
```

S0 只有複習與新內容（額度 60／40／0／0，併入假名練習）。S1 起才會出現「句型演練」「聽力」。清單來自 `TodayViewDto.tasks`，順序由 Rust 固定（`Review`、`NewContent` 或 `Integration`、`Drill`、`Listen`、`Checkpoint`）。分鐘數一律用 `TaskDto.minutes` 與 `estimated_minutes`，不顯示預算。今天沒有 `NewContent` 時（受限日、整合日或游標走完全部已發布的課），標題下那一行固定為「今天把學過的再練熟。」。

| `TaskDto` | 列標題／副標 | 執行元件 | 資料 | 結案 |
|---|---|---|---|---|
| `Review` | 複習／`min(due, budget.review_cap) + learning` 張；`due` 超過上限時寫「今天先做 N 張，其餘之後再排」。`due + learning` 為 0、`new_cards` 大於 0 時（`Review` 已 done，但這些卡今天還沒碰過，清單跑完才接觸）副標寫「最後再看 N 張新卡」，不寫「0 張」、不用「收尾」這個詞，這一列淡色但不蓋完成章。`due + learning + new_cards` 為 0 時 T1 不列（快照不動） | V4 的 `CardRunner` | `session_next(seed, audio)` 直到 `Done` | `complete_task(key, ms, audio)` |
| `NewContent` | 新內容 `title_zh`／`kana` 字、`words` 字＋`grammar` 文法、`rules` 規則（0 的不顯示） | L3（§3.10） | `new_content_session(key, seed, audio)` | 同上 |
| `Integration` | 對話 `title_zh`／階段（10 分方案為「第 1、2 段」或「第 3、4 段」） | S4，只跑 `phases` | `dialogue_detail(dialogue_id)`。`dialogue_id` 為 None 時改跑 D2（`DrillFilterDto.lesson_id = lesson_id`，`count = 10`） | 同上 |
| `Drill` | 句型演練／`questions` 題 | D2 | `drill_session(DrillFilterDto{task_key: key, count: questions}, seed, audio)` | 同上 |
| `Listen` | 聽力／`sentences` 句 | D2 版面 | `listen_session(key, seed, audio)`；作答用 `grade_drill` | 同上 |
| `Checkpoint` | 里程碑檢定／`plan_view` 的 `title_zh` | D3 | `checkpoint_start(milestone_id, seed, audio)` | `checkpoint_finish` 後 `complete_task`；「先略過」用 `checkpoint_dismiss`，回傳的清單已不含此項 |

`seed` 為 `session_seed`（§5.2）。`audio` 為 `audioAvailableProvider`（§6.6）。`Checkpoint` 的副標來自內容的 `title_zh`，可能帶 `{ja:}` 標記，用 `MixedText` 顯示；其他副標是 Dart 組的文案，用 `AppText`。

**T2 流程**：按「開始」進入 T2，同一路由內依序換元件。

```text
today_view(audio) → 從 start（否則第一個 done=false）開始
迴圈：執行該任務 → complete_task(key, durationMs, audio) → 取回新的 TodayViewDto
  第一個 NewContent 結案且 FirstRunMarker 存在 → 推入 O6
  下一個 done=false 的任務存在 → 過場頁
  清單跑完 → learning_tail > 0 時，用 CardRunner 呼叫 session_next 到 Done（不呼叫 complete_task）
    收尾包含今天的學習中卡片，以及前幾天建立、尚未接觸的卡（Review 的 new_cards）
  → /session/done（T3）；有略過的項目時改顯示「今天有項目沒做完」，不算完成
```

- 任務之間有過場頁（「下一項：文法 3 分鐘」＋「繼續」＋「今天先到這」），**不用倒數自動跳轉**。中途離開，回 T1 時該項顯示「繼續」。`durationMs` 由 Dart 計時，App 進背景時暫停。
- 語音可用性改變時，T2 以同 seed 重新呼叫 `today_view` 與當前任務的取題函式（§6.6）。取題回傳空陣列時略過該任務，不呼叫 `complete_task`。略過不是完成：過場頁寫「這一項先略過。」且不蓋章，略過的項目留在今日清單上。
- 回前景時 T2 重取 `today_view`，`logical_date` 改變就停止目前任務，提示「日期已經換了」並回到 T1，昨天的任務不再結案。`complete_task` 回 `NotFound` 時（該項已不在快照）重新載入今日，不留在重試。
- T1 顯示 `estimated_minutes`，已完成項淡色並蓋小章（只剩收尾新卡的 `Review` 淡色但不蓋章，見上表）。全部任務都 done 且 `learning_tail > 0` 時（例如受限日只剩前幾天建立的卡），清單下方多一列「收尾／N 張」（N 為 `learning_tail`）與「開始」，進 T2 直接跑收尾。
- T3：大朱印＋本日分鐘與答題數（`activity_range(today, today)`）。分鐘取整數，不到 1 分鐘顯示「不到 1 分鐘」。主視覺是「本週已學 N 天」（由 `calendar` 算），`streak` 只在 P1 小字顯示，符合課綱 §11.3「不累積債務」。
- **再學一批**：`TodayViewDto.can_learn_more` 為真時，T3 與全部完成的 T1 顯示此按鈕，文字「再學一批」，下方小字「不影響明天的安排」。按下呼叫 `learn_more(audio)`，取得新的 `TodayViewDto`，帶新任務的 key 重新進 T2。
- `is_study_day=false`：顯示「今天休息」與 `next_study_date`，到期複習仍可做。
- `recovery_reason` 對應頂部文案，語氣不責備（`today_copy.dart` 的 `recoveryMessage`）；清單是空的（休息日沒有複習）時沒有事可做，不顯示這一句。積壓日照常列出檢定（RULINGS O11），所以不說「只複習」；學完全部課後仍可能是 `Minimal`，當天沒有 `NewContent`／`Integration` 時不說「學一小批新的」：

  | `recovery_reason` | `minimal_new = false` | `minimal_new = true`，有主線切片 | `minimal_new = true`，沒有主線切片 |
  |---|---|---|---|
  | `ReturnAfterBreak` | 「歡迎回來。今天先複習，主線新內容暫停。」 | 不會發生（回鍋當天 `recovery_days` 固定為 1） | 同左 |
  | `ReviewBacklog` | 「複習累積了一些，今天的時間先給複習，主線新內容暫停。」 | 「複習還有一些，今天學一小批新的。」 | 「複習還有一些，今天先複習。」 |
  | `UnseenNewCards` | 「前幾天的新內容還沒看完，今天先看完。」 | 「前幾天的新內容還沒看完，今天先學一小批。」 | 「前幾天的新內容還沒看完，今天先看完。」 |

### 3.3 五十音表與假名練習

**K1 五十音表**

- 上方切換平假名／片假名（`kana_chart(script)`，回 `KanaGroupDto`，分區與欄數由 `title_zh`、`columns` 決定）。5 欄稿紙格，保留 や行、わ行 的空格維持母音對位（`KanaRowDto.cells` 的 None）；拗音 3 欄。
- 格內：假名（Klee）＋ romaji。**K1 永遠顯示 romaji**，不呼叫 `display_policy`。狀態：`NotStarted`（`ink.tertiary`）、`Learning`（`ink.primary`）、`Mastered`（右上角小朱點），`fast_badge` 為小型 ○ 記號。
- 所有格都可點，不因未學而鎖定。點一下：發音（`listen_disabled` 為真時不播，改顯示「單獨唸不準，看例字」），並更新固定在底部的**詳情條**（寬螢幕改為右欄）。詳情條用 `kana_detail`：大字、romaji、`origin_kanji`（「來自漢字：安」）、`hint_zh`、例字（各自可播）、`confusables`、`rule_id` 非 None 時的規則卡連結、「慢速」。不開 modal，連續點格子可以連續聽。
- 底部按鈕「練習這一課」進 K2。不影響計畫。

**K2 假名自由練習**（`kana_session(lesson_id, seed, audio)`）

**先教後考**：進入時先取 `lesson_detail(lesson_id).kana`，`status = NotStarted` 的字依序用 `kana_detail` 取內容、以 `KanaTeachCard`（§3.10）呈現，再進測驗，所以第一題一定考剛看過的字。全都學過時直接測驗。

版面：頂部細線進度條、中央題幹、下方作答、回饋條由底部滑入。題幹與選項由 `QuestionView` 依 body 分派（§3.6）。

| `question_type` | 題幹 | 作答 | 答後 |
|---|---|---|---|
| `KanaRead` | 大字假名 | 2–4 個 romaji 按鈕（第一批三選一） | 播音 |
| `KanaListen` | 僅一個大播放鈕，自動播一次，**不顯示任何文字** | 2–4 個假名格 | 顯示 romaji |
| `KanaMatch` | 左 5 假名、右 5 讀音 | 依序點兩側配對，答對的對變淡；計時僅顯示、不扣分 | 總秒數 |
| `KanaConfuse` | 同組字之一 | 只有該組的字可選，連續 8 題 | 顯示 `explain_zh`（字組的 `diff_zh`） |
| `MinimalPair` | 播 A 或 B，只有播放鈕 | 兩個按鈕，顯示 `OptionDto.text`（中文） | 顯示 `correct_display`，用兩個選項的 `speech` 各播一次比較 |
| `KanaWord` | 實字，先讀 | `Choice` 為 4 個中文意思；`Typing` 為打字 | 播音＋例字 |

- 作答一律 `kana_submit(reference, response, durationMs)`，**由 Rust 判定**。只有 `KanaRead`、`KanaListen`、`KanaConfuse` 計入熟練，回傳 `KanaMasteryDto`，UI 顯示 `run/required`（連續答對 2 次為熟練）。答錯的字在本回合末再出現一次。
- **`KanaMatch` 是唯一由 Dart 判定的題型**（配對在畫面上逐對確認，以 `AnswerPayload::Match{all_correct}` 回報），不計熟練。
- **時限只決定徽章**：3 秒內連續答對得 `fast_badge`，答慢不歸零。`KanaListen` 的 `durationMs` 從播放結束（`TtsCompleted`）起算，播放中作答記 0。設定 `kana_time_limit = false` 時完全不看時間。畫面不顯示倒數。

**K3 規則卡**（`rule_card(rule_id)`，促音、長音、助詞讀音、音調，K16–K19 與 KK07）：從 L2、K1 詳情條與 L3 的 `Rule` 步驟進入。

1. 標題（`title_zh`）、說明（`body_zh`），都走 `MixedText`。
2. 例字列表：每個 `RuleExampleDto` 一列，日文大字、中文、播放鈕。`beats` 非空時顯示 `BeatStrip`：每拍一格稿紙（促音與長音的格子以斜線格標出「停一拍」「拉長一拍」），按播放時整詞送 TTS，收到 `TtsStarted` 後依 `總時長 / 拍數` 等距逐格亮起。總時長用該詞上一次 `TtsStarted`→`TtsCompleted` 的實測值，第一次用 `拍數 × 320ms`。單拍不分開送 TTS，因為 っ、ー 無法單獨成音（`listen_disabled`），拍感要靠完整詞。無聲模式時以每拍 500ms 亮格並標示「無聲示範」。reduced motion 只改變格子底色，不做過渡。
3. `sound_groups` 用 S2 的 A/B 元件。`SoundGroupKindDto::Accent` 固定標註「由裝置合成，僅供參考」。
4. `drill_ids` 非空時，「測試一下」進 `/session/drill?drills=<drill_ids>`（`minimal_pair`）。L3 內不顯示此按鈕，由後續的 `KanaQuiz` 步驟出題。

### 3.4 單字

**V1 主題與搜尋**：`vocab_topics` 列出主題，頂部一個搜尋框（「搜尋：中文、假名、漢字或羅馬字」）。輸入停頓 200ms 呼叫 `search_vocab(query, 50)`，比對方式由 Rust 決定（`rust-core.md` §9.4），初學者打羅馬字或中文都找得到。結果用 V2 的單字列。

**V2 單字列表**：`vocab_page(filter, offset, 50)`，往下捲分頁。篩選放在頂部一行，寫進 URL：`only_introduced`（「只看學過的」，預設關）、`only_starred`（「收藏」）、`srs_state`（未學／學習中／複習中／熟練）。不鎖定任何主題；每列標出課次（「第 5 課」），未介紹的字淡色顯示，可點開。

V2、V3 的單字列是一行一字（細線分隔，不是卡片）：左單字、中間假名、右狀態與播放鈕。

**V3 單字詳情**（`vocab_detail`）：單字、假名、romaji（依 §3.7）、音調線（`accent` 非 None 時）、意思、參考級別（`jlpt`：「參考 N5」、「參考 N4」、`Beyond` 為「未列入參考詞表」，僅表示參考清單未收錄，不推定程度；`content_stage = P0a` 時只顯示 N5 的「參考 N5」，N4 與 Beyond 不顯示標籤）、`use_level`（`FriendsOnly`「非正式用語」、`RecognizeOnly`「聽懂就好」）、`trans`（他動詞／自動詞）、`hook_zh`、`trap_zh`、`pair`（自他成對）、`reading_family`（同字異讀）、`conjugations`（`form` 是 MixedText，用 `MixedText` 顯示）、例句（`RubyLine`＋播放）、`notes`（用 N1 的 `NoteBody`）。頂部右側兩個標記鈕：**已會**、**收藏**，呼叫 `set_vocab_flags(vocab_id, VocabFlagsDto{known, starred})`。已會的字不再排入複習；取消已會即恢復。「已會」按下時的說明：「這個字之後不會出現在複習裡。」

**V4 字卡**（`session_next` 逐張拉取，Dart 不維護佇列，下一張取決於 Rust 的排程）：

1. **題目**：依 `SessionCardDto.question.body` 分派（§3.6），**不是一律翻面**。`Recog`、`VocabListen`、`KanaRead`、`KanaListen`、`KanaConfuse` 是 `Choice`，自動判定；`use` 卡的題型來自演練題，可能是 `Choice`、`Reorder`；`Typing` 只用於 `conjugate` 與 `kana_word`，FSRS 卡片不會出現。
2. **自評型**（`SelfGrade`）：`Produce` 與干擾項不足時退回的 `Recog`、`VocabListen`。正面顯示中文或單字，點卡片或空白鍵翻面。Y 軸 3D 翻轉 280ms；reduced motion 時改 120ms 交叉淡入。
3. **評分列只在 `SelfGrade` 翻面後出現**，4 鍵等寬：再一次／困難／記得／簡單。`show_rating_intervals` 為真時才在鍵上顯示 `rating_previews` 的下次間隔（預設隱藏，FSRS 間隔對零基礎者是術語）。色彩只是輔助，文字永遠存在。桌面鍵盤 1–4。**不做滑動評分**，避免誤觸。
4. **答後展開**（`Choice`、`Reorder` 答完後，`SelfGrade` 翻面後）：`content_id` 為 `vo.*` 時呼叫 `vocab_detail`，顯示單字、romaji（依 §3.7）、意思、一個例句（`RubyLine`＋播放）、`hook_zh`、`trap_zh`、`notes`。徽章：含 `NoteDto::FalseFriend` 顯示「同形異義」（`shu`）並列出 `ja_zh`／`misread_zh`；含 `NoteDto::Shinjitai` 顯示「和正體不同」；`use_level = RecognizeOnly` 顯示「聽懂就好」。`gr.*` 用 `focus_ids` 的語法重點。
5. `submit_answer(AnswerDto)` 即寫入（`expected_reps` 來自 `SessionCardDto`，`hint_used = false`，`attempts = 1`）。`StaleCard` 代表連點，靜默忽略並取下一張。`Done` 時回完成頁或 T2。

`PromptDto.autoplay` 由 Rust 決定（例：與中文同形的字 `Recog` 先播音，`hide_text_until_answered = true`）。實際自動播放還要滿足 `settings.autoplay` 與 `!accessibleNavigation`；否則顯示大播放鈕由使用者按。

### 3.5 文法點

**G1 列表**：`grammar_list(stage, query)`，依 `stage_id` 分組，頂部搜尋框（`?q=`）。列上顯示 `GrammarStatus`（`NotStarted` 淡色加課次、`Introduced`「讀過」、`Practiced`「練過」），狀態由 Rust 推導，Dart 不寫入。所有文法點都可點開，不鎖定。

**G2** 像一頁短文章，順序固定，對應課綱 §5.4。所有中文欄位與 `pattern`、`formation` 走 `MixedText`，日文有振假名標記時顯示振假名：

1. 標題、`pattern`（`PatternBlocks`，把 `parse_mixed_text` 的 `Ja` 段畫成實心塊，`Zh` 段的 N、V 畫成空框）、`meaning_zh` 一行大字、`explain_zh`。
2. **和中文比一比**：`compare_zh`，左側 `ai` 色直線。**容易錯**：`trap_zh`，左側 `shu` 色直線。
3. `formation` 表（必要時）。例句先顯示 3 句，其餘展開，每句 `RubyLine`＋播放＋中文。`contrast` 連結。
4. **相關術語**（`terms`，P0 不做首次彈窗）：術語列，點開底部面板顯示 `NoteDto::Term` 的 `body_zh`，下方連到 `/learn/notes?kind=term`。
5. **小測驗**：3 題，`drill_session(DrillFilterDto{target: id, count: 3}, seed, audio)`，內嵌在頁面底部使用 `QuestionView`，作答用 `grade_drill`。完成不蓋章；「讀過／練過」由 `item_intro` 與 `use` 卡狀態推導。

### 3.6 句型演練各題型

Rust 把題型收斂成 6 種 `QuestionBodyDto`（`rust-core.md` §8.4、§8.6）。`QuestionView`（題幹、作答、回饋條、「繼續」，在 `core/question/`）依 body 選元件，依 `question_type` 調整題幹與選項語言。L3、V4、K2、D2、D3、G2 共用同一份。D2 答錯者本回合末重出一次。

| Body | 元件 | 互動 |
|---|---|---|
| `Choice` | `ChoiceBody` | 選項列，答對答錯由 `correct_option_id` 立即回饋，最終以 Rust 回傳為準。選項有 `sentence` 時用 `RubyLine`，否則 `text`。`blank_word_index` 非 None 時在 `RubyLine` 內畫空格 |
| `Reorder` | `ReorderBody` | 上方稿紙答題線、下方詞塊 tile（≥48 高）。**點一下移動**，再點移回。`accept_orders` 僅供立即回饋，以 Rust 判定為準 |
| `Typing` | `TypingBody` | **輸入羅馬字**，用 `romaji_input_preview`（同步）即時顯示假名。初學者不需要裝日文輸入法。`TextField` 設 `keyboardType: TextInputType.visiblePassword`、`autocorrect: false`、`enableSuggestions: false`、`enableIMEPersonalizedLearning: false`、`textCapitalization: none`，讓注音鍵盤的使用者直接得到 Latin 鍵盤（【實測】原始碼：iOS 對應 `UIKeyboardTypeASCIICapable`，Android 對應 `TYPE_TEXT_VARIATION_VISIBLE_PASSWORD`；實際鍵盤【待實機】） |
| `Match` | `MatchBody` | 兩欄配對，Dart 判定（僅 `KanaMatch`） |
| `SelfGrade` | `SelfGradeBody` | 翻面看 `reveal` 後用 `RatingBar` 自評，評分列只在此 body 出現 |
| `Shadow` | `ShadowBody` | 播放 → 空檔（句長×1.5，線條倒數）→ 自評三級，`AnswerPayload::Shadow{level}` |

| question_type | Body | 題幹與答後 |
|---|---|---|
| `Substitution` | Choice／Reorder | 句框的 slot 以稿紙空格強調，上方是該列中文；答後自動朗讀並提示「跟著念一次」 |
| `Reorder` | Reorder | `hide_text_until_answered=true`（`audio_first`）時分兩段：先只有播放鈕，播過一次才按「開始拼句」顯示詞塊，完整句子在答題後才出現 |
| `ParticleFill` | Choice | 題幹上方顯示句子中文（`plain_text`），`RubyLine` 內的空格，底部一排助詞鍵。答後顯示 `explain_zh` |
| `ZhToJaChoice` | Choice | 中文題幹，日文選項。選錯時顯示該項 `why_zh` |
| `ListenMeaning` | Choice | 只有播放鈕，文字以伏字條遮住；中文選項。答後展開全文、假名、中文、語法重點 |
| `SituationResponse` | Choice | 情境＋（可有）對方台詞；日文選項；選錯顯示 `why_zh` |
| `Conjugate` | Typing | 字典形＋目標形（例：「て形」）；答後顯示 `correct_display` 與 `romanize_reading(expected_reading, Word)` 並朗讀 |
| `RegisterConvert` | Reorder | 顯示原句與目標語體（常體／敬體），把詞塊排成目標語體 |
| `Shadowing` | Shadow | 自評：跟上了（`Kept`）／差一點（`Almost`）／跟不上（`Lost`）。可重播，不評分發音，**不進 FSRS**，只存練習統計 |
| `FalseFriend` | Choice | 問句＋中文選項；答後顯示 `explain_zh`（筆記內容） |

假名題見 §3.3，字卡題見 §3.4。

**答後語法重點**：每題的 `focus_ids` 逐一呼叫 `peek`，在回饋條內一次展開，和全文、假名、中文同時出現（課綱 §10.2）。

`PromptDto.hide_text_until_answered` 為真時，`QuestionView` 不把日文、假名、羅馬字放進 widget tree（不是視覺遮蓋），測試用 `find.text` 確認。選項語言由 `question_type` 決定（`optionLanguageOf`，§7.2）。

`PromptDto.text` 用 `RubyLine`，`plain_text` 與 `correct_display` 用 `MixedText`（`rust-core.md` §9.5），大字題幹的字級依 `question_type`：`KanaRead`、`KanaConfuse`、`KanaWord` 的 `plain_text` 用 `jaHero`，其餘用內文字級。

**D1 入口**：依課列出，進 `/session/drill?lesson=<id>`，用 `DrillFilterDto{lesson_id, count: 10}`。空狀態「這課目前沒有題目」。

**D3 里程碑檢定**（`checkpoint_start(milestone_id, seed, audio)`，K19、KK08 只有假名與規則題）：

1. 開始前一頁：里程碑名稱、題數、「中途不顯示對錯」。按鈕「開始」與「先略過」。「先略過」呼叫 `checkpoint_dismiss(milestone_id, audio)`，回傳 `TodayViewDto`，T2 接下一項，之後仍可從 P1 手動開始（`MilestoneDto.dismissed` 顯示「已略過，可隨時開始」）。
2. 作答：`QuestionView` 不顯示回饋，把每題的 `AnswerDto`（`expected_reps = 0`，其餘同 §5.3）累積在狀態中。離開後以同 seed 重做。
3. 結束呼叫 `checkpoint_finish(milestone_id, answers)`，**全部由 Rust 判定**。`passed` 為真時蓋章；未通過只建議複習，不鎖任何內容，文案「可以先往下學，有空再回來」。
4. 列出 `weak_ids`（逐一 `peek`）：`gr.*` 連到 G2、`vo.*` 連到 V3、`ka.*` 連到 K1，`gr.*`、`vo.*` 另有「練這題」進 `/session/drill?target=<id>`。

### 3.7 聽力與語音

**顯示規則**：由 Rust 的 `display_policy(DisplayContext{lesson_id})` 依**內容所屬的課**算出（課綱 §10.2），回看舊課不受目前進度影響，Dart 只套用。使用 `FutureProvider.family<DisplayPolicyDto, DisplayContext>`（FRB 產生的類別有 `==`）。

| 畫面 | `DisplayContext` |
|---|---|
| L2、V2、V3、G2、L3 的 Vocab／Grammar 步驟 | 該內容的 `lesson_id` |
| S3、S4 | `DialogueDto.lesson_id` |
| V4、D2、D3、聽力任務 | `questionContext(peek, fallback)`，見下 |

```dart
DisplayContext questionContext(PeekDto? peeked, String fallbackLessonId) =>
    DisplayContext(lessonId: peeked?.lessonId ?? fallbackLessonId);
```

`peeked` 來自 `peek(ref.content_id)`，以 content id 快取。`se.*` 不呼叫 `peek`，`fallbackLessonId` 依序為 D2 的 `lesson` 參數、T2 任務的 `lesson_id`、`PlanViewDto.current_lesson_id`；游標走完全部已發布的課時 `current_lesson_id` 為 None，改用 `course_overview` 的最後一個 L 課。`ka.*` 題目不套用規則，romaji 以選項為準。

| `RomajiMode` | 行為 |
|---|---|
| `Shown` | 永遠顯示 |
| `ShownToggleable` | 預設顯示，頁面右上開關可收起（只影響當前頁，全域用設定） |
| `TapToReveal` | 預設隱藏，每行末端有「aA」小按鈕，按下顯示該行 romaji，下一題重置 |
| `LongPressOnly` | 長按單字顯示該字 romaji；語意動作「顯示羅馬字」 |
| `Hidden` | 不顯示 |

`FuriganaMode`：`All`、`UnknownOnly`（`is_known` 的詞由 Dart 隱藏 ruby）。`word_spacing` 為真時顯示分詞空格。使用者的 `romaji_override`、`furigana_override` 優先。

**L09 起的確認**：`display_policy` 對 L09 以後的內容，在 `ms.kata` 未通過且 `romaji_off_confirmed = false` 時仍回 `TapToReveal`。游標到 L09 起，T1 頂部出現一行：「片假名還沒考過。要把羅馬字收起來嗎？」按鈕「收起來」（`update_settings(romaji_off_confirmed: true)`）與「先留著」（本日不再問）。X1 也有同一開關。

**點字查詢**：`RubyLine` 的詞可點，開 `WordPeek` 底部面板。`ref_id` 非 None 時呼叫 `peek`，顯示 `title`、`kana`、`romaji`、`summary_zh` 與「看完整內容」。`PeekDto.title` 依前綴呈現：`ref_id` 為 `vo.`、`ka.` 開頭時用 `JaText`，其餘用 `MixedText`；`summary_zh` 一律用 `MixedText`（`rust-core.md` §9.4）。答後語法重點與 D3 弱項的 `peek` 結果同此規則。`ref_id` 為 None 且 `gloss_zh` 非 None（`@new`）時顯示 `gloss_zh`，沒有連結。聽力作答前停用。

**S2 語音示範**：`sound_groups` 依 `SoundGroupKindDto` 分區（清濁、長短音、促音、拗音、音調）。每組是一對 A/B 大按鈕，文字＋中文＋播放，可切慢速。`SoundPairDto.listen_disabled` 為真時該對只顯示文字。`Accent` 區固定標註「由裝置合成，僅供參考」。`test_drill_ids` 非空時，下方「測試一下」進 D2（`minimal_pair`）。

**S3 對話列表**：`dialogues()`，`locked` 時淡色顯示課次（報讀念「還沒學到第 N 課」，淡色對報讀無效），仍可點進 S4，S4 頂部標「還沒學到第 N 課，可以先聽聽看。」（是否還沒學到只看 `dialogues()` 的 `locked`，讀不到列表時不標）；L2 課程詳情的對話列用同一個元件（`DialogueSummaryTile`）。課次由 `lessonNumberLabel` 依課 id 轉成可讀名稱：`le.l05`「第 5 課」、`le.k03`「平假名第 3 課」、`le.kk02`「片假名第 2 課」，無法辨識的 id 才原樣顯示。

**S4 對話**：固定四階段（課綱 §7），頂部以「一二三四」顯示，從 T2 進入時只跑 `Integration.phases`（10 分方案分兩天），從 S3 手動進入時跑全部。實戰與常體版對話由 Rust 輪替排進 `Integration`，畫面相同。

1. **盲聽**：只顯示 `scene_zh`。對白以伏字條（長度對應句長的墨線）呈現，全篇連播，接 `quiz_drill_ids`（`DrillFilterDto.drill_ids`，為空時跳過）。
2. **逐句**：展開全文。逐句播放，附中文與 `note_zh`。可切「逐詞」（詞間 400ms，每詞送 `WordDto.speech_kana`）。
3. **跟讀**：逐句播放＋空檔。
4. **角色扮演**：選角色。對方由 TTS 發聲，輪到自己時顯示台詞與空檔，可按「隱藏我的台詞」增加難度。

`audio_first` 的做法是「先聽，再顯示詞塊」（課綱 §10.2）。**無聲模式**時第一、三階段略過，第二階段只顯示文字，第四階段對方台詞以文字呈現。

角色語音：`roles[].voice` 為 a/b。裝置有 ≥2 個日語語音時分別指派，否則以 pitch（a=1.0、b=1.15）區分。

**S5 專區、S6 專區項目、看劇／聽歌任務**：已移除（見 RULINGS O13）。畫面代號 S5、S6 留空，不重新編號。

**跟讀的錄音回放**：屬 P1。原因是要加麥克風權限與兩個原生外掛，且 `audioplayers_linux` 會弄壞目前的 Linux 建置（實證 #17）。程式保留 `ShadowRecorder` 介面（`isAvailable == false` 時隱藏按鈕），P1 再實作。

### 3.8 計畫

P1 由上而下：

1. **里程碑線**：`MilestoneRail` 依 `PlanViewDto.milestones` 動態繪製，點數等於已發布里程碑數（`p0a` 為 3 個，預設 `p0` 為 6 個），已達成的蓋章（`passed`）。點開顯示 `pass_ratio`（「建議門檻 80%」）、`questions`、`best_score_percent`、`forecast_date`（標「粗估」）與「開始檢定」。
2. **目前位置**：第幾課（`current_lesson_id` 為 None 時顯示「這一版的內容都學完了，複習照常」）、`main_forecast_end`（文字標明「粗估」）。`status=Behind` 時顯示 `suggested_minutes` 的建議，一鍵套用。
3. **四週月曆**：28 個稿紙格（`calendar`），`is_active` 的日子蓋小章，非學習日留白。
4. **「調整計畫」**（底部面板）：分鐘數、學習日、目標日期。**套用前顯示影響**（`plan_preview`）。文字說明「只影響之後的安排，不會重置進度」。

| `content_stage` | 完成日的文字 | P2 關於程度 |
|---|---|---|
| `P0a` | 「假名與入門七課約在 M/D 完成（粗估）」 | 只寫「假名與入門七課」，不放 N4、日劇的內容 |
| `P0` | 「本版到 L30，約在 M/D 完成（粗估）」 | 課綱 §1.2、§1.3 的 `p0` 欄，「參考 N5」 |
| `Full` | 「完整版到 L48，約在 M/D 完成（粗估）」 | 課綱 §1.2、§1.3 的 `full` 欄 |

### 3.9 設定

- **語音**（X2）：狀態、測試播放、**無聲模式**（`silent_mode`）、慢速預設（`tts_rate`）、自動播放（`autoplay`）、語音選擇（≥2 個時，`voice_id`）、裝置設定教學。
- **顯示**：romaji（`romaji_override`，含「依課程」）、振假名（`furigana_override`）、L09 起收起羅馬字（`romaji_off_confirmed`）、主題（`theme_mode`）、評分鈕顯示間隔（`show_rating_intervals`）、字級預覽。
- **無障礙**：假名時限（`kana_time_limit`，關閉時不看 3 秒）。
- **資料**：清除全部進度（兩段式確認，第二段要輸入「清除」，呼叫 `reset_all`）。回傳 `Storage` 時顯示「請重新啟動 App」。成功後把 `onboardingDone` 設 false 回到引導。
- **關於**：程度說明（P2）、語音限制、字型授權。

全部用 `update_settings(SettingsPatchDto)` 寫入。可空欄位清除用 `clear_romaji_override`、`clear_furigana_override`、`clear_voice_id`。

### 3.10 新內容學習（L3）

L3 是 T2 執行 `NewContent` 的元件，也是使用者第一次接觸內容的地方。流程固定為**呈現、播音、立即一題**。呼叫 `new_content_session(task_key, seed, audio)`，依序呈現 `steps`：

| `NewContentStepDto` | 元件 | 內容 | 作答 |
|---|---|---|---|
| `Kana` | `KanaTeachCard` | 大字（`jaHero`）、自動播一次（`listen_disabled` 為真時不播）、romaji、`origin_kanji`、`hint_zh`（`MixedText`）、例字可播；按「下一步」 | 無 |
| `KanaQuiz` | `KanaQuizBody` | 假名題（§3.3），每批 3 字，每字兩題；第一批三選一。K11–K15 的切片最後再接一個手寫題的 `KanaQuiz`（`minimal_pair`、`kana_word`，rust-core §9.4） | `kana_submit` |
| `Rule` | K3 的 `RuleCardView` | §3.3 | 無，後接 `KanaQuiz`（`minimal_pair`） |
| `Confusable` | `ConfusableView` | `members` 並排大字、`literals`、`diff_zh`，各字可播 | 無，後接 `KanaQuiz`（`kana_confuse`） |
| `Vocab` | `VocabTeachCard` | 單字、假名、romaji（依 §3.7）、意思、自動播一次、一個例句、`hook_zh`、`trap_zh`、同形異義與字形徽章 | `first_card` 非 None 時按「考一題」出一題，`submit_answer` |
| `Grammar` | `GrammarTeachCard` | 標題、`pattern`、`meaning_zh`、`explain_zh`、`compare_zh`、`trap_zh`、完整 `formation` 接續表、1–2 句例句；接續表與 G2 共用，窄版上下排列 | 同上 |

- 頂部細線進度條（已完成步驟／總步驟）。**先教後考**：第一題必定考剛呈現過的內容，不會猜。
- `first_card` 是 `SessionCardDto`，用 V4 的 `CardRunner` 單張模式，答後展開、評分規則與 §3.4 相同。此卡當場離開 state=0，隔天不會誤判為「沒看完」。
- **斷點續做**：重新進入時，開頭連續 `first_card = None` 的 `Vocab`、`Grammar` 步驟直接跳過，從第一個還沒答的步驟開始。假名步驟沒有斷點，從頭再走一次（熟練已寫入）。全部都跳過時直接 `complete_task`。
- 全部步驟完成後 `complete_task(task_key, durationMs, audio)`。L3 不自行寫 `item_intro`。
- 中途按「今天先到這」不結案，回 T1 顯示「繼續」。

### 3.11 漢字陷阱（N1）

從 L1 進入（`notes_available` 為真時），G2 的術語也連到此頁。五個分頁對應 `note_list(NoteKind)`：同形異義（`FalseFriend`）、字形對照（`Shinjitai`）、讀音規律（`Reading`）、語言轉移（`Transfer`）、術語（`Term`）。`?kind=` 記住目前分頁。

每列用 `NoteBody`，以 `switch` 窮舉 sealed `NoteDto`：`FalseFriend` 為「日文意思／容易誤解成」兩行並連到 `vocab_id`；`Shinjitai` 為日文字形與台灣正體大字對照，日文一律 `JaText`，中間的標籤與下方一行說明依 `kind`：`simplified_differently`、`shape_detail`、`variant_split`（日文依意思分成兩個並存的字，如 着／著，台灣只用一個字）標「對照」，`kokuji` 標「意思近」並說明「日本自創的漢字，台灣不用」；`Reading` 含台語、華語對照例字與 `caveat_zh`，`examples[].ja` 走 `MixedText`；`Transfer` 為錯誤句與正確句，錯誤句用刪除線加 `shu` 色；`Term` 為術語與 `body_zh`，連到 `grammar_ids`。`p0a` 的 `note_list` 回空，入口也不露出；預設 `p0` 五類共 232 則。

### 3.12 題型首次操作提示

每種 `QuestionType` 第一次出現時，`QuestionView` 在題幹上方顯示一條 `QuestionHintStrip`（一行文字＋「知道了」），不擋作答。「知道了」平常在文字右側；扣掉按鈕後文字欄放不下 12 個內文字（`_minCharsBeside`，依實際寬度與縮放後字級判斷，例如 320 寬＋2 倍字級、375 寬＋1.5 倍）時改放到文字下方靠右（按鈕縮成內容寬度，點擊範圍不撐滿整列），文字用滿整列。顯示當下把該值加進 `SettingsDto.seen_question_hints` 並 `update_settings`，所以只出現一次；寫入失敗只記 log。`questionHintOf(QuestionType)` 用 `switch` 窮舉：

| 題型 | 提示 |
|---|---|
| `Recog` | 看日文，選出意思。 |
| `VocabListen` | 聽發音，選出意思。 |
| `Produce` | 看中文，先在心裡說出日文，再翻面自評。 |
| `KanaRead` | 看字，選出讀音。 |
| `KanaListen` | 聽音，選出聽到的字。 |
| `KanaMatch` | 先點左邊的字，再點右邊的讀音。 |
| `KanaConfuse` | 這幾個字長得很像，選出正確的那個。 |
| `MinimalPair` | 聽一次，選出你聽到的是哪一個。 |
| `KanaWord` | 拼拼看這個詞，選出意思或打出讀音。 |
| `Substitution` | 依中文提示，選出要換進空格的字詞。 |
| `Reorder` | 點詞塊排出句子，再點一下可以放回去。 |
| `ParticleFill` | 選出空格裡該放的助詞。 |
| `ZhToJaChoice` | 看中文，選出最自然的日文。 |
| `ListenMeaning` | 先聽，再選意思。答完才看得到文字。 |
| `SituationResponse` | 想想這個情境，選出最得體的回應。 |
| `Conjugate` | 用英文字母打出答案，上方會顯示假名。 |
| `RegisterConvert` | 把這句換成指定的語氣，點詞塊排好。 |
| `Shadowing` | 聽完跟著念，再選跟得上的程度。不評分發音。 |
| `FalseFriend` | 字面長得像中文，選出它在日文的意思。 |

第一次看到自評按鈕時，`RatingBar` 上方另有一行：「依你記得的程度選，App 會決定下次何時複習。」

---

## 4. 視覺方向：原稿と朱印

### 4.1 概念

不做和風裝飾，而是借用兩個真實物件的**結構**：

- **原稿用紙**（稿紙）：五十音表本來就是格子，稿紙格線直接成為全 App 的版面模組。內容寬度切 5 欄，假名格、月曆、答題線、頁面對齊全部來自同一套格線。
- **朱印**：學習的成就感來自「被蓋章」。完成不用進度環或紙花，只有一個略為歪斜的印。

編排規則，這些比配色更決定成品是否像模板：

1. **左對齊、不對稱**。大標題靠左，右上角留給印章。不做置中 hero。
2. **以細線分隔，不用卡片**。列表是線與留白。只有真的「拿在手上」的物件（字卡、底部面板）才有陰影。
3. **色彩稀缺**。主按鈕是墨色實心，`shu` 只用於印章、答錯、「再一次」與當前項的小標記。一個畫面出現超過兩處朱色就是設計錯誤。
4. **字級對比大**。標題 28–36、內文 16，大字假名 56 以上。
5. **日文一律教科書體**，它同時是視覺特色與教學需求（§4.3）。

已用 spike 在 320／375 寬、淺深色、字級 2.0 倍渲染過此方向的原型，版面成立。

### 4.2 Design tokens

檔案：`lib/design/tokens.dart`，以 `ThemeExtension<AppTokens>` 提供。

**色彩**（對比度為【實測】WCAG 公式，對 base／raised／sunken）

| Token | 淺色 | 深色 | 語意 | 淺色對比 | 深色對比 |
|---|---|---|---|---|---|
| `paper.base` | `#F5EFE0` | `#17140F` | 頁面底 | | |
| `paper.raised` | `#FBF7EC` | `#221E18` | 字卡、面板 | | |
| `paper.sunken` | `#EBE3CF` | `#100E0A` | 骨架、作答槽 | | |
| `ink.primary` | `#1E1A15` | `#EFE8D8` | 主文字、主按鈕底 | 15.1/16.2/13.5 | 15.1/13.6/15.8 |
| `ink.secondary` | `#5B5346` | `#B9AF9D` | 振假名、romaji、說明 | 6.6/7.1/5.9 | 8.5/7.6/8.9 |
| `ink.tertiary` | `#675E50` | `#9A907F` | 未學假名、註解 | 5.6/6.0/5.0 | 5.8/5.3/6.1 |
| `line.grid` | `#CFA08F` | `#4A3B33` | 稿紙格線（純裝飾） | 2.0 | 1.7 |
| `line.strong` | `#8A6A5C` | `#8C7768` | 需辨識的元件邊界（選項框、輸入槽） | 4.3/4.6/3.8 | 4.3/3.9/4.6 |
| `shu` | `#A92716` | `#EC7560` | 印章、答錯、再一次 | 6.1/6.6/5.5 | 6.4/5.8/6.7 |
| `onShu` | `#FFF8EE` | `#1B0F0A` | 朱底文字 | 6.7 | 6.5 |
| `ai` | `#24466F` | `#93B3DE` | 焦點框、聽力、記得 | 8.4/9.0/7.5 | 8.5/7.7/9.0 |
| `moegi` | `#3F6212` | `#A9C873` | 答對、簡單 | 6.2/6.6/5.5 | 9.8/8.8/10.3 |
| `kincha` | `#7A4F05` | `#E0B45C` | 警示、困難 | 6.2/6.7/5.6 | 9.5/8.6/10.0 |

**字級**（單位 logical px；`clamp` 為該級的最大字級縮放）

| Token | 字型 | 大小/行高 | clamp | 用途 |
|---|---|---|---|---|
| `displayL` | Noto Serif TC 800 | 36/46 | 1.3 | 今日標題（只放 `lib/` 內的固定字串與數字） |
| `displayM` | Noto Serif TC 800 | 28/36 | 1.3 | 頁標題（同上） |
| `title` | Noto Sans TC 700 | 20/28 | 1.5 | 區塊標題 |
| `body` | Noto Sans TC 400 | 16/26 | 2.0 | 內文 |
| `label` | Noto Sans TC 700 | 14/20 | 1.5 | 按鈕、標籤 |
| `caption` | Noto Sans TC 400 | 13/20 | 2.0 | 註解 |
| `jaHero` | Klee 600 | 56/72 | 1.2 | 字卡主字 |
| `jaSentence` | Klee 400 | 24/34 | 1.6 | 例句 |
| `jaBody` | Klee 400 | 18/30 | 2.0 | 句中日文 |
| `ruby` | Klee 600 | 基字×0.48，最小 12（`RubyLine` 基字最小 22） | 隨基字 | 振假名 |
| `romaji` | Noto Sans TC 400 | 基字×0.46，最小 12 | 1.5 | 羅馬字 |

`displayL`、`displayM` 的 Noto Serif TC 只打包 `lib/` 實際用字（§4.3），來自內容的字串（課名 `title_zh`）一律用 `title`。

假名格內字級 = 格寬×0.5，不隨字級縮放（格子已夠大，縮放會破壞對位）；romaji 依表。中文不用負字距；小標 `letterSpacing: 2`。

**間距**：`s1=4, s2=8, s3=12, s4=16, s5=24, s6=32, s7=48, s8=72`。節奏：同組內 8–12，組與組 24，區塊與區塊 48。頁面側邊 16（寬度 <360）或 24。內容最大寬 720；≥1024 時兩欄，主欄 720。**稿紙模組**：`cell = floor(內容寬 / 5)`，列距 6。

**圓角**：`r0=0`（稿紙格、列表、字卡）、`r1=2`（按鈕、tile）、`r2=印章邊長×0.12`。App 不使用大圓角或膠囊形。

**陰影**（暖色、低擴散）：`paper1 = 0 1 0 #1E1A1510, 0 2 6 #1E1A1514`；`paper2 = 0 6 16 #1E1A1520`。深色模式不用陰影，改 1px `line.grid` 邊框加 `paper.raised`。

**動效**

| Token | 時長 | 曲線 | 用途 | reduced motion |
|---|---|---|---|---|
| `fast` | 120ms | easeOut | hover、按壓 | 同 |
| `base` | 220ms | easeOutCubic | 回饋條、展開 | 0ms |
| `page` | 280ms | easeOutCubic | 轉場、翻卡 | 翻卡 120ms 淡入，轉場 0ms |
| `stamp` | 360ms | easeOutBack | 蓋章：scale 1.4→1、旋轉 -8°→-6°、透明度 0→1 | 120ms 淡入 |

只動 `transform` 與 `opacity`。播放中的音波動畫在 reduced motion 時改為靜止圖形加文字「播放中」。

**質感**：`assets/textures/washi_256.png`（256px 灰階紙纖維，≤20KB，由 `tools/` 腳本產生）以 `ImageRepeat.repeat` 疊在 `paper.base`，透明度淺色 5%、深色 3%；高對比模式關閉。

### 4.3 字型

| 角色 | 字型 | 字重 | 子集 | 原始檔 | 子集 | 授權 |
|---|---|---|---|---|---|---|
| 所有日文（family `KleeOneJP`） | Klee One | 400、600 | 常用漢字聯集內容用字（`make_charset.py` 產生） | 8.7MB×2 | 常用漢字子集 1.45＋1.49MB【實測】，聯集內容用字後略增 | OFL 1.1 |
| 中文 UI 與內文（`NotoSansTC`） | Noto Sans TC | 400、700（靜態實例） | Big5 常用字＋ASCII | 11.9MB（可變） | 1.98×2MB | OFL 1.1 |
| 中文標題（`NotoSerifTC`） | Noto Serif TC | 800（靜態實例） | `lib/` 實際用字＋ASCII 數字與標點 | 16.9MB（可變） | 估計約 0.5MB（Big5 子集實測 2.77MB／5,401 字，換算約 1,000 字） | OFL 1.1 |

合計約 7.4MB，預算 12MB。**為什麼選 Klee One**：它是教科書風格的字形，き、さ、そ、ふ、ら、り 的筆形接近手寫。黑體常把這些字連筆，初學者學到的字形會和手寫不同。這是教學上的理由，也恰好是視覺識別。缺點是細，所以 ruby 用 600，並避免小於 12px。

**為什麼打包中文字型**：(a) iOS 的 PingFang 與 Android 的 Noto 字寬、行高不同，打包後 320 寬的 golden 才代表使用者實際看到的版面；(b) 手機沒有內建繁中明體，Noto Serif TC 無論如何都要打包，它是編輯風格的主要來源，只取 `lib/` 實際用字以減少體積。若 APK 大小成為問題，把 token 的 `NotoSansTC` 換成系統字型是單點修改。

**不用 LXGW WenKai TC**：該字型採傳承字形，`no.sj.*` 的字形對照內容不能用它（reuse §5.4）。

**為什麼用靜態實例**：pubspec 的 `weight:` 對應靜態字重最單純；可變字型需另外傳 `fontVariations`。【實測】請求 700 時選到 600，不會產生假粗體（像素相同），所以 token 只使用已打包的字重。

**建置**：Klee One 依 `reuse-and-verification.md` §5.3（`tools/fonts/`），字元集由 `make_charset.py` 產生，內容是常用漢字聯集內容用字，因為內容用到常用漢字以外的字（例如 飴，以及假名字源 `origin_kanji` 的 乃、阿）。F01 lint 擋日文缺字，F02 檢查每個打包字型都有授權檔。中文子集同樣用 `--layout-features='kern,palt,liga,ccmp,locl,mark,mkmk' --no-hinting`，CI 另檢查 `lib/**/*.dart` 的非 ASCII 中文都在 `NotoSansTC` 內，`NotoSerifTC` 子集依 `reuse-and-verification.md` §5.3 的 `charset_noto_serif.txt` 產生，CI 重新產生並比對，介面文字改動時要一併更新。子集成品 commit 進 repo。

**授權**：子集屬於 OFL 的 Modified Version。Klee、Noto Serif TC 未宣告 Reserved Font Name；Noto Sans TC 的 RFN 是「Source」，新名稱不含該字。「Klee」是 Fontworks 商標，只作內部 family 名，不用於產品名稱。Klee、Noto Sans TC、Noto Serif TC 的 `OFL.txt` 都放 `assets/fonts/licenses/`，並登錄在 `THIRD_PARTY_NOTICES.md`，啟動時以 `LicenseRegistry.addLicense` 註冊，X3 顯示。

### 4.4 元件清單（`lib/design/widgets/`）

| 元件 | 內容 | 狀態與無障礙 |
|---|---|---|
| `PaperScaffold` | 頁面骨架：`Material(transparency)`、紙底、紙紋、SafeArea、最大寬 | 所有畫面的根 |
| `InkNavBar` | 底部與側邊導覽，當前項以朱色方框圈住圖示字 | 語意標籤為中文、selected 狀態 |
| `GenkoGrid` | 稿紙格 `CustomPainter`＋子元件定位 | 線條 `ExcludeSemantics` |
| `KanaCell` | 假名＋romaji＋狀態點 | 未學、學習中、熟練、選取、hover/focus。語意：「か，ka，已熟練」，日文部分標 ja |
| `FlipCard` | 翻面容器 | 語意順序隨面切換；reduced motion |
| `RatingBar` | FSRS 四鍵（再一次／困難／記得／簡單），只在 `SelfGrade` 出現；間隔依 `show_rating_intervals` | 色＋文字；鍵盤 1–4 |
| `HankoBadge` | 朱印，內文 1–2 字（済、合格、学） | `textScaler: noScaling`；語意「完成」 |
| `StampOverlay` | 全頁蓋章動畫 | 播完自動淡去，不擋互動 |
| `JaText`、`RubyLine`、`MixedText`（§7）；`SpeakButton`、`SpeedToggle`（§6.5） | | |
| `ChoiceTile` | 選項，含答對答錯態 | ○／× 形狀＋文字，色彩僅輔助 |
| `WordTile` | reorder 詞塊 | 自訂語意動作「移到答案」 |
| `CensorBar` | 伏字條 | 語意「隱藏的日文」 |
| `KanaTeachCard`、`ConfusableView`、`VocabTeachCard`、`GrammarTeachCard` | L3 與 K2 的呈現卡 | 自動播放依 §3.4 的條件；「下一步」為主要焦點 |
| `RuleCardView`、`BeatStrip` | 規則卡、拍感稿紙格 | 拍格語意「第 2 拍，停一拍」；reduced motion 只換底色 |
| `QuestionHintStrip` | 題型首次操作提示 | `liveRegion: true`；「知道了」可聚焦 |
| `NoteBody` | 五種筆記的呈現 | 字形對照的日文部分標 ja |
| `FeedbackStrip` | 底部回饋 | `liveRegion: true` |
| `AnswerLine`、`PatternBlocks`、`SideRuleNote`、`MilestoneRail` | 答題線、文法公式、左側直線提示、里程碑線 | |
| `InkButton`／`GhostButton`／`ShuButton` | 主、次、警示 | 最小 48 高；hover 變 `paper.raised`；按下下移 1px；焦點 2px `ai` 外框 |
| `SkipItemButton` | T2 單項略過，T2、L3、聽力共用，文案一律「略過這一項」 | 同 `GhostButton` |
| `BackLine`（`PageBackLink`、`PopBackLine`） | 次層畫面的返回，唯一的元件：畫出來的箭頭＋文字，預設「返回」。`PageBackLink` 有上一頁就回去，否則到 `fallback`；`PopBackLine` 沒有上一頁時不顯示。引導流程的文字用「上一步」，進行中的練習用「離開」，只換文字不換元件 | 語意標籤同文字；最小 48 高 |
| `ErrorSlip`／`SkeletonLines`／`VoiceBanner` | 共通狀態 | `VoiceBanner` 分「語音不可用」與「無聲模式」兩種：前者可關閉但下次啟動仍檢查，後者常駐於 T1、S1 |

### 4.5 亮暗主題

- 淺色「和紙」、深色「墨夜」。預設跟隨系統，可手動。兩者共用同一組 token 名稱，元件不得判斷亮暗。深色的 `shu` 提亮到 `#EC7560` 以維持對比。
- 高對比（`MediaQuery.highContrastOf`）：`ink.secondary`、`ink.tertiary` 改用 `ink.primary`，`line.grid` 改 `line.strong`，關閉紙紋。
- L1 的稿紙條與課程列方格：略過的課是 `line.grid` 填色再畫一條 `ink.secondary` 斜線，未開始是空格。深色的填色和紙面太接近，所以靠斜線區分，不只靠顏色。斜線畫在填色上，對比以填色為底算（淺色 3.28、深色 4.93；`line.strong` 只有 2.11、2.52，高對比模式還和填色同色）。

### 4.6 無障礙要求

- **對比**：文字 ≥4.5:1，元件邊界 ≥3:1。`test/design/contrast_test.dart` 用公式檢查 token 配對，不用 `textContrastGuideline`（實證 #15）。
- **字級**：每級有 clamp（§4.2）。文字縮放 2.0 倍時 320 寬不得溢位（golden 涵蓋）。
- **Reduced motion**：一律透過 `AppMotion.of(context)` 取時長，內部讀 `MediaQuery.disableAnimationsOf`。元件不得寫死 Duration。
- **語意**：日文語言標註見 §7。所有圖示按鈕有中文標籤。答題回饋 `liveRegion`。
- **點擊目標**：最小 48×48（320 寬時假名格約 57px）。**不只靠顏色**：對錯有形狀與文字，狀態點有語意文字。
- **螢幕報讀與 TTS 不打架**：`MediaQuery.accessibleNavigationOf` 為真時，停用所有自動播放。
- **鍵盤**（桌面與外接鍵盤）：空白鍵翻卡、1–4 評分（僅 `SelfGrade`）、R 重播、Esc 離開。焦點順序依閱讀順序。
- **時限**：假名測驗不顯示倒數，`kana_time_limit` 可完全關閉（§3.9），時限只影響徽章，年長或肢體障礙的使用者不受影響。

---

## 5. 程式結構

見 [flutter-app-architecture.md](flutter-app-architecture.md)（目錄、狀態管理、Repository 與 Rust 介面、錯誤處理、路由與 App 根）。

---

## 6. TTS 服務

見 [flutter-app-tts.md](flutter-app-tts.md)（§6.1–§6.6）。

---

## 7. 文字渲染規則

### 7.1 實測結論

App locale 為 zh-TW，字串為「直骨角今海遅糸」，Linux 實跑比對像素：

| 情境 | 結果 |
|---|---|
| 系統字型，無 locale vs `locale: ja` | 不同。無 locale 時繼承 zh-TW，顯示中文字形 |
| Noto Sans TC（打包）＋ `locale: ja` | **locale 沒用**。除了字型沒有的 遅 之外全部維持中文字形 |
| Klee（打包）有無 locale | 完全相同，字型本身就是日文字形 |
| TC 為主、fallback Klee | 只有 遅 用 Klee，**同一句混兩種字形** |
| Klee 為主、fallback TC | 與單用 Klee 相同，fallback 只用於缺字 |
| 系統 pan-CJK `Noto Sans CJK JP`＋locale zh-TW | 顯示**中文字形**，字型名稱寫 JP 也沒用 |
| 缺字走系統 fallback | locale 會改變選到的字型 |

### 7.2 規則

1. 日文的 `TextStyle`：`fontFamily: 'KleeOneJP'`，`fontFamilyFallback` 留空。**不得把 Noto Sans TC 放進 fallback**，缺字時應走系統 fallback 並由 `locale: ja` 選字形。缺字本身由 CI 擋下。
2. 所有日文都要 `locale: Locale('ja','JP')`。Klee 雖然不受影響，但 locale 決定缺字 fallback 與螢幕報讀語言。
3. **一般日文用 `Text(data, locale: ja)`**，同時處理字形與螢幕報讀。
4. **混排的 span** 必須兩個都設：`TextSpan(text: t, locale: ja, style: style.copyWith(locale: ja))`。只設其一，字形或螢幕報讀其中之一會錯（實證 #12）。
5. 中文 UI 用 `NotoSansTC`，繼承 App locale。
6. Widget 層禁止直接用 `Text` 顯示日文，必經 `JaText`、`RubyLine`、`MixedText`。
7. `OptionDto.text` 不帶語言，由 `optionLanguageOf(QuestionType)` 決定：`ja` 用 `JaText`，`zh` 用 `MixedText`，`romaji` 用一般文字。依 `rust-core.md` §8.6 窮舉全部 19 個值，不寫 `default`，新增題型時編譯失敗：

   | `OptionLanguage` | `QuestionType` |
   |---|---|
   | `ja` | `KanaListen`、`KanaConfuse`、`Substitution`、`ParticleFill`、`ZhToJaChoice`、`SituationResponse` |
   | `zh` | `Recog`、`VocabListen`、`MinimalPair`、`KanaWord`、`ListenMeaning`、`FalseFriend` |
   | `romaji` | `KanaRead` |
   | `none` | `Produce`、`KanaMatch`、`Reorder`、`Conjugate`、`RegisterConvert`、`Shadowing` |

### 7.3 元件

**`RubyLine`**（已原型驗證）：Flutter 沒有內建 ruby。用 `Wrap` 排 `WordDto`。詞內依 `ruby: List<RubyPartDto>` 排成一列，每段是一個 `RubyBox`（ruby 在上、底字在下），romaji 放在整詞下方。

- 每段一律保留 ruby 列高度（無假名時放空白），各列基線自然對齊，不需 `WidgetSpan`。
- **ruby 懸掛**（`RubyBox`，取 JIS X 4051 ルビの掛け的精神）：ruby 比底字寬時，可以懸在相鄰、本身沒有 ruby 的假名、標點、中文或分詞空格上方，每側至多一個 ruby 字寬（ruby 寬 ÷ 字數），也不超過那段文字本身；段的版面寬度 = max(底字寬, ruby 寬 − 兩側實際可懸掛量)。兩段 ruby 夾著同一段文字時，本段兩側合計不超過那段文字的一半，另一頭的 ruby 本身不比底字寬多少時可多用（`RubyRun.budget`），所以相鄰兩段 ruby 不會重疊。純計算在 `ruby_fit.dart`、鄰居判定在 `ruby_neighbor.dart`，都有單元測試。
  - **餘量分配（1:2:1）**：懸掛額度用完後段寬還比底字寬時，多出的寬度依 JIS X 4051 分配到底字之間與兩端：字間一份、兩端各半份，單一底字就是置中，底字後面不留連續空白。作法是把多出的寬度 ÷ 底字字數當 `letterSpacing`（文字引擎把字距前後各半加在每個字兩側，`ruby_spacing_test.dart` 釘住這個行為）。字距要排版後才算得出來，由 `RenderRubyBox` 在 layout 時替換底字 `RenderParagraph` 的文字。
  - **行首、行尾**：換行位置要排過才知道，所以由 `RubyOverhangBoundary`（包住 `MixedText` 的 `RichText`、`RubyLine` 的 `Wrap`）做兩階段排版：排完檢查哪些 ruby 超出容器，取消那一側的懸掛（段因此加寬，同樣依 1:2:1 分配），再排一次，直到沒有新的超出。判定只增不減，所以一定會停；每次重排從頭判定，改寬度後不殘留。結果是 ruby 不懸出容器，貼齊容器的 ruby 只往內側懸，至多一個 ruby 字寬。
  - `unknownOnly` 下已知詞的漢字雖然不顯示讀音，仍擋住懸掛（當作有 ruby 的段），讀者才不會把懸上去的讀音當成那個漢字的。
  - 已知限制：懸在盒外的讀音點下去由鄰近的詞接住（`onWordTap` 查到隔壁的詞），點底字則正確（裁決 U3 接受）。行尾的段加寬後被換到下一行時，它的行尾判定仍保留（判定只增不減才保證會停），那段右側不懸掛，底字字距比必要的略大。
- **行首行尾禁則**（`ruby_kinsoku.dart`，JIS X 4051；表只用來比對，內容用不到、字型子集也沒有的字寫成 `\uXXXX`，否則 `verify` F04 會把原始碼裡的字當成要顯示的字）：不能落在行尾的字是開括號（`「『（【〈《〔［｛` 與半形 `([{｢`）；不能落在行首的字是收尾標點、小書き假名（`ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ`）、長音 `ー`、`々ゝゞヽヾ`。`WidgetSpan` 與 `Wrap` 的邊界文字引擎管不到，所以用同一個機制併進相鄰的 `RubyBox`：開括號併進下一個盒子（`leading`），其餘併進前一個盒子（`trailing`），ruby 可懸在併進來的字上。
  - `RubyLine`：句尾標點放進最後一段的 `RubyBox`，開括號放進下一個詞的第一段。開頭不能在行首的詞（`って`、`っす`）和前一個詞組成一組換行；那幾個開頭的字（`っ`）併進前一個詞最後一段的盒子，分詞空格畫在它前面，這組比一行還長、只能在組內換行時，換行點才不會落在這個字前面。併走的字另有點擊區，查的仍是原本的詞，羅馬字也還在原本的詞下面。挖空的詞不拆（答案不進樹），前一個詞挖空、或整個詞都是這種字時也不拆。
  - 文字引擎在純文字裡也會在小書き假名、`ー` 前換行（實測），所以 `MixedText` 不帶讀音的日文段、沒有讀音的底字，在這些字前插 U+2060（WORD JOINER，零寬）；日文段前面緊接著文字時，段首也插（中文後面的 `{ja:って}` 不落在行首），段落的第一個字不插。空白剛好超出行寬時引擎在空白之後換行，WORD JOINER 擋不住（內容常寫 `都用 {ja:って}`），所以空白後面接不能在行首的字時換成 U+00A0。報讀與比對仍是原文（`semanticsLabel`）。
  - 怎麼改回：`ruby_kinsoku.dart` 的字元表決定哪些字受限；移除某類字只要改表。
- 換行只發生在詞界，對初學者比句中斷開更好。
- 語意：整句 `MergeSemantics`，label 為句子表層文字，標 ja。
- 參數 `DisplayPolicyDto policy`、`int? blankWordIndex`（把該詞畫成稿紙空格，不把答案放進 widget tree）。`SentenceDto` 沒有 `lesson_id`，由呼叫端傳入 policy。

**`MixedText`**：中文解說內夾日文，由呼叫 `parse_mixed_text`（`#[frb(sync)]`）取得 `List<MixedSpanDto>`，Dart 只負責排版，**不做任何自動判定**。

- 內容標記一律是 `{ja:日文}`，含漢字時可寫 `{ja:飯を食べる|めしをたべる}`（課綱 §12.2），純假名也要包。語法錯誤時 Rust 整段回 `Zh`，內容 lint（R19）在建置時已擋下。
- `Zh` 段用 `NotoSansTC`；`Ja` 段依 §7.2 第 4 條設定。`Ja` 段的 `ruby` 有任何一段非 None 時，每個 part 各以 `WidgetSpan`（`PlaceholderAlignment.baseline`）包一個 `RubyBox`，否則用 `TextSpan`。整段包在 `RubyOverhangBoundary` 裡。禁則（上方）跨 `Zh`、`Ja` 段與 part 計算：前面的開括號併進盒子，後面的收尾字併進盒子，例如「知|ってる」的 `っ` 併進 `知` 的盒子。ruby 懸掛規則同 `RubyLine`（上方），相鄰文字跨 `Zh`、`Ja` 段計算；語意標籤：整段日文只在第一個畫出來的盒子標一次 ja；併進盒子的收尾標點（例如「？」」）接在那段文字後面念一次，不帶 ja；併進盒子的開括號仍由原本那段文字念（`semanticsLabel`），都不重複也不漏念。
- 適用欄位：所有 `*_zh` 與 `pattern`、`formation[].from`／`to`、`term`、`wrong`、`right`、`no.rd.*` 的 `examples[].ja`（清單由課綱 §12.2 定義），以及 `PromptDto.plain_text`、`correct_display` 與語言為 `zh` 的 `OptionDto.text`。`zh`、`example_words[].zh`、`literals[].zh`、`examples[].zh` 不走 `MixedText`，不得含假名，也不開放標記；它們被用作 `zh` 選項或 `correct_display` 時沒有標記，解析結果只有一個 `Zh` 段。
- `PeekDto.title`：`ref_id` 為 `vo.`、`ka.` 開頭時用 `JaText`，其餘用 `MixedText`（`rust-core.md` §9.4）。

`VerticalTitle`（裝飾用直排短語）以 `Column` 逐字排，只用於不含「ー」的固定字串，`ExcludeSemantics`。

---

## 8. 測試策略

見 [flutter-app-testing.md](flutter-app-testing.md)。

---

## 9. 待實機驗證與風險

實機驗證不是開發前置條件（O3）。內容與語音先用保守預設，專案產出 `docs/TTS_DEVICE_CHECKLIST.md`，專案擁有者在 Android、iOS 實機檢查後，結果透過 `tts_text`、`listen_disabled` 回寫，不需改程式。

| 項目 | 風險 | 驗證方式與備案 |
|---|---|---|
| 單一假名發音 | 行動平台 TTS 可能念字母名或不發聲（ん、小字） | `っ`、`ー`、`ゃゅょ` 預設 `listen_disabled: true`；`ん` 先送本字並列入清單。不佳者回寫 `tts_text`，仍不佳者 `listen_disabled: true`，只出 `kana_read`，UI 不用改 |
| 多音字誤讀 | 今日、何 等 | 課綱的 `tts: kana` 機制與 `tts_risky.txt`，列入清單抽聽 |
| 音調示範 | 雨／飴 可能本身就錯 | 畫面固定標註「由裝置合成，僅供參考」；聽不出差別的配對設 `listen_disabled: true` |
| iOS 慢速值 | rate 非線性 | 計時校準 `TtsRateProfile` |
| Android 語音 | 各廠牌預設引擎可能沒有日語，`isLanguageInstalled` 依賴 voice 比對 | 列入清單，至少測 Pixel 與一款三星；O5 的引導文案依實測修改 |
| iOS 音訊 | playback 類別與靜音開關、`duckOthers` 與音樂 App 的互動 | 實機確認 |
| 打字鍵盤 | `visiblePassword` 在台灣常見的注音輸入法上是否切到 Latin | 實機確認，不行時改 `TextInputType.url` |
| 字型總量 | 約 7.4MB，Klee 與 Noto Serif TC 子集以實際建置為準 | 超預算時先把 Noto Sans TC 換系統字型（單點修改） |
| Klee 小字 | 12–13px 振假名在低解析度螢幕的清晰度 | 實機檢視，必要時 ruby 改 13px 起跳 |
| `BeatStrip` 拍感 | 整詞切等分與實際合成的節奏有差 | 實機試看，差太多時改為無聲固定節拍 |

**暫不實作（P1）**：本機每日提醒、備份匯出與匯入、錄音回放、手寫描紅與筆順、VOICEVOX、術語卡的首次彈窗。**本版也不做**：同步、語音辨識評分、撤銷上一次評分。

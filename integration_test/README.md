# 整合測試（真實 Rust＋真實 p0 內容）

走完整的 App，資料庫與內容都是真的（`CONTENT_STAGE` 預設 `p0`：L01–L30、對話、筆記），只有 TTS 用假引擎。
FakeBackend 測不到的 Rust 行為、DTO 邊界、真實內容長度造成的版面問題都在這裡抓。
每個旅程開機時都會確認載入的內容版本是 `p0`（`support/e2e_harness.dart` 的 `e2eContentStage`）。

## 測的是哪一份 Rust 函式庫

App 在 Linux 會先載入執行檔旁打包的 `build/linux/x64/debug/bundle/lib/libjp_core.so`
（`lib/core/backend/frb/native_library.dart`），找不到才交回 flutter_rust_bridge 的預設流程；
預設流程會先找工作目錄下的 `rust/target/release/libjp_core.so`，那裡可能是舊的建置（實測曾是 `p0a`）。
所以不需要再設定 `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR`。
每個旅程開機時仍會確認載入的內容版本是 `p0`，載錯時一開機就失敗並說明原因。

## 環境需求

`xvfb-run`（無螢幕環境）、Linux 桌面建置工具。第一次含 Rust 建置需要幾分鐘。

## 執行

一次執行一個檔案（Linux 桌面下一次 `flutter test` 跑多個檔案時，第二個會出現 `Unable to start the app`）。
除了 J7，其餘都用 `JLA_TTS=fake`：

```bash
xvfb-run -a -s "-screen 0 1400x1100x24" flutter test \
  integration_test/first_run_journey_test.dart \
  -d linux --dart-define=JLA_TTS=fake --dart-define=JLA_TEST_HOOKS=true
# multi_day、all_tabs、main_lesson、after_l21 同樣方式執行

# J7 語音不可用（需要不同的 JLA_TTS，會讓其他檔案失敗，所以另外跑）
xvfb-run -a -s "-screen 0 1400x1100x24" flutter test \
  integration_test/no_voice_journey_test.dart \
  -d linux --dart-define=JLA_TTS=unavailable --dart-define=JLA_TEST_HOOKS=true

# 冒煙（不需要 JLA_TEST_HOOKS）
JLA_DATA_DIR=$(mktemp -d) xvfb-run -a flutter test integration_test/boot_test.dart \
  -d linux --dart-define=JLA_TTS=fake
```

或全部依序跑：`bash integration_test/run_all.sh`（主要花在每個檔案各自建置與啟動）。

只跑某一個旅程：加 `--plain-name '<名稱片段>'`，例如 `--plain-name 'J6 清除全部進度'`。
每個旅程各用自己的資料目錄，J2、J6 的前置資料用真實 API 建，不依賴 J1 先跑。

文案守門（O7）的規則是不依賴畫面的純函式（`support/p0_copy_rules.dart`），單元測試不需要開 App。
`flutter test` 會把 `integration_test/` 底下的檔案都當成要上裝置的整合測試，所以指定無畫面的
`flutter-tester`：

```bash
flutter --show-test-device test integration_test/support/p0_copy_rules_test.dart -d flutter-tester
```

截圖：加 `--dart-define=JLA_SHOTS_DIR=<目錄>`（或 `JLA_SHOTS_DIR=<目錄> bash integration_test/run_all.sh`），
J3 的 S0 今日（375）、J4 的 375 與 320＋2 倍字級、J9 兩種尺寸會沿途把 PNG 存進該目錄
（`support/screenshots.dart`，兩倍光柵化），用來人工檢查缺字、截斷與日文字形。沒給這個定義時不寫任何檔案。
主題跟隨系統：沒有另外指定時，截圖的明暗由執行環境決定（實測這台機器在 xvfb 下是深色）。
只有 L1 進度條（`learn_progress_light`、`learn_progress_dark`）固定兩種主題各截一張。

| 檔案 | 測試數 | 旅程 |
|---|---:|---|
| `first_run_journey_test.dart` | 4 | J1 首次使用（含 T3「不到 1 分鐘」、假名課的 L2 課名）、J2 持久化、J2 中途關閉（第一天沒有卡時複習列收起）、J6 清除全部進度 |
| `multi_day_journey_test.dart` | 1 | J3 跨 7 天：複習到期、評分、統計與月曆；每天 T1 的複習列（只剩收尾新卡時寫「最後再看 N 張新卡」、不蓋完成章，不寫「0 張」） |
| `all_tabs_journey_test.dart` | 4 | J4 全分頁可達：375／320／320＋2 倍字級／1280 各 1；含 N1 筆記五個分頁（和製漢字「意思近」、讀音的台羅說明）、V1～V3 與 N1 的返回元件（V3、V1 實際點它回上一頁）、S3 還沒學到的對話（可點，S4 標「還沒學到」） |
| `main_lesson_journey_test.dart` | 2 | J5 平假名畢業考進 L01，六種作答方式都用真實題（375 與 320＋2 倍字級各 1） |
| `no_voice_journey_test.dart` | 1 | J7 語音不可用時無聲模式完成今日任務 |
| `after_l21_journey_test.dart` | 2 | J9 L21 之後：今日任務的 L22 新內容（單字與文法教學卡）；常體對話（`lesson` 為 L21 以後，游標到 L21 起不鎖；從 S3 進 S4 跑完四階段，按「回到列表」回 S3）；L1 進度條兩種主題的截圖（`basic` 起點有略過的課）；L22 的單字與文法頁；375 與 320＋2 倍字級各 1 |
| `boot_test.dart` | 1 | 全新資料庫啟動冒煙 |
| `support/p0_copy_rules_test.dart` | 35 | 文案守門的單元測試（不開 App，見上方指令；不算在上面的 15 個旅程測試內） |

2026-11-16 實測（與 `run_all.sh` 相同的七個指令依序執行，含各自的建置與啟動）：15 個測試全過，合計 13 分 40 秒（first_run 4：86 秒、multi_day 1：110 秒、all_tabs 4：183 秒、main_lesson 2：205 秒、after_l21 2：114 秒、no_voice 1：61 秒、boot 1：61 秒），帶 `JLA_SHOTS_DIR` 時截圖 27 張；單元測試 35 個通過。之後 J9 補上「常體對話進 S4 跑完四階段」，七個檔再各跑一次，15 個測試全過；上面的各檔時間沒有重量。

J8（curriculum §11.4 的天數對照）與「整合日排進主對話」在 Rust：

- 預設 `p0`：`real_content_p0.rs` 的 `plan_preview_forecasts_main_end_for_every_preset`（四種方案的主線完成天數）、
  `real_content_p0_slices.rs`（L01–L30 的切片、整合日與主對話）。
- `p0a` 切片：`curriculum_days_real_content.rs`（測試內固定以 `ContentStage::P0a` 載入）。

```bash
cargo test --manifest-path rust/Cargo.toml --test real_content_p0 --test real_content_p0_slices \
  --test curriculum_days_real_content
```

## 測試注入點（預設全部關閉）

| 開關 | 作用 |
|---|---|
| `--dart-define=JLA_TEST_HOOKS=true` | 讓 `FrbBootGateway(testOptions: ...)` 生效：獨立資料目錄、`CoreConfig.fixed_now_utc`、UTC 偏移。沒帶這個定義時 `testOptions` 會被忽略，正式建置不受影響 |
| `--dart-define=JLA_TTS=fake` | 永遠可用的假 TTS |
| `--dart-define=JLA_TTS=unavailable` | 探測回報「裝置沒有日語語音」 |

## 寫新旅程

- 用 `support/e2e_harness.dart` 的 `E2eApp`：每個旅程一個資料目錄，`restart(advance:)` 用同一目錄重開並推進 FixedClock。
- 真實 FFI 不會讓 `pumpAndSettle` 等待，用 `pumpUntil`／`pumpUntilFound`；換頁後用 `pumpPage` 等轉場，否則上一頁的同名文字會被找到。
- `support/study_bot.dart` 會從畫面上的 `QuestionDto` 找正解並點真實 UI 作答，也記錄每題的 Rust 判定（`answered`）；新的流程按鈕加進 `_advanceLabels`。
- 測試框架會把溢位與未捕捉例外判為失敗，走得完本身就是檢查。
- 文案檢查用 `expectNoErrorSlip`（O7：不宣稱 N4、不出現 L31 以後的課（含「第 31～48 課」這類範圍寫法）與「完整版」）。只有 V3 單字詳情頁上、整段就是級別標籤（「參考 N4」）的文字不算（RULINGS O7 附註）；`Beyond` 顯示「未列入參考詞表」，不再使用「N4 以外」。沒有畫面脈絡的文字（StudyBot 記下的、O4）用 `expectP0CopyOnly`，不豁免。`expectNoErrorSlip` 另斷言畫面上沒有原樣的 `{ja:` 標記（`rawMarkupTexts`；內容的 `*_zh` 欄位要經 MixedText）、課的內部 id（`rawLessonIdTexts`）與舊的略過文案（`retiredSkipTexts`）。
- 「略過這一項」只在單項載入失敗時出現，真實資料的旅程走不到，所以這裡只守舊文案不再出現；按鈕本身在 widget test 驗。
- `tapWidget` 會等目標真的接得到點擊（進場動畫、頁內捲動還在走時，中心點可能落在底部導覽上）。

## 推進到 L21 之後（J9）

常體對話的 `lesson` 是 L21 以後，游標到 L21 才不鎖（rust-core §9.4）；L22 的內容要 L21 完成才看得到。`basic` 起點從 L08 開始，UI 一天走不到。`support/api_seed.dart` 用 App 同一套真實 API 推進：
`create_plan`（`start_level = basic`，略過假名課與 L01–L07，引導不會送這個值，是計畫引擎保留給分級測驗的起點），
然後在同一天反覆「取今日快照、新內容先取 `new_content_session` 再 `complete_task`、`learn_more`」，直到 L21 完成（實測約 1.5 秒）。
不寫資料庫、不造 DTO；跳過的是逐題作答，那部分由 J1、J3、J5 用真實 UI 驗證。
推進完用同一個資料目錄重開，今日任務裡還沒做的 L22 第一批新內容由真實 UI 作答。

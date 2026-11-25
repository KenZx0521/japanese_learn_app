# Flutter App 測試策略（flutter-app-testing.md）

本文件是 [flutter-app.md](flutter-app.md) 的 §8，章節編號沿用，文中其他 § 指主文件與 [flutter-app-architecture.md](flutter-app-architecture.md)、[flutter-app-tts.md](flutter-app-tts.md)。內容驗證工具以 `reuse-and-verification.md` 為準，Rust 端測試見 `rust-core.md` §11。

## 8. 測試策略

先寫測試，覆蓋率 80% 以上（排除 `lib/src/rust/**`、`*.freezed.dart`）。

**純函式單元測試**：`reduceQuestionRun`、`reduceNewContent`（含 `first_card` 為 None 的斷點續做）、`reduceTodayFlow`（含 `learning_tail` 收尾、`Review{due: 0, learning: 0, new_cards: 3, done: true}` 且 `learning_tail = 3` 時清單跑完仍進 `CardRunner`、取題為空時略過）、`optionLanguageOf`（19 值）、`questionHintOf`（19 值）、`questionContext`、`speedFromRate`、`guardBackend` 的錯誤對應、`TtsController`（假引擎，覆蓋過期事件、看門狗、同 id 切換）、`FlutterTtsEngine` 的事件歸屬、語速表。

**Widget test（fake backend）**：入口為 `pumpApp(tester, backend: FakeBackend(...), tts: FakeTtsEngine(), width: 375)`。

- `pumpApp` 建立 `ProviderScope(retry: (_, _) => null, overrides: [...])`，並用 `tester.view` 設定尺寸。DTO 可直接建構，fake 不需要原生函式庫。
- 每個畫面測 §2.3 的四個狀態（載入、空、錯誤、資料）。
- **任務模型**：`TaskDto` 六種變體的列與執行元件對應；`complete_task` 帶 key、`durationMs`、`audio`；T2 跑完後 `learning_tail > 0` 會呼叫 `session_next` 到 `Done`；全部任務 done 且 `learning_tail > 0` 時 T1 出現「收尾」列並能進 T2；`can_learn_more` 控制「再學一批」；`checkpoint_dismiss` 後 T2 接下一項。
- **引導**：O5 失敗時停在本步，必須選「現在設定」或「先用無聲模式」；三種 O3 對應的 `PlanInputDto`；`FirstRunMarker` 存在時第一個 `NewContent` 結案後出現 O6，且只出現一次。
- **L3**：六種 `NewContentStepDto` 的呈現；`first_card` 走 `submit_answer`；`KanaQuiz` 走 `kana_submit`；第一題考的字必定在此前的 `Kana` 步驟出現過。
- **K3**：`beats` 非空時顯示 `BeatStrip`，`TtsStarted` 後依序亮格；無聲模式改固定節拍；reduced motion 不做過渡。
- **作答**：每種 body 與 `question_type` 測作答、對錯回饋；評分列只在 `SelfGrade`；`Shadow` 回傳 `ShadowLevel`；`reference` 原樣帶回（含 `variant`）；`hide_text_until_answered` 時 `find.text` 找不到題目日文；`Typing` 的 `TextField` 設定含 `visiblePassword`、關閉自動校正。
- **操作提示**：題型第一次顯示提示且寫入 `seen_question_hints`，第二次不顯示。
- **顯示規則**：五種 `RomajiMode` 的行為；`K1` 不呼叫 `display_policy`；游標在 L09 以後且 `ms.kata` 未通過時出現確認列（用夾具的 `PlanViewDto`）。
- **搜尋與標記**：`search_vocab` 去抖；`set_vocab_flags` 後列表狀態更新；`grammar_list` 帶 `query`。
- **範圍文案（O7）**：`content_stage = P0a` 時，走訪全部會顯示範圍的畫面（O1、O4、O6、P1、P2、X1 關於、V3），文字不得含「N4」、「看懂日劇」、「聽懂日劇」；V3 用 `jlpt = N4` 與 `jlpt = Beyond` 各一筆 `VocabDetailDto` 夾具，確認不顯示級別標籤；筆記入口不存在。`P0`（預設）寫「本版到 L30」、「參考 N5」，不含「N4」、L31 以後的課號與「完整版」（`test/features/plan/scope_copy_test.dart`）；V3 的「參考 N4」是單字的逐字級別標示，不算宣稱；`Beyond` 顯示「未列入參考詞表」，不推定程度。整合測試另在每一站以 `expectP0CopyOnly` 檢查真實畫面（`integration_test/README.md`）。
- **語音**：TTS 五種 availability 的畫面（`unknown` 為骨架）；探測完成前 fake backend 收不到 `today_view`（`FakeTtsEngine` 的 `probe()` 用 `Completer` 控制完成時機），探測結果為非 `ready` 時同樣要在完成後才收到；`onResume` 的 `today_view` 在重新探測完成後才呼叫；無聲模式時 `audio_available = false` 傳給所有取題函式；語音不可用時不顯示略過，改以 `audio_available` 排除（§6.6）；中途播放失敗顯示 `VoiceFailedPanel`。
- **筆記的夾具**（O1）：在 `test/features/notes/` 的測試內建構 `NoteDto` 五種變體，測 N1。Rust 端另有 `content_api.rs` 用 `rust/crates/jp_content/tests/fixtures/full/` 驗證 API，預設 `p0` 的真實筆記由 `real_content_p0.rs` 驗證（`rust-core.md` §11.2）。
- **已移除功能的反向回歸**（RULINGS O13）：聽說頁沒有專區區塊（`test/features/listen/listen_home_screen_test.dart`）、`/listen/zone/...` 沒有對應路由（`test/app/router_test.dart`）、引導流程沒有學習目標步驟（`test/features/onboarding/onboarding_flow_test.dart`）。
- Reduced motion：`disableAnimations: true` 時轉場與蓋章沒有動畫。語意：`Text(locale: ja)` 的 `attributedLabel` 含 `LocaleStringAttribute(ja-JP)`。
- 使用 `androidTapTargetGuideline`、`iOSTapTargetGuideline`、`labeledTapTargetGuideline`。

**截圖回歸**（`flutter test --tags golden`，只在 Linux 執行）：

- `test/flutter_test_config.dart` 用 `FontLoader` 載入打包字型，否則 Ahem 字型會顯示方塊【實測可用】。
- 矩陣：寬 320／375／768／1024 × 淺色／深色；320 額外跑字級 2.0 倍。
- 涵蓋：T1（S0 與 S1 兩種任務組合）、K1、K3、L3 的 `Kana` 與 `Vocab` 步驟、V4 的 `Choice` 與 `SelfGrade`、D2（reorder、listen_meaning）、G2、N1、S4 盲聽、P1、O5 語音失敗。
- 基準放 `test/goldens/`，更新要用 `--update-goldens` 並在 PR 檢視差異。

**Integration test（真 Rust，Linux）**：

```bash
integration_test/run_all.sh
```

- Linux 桌面一次只能啟動一個測試 App，`flutter test integration_test` 跑多個檔案時第二個會連不上，所以逐檔執行。單跑一個檔案：

```bash
xvfb-run -a -s "-screen 0 1400x1100x24" \
  flutter test integration_test/first_run_journey_test.dart -d linux \
  --dart-define=JLA_TTS=fake --dart-define=JLA_TEST_HOOKS=true
```

- 【實測】可在 xvfb 下跑，首次含建置約 60 秒。環境變數會傳入 App。
- 每個旅程在系統暫存目錄建自己的資料目錄（`e2e_harness.dart` 的 `E2eApp`，經 `JLA_TEST_HOOKS=true` 才生效的 `BootTestOptions.dataDir` 傳入），每個測試獨立 DB；`CoreConfig.fixed_now_utc` 固定時間，避免跨日不穩定。不帶 hooks 的 `boot_test.dart` 改用環境變數 `JLA_DATA_DIR` 指向暫存目錄（只有 debug、profile 建置讀這個變數）。
- 內容用預設 `CONTENT_STAGE=p0` 的真實資料；旅程開機時確認載入的是 `p0`。App 在 Linux 先載執行檔旁 `lib/libjp_core.so`（`native_library.dart`），bundle 缺檔時才交回 FRB 預設（會先找工作目錄下的 `rust/target/release/libjp_core.so`），所以 `run_all.sh` 不再設 `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR`（`integration_test/README.md`）。J1、J2、J6 各用新的資料目錄，J2、J6 的前置資料用真實 API 建立（`api_seed.dart` 的 `finishFirstDayThroughApi`），可用 `--plain-name` 單獨執行。旅程每站斷言畫面上沒有原樣的 `{ja:` 標記（`p0_copy_rules.dart` 的 `rawMarkupTexts`）。
- 流程：新手引導 → `create_plan` → 第一個 `NewContent`（L3）→ O6 → 完成 → 重開 `AppCore` → 進度還在；字卡評分後到期數減少；調整計畫後今日任務改變；無聲模式下沒有聽力題也沒有 `Listen` 任務。`SpdSayTtsEngine` 的 Started → Completed 由 `test/core/tts/spd_say_engine_test.dart` 用假行程驗證；`--dart-define=JLA_TTS=spd` 可強制用這個引擎手動試，整合測試不走它。
- 每一站的共用守門（O7 文案、原樣的 `{ja:` 標記、內部課 id、舊略過文案）與返回元件的斷言，寫在 `integration_test/support/`，各旅程驗了哪些見 `integration_test/README.md`。振假名排版（1:2:1、行首行尾禁則）只在 widget test 驗（`test/core/text/`）；原本在真實畫面上的量測都在專區畫面，已隨專區移除（RULINGS O13）。
- 筆記（N1 五個分頁）在 J4 用真實內容走。常體對話要游標到 L21 才開放、L22 的內容要 L21 完成才看得到，J9 先以真實 API 推進（`create_plan` 的 `basic` 起點＋同一天反覆 `complete_task`、`learn_more`，見 `integration_test/support/api_seed.dart`），再用 UI 走常體對話（進 S4 跑完四階段）與 L22。`AppCore::open_with_content` 是 `#[frb(ignore)]`，Dart 叫不到，夾具仍只在 widget test 與 Rust 的 `content_api.rs`。
- 截圖用根圖層的 `OffsetLayer.toImage`（包在 `tester.runAsync` 內，`--dart-define=JLA_SHOTS_DIR` 才寫檔）存成 CI artifact，不做像素比對。`binding.takeScreenshot` 在 Linux 不可用。

**CI 順序**：`dart format --set-exit-if-changed` → `flutter analyze` → 禁止 import 檢查 → 離線檢查（`python3 tools/verify/check_offline.py`，規則見 `reuse-and-verification.md` §9.12；Android 建置後加 `--apk build/app/outputs/flutter-apk/app-release.apk --require-apk`）→ `flutter test --coverage --exclude-tags golden` → 覆蓋率門檻 → `flutter test --tags golden` → 字型覆蓋檢查 → `flutter build linux --release` → integration test。

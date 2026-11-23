# Flutter App 程式結構（flutter-app-architecture.md）

本文件是 [flutter-app.md](flutter-app.md) 的 §5，章節編號沿用。文中的 §1–§4、§7 指主文件，§6 指 [flutter-app-tts.md](flutter-app-tts.md)，§8 指 [flutter-app-testing.md](flutter-app-testing.md)。

## 5. 程式結構

### 5.1 目錄

```text
lib/
  main.dart                     # 只呼叫 bootstrap()
  bootstrap.dart                # 初始化順序、BootErrorApp
  app/  app.dart  router.dart  shell/app_shell.dart
  design/
    tokens.dart  theme.dart  motion.dart
    widgets/...                 # §4.4，一元件一檔
  core/
    backend/
      failures.dart             # AppFailure、guardBackend
      repositories.dart         # 全部抽象介面
      providers.dart            # 介面的 provider，預設 throw
      first_run_marker.dart     # §3.1 的 O6 旗標檔
      frb/                      # Frb*Repository、dto.dart（export DTO、hide AppCore），唯一可 import lib/src/rust 的目錄
    tts/  tts_engine.dart  tts_controller.dart  flutter_tts_engine.dart  spd_say_engine.dart  voice_help.dart  audio_available.dart
    text/ja_text.dart  ruby_line.dart  mixed_text.dart  option_language.dart  display_context.dart
    question/                   # L3、V4、K2、D2、D3、G2 共用
      question_view.dart        # 依 QuestionBodyDto 分派
      question_reducer.dart     # 純函式
      question_hints.dart  answer_factory.dart
      bodies/                   # choice、reorder、typing、match、self_grade、shadow
  features/
    onboarding/  today/  learn/  kana/  vocab/  grammar/  notes/  listening/  plan/  settings/
    session/                    # T2 要串接的全螢幕流程，同放一處
      today_flow/   {today_flow_controller, today_flow_reducer, today_flow_screen, done_screen, expectation_screen}
      new_content/  {new_content_controller, new_content_reducer, teach_cards/}
      kana_quiz/  cards/  drill/{drill_screen, checkpoint_screen}  dialogue/
  src/rust/                     # FRB 產生，不手改
test/         # 對應 lib/ 結構
  flutter_test_config.dart      # 載入真字型
  support/{fake_backend.dart, fake_tts_engine.dart, pump_app.dart}
  goldens/
integration_test/
tools/fonts/
```

依賴方向：`features → core、design`；`features` 之間不互相 import，共用的提到 `core/` 或 `design/`，畫面之間的跳轉只經過 `app/router.dart` 的路徑。T2 要依序執行 L3、V4、D2、S4 等流程，所以這些全螢幕流程都放在 `features/session/`。`lib/src/rust` 只能被 `core/backend/frb/` import，CI 以 grep 檢查（`bootstrap.dart` 的 `RustLib.init` 為唯一例外）。

### 5.2 狀態管理

| 用途 | 形式 |
|---|---|
| 依賴注入 | `Provider<XRepository>`，預設 throw，bootstrap 用 `overrideWithValue` |
| 唯讀資料 | `FutureProvider.autoDispose(.family)` |
| Session（答題、字卡、對話、T2） | `NotifierProvider.autoDispose.family`，狀態不可變，邏輯在純函式 reducer |
| 全域偏好 | `AsyncNotifierProvider<SettingsController, Settings>` |
| TTS 播放狀態 | `NotifierProvider<TtsController, TtsPlayback>`，非 autoDispose |
| 語音可用性 | `ttsAvailabilityProvider`（`NotifierProvider<TtsAvailabilityController, TtsAvailability>`：`build` 回 `kind = unknown` 並啟動第一次 `probe()`；`reprobe()` 回傳 `Future<void>`，重新探測期間保留上一次結果，不回到 `unknown`，畫面不閃骨架），`Provider<bool> audioAvailableProvider` 與 `audioResolvedProvider`（§6.6） |

Session 的狀態是 final 欄位加 `copyWith` 的不可變類別，邏輯在純函式（`reduceQuestionRun`、`reduceNewContent`、`reduceTodayFlow`）。Controller 為 `Notifier`，建構子收 family 參數（`NotifierProvider.autoDispose.family<C, S, Args>(C.new)`，已驗證）。`answer()` 先 reduce 更新畫面，再 await 寫入，await 之後檢查 `ref.mounted`，失敗時進入 `saveFailed` 階段顯示重試。

- family 參數必須實作 `==`（用 record、`String` 或 FRB 產生的無 `Vec` DTO）。含 `Vec` 的 DTO（`DrillFilterDto`）不當 family 參數，改用 query 字串。
- `ProviderScope(retry: (_, _) => null)`（實證 #4）。
- 不使用 `StateProvider`（已移到 `legacy.dart`）。
- `session_seed`：對 `logical_date` 字串算 32 位元 FNV-1a，同一天重開題目相同。不得用 `String.hashCode`，它不保證跨執行穩定。

### 5.3 Repository 與 Rust 介面

FRB 產生的 DTO 是普通 Dart 類別，未載入原生函式庫也能建構（實證 #16），所以：

- **函式**包在抽象 Repository 內，widget test 注入 fake。
- **DTO** 直接使用（`rust-core.md` §9.5），不再建一層 Dart model，Rust 是單一事實來源。
- Opaque 型別只有 `AppCore`，且只存在 `core/backend/frb/` 內。Features 一律 import `core/backend/frb/dto.dart`，不直接 import `lib/src/rust`。

下表的 Rust 函式以 `rust-core.md` §9.4 為準，Repository 方法只把參數轉成 camelCase。`audio` 是 `audio_available`，由 controller 從 `audioAvailableProvider` 讀入後傳入。

| Repository | 方法 | 對應 Rust API | 使用者 |
|---|---|---|---|
| `TodayRepository` | `today(audio)`；`completeTask(key, durationMs, audio)`；`learnMore(audio)`；`newContent(key, seed, audio)`；`listenSession(key, seed, audio)` | `today_view`；`complete_task`；`learn_more`；`new_content_session`；`listen_session` | T1–T3、L3 |
| `CourseRepository` | `overview()`；`lesson(id)` | `course_overview`；`lesson_detail` | L1、L2、O3 |
| `KanaRepository` | `chart(script)`；`detail(id)`；`ruleCard(id)`；`session(lessonId, seed, audio)`；`submit(reference, response, durationMs)` | `kana_chart`；`kana_detail`；`rule_card`；`kana_session`；`kana_submit` | K1–K3、L3 |
| `VocabRepository` | `topics()`；`page(filter, offset, limit)`；`search(q, limit)`；`detail(id)`；`setFlags(id, flags)` | `vocab_topics`；`vocab_page`；`search_vocab`；`vocab_detail`；`set_vocab_flags` | V1–V4、L3 |
| `ReviewRepository` | `summary(audio)`；`next(seed, audio)`；`submit(answer)` | `session_summary`；`session_next`；`submit_answer` | V4、T2、L3 |
| `GrammarRepository` | `list(stage, query)`；`detail(id)` | `grammar_list`；`grammar_detail` | G1、G2 |
| `NoteRepository` | `list(kind)` | `note_list` | N1 |
| `DrillRepository` | `session(filter, seed, audio)`；`grade(reference, response)`；`checkpointStart(id, seed, audio)`；`checkpointFinish(id, answers)`；`checkpointDismiss(id, audio)` | `drill_session`；`grade_drill`；`checkpoint_start`；`checkpoint_finish`；`checkpoint_dismiss` | D1–D3、G2 |
| `ListeningRepository` | `soundGroups()`；`dialogues()`；`dialogue(id)` | `sound_groups`；`dialogues`；`dialogue_detail` | S2–S4、T2 |
| `PlanRepository` | `view()`；`preview(input)`；`create(input)`；`update(input)`；`calendar(weeks)`；`stats()`；`activity(from, to)` | `plan_view`；`plan_preview`；`create_plan`；`update_plan`；`calendar`；`stats_overview`；`activity_range` | O3、O4、P1、T3 |
| `SettingsRepository` | `load()`；`patch(p)`；`displayPolicy(context)`；`resetAll()` | `settings`；`update_settings`；`display_policy`；`reset_all` | 全域 |
| `ContentPeekRepository` | `peek(refId)` | `peek` | `WordPeek`、答後語法重點、D3 弱項、§3.7 |

`AppCore::open`、`set_utc_offset` 在 `core/backend/frb/` 內直接呼叫。`delete_database` 只給 `BootErrorApp`。`sentence` 目前沒有畫面需要單獨取一句，不包進 Repository。

`#[frb(sync)]` 的 `romaji_input_preview`、`romanize_reading`、`parse_mixed_text` 放在函式型 provider（`TextToolsProvider`），測試注入假實作。

**作答對應**（`core/question/answer_factory.dart`）：`reference` 一律是 `QuestionDto.reference` 原樣帶回，含 `variant`，Dart 不解讀。

| body | `AnswerPayload` |
|---|---|
| `Choice` | `Choice{option_id}` |
| `Reorder` | `Reorder{order}`（`ChunkDto.index` 的順序） |
| `Typing` | `Typing{input}`（使用者打的羅馬字原文） |
| `Match` | `Match{all_correct}` |
| `SelfGrade` | `SelfGrade{rating}` |
| `Shadow` | `Shadow{level}` |

| 情境 | 寫入 |
|---|---|
| V4、L3 的 `first_card` | `submit_answer(AnswerDto)`，`expected_reps` 取自 `SessionCardDto`，`hint_used = false`，`attempts = 1` |
| K2、L3 的 `KanaQuiz` | `kana_submit(reference, response, durationMs)` |
| D2、聽力任務、G2 小測驗 | `grade_drill(reference, response)`，回傳 `DrillResultDto` |
| D3 | 累積 `AnswerDto`，結束時 `checkpoint_finish(milestone_id, answers)` |

`SettingsDto.tts_rate` 是 `f64`，Dart 以 `rate <= 0.85` 視為慢速，其餘一律當正常速度（§6.5）。

`SessionNextDto`、`TaskDto`、`QuestionBodyDto`、`NewContentStepDto`、`NoteDto` 都是 FRB 產生的 sealed class，一律用 `switch` 窮舉，不寫 `default`。

### 5.4 錯誤處理

```dart
sealed class AppFailure implements Exception { const AppFailure(); String get userMessage; }
// NotFoundFailure、InvalidInputFailure、NoPlanFailure、ContentFailure、StorageFailure、UnexpectedFailure

Future<T> guardBackend<T>(Future<T> Function() call) async {
  try { return await call(); }
  on CoreError catch (e) { throw mapCoreError(e); }
  on Exception catch (e, st) { logLocal(e, st); throw const UnexpectedFailure(); }   // 含 PanicException
}
```

| `CoreError` | 處理 |
|---|---|
| `NotFound`、`InvalidInput`、`Internal` | `ErrorSlip`；技術訊息只寫 log |
| `StaleCard` | 不顯示，直接取下一題（連點） |
| `NoActivePlan` | 導向新手引導 |
| `ContentCorrupt`、`MigrationFailed` | 啟動時為 `BootErrorApp` |
| `Storage` | 留在當前畫面，顯示重試，不前進，避免進度遺失。`reset_all` 回傳此錯誤時顯示「請重新啟動 App」 |

- `AsyncBody<T>(value:, data:)` 統一處理 loading／error。`ErrorSlip` 顯示 `userMessage`、「重試」（`ref.invalidate`）、「複製錯誤資訊」。`PanicException` 訊息含 backtrace，不可顯示。
- `FlutterError.onError` 與 `PlatformDispatcher.instance.onError` 寫入本機環狀日誌（≤256KB），不上傳任何資料。`BootErrorApp`：重試、複製資訊、重設資料（兩段式確認後呼叫 `delete_database(dbPath)`，此函式不需要 `AppCore`）。

**啟動順序**（`bootstrap.dart`）：

```text
ensureInitialized → 註冊字型授權 → getApplicationSupportDirectory
→ RustLib.init()（同一 Isolate 只能一次；Linux 傳執行檔旁 lib/libjp_core.so 的 ExternalLibrary，缺檔才用 FRB 預設，native_library.dart）
→ AppCore.open(CoreConfig(dbPath, utcOffsetMinutes))
→ settings、plan_view（決定 onboardingDone）
→ 依平台建立 TtsEngine（§6.2）
→ runApp(ProviderScope(retry: null, overrides: [...], child: App()))
```

`AppLifecycleListener.onResume` 依序呼叫 `set_utc_offset`、`await` 重新探測語音（`reprobe()`，§6.4），探測完成後才 invalidate today（跨日、旅行），否則跨日的 `today_view` 可能用舊的 `audio_available` 寫入當日快照。

### 5.5 路由與 App 根

已驗證：redirect、分頁狀態保留、root navigator 蓋過 shell。結構為 `GoRouter(navigatorKey: rootKey, initialLocation: '/today', refreshListenable: onboarded, redirect: ...)`，內含 `/welcome`、一個 `StatefulShellRoute.indexedStack`（5 個 branch，builder 回傳 `AppShell`）與 `parentNavigatorKey: rootKey` 的 `/session/...`。

App 根用 `material_ui` 的 `MaterialApp.router`，`locale: Locale('zh','TW')`，`localizationsDelegates: GlobalMaterialLocalizations.delegates`，亮暗主題來自 `buildTheme(AppTokens.light/dark)`。

`buildTheme` 設 `fontFamily: 'NotoSansTC'`、把 `splashFactory` 設為 `NoSplash.splashFactory`（Material 水波紋是模板感的主要來源）、掛上 `AppTokens`。App 內不直接使用 `AppBar`、`NavigationBar`、`Card`、`ElevatedButton`；`Scaffold`、`TextField`、`showModalBottomSheet` 可作為基礎設施，但外觀要自訂。

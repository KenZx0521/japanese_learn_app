# Rust 核心設計（rust-core.md）

本文件定義內嵌於 App 的 Rust 函式庫 `jp_core`：內容載入、假名與羅馬字、SQLite、間隔重複、學習計畫、測驗產生、給 Dart 的 API。權威範圍：函式簽章與 DTO 以本文件 §9 為準，它是 Dart 介面的唯一來源；內容欄位與教學規則以 `curriculum.md` 為準，§3.2 的 struct 必須與其 §12 逐欄相同。文件間有衝突時以 `RULINGS.md` 為最高依據。

標記「實測」的項目都在 spike 中實際編譯或執行過（環境：Rust 1.99.1、Flutter 3.47.9、Linux x86-64）。未標記的是設計決定。

---

## 0. 實測結論

### 0.1 實際解析到的版本

| 套件 | 版本 | 備註 |
|---|---|---|
| flutter_rust_bridge | =2.13.0 | 需開 `chrono` feature（非預設） |
| rusqlite | 0.41.1 | `bundled`；libsqlite3-sys 0.39.1，SQLite 3.54.1 |
| rs-fsrs | =1.2.1 | |
| chrono | 0.4.45 | |
| serde / serde_json | 1.0.229 / 1.0.154 | |
| thiserror | 2.0.21 | |
| rand_chacha | 0.9.0 | 只用它的 `rand_core`，不直接依賴 `rand` |

組合在 Rust 1.99.1 編譯無錯誤。release `.so`（含 SQLite）3.3 MB。相依樹沒有任何 HTTP 或 TLS 套件；tokio 由 FRB 帶入，只用於 async runtime。

### 0.2 會直接影響實作的發現

| # | 發現 | 證據 | 對策 |
|---|---|---|---|
| F1 | rs-fsrs 以真實經過時間計算 `elapsed_days`（`num_days()` 無條件捨去）。21:00 複習、隔天 08:00 再複習，經過天數算成 0，Good 後穩定度完全不變 | 4.351→4.351；用邏輯日校正後 4.351→7.197 | §6.3 校正 `last_review` |
| F2 | 時鐘倒退會汙染資料：倒退 10 天 stability 為負（-11.4），倒退 100 天為 NaN | 實測 | §6.3 夾住 `now`，寫入前檢查 |
| F3 | SQLite 會**接受 Infinity**，NaN 則變 NULL 被 NOT NULL 擋下 | 實測 | CHECK 不足以防護，必須檢查 `is_finite()` |
| F4 | `chrono::NaiveDate` 經 FFI 會差一天：台北 `DateTime(2026,3,4,3,0)` 到 Rust 變 03-03；洛杉磯 `23:00` 變 03-05 | 實測兩時區 | DTO **禁用 NaiveDate**，日期一律 `"YYYY-MM-DD"` 字串 |
| F5 | `DateTime<Utc>` 經 FFI 精確到微秒，傳回 Dart 為 `isUtc=true`；傳入本地 `DateTime` 保持同一時刻 | 實測 | 時刻用 `DateTime<Utc>` |
| F6 | 帶欄位的 enum 需要 freezed，否則 codegen 失敗（`MissingDep`） | 實測 | 加入 `freezed_annotation`、`freezed`、`build_runner`；已驗證 3.1.0 / 4.0.3 / 2.17.1 可用，Dart 端可用 sealed `switch` 窮舉 |
| F7 | `integrate` 產生的 crate-type 只有 `cdylib`、`staticlib`，`rust/tests/` 無法連結（E0433） | 實測 | 手動加 `rlib` |
| F8 | `impl AppCore` 可分散在 `api/` 下多個檔案，方法全部生成到同一個 Dart class | 實測 | 依功能分檔，符合 200–400 行 |
| F9 | 打字判定若走「羅馬字→假名→羅馬字」，`paatii` 會變 `paachii` 而對不上 パーティー（反向表 `ti` 是 ち 的別名） | spike 測出 | §4.5 先做直接比對 |
| F10 | 手寫 `include_str!` 不適合約 170 個內容檔；`build.rs` 生成清單後，新增、修改、刪除檔案都會觸發重建，且與 FRB codegen 相容 | 實測三種情境 | §3.1 |

### 0.3 rs-fsrs 評估

保留 rs-fsrs 1.2.1。問題都能以薄包裝解決，換掉反而要自寫狀態機。

| 項目 | rs-fsrs 1.2.1 | fsrs 6.6.2（官方） |
|---|---|---|
| 演算法 | FSRS-5 的 19 參數；難度更新少了線性阻尼 `(10-D)/9` | FSRS-6，21 參數 |
| 維護 | crates.io 僅 1.2.1（2024-10-28）；近期 commit 皆 dependabot；未封存 | 活躍（2026-11 仍有 push） |
| API | 完整卡片狀態機與 1/5/10 分鐘學習步驟，輸入 `DateTime<Utc>` | `next_states(Option<MemoryState>, retention, days_elapsed: u32)`，純函式但**沒有學習步驟**與 due |
| 序列化 | `Card`、`ReviewLog`、`Rating`、`State` 有 serde feature；`Parameters`、`SchedulingInfo` 沒有 | `MemoryState` 只有 `Serialize` |
| 相依 | chrono（serde 可選） | 約 40 個 crate（ndarray、rayon 等） |
| strip 後 .so | 392 KB | 362 KB |

替換條件：若日後需要 FSRS-6 或個人化參數，換成 fsrs 6.x，並自寫學習步驟（約 100 行）。`SrsScheduler` trait 隔離了這個決定，資料庫存的 stability、difficulty 不需遷移。若要 vendor rs-fsrs，注意它有 `#![deny(warnings)]`，只有作為 registry 相依時才被 cap-lints 壓制。

**不要使用** `Card::new()`（內部呼叫 `Utc::now()`）與 `Seed::Empty`／`Seed::Default`（`inner_str` 無窮遞迴）。

實測排程（Fuzz 關閉，依序 Good×4、Again、Good×2、Hard、Easy）：

| # | 評分 | 狀態 | 排程 | S | D |
|---:|---|---|---|---:|---:|
| 0 | Good | New→Learning | 10 分鐘 | 3.126 | 5.315 |
| 1 | Good | Learning→Review | 4 天 | 4.351 | 5.267 |
| 2 | Good | Review | 15 天 | 14.949 | 5.221 |
| 3 | Good | Review | 48 天 | 47.788 | 5.175 |
| 4 | Again | Review→Relearning | 5 分鐘 | 4.605 | 7.211 |
| 5 | Good | Relearning→Review | 6 天 | 6.409 | 7.119 |
| 6 | Good | Review | 17 天 | 16.528 | 7.030 |
| 7 | Hard | Review | 23 天 | 22.573 | 7.982 |
| 8 | Easy | Review | 95 天 | 95.162 | 6.832 |

Fuzz 開啟時結果具確定性（種子由 now、reps、D×S 推導，同輸入同輸出），可搭配 FixedClock 測試。

---

## 1. 專案整合與 crate 結構

### 1.1 建立步驟（實測）

```bash
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
flutter_rust_bridge_codegen integrate --no-integration-test --rust-crate-name jp_core --rust-crate-dir rust
flutter pub add freezed_annotation dev:freezed dev:build_runner
# 手動：Cargo.toml 加 rlib 與相依；還原 lib/main.dart；刪 rust/src/api/simple.rs
flutter_rust_bridge_codegen generate
```

`integrate` 實際造成的變更：

| 位置 | 變更 |
|---|---|
| `rust/` | 新 crate，含 `src/frb_generated.rs`、`src/api/simple.rs` |
| `rust_builder/` | cargokit 與各平台殼（Android gradle、iOS podspec 用 `-force_load`、Linux CMake） |
| `flutter_rust_bridge.yaml` | `rust_input: crate::api`、`rust_root: rust/`、`dart_output: lib/src/rust` |
| `lib/src/rust/` | 生成的 Dart |
| `lib/main.dart` | **改寫成示範頁，原內容註解掉** |
| `pubspec.yaml` | 加 `jp_core: path: rust_builder`、`flutter_rust_bridge: 2.13.0` |
| `analysis_options.yaml` | exclude `rust_builder/cargokit/**` |

`generate` 首次執行若沒有 cargo-expand，會自動安裝到 `~/.cargo/bin`。CI 需預先安裝。

Linux 上 `flutter build linux` 已實測可建置，產物 bundle 含 `libjp_core.so`，在 xvfb 下啟動 15 秒沒有錯誤。Android 與 iOS 本機無 SDK，尚未驗證（§12）。

網路權限：`android/app/src/main/AndroidManifest.xml` 目前沒有 `INTERNET`，只有 debug 與 profile 有（熱重載需要），release 不需調整。

### 1.2 Cargo.toml

`rust/Cargo.toml` 同時是 workspace 根與 `jp_core` package。領域邏輯拆成六個 crate 放在 `rust/crates/`，由 crate 邊界強制依賴方向（§1.3）；FRB 只掃描根 crate 的 `src/api/`。節錄（完整內容見該檔）：

```toml
[workspace]
members = [
    "crates/jp_lang", "crates/jp_content", "crates/jp_store",
    "crates/jp_srs", "crates/jp_plan", "crates/jp_quiz",
    "tools/content_tool",
]
resolver = "2"

[workspace.package]
version = "0.1.0"
edition = "2021"
publish = false

[workspace.dependencies]
# App 相依，版本鎖定 §0.1
flutter_rust_bridge = { version = "=2.13.0", features = ["chrono"] }
rusqlite = { version = "=0.41.1", features = ["bundled"] }
rs-fsrs = "=1.2.1"
chrono = { version = "=0.4.45", features = ["serde"] }
serde = { version = "=1.0.229", features = ["derive"] }
serde_json = "=1.0.154"
thiserror = "=2.0.21"
rand_chacha = "=0.9.0"
# 內部 crate：jp_lang = { path = "crates/jp_lang" } 等六個
# 僅測試：tempfile、proptest；僅 content_tool：clap、sha2、toml、ttf-parser、wana_kana、encoding_rs

[package]
name = "jp_core"
version.workspace = true
edition.workspace = true
publish.workspace = true

[lib]
crate-type = ["cdylib", "staticlib", "rlib"]

[dependencies]
flutter_rust_bridge.workspace = true
chrono.workspace = true
thiserror.workspace = true
jp_lang.workspace = true      # 以及 jp_content、jp_store、jp_srs、jp_plan、jp_quiz

[dev-dependencies]
jp_content = { workspace = true, features = ["test-support"] }
tempfile.workspace = true

[lints.rust]
unexpected_cfgs = { level = "warn", check-cfg = ['cfg(frb_expand)'] }
```

各 crate 的相依一律寫 `.workspace = true`，版本只在根目錄定一次。`jp_content` 有兩個 feature：`tooling`（讀磁碟、lint、走訪內容，只給 `content_tool` 與測試）與 `test-support`（共用測試夾具，下游 crate 在 dev-dependencies 開啟）；App 不開，所以這些程式碼不進 App。

在 `rust/` 下 `cargo build` 只建 `jp_core` 與它依賴的 crate，不會建 `content_tool`；工具用 `-p content_tool`。`content_tool` 放 `rust/tools/content_tool/`，依賴 `jp_lang` 與開了 `tooling` 的 `jp_content`，App 不依賴工具，所以工具的相依不會進 App（reuse-and-verification.md §9.12 的 L03）。

`clippy.toml` 禁用非注入的時間來源，只有 `crates/jp_lang/src/clock.rs` 的 `SystemClock` 以 `#[allow]` 例外（開發工具 `content_tool` 的 `verify.rs` 取今天日期另有一處例外，不進 App）：

```toml
disallowed-methods = ["chrono::Utc::now", "chrono::Local::now", "rs_fsrs::Card::new"]
```

### 1.3 模組切分

一個根 crate 加六個領域 crate（2026-11-10 依 `rust/Cargo.toml` 與各 crate 的 `src/` 核對）。依賴方向由 Cargo 強制，下層不得依賴上層：

```text
jp_core（rust/src：api → app）
  → jp_plan、jp_quiz → jp_srs → jp_store、jp_content → jp_lang
  （jp_plan、jp_quiz 也直接依賴 jp_store、jp_content、jp_lang；jp_store 不依賴 jp_content）
content_tool（rust/tools/content_tool）→ jp_content（tooling）、jp_lang
```

本文件其他章節沿用短名稱，對應如下：`api/`、`app/` 在 `rust/src/`；`kana/`、`grammar/`、`clock.rs` 在 `rust/crates/jp_lang/src/`（`quiz/rng.rs` 也在這裡）；`content/` 是 `rust/crates/jp_content/src/`；`store/` 是 `rust/crates/jp_store/src/`；`srs/` 是 `rust/crates/jp_srs/src/`；`plan/` 是 `rust/crates/jp_plan/src/`；`quiz/` 是 `rust/crates/jp_quiz/src/`（`drill_quiz.rs` 已拆成 `drill/` 目錄）；`app/mapping.rs` 已拆成 `rust/src/app/mapping/` 目錄。

| 位置 | 職責 |
|---|---|
| **`rust/src/`（jp_core，cdylib，FRB 入口）** | |
| `lib.rs` | 模組宣告：`pub mod api`、`mod app`、`mod frb_generated` |
| `api/`（只有這個目錄被 FRB 掃描，所有 DTO 與 `CoreError` 放這裡） | `core.rs`：`AppCore` 不透明型別、開啟、設定、清除資料；`error.rs`：`CoreError` 與各 crate 錯誤的轉換；`dto_content.rs`、`dto_study.rs`、`dto_plan.rs`：DTO（§9.5）；`content_api.rs`、`session_api.rs`、`today_api.rs`、`plan_api.rs`、`drill_api.rs`：`impl AppCore`（§9.4）；`tools_api.rs`：`#[frb(sync)]` 工具函式 |
| `app/` | API 與領域 crate 之間的組裝層：`deps.rs`（`Deps` 組裝與 `Clock` 注入）、`views.rs`（一次 API 呼叫共用的進度快照）、各功能檔 `course`、`dialogue`、`drill`、`grammar`、`kana`、`new_content`、`peek`、`plan`、`session`、`settings`、`stats`、`today`、`vocab`、`vocab_search` |
| `app/mapping/` | 領域型別→DTO，依領域分檔：`dialogue`、`enums`、`grammar`、`kana`、`plan`、`question`、`sentence`、`settings`、`vocab` |
| `frb_generated.rs` | FRB 產生，不手改 |
| **`crates/jp_lang`**（不依賴其他 jp_* crate） | |
| `clock.rs` | `Clock`、`SystemClock`、`FixedClock`、`DayContext`、`LogicalDate`（§2） |
| `kana/` | `table.rs` 假名↔羅馬字對照表、`romanize.rs` 假名→羅馬字、`reverse.rs` 羅馬字→假名、`grade.rs` 打字判定、`furigana.rs` 振假名對齊（§4） |
| `grammar/` | `conjugate.rs` 變化引擎（§4.7）、`stems.rs` R07 的合法語幹 |
| `quiz/rng.rs` | 確定性亂數：ChaCha8、FNV-1a、洗牌（§8.1） |
| **`crates/jp_content`**（依賴 jp_lang） | |
| `build.rs` | 走訪 `rust/content/**/*.json` 生成清單、寫入 `CONTENT_STAGE`（§3.1） |
| `manifest.rs`、`load.rs`、`raw.rs` | `include!` 生成的清單；啟動流程（§3.4）；依路徑分派解析 |
| `schema/` | serde 結構，依內容檔分檔：`course`、`dialogue`、`drills`、`enums`、`kana`、`lexicon`、`notes`（§3.2） |
| `sentence.rs`、`mixed.rs`、`speech.rs` | `t` 解析與衍生資料（顯示、分詞假名、羅馬字、振假名、TTS，§3.3）；`{ja:…}` 標記；非句子內容的語音文字 |
| `filter.rs`、`refs.rs`、`validate.rs` | `CONTENT_STAGE` 過濾與軟引用修剪；列舉引用；啟動驗證（R01–R03） |
| `store/` | `ContentStore`、衍生資料與次級索引 |
| `disk.rs`、`scan.rs`、`lint/`（`tooling` feature） | 從磁碟讀內容與 `DEFAULT_STAGE`；工具用的內容走訪；內容 lint R01–R25、RC1–RC11（§11.3），依規則分檔；R13、R14、R21、R22、R23 已移除，編號留空（RULINGS O13） |
| `test_support.rs`（`test-support` feature） | 共用測試夾具（`load_full_fixture` 等） |
| **`crates/jp_store`**（依賴 jp_lang） | |
| `db.rs`、`migrate.rs`、`sql/001_init.sql` | 開檔、PRAGMA、`Mutex<Connection>`、`reset_all` 的換檔（§5.1、§5.5）；遷移（§5.2）；schema（§5.3） |
| `repo.rs`、`records.rs`、`convert.rs`、`error.rs` | Repository traits（§5.4）；不可變的 record 型別；時間與邏輯日的資料庫表示；`StoreError` |
| `sqlite_srs.rs`、`srs_write.rs` | SrsRepo 的查詢與寫入 |
| `sqlite_plan.rs`、`plan_progress.rs`、`plan_versions.rs` | PlanRepo；進度（`item_intro`、`lesson_progress`、任務、里程碑）與計畫版本、快照的 SQL |
| `sqlite_activity.rs`、`sqlite_settings.rs` | ActivityRepo、SettingsRepo |
| **`crates/jp_srs`**（依賴 jp_lang、jp_content、jp_store） | |
| `card_id.rs`、`scheduler.rs`、`facets.rs` | `CardId`、facet；`SrsScheduler` trait 與 rs-fsrs 包裝（§6.3）；內容→卡片與 facet 解鎖（§6.1） |
| `queue.rs`、`review.rs`、`use_cards.rs`、`kana_mastery.rs` | 複習佇列（§6.4）；作答後的評分流程；`use` 卡的題目選取；假名熟練（§6.5） |
| **`crates/jp_plan`**（依賴 jp_lang、jp_content、jp_store、jp_srs） | |
| `input.rs`、`calendar.rs`、`state.rs` | 計畫輸入與略過規則（§7.1）；學習日與 `weekday_mask`；游標狀態（§7.3） |
| `budget.rs`、`compose.rs`、`tasks.rs`、`today.rs` | 每日預算、受限判定、`review_cap`／`capacity`／收尾上限（§7.2）；今日任務的純函式組裝；任務與快照型別；快照讀寫與 `TodayView`（§7.4） |
| `slice.rs`、`slice_kana.rs` | 新內容切分與對話輪替；假名切片（§7.3） |
| `complete.rs`、`completion.rs` | `complete_task` 的副作用；切片完成時的進度變化（與 `forecast` 共用） |
| `forecast.rs`、`milestone.rs`、`streak.rs` | 里程碑與主線完成日預測（§7.5）；檢定任務條件；連續天數（§7.6） |
| **`crates/jp_quiz`**（依賴 jp_lang、jp_content、jp_store、jp_srs） | |
| `model.rs`、`context.rs`、`question_type.rs`、`view.rs` | 題目與作答的領域型別（與 §9.5 DTO 對應）；出題共用輸入；§8.6 對照；由內容組 `SentenceView` 與語音字串 |
| `distractor.rs`、`kana_quiz.rs`、`vocab_quiz.rs`、`card.rs` | 干擾項（§8.2、§8.3）；假名題；單字題；FSRS 卡片對應的題目 |
| `drill/` | 手寫演練轉題目與判定（§8.4）：`choice`、`order`、`simple`、`substitution`、`grade` |
| `slice_drill.rs`、`listen_quiz.rs`、`checkpoint.rs`、`grade.rs` | K11–K15 切片後接的手寫題；聽力 session 與自動補的 `listen_meaning`；檢定（§8.5）；作答判定 |
| **`tools/content_tool`**（開發用，不進 App） | `available`、`lint`、`stats`、`verify`、`coverage`、`charset` 子指令；`rules/` 為 B 層規則，`data/` 讀 `.verify-cache/` 的外部資料（reuse-and-verification.md §9.4） |

測試放在各 crate 的 `tests/`（例如 `crates/jp_plan/tests/budget.rs`）與根目錄的 `rust/tests/`（跨 crate、真實內容與學習迴路），少數模組另有 `#[cfg(test)]`（§11）。

### 1.4 離線保證

App 全程離線：release 建置不得有 `INTERNET` 權限，相依樹不得有 HTTP／TLS client。兩項都由同一支腳本把關，規則與黑名單見 reuse-and-verification.md §9.12（L03、L05–L08），列入 CI（§11.5）：

```bash
# 在 repo 根目錄執行；exit 0 通過、1 違規、2 環境問題
python3 tools/verify/check_offline.py

# CI：Android release 建置之後
python3 tools/verify/check_offline.py --apk build/app/outputs/flutter-apk/app-release.apk --require-apk
```

tokio 由 FRB 帶入，只用於 async runtime，不算 HTTP client。

---

## 2. 時間模型

所有時間只經由 `Clock` 取得。

```rust
pub trait Clock: Send + Sync {
    fn now_utc(&self) -> DateTime<Utc>;
    fn utc_offset_minutes(&self) -> i32;
}
pub struct SystemClock { offset_minutes: AtomicI32 }          // 由 Dart 更新
pub struct FixedClock { now: Mutex<DateTime<Utc>>, offset_minutes: i32 } // 測試用，有 advance()

#[derive(Clone, Copy)]
pub struct DayContext { pub now: DateTime<Utc>, pub utc_offset_minutes: i32, pub rollover_hour: u32 }

impl DayContext {
    pub fn logical_date_of(&self, at: DateTime<Utc>) -> NaiveDate; // 內部可用 NaiveDate
    pub fn today(&self) -> NaiveDate;
    pub fn end_of_today_utc(&self) -> DateTime<Utc>;
}
```

```text
logical_date(t)     = (t + offset - rollover_hour).date()
end_of_day_utc(d)   = (d + 1天)T00:00 + rollover_hour - offset
```

**時區來源**：不用 `chrono::Local`，避免依賴各平台時區資料庫。Dart 用 `DateTime.now().timeZoneOffset.inMinutes` 傳入，在 `open` 時給一次，並於 `AppLifecycleState.resumed` 時呼叫 `set_utc_offset`。範圍 -720..=840，超出回 `InvalidInput`。

**換日時間**：`day_rollover_hour` 預設 4，範圍 0..=12。修改後只影響之後的計算，歷史不重寫。

**不可變的歷史**：`review_log`、`daily_activity` 存當下算出的 `logical_date`，所以旅行或改換日時間不會改寫過去，也不會把連續天數算錯。

邊界測試表（實測，另以 8 組時區與換日時間的組合、每 10 分鐘一步驗證 `end_of_day` 與 `logical_date` 完全對應）：

| UTC 時刻 | 時差（分） | 換日 | 邏輯日 |
|---|---:|---:|---|
| 2026-03-04T19:59:59Z | +480 | 4 | 2026-03-04 |
| 2026-03-04T20:00:00Z | +480 | 4 | 2026-03-05 |
| 2026-03-04T15:59:59Z | +480 | 0 | 2026-03-04 |
| 2026-03-04T16:00:00Z | +480 | 0 | 2026-03-05 |
| 2026-01-01T03:59:59Z | 0 | 4 | 2025-12-31 |
| 2026-03-01T03:00:00Z | 0 | 4 | 2026-02-28 |
| 2028-03-01T03:00:00Z | 0 | 4 | 2028-02-29 |
| 2026-03-04T11:00:00Z | -480 | 4 | 2026-03-03 |
| 2026-03-04T12:00:00Z | -480 | 4 | 2026-03-04 |
| 2026-03-04T13:59:59Z | +840 | 4 | 2026-03-04 |
| 2026-03-04T14:00:00Z | +840 | 4 | 2026-03-05 |

---

## 3. 內容載入

內容格式見 `curriculum.md` §12。本節定義載入方式與對應的 Rust 型別。

### 3.1 嵌入（實測）

`rust/crates/jp_content/build.rs` 走訪 `rust/content/**/*.json`，排序後生成 `$OUT_DIR/content_manifest.rs`，每列是 `(相對路徑, include_str!(絕對路徑))`，並把環境變數 `CONTENT_STAGE`（`p0a`、`p0`、`full`，預設 `p0`）寫成常數。預設值另有一份在 `jp_content::disk::DEFAULT_STAGE`（`content_tool` 與 lint 測試用），`disk.rs` 的 `build_default_matches_runtime_default` 在沒有設 `CONTENT_STAGE` 時比對兩者。以下為該檔現況：

```rust
//! 走訪 `rust/content/**/*.json` 生成內容清單，並把 `CONTENT_STAGE` 寫成常數（rust-core.md §3.1）。

use std::{
    env,
    fmt::Write as _,
    fs,
    path::{Path, PathBuf},
};

const CONTENT_DIR: &str = "../../content";
const STAGE_ENV: &str = "CONTENT_STAGE";
/// 必須和 `jp_content::disk::DEFAULT_STAGE` 一致（disk.rs 有測試）。
const DEFAULT_STAGE: &str = "p0";
const VALID_STAGES: [&str; 3] = ["p0a", "p0", "full"];

fn collect(dir: &Path, out: &mut Vec<PathBuf>) -> std::io::Result<()> {
    for entry in fs::read_dir(dir)? {
        let path = entry?.path();
        if path.is_dir() {
            collect(&path, out)?;
        } else if path.extension().is_some_and(|e| e == "json") {
            out.push(path);
        }
    }
    Ok(())
}

fn render_manifest(
    stage: &str,
    root: &Path,
    files: &[PathBuf],
) -> Result<String, Box<dyn std::error::Error>> {
    let mut src = format!("pub const CONTENT_STAGE_NAME: &str = {stage:?};\n");
    src.push_str("pub const CONTENT_FILES: &[(&str, &str)] = &[\n");
    for file in files {
        let rel = file
            .strip_prefix(root)?
            .to_string_lossy()
            .replace('\\', "/");
        writeln!(
            src,
            "    ({rel:?}, include_str!({:?})),",
            file.to_string_lossy()
        )?;
    }
    src.push_str("];\n");
    Ok(src)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed={CONTENT_DIR}");
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-env-changed={STAGE_ENV}");

    let stage = env::var(STAGE_ENV).unwrap_or_else(|_| DEFAULT_STAGE.to_string());
    if !VALID_STAGES.contains(&stage.as_str()) {
        return Err(format!("{STAGE_ENV} must be p0a, p0 or full, got {stage}").into());
    }

    let root = PathBuf::from(env::var("CARGO_MANIFEST_DIR")?)
        .join(CONTENT_DIR)
        .canonicalize()?;
    let mut files = vec![];
    collect(&root, &mut files)?;
    files.sort();

    let src = render_manifest(&stage, &root, &files)?;
    fs::write(
        PathBuf::from(env::var("OUT_DIR")?).join("content_manifest.rs"),
        src,
    )?;
    Ok(())
}
```

`content/manifest.rs` 只有一行：`include!(concat!(env!("OUT_DIR"), "/content_manifest.rs"));`。

只收 `.json`。`content/lint/*.txt`（`tts_risky.txt`、`zh_tw_denylist.txt`、`zh_simplified_chars.txt`、`unsplit_allow.txt`、`r10_allow.txt`）只給測試使用，不進 App。

不用 `include_dir`，因為多一個相依；不手寫清單，因為檔案多（2026-11-16 為 140 個）容易漏列。

`CONTENT_STAGE` 無效值會讓建置失敗（實測），改值後自動重建（實測）。所有階段的檔案都會嵌入，範圍由 §3.4 第 2 步在載入時過濾，所以內容增加時不必搬檔。

### 3.2 結構

每個檔案是 `{ "schema": 1, "items": [...] }`，`course.json` 為 `{ "schema": 1, "stages": [...], "order": [...], "lessons": [...] }`。`schema` 不是 1（含省略）就回 `ContentCorrupt`。

下列 struct 與 `curriculum.md` §12 逐欄對應，本節與該節不得不同。實測：整組 struct 用 serde 1.0.229 編譯，`curriculum.md` §12.4–12.6 的全部 JSON 範例（24 個物件、13 題演練、課程檔）都能反序列化；多餘欄位（`seq`、`reorder.distractors`）會被擋下。`content_schema.rs`（§11.2）持續比對這兩處。

共通規則，下列程式碼不重複標示：

- 全部 `#[derive(Deserialize)]`，且 `#[serde(deny_unknown_fields)]`，唯一例外是 `SubRowDef`（slot 鍵是動態的，要用 `flatten`，而 `flatten` 與 `deny_unknown_fields` 不相容）。
- 每個 `Vec<_>`、`bool` 欄位都有 `#[serde(default)]`；`Option<_>` 省略時為 `None`。必填陣列非空由 RC10 檢查（§11.3）。
- 所有 enum `#[serde(rename_all = "snake_case")]`。
- 標 `// +R` 的 struct 末尾都有 `pub retired: bool, pub replaced_by: Option<String>`（curriculum §12.1 穩定性規則 2）。

```rust
// 列舉
pub enum ContentStage { P0a, P0, Full }  // 另 derive PartialOrd, Ord：P0a < P0 < Full
pub enum Pos { N, Pron, Num, Counter, V5, V1, V1S, Vs, Vk, AdjI, AdjNa, Adv, Conj, Interj, Phrase } // V1S 的 JSON 值是 v1_s；Pos::family() 把 V1S 歸入 V1
pub enum Jlpt { N5, N4, Beyond }
pub enum Transitivity { Tr, In, Both }
pub enum UseLevel { Safe, FriendsOnly, RecognizeOnly }
pub enum TtsMode { Auto, Kana }
pub enum Style { Polite, Plain, Mixed, Neutral }
pub enum Register { Polite, Plain, Neutral }
pub enum Script { Hira, Kata }
pub enum KanaKind { Basic, Dakuten, Yoon, Extended, Mark }
pub enum ConfusableKind { Shape, CrossScript, KanaKanji, Listen }
pub enum SoundGroupKind { Voicing, Length, Sokuon, Yoon, Accent }
pub enum DialogueKind { Lesson, Extra, Casual }
pub enum KanaWordMode { Choice, Typing }
pub enum ConjForm { Masu, Te, Ta, Nai, Potential, Volitional, Ba, Passive, Causative, Imperative }

// course.json（檢定位置只由 MilestoneDef.lesson 決定）
pub struct CourseDef { pub schema: Option<u32>, pub stages: Vec<StageDef>, pub order: Vec<String>, pub lessons: Vec<LessonDef> }
pub struct StageDef { pub id: String, pub title_zh: String }
pub struct LessonDef {
    pub id: String, pub stage: String, pub content_stage: ContentStage,
    pub title_zh: String, pub can_do_zh: String, pub dialogue: Option<String>,
}

// kana/
pub struct KanaDef {                                                    // +R
    pub id: String, pub lesson: String, pub script: Script, pub kind: KanaKind,
    pub row: Option<String>,                 // kind = yoon 必填
    #[serde(rename = "char")] pub ch: String,
    pub rule: Option<String>,                // 只有 kind = mark 使用
    pub origin_kanji: Option<String>, pub hint_zh: String,
    pub confusable: Vec<String>, pub example_words: Vec<ExampleWordDef>,
    pub tts_text: Option<String>,            // 省略時送 ch
    pub listen_disabled: bool,
}
pub struct ExampleWordDef { pub surface: String, pub zh: String }
pub struct ConfusableDef {                                              // +R
    pub id: String, pub lesson: String, pub kind: ConfusableKind,
    pub members: Vec<String>, pub literals: Vec<LiteralDef>, pub diff_zh: String,
}
pub struct LiteralDef { pub text: String, pub zh: String }
pub struct RuleCardDef {                                                // +R
    pub id: String, pub lesson: String, pub title_zh: String, pub body_zh: String,
    pub sound_groups: Vec<String>, pub drills: Vec<String>, pub examples: Vec<RuleExampleDef>,
}
pub struct RuleExampleDef { pub text: String, pub zh: String, pub beats: Vec<String> }
pub struct SoundGroupDef {                                              // +R
    pub id: String, pub lesson: String, pub kind: SoundGroupKind, pub title_zh: String,
    pub body_zh: String, pub test_drills: Vec<String>, pub pairs: Vec<PairDef>,
}
pub struct PairDef {
    pub a: String, pub a_zh: String, pub b: String, pub b_zh: String,
    pub a_kana: Option<String>, pub b_kana: Option<String>,
    pub a_tts_text: Option<String>, pub b_tts_text: Option<String>, pub listen_disabled: bool,
}

// vocab/
pub struct VocabDef {                                                   // +R
    pub id: String, pub lesson: String, pub lesson_order: u32,
    pub surface: String, pub kana: String, pub zh: Vec<String>, pub pos: Pos,
    pub trans: Option<Transitivity>, pub accent: Option<u8>, pub jlpt: Jlpt,
    pub topics: Vec<String>, pub examples: Vec<String>,
    pub tts: Option<TtsMode>,                 // 省略時 Kana
    pub same_form_zh: bool, pub hook_zh: Option<String>, pub trap_zh: Option<String>,
    pub notes: Vec<String>, pub pair: Option<String>, pub reading_family: Vec<String>,
    pub use_level: Option<UseLevel>,          // 省略時 Safe
    pub conj_omit: Vec<ConjForm>,             // 活用表略過的形；conjugate 題不得考（RC7）
}

// grammar/
pub struct GrammarDef {                                                 // +R
    pub id: String, pub lesson: String, pub lesson_order: u32, pub jlpt: Jlpt,
    pub title_zh: String, pub pattern: String, pub meaning_zh: String, pub explain_zh: String,
    pub compare_zh: String, pub trap_zh: Option<String>, pub formation: Vec<FormationRowDef>,
    pub register: Register, pub requires: Vec<String>, pub examples: Vec<String>,
    pub contrast: Vec<String>, pub terms: Vec<String>,
}
pub struct FormationRowDef { pub from: String, pub to: String }

// sentences/
pub struct SentenceDef {                                                // +R
    pub id: String, pub lesson: String, pub t: String,
    pub zh: String, pub style: Style,
    pub tts: Option<TtsMode>,                 // 省略時 Auto
}

// notes/：一個檔案一種形狀，依路徑分派，不用 untagged
pub struct FalseFriendNoteDef {                                         // +R
    pub id: String, pub surface: String, pub vocab: Option<String>,
    pub ja_zh: String, pub misread_zh: String, pub lesson: Option<String>,
}
pub struct ShinjitaiNoteDef {                                           // +R
    pub id: String, pub ja: String, pub zh_tw: String, pub kind: String, pub vocab: Vec<String>,
}
pub struct ReadingNoteDef {                                             // +R
    pub id: String, pub lesson: String, pub title_zh: String, pub body_zh: String,
    pub examples: Vec<ReadingExampleDef>, pub vocab: Vec<String>, pub caveat_zh: String,
}
pub struct ReadingExampleDef { pub hanzi: String, pub tai: String, pub ja: String }
pub struct TransferNoteDef {                                            // +R
    pub id: String, pub lesson: String, pub title_zh: String, pub zh_pattern: String,
    pub wrong: String, pub right: String, pub explain_zh: String,
    pub grammar: Vec<String>, pub vocab: Vec<String>,
}
pub struct TermNoteDef {                                                // +R
    pub id: String, pub lesson: String, pub term: String, pub aka_zh: Option<String>,
    pub body_zh: String, pub grammar: Vec<String>,
}

// drills/：#[serde(tag = "type", rename_all = "snake_case", deny_unknown_fields)]
// 每個變體開頭都有 id: String, lesson: String, targets: Vec<String>，結尾都是 +R，下面省略不寫
pub enum DrillDef {
    Substitution { frame: String, rows: Vec<SubRowDef> },
    Reorder { sentence: String, accept_orders: Vec<Vec<u32>>, audio_first: bool },
    ParticleFill { sentence: String, blanks: Vec<BlankDef>, explain_zh: Option<String> },
    ZhToJaChoice { prompt_zh: String, answer: String, distractors: Vec<DistractorDef>, tts: Option<TtsMode> },
    ListenMeaning { sentence: String, choices_zh: Vec<String>, answer_index: u32 },
    SituationResponse { situation_zh: String, style: Option<Style>, prompt: Option<String>,
                        answer: String, distractors: Vec<DistractorDef>, tts: Option<TtsMode> },
    Conjugate { form: ConjForm, lemmas: Vec<String> },
    RegisterConvert { from: String, to: String },
    Shadowing { sentence: String },
    FalseFriend { note: String, prompt_zh: String, choices_zh: Vec<String>, answer_index: u32 },
    MinimalPair { a: String, a_zh: String, b: String, b_zh: String, a_kana: Option<String>, b_kana: Option<String>,
                  a_tts_text: Option<String>, b_tts_text: Option<String>, listen_disabled: bool },
    KanaWord { word: String, zh: String, mode: KanaWordMode, choices_zh: Vec<String>, answer_index: Option<u32> },
}
pub struct SubRowDef {                        // 無 deny_unknown_fields；slots 的鍵由 lint 比對 frame
    pub zh: String, pub tts: Option<TtsMode>,
    #[serde(flatten)] pub slots: BTreeMap<String, String>,
}
pub struct BlankDef { pub word_index: u32, pub choices: Vec<String> }   // P0：blanks 長度固定 1（R12）
pub struct DistractorDef { pub t: String, pub why_zh: String }

// dialogues/
pub struct DialogueDef {                                                // +R
    pub id: String, pub kind: DialogueKind, pub lesson: String,
    pub style: Style, pub scene_zh: String, pub goal_zh: String,
    pub roles: Vec<RoleDef>, pub turns: Vec<TurnDef>, pub focus: Vec<String>,
    pub quiz: Vec<String>,                    // listen_meaning 的 dr.* ID
}
pub struct RoleDef { pub id: String, pub name_zh: String, pub voice: String }
pub struct TurnDef { pub role: String, pub t: String, pub zh: String, pub note_zh: Option<String>, pub tts: Option<TtsMode> }

// plan/
pub struct PlanPresetDef {
    pub id: String, pub minutes: u32, pub new_words_per_day: u32, pub kana_chars_per_day: u32,
    pub split: SplitDef,
}
pub struct SplitDef { pub new: u32, pub review: u32, pub drill: u32, pub listen: u32 }
pub struct MilestoneDef { pub id: String, pub lesson: String, pub title_zh: String, pub pass_ratio: f64, pub questions: u32 }
```

`ZhToJaChoice.answer` 與 `SituationResponse.answer` 可以是 `se.*` ID 或內嵌 `t`：字串含 `|` 或空白時視為 `t`，否則視為 ID。

檔案、Def、DTO 的對應（`app/mapping/` 依此實作）：

| 路徑 | curriculum §12 範例 | Def | DTO（§9.5） |
|---|---|---|---|
| `course.json` | §12.4 課程 | `CourseDef` | `CourseOverviewDto`、`LessonDetailDto` |
| `kana/hiragana.json`、`katakana.json` | `kana*` | `KanaDef` | `KanaCellDto`、`KanaDetailDto` |
| `kana/confusables.json` | `confusable_*` | `ConfusableDef` | `ConfusableDto` |
| `kana/rules.json` | `rule_card` | `RuleCardDef` | `RuleCardDto` |
| `kana/sound_groups.json` | `sound_group*` | `SoundGroupDef` | `SoundGroupDto` |
| `vocab/*.json` | `vocab*` | `VocabDef` | `VocabSummaryDto`、`VocabDetailDto` |
| `grammar/*.json` | `grammar` | `GrammarDef` | `GrammarSummaryDto`、`GrammarDetailDto` |
| `sentences/*.json` | `sentence` | `SentenceDef` | `SentenceDto` |
| `drills/*.json` | §12.5 | `DrillDef` | `QuestionDto`（`quiz/`） |
| `dialogues/*.json` | `dialogue` | `DialogueDef` | `DialogueDto`、`DialogueSummaryDto` |
| `notes/false_friends.json` | `note_false_friend` | `FalseFriendNoteDef` | `NoteDto::FalseFriend` |
| `notes/shinjitai.json` | `note_shinjitai` | `ShinjitaiNoteDef` | `NoteDto::Shinjitai` |
| `notes/readings.json` | `note_reading` | `ReadingNoteDef` | `NoteDto::Reading` |
| `notes/transfer.json` | `note_transfer` | `TransferNoteDef` | `NoteDto::Transfer` |
| `notes/terms.json` | `note_term` | `TermNoteDef` | `NoteDto::Term` |
| `plan/presets.json` | `plan_preset` | `PlanPresetDef` | `BudgetDto`（`plan/budget.rs`） |
| `plan/milestones.json` | `milestone` | `MilestoneDef` | `MilestoneDto` |

中文與混合欄位的 `{ja:…}` 標記（curriculum §12.2）在 DTO 裡保留原文，Dart 用 `parse_mixed_text`（§9.4）轉成 span。

### 3.3 `t` 解析（實測，以 curriculum 的樣本驗證）

```rust
pub struct Morph { pub surface: String, pub kana: String, pub r#ref: String }
pub enum Word { Punct(String), Morphs(Vec<Morph>) }
pub fn parse_t(t: &str) -> Result<Vec<Word>, TParseError>;
```

| 輸入 | 顯示 | 羅馬字 |
|---|---|---|
| `私\|わたし\|vo.watashi は\|gr.wa_topic 毎朝\|まいあさ\|vo.maiasa ご飯\|ごはん\|vo.gohan を\|gr.wo_obj 食べ\|たべ\|vo.taberu+ます\|gr.masu 。` | 私は毎朝ご飯を食べます。 | watashi wa maiasa gohan o tabemasu. |
| `こんにち\|vo.konnichiwa は\|vo.konnichiwa` | こんにちは | konnichi wa |
| `何\|なに\|vo.nani し\|vo.suru+てる\|gr.te_iru_prog の\|gr.n_desu ？` | 何してるの？ | nani shiteru no? |
| `歯\|は\|vo.ha が\|gr.ga_subject 痛\|いた\|vo.itai+い\|gr.i_adj 。` | 歯が痛い。 | ha ga itai. |
| `3本\|さんぼん\|gr.counters` | 3本 | sanbon |
| `はい\|vo.hai 、 見\|み\|vo.miru+ませんでした\|gr.masu_past 。` | はい、見ませんでした。 | hai, mimasendeshita. |
| `「 それ\|vo.sore 」 は\|gr.wa_topic 何\|なに\|vo.nani` | 「それ」は何 | "sore" wa nani |

推導結果：

- **顯示文字**：surface 串接。
- **分詞假名**：每個詞的 kana 串接，詞間空白（供羅馬字、打字判定）。
- **羅馬字**：§4.3。
- **振假名**：每個語素呼叫 `furigana(surface, kana)`（§4.6）。
- **TTS 文字**：`speech_kana` 永遠是分詞假名，並把單獨成詞且 surface 為假名的 は／へ 換成 わ／え（curriculum §10.1）；每個 `WordDto` 也帶自己的 `speech_kana`，供逐詞播放。`SpeechDto.text` 依 `tts` 的有效值決定：`auto` 為顯示文字，`kana` 等於 `speech_kana`。有效值的解析順序是 `t` 自身的 `tts`（`se.*`、`turns[]`、`rows[]`）→所屬題目的 `tts`→`auto`，含 `@name` 的 `t` 一律 `kana`。`SpeechDto.kana` 永遠等於 `speech_kana`。行動平台送 `text`，Linux 備援送 `kana`（flutter-app.md）。
- **排序題詞塊**：標點不算；ref 為 `gr.*`、單一語素、surface 屬於助詞集合（は が を に で へ と も の から まで より か ね よ や）的詞，黏到前一詞（實測得到 `私は／毎朝／ご飯を／食べます`）。
- **`@new`**：`@new:釋義` 的中文放進 `WordDto.gloss_zh`，`ref_id` 跳過 `@` 開頭的 ref。

非句子內容的 `SpeechDto`：

| 內容 | `text` | `kana` |
|---|---|---|
| 假名 | `tts_text`，省略時 `char` | 同 `text` |
| 單字，`tts: kana`（預設） | `vocab.kana`；含空白時把獨立的 は／へ 換成 わ／え | 同 `text` |
| 單字，`tts: auto` | `surface` | 同上一列的 `text` |
| `minimal_pair`、語音示範組的 `a`／`b` | `a_tts_text`，省略時 `a` | `a_kana`，省略時同 `text` |
| 規則卡例字 | `text` | 同 `text` |

kana 模式送出前的空白處理以實機試聽定案，集中在 `content/sentence.rs` 的 `speech_kana` 一個函式，改動不影響其他模組。

錯誤（實測）：含漢字卻省略 kana → `MissingKana`；沒有 ref → `MissingRef`；ref 前綴不合法 → `BadRef`；空字串 → `Empty`。

### 3.4 啟動流程與索引

`AppCore::open` 執行一次，存入 `Arc<ContentStore>`，之後唯讀。載入邏輯在 `pub fn load_content(files: &[(&str, &str)], stage: ContentStage) -> Result<ContentStore, CoreError>`；App 經 `load_embedded()` 以建置時的 `CONTENT_STAGE_NAME`（預設 `p0`）呼叫它。整合測試用它載入夾具（`rust/crates/jp_content/tests/fixtures/full/`，經 `jp_content::test_support::load_full_fixture`）或真實內容（`p0` 的測試用嵌入的 `CONTENT_FILES`，`p0a` 的測試讀磁碟上的 `rust/content/`；兩者都在測試內寫死階段，見 §11.2），再以 `#[frb(ignore)]` 的 `AppCore::open_with_content(config, store)` 組成 `AppCore`。

1. 走過 `CONTENT_FILES`，依路徑前綴分派解析（§3.2 表）。
2. **階段過濾**（`content/filter.rs`）。`included` 為 `content_stage` 不高於 `CONTENT_STAGE` 的課。`course.order` 與 `lessons` 只留 `included`；`course.stages` 只留至少有一個 `included` 課的階段；帶 `lesson` 的項目（假名、單字、文法、句子、演練、對話、里程碑、筆記）若其課不在 `included` 就丟棄。`no.*` 在 `p0a` 全部略過，以筆記為硬引用的 `false_friend` 演練（`dr.*.ffr.*`）也一併略過；其他階段照常保留，筆記 ID 打錯仍由硬引用檢查抓出；`no.sj.*` 沒有 `lesson`，`p0` 起全部保留。`plan/presets` 永遠保留。
3. 建立主索引，同時檢查 ID 唯一（R01）。
4. 解析全部 `t`，預先算好羅馬字等衍生資料（R02）。
5. 檢查交叉引用存在（R03）。**軟引用**可以指向被階段過濾掉的項目，這時直接從欄位移除，不算錯誤：單字與文法的 `examples`、`contrast`、`reading_family`、`pair`、`notes`，文法的 `terms`，假名的 `confusable`，筆記的 `vocab`、`grammar`。其餘引用（`t` 內的 ref、`requires`、`targets`、`quiz`、`drills`、`sound_groups`、`test_drills`、題目的 `sentence`、`answer`、`from`、`to`、`note`、`lemmas`）必須存在，否則回 `ContentCorrupt`。
6. 建立次級索引。

```rust
pub struct ContentStore {
    stage: ContentStage,
    kana: Vec<KanaEntry>,      confusables: Vec<ConfusableDef>, rule_cards: Vec<RuleCardDef>, sound_groups: Vec<SoundGroupDef>,
    vocab: Vec<VocabEntry>,    grammar: Vec<GrammarEntry>,      sentences: Vec<SentenceEntry>,
    drills: Vec<DrillDef>,     dialogues: Vec<DialogueEntry>,   notes: Vec<NoteDef>,
    course: CourseIndex,       presets: Vec<PlanPresetDef>,     milestones: Vec<MilestoneDef>,
    id_index: HashMap<String, ItemRef>,            // ItemRef = (類別, Vec 下標)
    lesson_pos: HashMap<String, u32>,              // 來自 course.order
    items_by_lesson: HashMap<String, LessonItems>, // 由各項目的 lesson 反查
    sentence_refs: Vec<Box<[u32]>>,                // 每句的 vo.*、gr.* 引用，判斷句子是否可用
    drills_by_target: HashMap<String, Vec<u32>>,
    vocab_by_pos: HashMap<Pos, Vec<u32>>,          // 鍵是 Pos::family()，v1_s 與 v1 同組
    vocab_by_topic: HashMap<String, Vec<u32>>,
}
pub struct LessonItems {
    kana: Vec<u32>, rules: Vec<u32>, confusables: Vec<u32>,
    words: Vec<u32>,     // 依 lesson_order
    grammar: Vec<u32>,   // 依 lesson_order
    dialogues: Vec<u32>,
}
```

`retired` 項目留在 `id_index`（舊卡片仍可解析），但不進次級索引。單字與文法在同一課內依 `lesson_order` 排序，假名依檔案與陣列下標，其他項目依（檔案路徑、陣列下標），排序固定。

啟動只做防止執行期 panic 的檢查（R01–R03 的存在性部分）。其他 lint 由 `cargo test` 負責。內容與程式一起編譯，啟動驗證失敗代表建置有問題，回傳 `ContentCorrupt`。

效能（實測，6,000 筆、1.2 MB 的合成資料，x86 桌機）：release 解析 2.5 ms、建索引 0.2 ms、羅馬字 10 ms；debug 16 ms、1 ms、58 ms。依 curriculum §14 的目標，App 的內容量為 `p0a` 1,152 筆、`p0` 3,739 筆、`full` 5,685 筆，每筆句子多一道 `t` 解析；預設 `p0` 的實際筆數高於目標（單字 812、主線例句 1,932、課程演練 1,082 等，`content_tool --stage p0 stats`，2026-11-16）。真實 `p0` 內容在手機上的載入時間還沒量過。手機可能慢數倍，但 `open` 在背景執行緒完成，不會卡 UI。

---

## 4. 假名與羅馬字引擎

單一事實來源：內容不寫羅馬字。下列規則與表格的案例都在 spike 中全部通過。

### 4.1 公開介面

```rust
pub enum ReadingMode { Word, Sentence }
pub fn reading_mode_of(reading: &str) -> ReadingMode;                // 含空白為 Sentence，否則 Word
pub fn to_romaji_word(kana: &str) -> Result<String, KanaError>;      // 單詞模式
pub fn to_romaji_sentence(reading: &str) -> Result<String, KanaError>; // 空白分詞模式
pub fn to_romaji_reading(reading: &str, mode: ReadingMode) -> Result<String, KanaError>; // 依 mode 分派上兩者
pub fn romanize_words(words: &[Word]) -> Result<String, KanaError>;  // 已解析的 t
pub fn romaji_to_hiragana(input: &str) -> Result<String, RomajiError>;
pub fn typed_answer_matches(input: &str, expected_reading: &str, mode: ReadingMode) -> bool;
pub fn to_hiragana(s: &str) -> String;
pub fn furigana(surface: &str, kana: &str) -> Result<Vec<Ruby>, usize>;

pub enum KanaError { InvalidChar { ch: char, pos: usize }, DanglingLongMark { pos: usize } }
pub enum RomajiError { Unparsable { pos: usize } }
```

### 4.2 單詞規則

先把片假名轉平假名（U+30A1..=U+30F6 減 0x60）。由左至右，**雙字元（拗音、外來語）優先**於單字元。

| 類別 | 規則 |
|---|---|
| 子音 | 赫本式：し shi、ち chi、つ tsu、ふ fu、じ ji、ぢ ji、づ zu |
| 拗音 | しゃ sha、ちゃ cha、じゃ ja、ぢゃ ja，其他 kya 系 |
| 外來語 | ティ ti、ディ di、トゥ tu、ドゥ du、テュ tyu、デュ dyu、ファ／フィ／フェ／フォ fa fi fe fo、フュ fyu、ウィ／ウェ／ウォ wi we wo、シェ she、ジェ je、チェ che、ツァ／ツィ／ツェ／ツォ tsa tsi tse tso、ヴ vu、ヴァ／ヴィ／ヴェ／ヴォ va vi ve vo、ヴュ vyu、イェ ye、クァ／クィ／クェ／クォ kwa kwi kwe kwo、グァ gwa、スィ si、ズィ zi |
| 促音 っ | 下一音節首子音重複；`ch` 前寫 `t`（matcha）。後面沒有音節或是母音時省略（あっ → a，定案 curriculum §12.7 的待決項） |
| 撥音 ん | 寫 `n`；後接母音**或 y** 時寫 `n'`。決策 3 只提母音，y 是補充，否則 ほんや 與 ほにゃ 相同。b／m／p 前仍寫 n（shinbun） |
| 長音符 ー | 重複前一母音（ねーー → neee）；ん 後重複 n（んー → nn）；開頭或 っ 後 → `DanglingLongMark` |
| 長母音 | 不用長音符號：おう → ou、おお → oo、えい → ei |
| 小寫假名單獨出現 | 轉一般母音（ねぇ → nee、はぁ → haa、きゃぁ → kyaa） |
| 標點 | `。.`、`、,`、`！!`、`？?`、`「」『』"`、`…...`、`〜～~`（U+301C、U+FF5E、ASCII）、`（）()`、`・` 空白 |
| ゐ ゑ | i、e |
| 單詞模式的 は／へ／を | ha、he、wo（50 音表與單字用） |
| 不支援 | 漢字、拉丁字母、數字、疊字符（ゝゞヽヾ）、ヷ 系 → `InvalidChar` |

羅馬字輸出與 ID slug 是兩回事：ぢ、づ 的羅馬字是 ji、zu，ID slug 是 di、du（curriculum §12.1）。

### 4.3 句子規則

`reading_mode_of(reading)`：含 ASCII 空白、U+3000 或 Tab 時為 `Sentence`，否則為 `Word`。單字的 `vocab.kana` 依此分流：`こんにち は` 走句子模式（konnichi wa），`は`（歯）、`へ` 走單詞模式（ha、he，reuse-and-verification.md 的 J08）。`typed_answer_matches` 與 `romanize_reading` 用同一套規則，由呼叫端傳 `mode`。

**字串模式**（含空白的分詞假名）：以 ASCII 空白、U+3000、Tab 切詞，空詞略過，輸出以單一空白連接。每個詞去掉前後標點後：

- 等於 は／へ／を → wa／e／o。
- 否則若屬於固定語表 `こんにちは こんばんは では それでは または あるいは もしくは`，尾端 は 讀 wa（防禦用；內容規範是寫成 `こんにち は`，由 lint 擋下未切分的寫法）。
- 否則用單詞規則。

**`t` 模式**：多一道判斷——單一語素且 **surface 為假名** 的詞才適用助詞規則，所以 `歯|は|vo.ha` 讀 ha。標點黏前一詞；開引號／括號黏後一詞。

提及助詞本身時（「は」）讀 wa，這是正確結果。

### 4.4 測試案例表（spike 全數通過）

單詞模式：

| 類別 | 案例 |
|---|---|
| 基本 | あいうえお→aiueo、し→shi、ち→chi、つ→tsu、ふ→fu、じ→ji、ぢ→ji、づ→zu、カタカナ→katakana |
| 拗音 | きゃ→kya、しゃしゅしょ→shashusho、ちゃ→cha、じゃ→ja、ぢゃ→ja、りょこう→ryokou |
| 促音 | がっこう→gakkou、きって→kitte、ざっし→zasshi、まっちゃ→matcha、こっち→kotchi、みっつ→mittsu、はっぴょう→happyou、ベッド→beddo、バッグ→baggu、マッチ→matchi、あっ→a、えっ→e |
| 撥音 | ほん→hon、ほんや→hon'ya、ほにゃ→honya、きんえん→kin'en、きねん→kinen、ぜんいん→zen'in、でんわ→denwa、おんな→onna、しんぶん→shinbun、さんぽ→sanpo、てんき→tenki、ほんを→honwo |
| 長音符 | コーヒー→koohii、ラーメン→raamen、スーパー→suupaa、ケーキ→keeki、ノート→nooto、ビール→biiru、らーめん→raamen、ねーー→neee、んー→nn、すごーい→sugooi |
| 長母音 | ありがとう→arigatou、おおきい→ookii、おとうさん→otousan、おかあさん→okaasan、せんせい→sensei、おねえさん→oneesan、おいしい→oishii、くうき→kuuki、とけい→tokei、とうきょう→toukyou |
| 外來語 | ティー→tii、パーティー→paatii、ディズニー→dizunii、ファン→fan、フィルム→firumu、カフェ→kafe、フォーク→fooku、ウィンドウ→windou、ウェブ→webu、シェフ→shefu、ジェット→jetto、チェック→chekku、ツアー→tsuaa、トゥ→tu、ドゥ→du、デュエット→dyuetto、ヴァイオリン→vaiorin、イェ→ye、クォーター→kwootaa、グァム→gwamu |
| 小寫 | ねぇ→nee、はぁ→haa、あぁ→aa、きゃぁ→kyaa |
| 助詞字元 | は→ha、へ→he、を→wo、はな→hana、へや→heya |
| 標點 | はい、そうです。→hai,soudesu. |

句子模式：

| 輸入 | 輸出 |
|---|---|
| わたし は がくせい です。 | watashi wa gakusei desu. |
| がっこう へ いきます | gakkou e ikimasu |
| ほん を よみます | hon o yomimasu |
| こんにち は | konnichi wa |
| で は | de wa |
| こんにちは | konnichiwa |
| こんばんは。 | konbanwa. |
| こんにちは、 せかい！ | konnichiwa, sekai! |
| では また | dewa mata |
| それでは | soredewa |
| はは は げんき です | haha wa genki desu |
| はな が きれい | hana ga kirei |
| わたし は、 がくせい | watashi wa, gakusei |
| 「は」 は じょし | "wa" wa joshi |
| ほん や | hon ya |
| にほん へ は いきません | nihon e wa ikimasen |
| コーヒー を のみます か？ | koohii o nomimasu ka? |
| わたし　は　がくせい（全形空白） | watashi wa gakusei |
| 　がくせい  です （多餘空白） | gakusei desu |
| 空字串 | 空字串 |

依 `reading_mode_of` 分流：`は`→ha、`へ`→he、`こんにち は`→konnichi wa。

錯誤：`ーあ`→`DanglingLongMark{pos:0}`；`漢字`、`abc`、`3じ`、`いすゞ`、`ヷ`→`InvalidChar`；`っー`→錯誤。

### 4.5 羅馬字→假名與打字判定

反向對照用於打字題與即時預覽。寬鬆接受：`si`／`ti`／`tu`／`hu`／`zi`、`sya`／`tya`／`cya`／`zya`／`jya`，大小寫不分，`-`→ー，`wo`→を。

`n` 的處理（赫本優先，非 IME 邏輯）：

| 情況 | 結果 |
|---|---|
| `n'` | ん，跳 2 |
| 字尾 | ん |
| `nn` 後接母音或 y | ん，只吃 1 個 n（onna → おんな，honnya → ほんにゃ） |
| `nn` 其他 | ん，跳 2（honn → ほん、onnna → おんな） |
| `n` 後接非母音非 y | ん |

雙子音→っ；`tch`→っ＋ち系。無法解析 → `RomajiError`。

有損對應（不屬於來回一致性測試）：ぢ／じ、づ／ず、を（`o`）／お、ー／重複母音、ティ／ち（`ti`）、トゥ／つ（`tu`）、スィ／し（`si`）、ズィ／じ（`zi`）。

`typed_answer_matches`：

1. 輸入含假名：雙方轉平假名、去空白與標點後比對。
2. 否則算期望羅馬字 `want`（依 `mode`），去撇號、空白、標點，折疊長音（`oo`→`ou`、`ee`→`ei`）。
3. **先直接比對**：輸入轉小寫，`-` 展開成前一母音，同樣正規化後等於 `want` 就通過（解決 F9）。
4. 否則轉假名再轉羅馬字，正規化後比對。

下表的 `mode` 都是 `reading_mode_of(期望讀音)`。

| 輸入 | 期望讀音 | 結果 |
|---|---|---|
| watashi wa gakusei desu | わたし は がくせい です | 通過 |
| watasi wa gakusei desu. | わたし は がくせい です。 | 通過 |
| watashi ha gakusei desu | わたし は がくせい です | **失敗**（故意考助詞） |
| hon wo yomimasu | ほん を よみます | **失敗** |
| arigatoo／arigatou | ありがとう | 通過 |
| わたしはがくせいです | わたし は がくせい です。 | 通過 |
| ワタシハガクセイデス | わたし は がくせい です | 通過 |
| konnichiwa／konnichi wa | こんにち は | 通過 |
| honya | ほんや | 通過（撇號不強制） |
| paatii／paati-／PAATII | パーティー | 通過 |
| paachii | パーティー | 失敗 |
| matcha／mattya | まっちゃ | 通過 |
| ha | は（歯） | 通過 |
| wa | は（歯） | 失敗 |

### 4.6 振假名對齊

把 surface 切成「漢字類」與「假名」交錯的段（數字與 ASCII 英數字歸漢字類；§4.2 標點表的字元，例如 `？`、`、`、`〜`，和假名一樣當錨點，讀音裡要原樣出現，不放進振假名），用回溯對齊 kana。解的數量必須恰為 1（R08），否則 lint 失敗；執行期拿不到唯一解時，整個語素當一段 ruby。

- 接在 ASCII 英數字後面的 ASCII `.`、`,` 是小數點、千分位或縮寫，歸漢字類：`3.5キロ／さんてんごきろ` → 3.5(さんてんご)＋キロ；`1,000円`、`1.5倍`、`Mr.田中` 整段一個 ruby。
- 標點錨點以 §4.2 表的同一組比對：`〜`、`～`、`~` 互通，`？`、`?` 互通（`〜人／～にん` → 〜＋人(にん)）；不同組（`？` 對 `！`）不通。
- `{ja:S|K}` 標記的讀音若與底字 0 解（例如讀音漏了 `？`），lint R19 報錯；多解（整句標記常見，`私は音楽が好きです` 的 音楽 可對 おん）執行期同樣退回整段 ruby，假名被讀音蓋住，lint R19 報警告，內容要拆成逐詞標記（課綱 §12.2）。

實測：食べ／たべ → 食(た)＋べ；毎朝／まいあさ → 毎朝(まいあさ)；お願いします／おねがいします → お＋願(ねが)＋いします；3本／さんぼん → 3本(さんぼん)；行き来／いきき → 行(い)＋き＋来(き)；コーヒー／こーひー → 無 ruby；食べ／のむ → 0 解。

### 4.7 變化引擎（`grammar/conjugate.rs`）

`conjugate` 題型與 R07 都需要。

```rust
pub fn conjugate_kana(kana: &str, pos: Pos, form: Form) -> Option<String>;
pub fn conjugate_surface(surface: &str, kana: &str, pos: Pos, form: Form) -> Option<String>;
pub fn legal_stems(lemma: &VocabDef) -> Vec<(String, String)>; // R07：(surface, kana)；vs 回傳空
```

`Form`：`Masu Te Ta Nai Potential Volitional Ba Imperative Passive Causative`。

| 類別 | 規則 |
|---|---|
| v1 | 去 る 接語尾：ます、て、た、ない、られる、よう、れば、ろ |
| v1_s | 特殊一段（くれる）：同 v1，只有命令形是語幹（くれ），不接 ろ；R07 的合法語幹也沒有 くれろ |
| v5 | 語尾依段轉換：ます 用 い段、ない 用 あ段（う→わ）、可能／ば／命令 用 え段、意向 用 お段＋う |
| v5 て／た | う つ る→って／った；む ぶ ぬ→んで／んだ；く→いて／いた；ぐ→いで／いだ；す→して／した |
| 例外 | 行く 的 て／た 形：行って、行った；ある 的 ない 形：ない；いらっしゃる くださる おっしゃる なさる ござる 的ます形：り→い（敬語，S3 教學前要補測試） |
| vs | `surface`、`kana` 是語幹（勉強／べんきょう），活用為語幹＋する 的變化：べんきょうします、して、した、しない、できる、しよう、すれば、しろ；`surface` 算出 勉強して。`vo.suru` 本身（`kana` 為 する）語幹為空 |
| vk | 來る：きます、きて、きた、こない、こられる、こよう、くれば、こい；surface 保留 来 |
| adj_i | くない、くて、かった、ければ；いい 以 よ 為語幹 |

surface 的算法：比對 kana 與變化後 kana 的共同前綴，把 surface 尾端的 okurigana 換掉；保留漢字。spike 通過 49 筆 kana 案例與 16 筆 surface 案例（食べる、飲む、行く、書く、買う、来る、勉強する、高い、いい、ある、する、見る、寝る）。`Passive`、`Causative` 與敬語例外未在 spike 涵蓋，實作時先補測試。

`vs` 的單字在 `t` 裡寫成 `勉強|べんきょう|vo.benkyou し|vo.suru+ます|gr.masu`，活用全由獨立的 `vo.suru` 承擔，所以 R07 對 `vs` 比對合併 surface，`legal_stems` 回傳空。`vo.suru` 本身是例外，`legal_stems` 回傳 し、する、すれ、しろ、しよ、さ、せ，R07 以「`legal_stems` 非空」判定是否為活用語。上面 spike 的 `勉強する` 案例驗證的是前綴保留，語幹輸入（勉強→勉強して）與 `legal_stems` 的 `vs` 行為，實作時先補測試。

---

## 5. SQLite

### 5.1 開啟

Dart 傳入 `path_provider` 的 `getApplicationSupportDirectory()/jp_core.db`。開啟後：

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;
```

### 5.2 遷移

`store/migrate.rs` 持有 `const MIGRATIONS: &[&str]`（`include_str!` SQL 檔），以 `PRAGMA user_version` 記錄版本。每一步在一個 `IMMEDIATE` transaction 內同時執行 SQL 與更新版本（實測：失敗時版本與 DDL 一起回滾）。**已發布的遷移不可修改**，新需求一律加新檔。開啟時若資料庫版本高於 App 版本，回 `MigrationFailed`，不嘗試降級。

### 5.3 Schema（`001_init.sql`）

全部 `STRICT`，實測會拒絕型別錯誤。時間存 INTEGER（UTC 毫秒），邏輯日存 TEXT（`YYYY-MM-DD`）。

```sql
CREATE TABLE app_setting(
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
) STRICT, WITHOUT ROWID;

CREATE TABLE srs_card(
  card_id           TEXT PRIMARY KEY,
  content_id        TEXT NOT NULL,
  facet             TEXT NOT NULL CHECK (facet IN ('read','listen','recog','produce','use')),
  priority          INTEGER NOT NULL DEFAULT 0 CHECK (priority IN (0,1)),
  state             INTEGER NOT NULL CHECK (state BETWEEN 0 AND 3),
  due_at            INTEGER NOT NULL,
  last_review_at    INTEGER NOT NULL,
  stability         REAL NOT NULL CHECK (stability >= 0),
  difficulty        REAL NOT NULL CHECK (difficulty BETWEEN 0 AND 10),
  elapsed_days      INTEGER NOT NULL,
  scheduled_days    INTEGER NOT NULL,
  reps              INTEGER NOT NULL DEFAULT 0,
  lapses            INTEGER NOT NULL DEFAULT 0,
  last_logical_date TEXT,
  suspended         INTEGER NOT NULL DEFAULT 0 CHECK (suspended IN (0,1)),
  introduced_seq    INTEGER NOT NULL,
  created_at        INTEGER NOT NULL
) STRICT, WITHOUT ROWID;

CREATE INDEX idx_card_sched   ON srs_card(state, due_at) WHERE suspended = 0;
CREATE INDEX idx_card_new     ON srs_card(priority, introduced_seq) WHERE suspended = 0 AND state = 0;
CREATE INDEX idx_card_content ON srs_card(content_id, last_logical_date);

CREATE TABLE review_log(
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id            TEXT NOT NULL,
  rating             INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 4),
  state_before       INTEGER NOT NULL CHECK (state_before BETWEEN 0 AND 3),
  state_after        INTEGER NOT NULL CHECK (state_after BETWEEN 0 AND 3),
  elapsed_days       INTEGER NOT NULL,
  scheduled_days     INTEGER NOT NULL,
  stability_after    REAL NOT NULL CHECK (stability_after > 0),
  difficulty_after   REAL NOT NULL CHECK (difficulty_after BETWEEN 1 AND 10),
  reviewed_at        INTEGER NOT NULL,
  logical_date       TEXT NOT NULL,
  utc_offset_minutes INTEGER NOT NULL,
  duration_ms        INTEGER NOT NULL CHECK (duration_ms >= 0),
  question_type      TEXT NOT NULL,
  clock_skewed       INTEGER NOT NULL DEFAULT 0 CHECK (clock_skewed IN (0,1))
) STRICT;

CREATE INDEX idx_log_card ON review_log(card_id, id);
CREATE INDEX idx_log_date ON review_log(logical_date);

CREATE TRIGGER review_log_no_update BEFORE UPDATE ON review_log
BEGIN SELECT RAISE(ABORT, 'review_log is append-only'); END;
CREATE TRIGGER review_log_no_delete BEFORE DELETE ON review_log
BEGIN SELECT RAISE(ABORT, 'review_log is append-only'); END;

CREATE TABLE daily_activity(
  logical_date TEXT PRIMARY KEY,
  reviews_done INTEGER NOT NULL DEFAULT 0,
  new_done     INTEGER NOT NULL DEFAULT 0,
  relearn_done INTEGER NOT NULL DEFAULT 0,
  lessons_done INTEGER NOT NULL DEFAULT 0,
  drills_done  INTEGER NOT NULL DEFAULT 0,
  study_ms     INTEGER NOT NULL DEFAULT 0,
  shadow_kept   INTEGER NOT NULL DEFAULT 0,
  shadow_almost INTEGER NOT NULL DEFAULT 0,
  shadow_lost   INTEGER NOT NULL DEFAULT 0
) STRICT, WITHOUT ROWID;

CREATE TABLE plan_version(
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  effective_from TEXT NOT NULL,
  daily_minutes  INTEGER NOT NULL CHECK (daily_minutes IN (10,20,30,45)),
  weekday_mask   INTEGER NOT NULL CHECK (weekday_mask BETWEEN 1 AND 127),
  start_level    TEXT NOT NULL CHECK (start_level IN ('zero','hiragana','kana','basic')),
  target_date    TEXT,
  created_at     INTEGER NOT NULL
) STRICT;

CREATE INDEX idx_plan_effective ON plan_version(effective_from, id);

CREATE TRIGGER plan_version_no_update BEFORE UPDATE ON plan_version
BEGIN SELECT RAISE(ABORT, 'plan_version is append-only'); END;
CREATE TRIGGER plan_version_no_delete BEFORE DELETE ON plan_version
BEGIN SELECT RAISE(ABORT, 'plan_version is append-only'); END;

CREATE TABLE plan_baseline(
  plan_version_id INTEGER NOT NULL REFERENCES plan_version(id),
  milestone_id    TEXT NOT NULL,
  planned_date    TEXT NOT NULL,
  PRIMARY KEY (plan_version_id, milestone_id)
) STRICT, WITHOUT ROWID;

CREATE TABLE item_intro(
  item_id      TEXT PRIMARY KEY,
  lesson_id    TEXT NOT NULL,
  logical_date TEXT NOT NULL,
  introduced_at INTEGER NOT NULL
) STRICT, WITHOUT ROWID;

CREATE INDEX idx_intro_lesson ON item_intro(lesson_id);

CREATE TABLE kana_mastery(
  kana_id       TEXT PRIMARY KEY,
  correct_run   INTEGER NOT NULL DEFAULT 0,
  fast_run      INTEGER NOT NULL DEFAULT 0,
  attempts      INTEGER NOT NULL DEFAULT 0,
  mastered_at   INTEGER,
  fast_badge_at INTEGER
) STRICT, WITHOUT ROWID;

CREATE TABLE lesson_progress(
  lesson_id             TEXT PRIMARY KEY,
  integration_days_done INTEGER NOT NULL DEFAULT 0,
  integration_dialogue  TEXT,
  skipped               INTEGER NOT NULL DEFAULT 0 CHECK (skipped IN (0,1)),
  completed_date        TEXT,
  completed_at          INTEGER
) STRICT, WITHOUT ROWID;

CREATE TABLE milestone_result(
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  milestone_id TEXT NOT NULL,
  correct      INTEGER NOT NULL CHECK (correct >= 0),
  total        INTEGER NOT NULL CHECK (total > 0),
  passed       INTEGER NOT NULL CHECK (passed IN (0,1)),
  logical_date TEXT NOT NULL,
  taken_at     INTEGER NOT NULL
) STRICT;

CREATE INDEX idx_milestone ON milestone_result(milestone_id, id);

CREATE TRIGGER milestone_result_no_update BEFORE UPDATE ON milestone_result
BEGIN SELECT RAISE(ABORT, 'milestone_result is append-only'); END;
CREATE TRIGGER milestone_result_no_delete BEFORE DELETE ON milestone_result
BEGIN SELECT RAISE(ABORT, 'milestone_result is append-only'); END;

CREATE TABLE daily_plan_snapshot(
  logical_date    TEXT PRIMARY KEY,
  plan_version_id INTEGER NOT NULL REFERENCES plan_version(id),
  payload_json    TEXT NOT NULL,
  created_at      INTEGER NOT NULL
) STRICT, WITHOUT ROWID;

CREATE TABLE daily_task_done(
  logical_date TEXT NOT NULL,
  task_key     TEXT NOT NULL,
  done_at      INTEGER NOT NULL,
  PRIMARY KEY (logical_date, task_key)
) STRICT, WITHOUT ROWID;

CREATE TABLE milestone_dismissed(
  milestone_id TEXT PRIMARY KEY,
  logical_date TEXT NOT NULL,
  dismissed_at INTEGER NOT NULL
) STRICT, WITHOUT ROWID;

CREATE TABLE vocab_flag(
  vocab_id   TEXT PRIMARY KEY,
  known      INTEGER NOT NULL DEFAULT 0 CHECK (known IN (0,1)),
  starred    INTEGER NOT NULL DEFAULT 0 CHECK (starred IN (0,1)),
  updated_at INTEGER NOT NULL
) STRICT, WITHOUT ROWID;
```

`review_log.card_id` 刻意不設外鍵，紀錄要永久保留。內容淘汰時卡片設 `suspended = 1`，不刪除（啟動時 `reconcile` 比對 `ContentStore` 處理）。使用者標記「已會」同樣用 `suspended`，由 `vocab_flag.known` 記錄來源，`set_vocab_flags`（§9.4）解除時只動該字的卡。

關鍵查詢（實測 3 萬張卡片，全部走索引，單次 200 µs 以內；`:audio`、`created_at` 條件另以 SQLite 3.45.1 驗過查詢計畫，索引選擇相同）。`:audio` 為 1 時不過濾，對應 `audio_available`：

```sql
-- 到期複習（含同內容當日 sibling 排除）
SELECT c.card_id FROM srs_card c
WHERE c.suspended = 0 AND c.state = 2 AND c.due_at < :end_of_today
  AND (:audio = 1 OR c.facet <> 'listen')
  AND NOT EXISTS (SELECT 1 FROM srs_card s
                  WHERE s.content_id = c.content_id AND s.card_id <> c.card_id
                    AND s.last_logical_date = :today)
ORDER BY c.due_at, c.card_id LIMIT 1;

-- 學習中
SELECT c.card_id FROM srs_card c
WHERE c.suspended = 0 AND c.state IN (1,3) AND c.due_at <= :limit
  AND (:audio = 1 OR c.facet <> 'listen')
ORDER BY c.due_at, c.card_id LIMIT 1;

-- 新卡（只取今天以前建立的；priority 1 排除同內容當日 sibling，§6.4）
SELECT c.card_id FROM srs_card c
WHERE c.suspended = 0 AND c.state = 0 AND c.priority = :priority AND c.created_at < :start_of_today
  AND (:audio = 1 OR c.facet <> 'listen')
  AND (c.content_id GLOB 'ka.*'                                 -- 主線字卡要教過才取（§6.4）
       OR EXISTS (SELECT 1 FROM item_intro i WHERE i.item_id = c.content_id))
  AND (:priority = 0 OR NOT EXISTS (SELECT 1 FROM srs_card s
                                    WHERE s.content_id = c.content_id AND s.card_id <> c.card_id
                                      AND s.last_logical_date = :today))
ORDER BY c.introduced_seq LIMIT 1;

-- §7.2 條件 3：教過卻還沒做的舊新卡，假名與 :listen 卡除外
SELECT COUNT(*) FROM srs_card c
WHERE c.suspended = 0 AND c.state = 0 AND c.priority = 0 AND c.created_at < :start_of_today
  AND c.content_id NOT GLOB 'ka.*'
  AND c.facet <> 'listen'
  AND EXISTS (SELECT 1 FROM item_intro i WHERE i.item_id = c.content_id);
```

SQLite 的部分索引只認字面條件，`state = 2` 不會被判定蘊含 `state <> 0`，所以索引鍵放 `state` 而不是部分條件。

### 5.4 Repository

分四個 trait，合成一個 `Repository`。方法全部收 `&self`，並發由實作內部的 Mutex 處理。`:memory:` 足夠快，測試直接用真實 SQLite，不寫 fake。

```rust
#[derive(Clone, Copy)]
pub struct QueueFilter { pub audio_available: bool } // false：排除 facet = 'listen'（§9.4）

pub trait SrsRepo {
    fn card(&self, id: &CardId) -> Result<Option<CardRow>, CoreError>;
    fn next_learning(&self, limit_at: DateTime<Utc>, queue: QueueFilter) -> Result<Option<CardRow>, CoreError>;
    fn next_due_review(&self, ctx: &DayContext, queue: QueueFilter) -> Result<Option<CardRow>, CoreError>;
    fn next_new(&self, priority: u8, ctx: &DayContext, queue: QueueFilter) -> Result<Option<CardRow>, CoreError>;
    fn earliest_learning_due(&self, queue: QueueFilter) -> Result<Option<DateTime<Utc>>, CoreError>;
    fn due_review_facets(&self, ctx: &DayContext, queue: QueueFilter) -> Result<Vec<String>, CoreError>; // 依 due_at、card_id；條件同 next_due_review
    fn count_due_reviews(&self, ctx: &DayContext, queue: QueueFilter) -> Result<u32, CoreError>; // 條件同 next_due_review
    fn count_learning(&self, limit_at: DateTime<Utc>, created_before: Option<DateTime<Utc>>, queue: QueueFilter) -> Result<u32, CoreError>;
    fn count_new(&self, priority: u8, ctx: &DayContext, queue: QueueFilter) -> Result<u32, CoreError>;
    fn count_unseen_new(&self, ctx: &DayContext) -> Result<u32, CoreError>; // §7.2 條件 3，不計 facet = 'listen'
    fn count_new_done(&self, priority: u8, on: NaiveDate) -> Result<u32, CoreError>; // 當日第一次接觸（state_before = 0）
    fn count_tail_new_done(&self, ctx: &DayContext) -> Result<u32, CoreError>; // 同上，只算今日起點以前建立的卡（§6.4 收尾上限）
    fn insert_cards(&self, cards: &[NewCard]) -> Result<u32, CoreError>; // INSERT OR IGNORE
    fn apply_review(&self, write: &ReviewWrite) -> Result<(), CoreError>;
    fn set_content_suspended(&self, content_id: &str, suspended: bool) -> Result<u32, CoreError>;
    fn suspend_missing(&self, keep: &HashSet<String>) -> Result<u32, CoreError>;
    fn reviews_for_card(&self, id: &CardId) -> Result<Vec<ReviewLogRow>, CoreError>;
    fn card_counts(&self) -> Result<CardCounts, CoreError>;
}

pub trait PlanRepo {
    fn active_plan(&self, on: NaiveDate) -> Result<Option<PlanVersionRow>, CoreError>;
    fn plan_versions(&self) -> Result<Vec<PlanVersionRow>, CoreError>;
    fn insert_plan(&self, plan: &NewPlan, baseline: &[(String, NaiveDate)], skips: &SkipWrite) -> Result<i64, CoreError>;
    fn baseline(&self, plan_id: i64) -> Result<Vec<(String, NaiveDate)>, CoreError>;
    fn introduced_items(&self) -> Result<HashSet<String>, CoreError>;
    fn lesson_progress(&self) -> Result<HashMap<String, LessonProgressRow>, CoreError>;
    fn snapshot(&self, on: NaiveDate) -> Result<Option<SnapshotRow>, CoreError>;
    fn latest_snapshot_before(&self, on: NaiveDate) -> Result<Option<SnapshotRow>, CoreError>;
    fn put_snapshot(&self, row: &SnapshotRow) -> Result<(), CoreError>; // UPSERT；再學一批會改寫當日快照
    fn delete_snapshot(&self, on: NaiveDate) -> Result<(), CoreError>;
    fn task_done(&self, on: NaiveDate) -> Result<HashSet<String>, CoreError>;
    fn complete_task(&self, write: &CompleteTaskWrite) -> Result<(), CoreError>; // §7.4 全部副作用同一 tx
    fn kana_mastery(&self, id: &str) -> Result<Option<KanaMasteryRow>, CoreError>;
    fn all_kana_mastery(&self) -> Result<Vec<KanaMasteryRow>, CoreError>;
    fn put_kana_mastery(&self, row: &KanaMasteryRow) -> Result<(), CoreError>;
    fn insert_milestone_result(&self, row: &MilestoneResultRow) -> Result<(), CoreError>;
    fn milestone_results(&self) -> Result<Vec<MilestoneResultRow>, CoreError>;
    fn dismiss_milestone(&self, id: &str, on: NaiveDate, at: DateTime<Utc>) -> Result<(), CoreError>;
    fn dismissed_milestones(&self) -> Result<HashSet<String>, CoreError>;
    fn vocab_flags(&self) -> Result<HashMap<String, VocabFlagRow>, CoreError>;
    fn put_vocab_flags(&self, row: &VocabFlagRow) -> Result<(), CoreError>;
}

pub trait ActivityRepo {
    fn activity_range(&self, from: NaiveDate, to: NaiveDate) -> Result<Vec<DailyActivityRow>, CoreError>;
    fn active_dates(&self) -> Result<BTreeSet<NaiveDate>, CoreError>;
    fn plan_active_dates(&self) -> Result<BTreeSet<NaiveDate>, CoreError>;
    fn add_activity(&self, on: NaiveDate, delta: ActivityDelta) -> Result<(), CoreError>;
}

pub trait SettingsRepo {
    fn get_settings(&self) -> Result<SettingsRow, CoreError>;
    fn put_settings(&self, row: &SettingsRow) -> Result<(), CoreError>;
}

pub trait Repository: SrsRepo + PlanRepo + ActivityRepo + SettingsRepo + Send + Sync {}
```

`apply_review` 在一個 `BEGIN IMMEDIATE` 內完成三件事：以 `WHERE card_id = ? AND reps = ?` 更新 `srs_card`（0 列則回 `StaleCard`，實測能擋連點）、INSERT `review_log`、UPSERT `daily_activity`。

record 型別都是不可變值，更新時產生新 record。

日後同步的接點：實作另一個 `Repository`，或在 `apply_review` 外包一層把 `review_log` 上傳。現在不做。

### 5.5 清除全部資料（`reset_all`）

`review_log`、`plan_version`、`milestone_result` 有 append-only 觸發器，不能用 `DELETE`。`reset_all` 改走換檔：

1. 取得連線的 Mutex，全程持有，其他呼叫在鎖上等待。
2. `mem::replace` 把連線換成 `Connection::open_in_memory()`，舊連線 drop 時關閉並收斂 WAL。
3. 刪除 `.db`、`-wal`、`-shm`（與 `delete_database` 共用）。
4. 在同一路徑開新檔，執行 PRAGMA 與遷移，把連線換回。

第 3、4 步失敗時回 `Storage`，此時連線停在記憶體庫，Dart 顯示「請重新啟動 App」。下次 `open` 會在同一路徑建立新資料庫。設定（`app_setting`）一併清除。

---

## 6. 間隔重複

### 6.1 內容→卡片

卡片 ID 為 `<content_id>:<facet>`（curriculum §12.1）。

| 內容 | facet | priority | 建立時機 | 題型（`QuestionType`，§8.6） |
|---|---|---:|---|---|
| `ka.*`（`kind ≠ mark`） | `read` | 0 | 熟練時，或切片 `complete_task` 補建（§6.5） | `KanaRead`、`KanaConfuse`（有 `shape`／`cross_script` 字組時） |
| `ka.*`（`listen_disabled = false`） | `listen` | 1 | `read` 的 `scheduled_days ≥ 4` | `KanaListen` |
| `vo.*` | `recog` | 0 | `new_content_session`（§9.4） | `Recog`：日→中四選一；`same_form_zh` 的字見下 |
| `vo.*`，`same_form_zh = true` | `listen` | 0 | 與 `recog` 同時 | `VocabListen`：聽音選中文 |
| `vo.*`，其他 | `listen` | 1 | `recog` 的 `scheduled_days ≥ 4` | `VocabListen` |
| `vo.*` | `produce` | 1 | `recog` 的 `scheduled_days ≥ 7` | `Produce`：`SelfGrade`（中→日回想，`reveal` 由單字合成，§8.3） |
| `gr.*` | `use` | 0 | `new_content_session` | 從候選題輪流取 |
| `ka.*`（`kind = mark`） | 無 | | 不建卡 | |

`use_level: recognize_only` 的單字不建立 `produce`。`Typing` 只用於 `conjugate` 與 `kana_word`；FSRS 卡片的題型不用打字。

`same_form_zh` 的字：`Recog` 在 `audio_available` 時先播音再選意思（`autoplay = true`、`hide_text_until_answered = true`），否則只顯示假名。

解鎖是作答後的純函式 `unlocks(card_after) -> Vec<NewCard>`，由 `srs/facets.rs` 實作。

`use` 卡的題目選取：候選為 `drills_by_target[content_id]` 中 `pos(drill.lesson) ≤ pos(游標)`、不是 `shadowing`、內含的 `vo.*`、`gr.*` 都已 `item_intro`（`first_card` 依 §7.3 的已知集合），且 `audio_available = false` 時不需語音的題目。候選少於 3 題時，由該項目的例句自動補 `listen_meaning`（句子的可用性同上，`audio_available = false` 時除外）。取 `candidates[(reps + fnv1a(card_id)) % len]`，靠 `reps` 自然輪替，不需題目歷史。候選為空時退回顯示例句的 `SelfGrade`（`question_type` 記為 `Recog`）；例句同樣必須可用，沒有可用例句時只顯示項目標題，不露出還沒教的字。

`shadowing` 不進 FSRS，也不是 `use` 卡候選。三級自評只累計 `daily_activity` 的練習統計（§9.4 `grade_drill`）。

### 6.2 評分對應

| 情境 | 評分 |
|---|---|
| 自評四鈕（再一次／困難／記得／簡單） | Again／Hard／Good／Easy |
| 自動判定：答錯 | Again |
| 自動判定：用了提示或重試後才對 | Hard |
| 自動判定：一次答對 | Good |

自動判定**從不給 Easy**：選擇題答對不代表記憶很穩，給 Easy 會把間隔拉得過長。`duration_ms` 與 `question_type` 寫入 `review_log`，供日後個人化參數使用。自評四鈕只在 `SelfGrade` body 顯示。

### 6.3 包裝 rs-fsrs

```rust
pub trait SrsScheduler: Send + Sync {
    fn preview(&self, card: &CardState, ctx: &DayContext) -> Result<[Outcome; 4], CoreError>;
    fn review(&self, card: &CardState, rating: Rating, ctx: &DayContext) -> Result<Outcome, CoreError>;
}
```

參數：`request_retention` 由設定（預設 0.9，範圍 0.80–0.95）、`maximum_interval: 3650`、`enable_short_term: true`、`enable_fuzz: true`。

每次呼叫：

```rust
fn prepare(card: &CardState, ctx: &DayContext) -> (rs_fsrs::Card, DateTime<Utc>, bool) {
    let skewed = ctx.now < card.last_review;
    let now = ctx.now.max(card.last_review);                    // F2：時鐘倒退
    let elapsed = if card.state == State::New { 0 } else {
        (ctx.logical_date_of(now) - ctx.logical_date_of(card.last_review)).num_days().max(0)
    };
    let last_review = if card.state == State::New { card.last_review }
                      else { now - Duration::days(elapsed) };   // F1：讓 FSRS 看到邏輯日差
    (card.to_fsrs(last_review), now, skewed)
}

fn guard(c: &rs_fsrs::Card) -> Result<(), CoreError> {
    let ok = c.stability.is_finite() && c.stability > 0.0
          && c.difficulty.is_finite() && (1.0..=10.0).contains(&c.difficulty);
    if ok { Ok(()) } else { Err(CoreError::Internal { message: "invalid FSRS output".into() }) }
}
```

輸出卡片的 `last_review` 由 rs-fsrs 設成 `now`，實測正確。`clock_skewed` 寫入 log。

建立新卡：`Card { due: now, last_review: now, ..Default::default() }`，不用 `Card::new()`。

### 6.4 複習佇列（`session_next`）

依序，第一個命中就回傳。`audio_available = false` 時每一步都排除 `listen` facet：

1. 學習中卡片：`state IN (1,3) AND due_at <= now`。
2. 到期複習：`state = 2 AND due_at < end_of_today`，且今日已複習數 < `review_cap`。排除同內容今日已做過的 sibling。
3. 新卡 priority 0：`state = 0 AND created_at < 今日起點`。
4. 新卡 priority 1：同上，且今日 priority 1 已做數 < `new_words_per_day`。同樣排除 sibling。

   第 3、4 步合計有當日收尾上限 `tail_new_cards_per_day`（快照預算的 `tail_card_limit(split.review)`，§7.2）：今日起點以前建立、今天第一次接觸的卡（`count_tail_new_done`）達到上限後，這兩步都不再出卡，剩下的留到隔天。長期無聲後打開聲音時，累積的 `:listen` 新卡因此分散到之後幾天。
5. 提前學習：`state IN (1,3) AND due_at <= now + 20 分鐘`。
6. 都沒有：回 `Done { next_due_at }`。

判定到期用 `due_at < end_of_today`：21:00 排程 4 天的卡，第 4 天早上 08:00 就到期，不必等到 21:00。

`review_cap` 只計 `state = 2` 的卡。超過上限的卡留到隔天，排序為 `due_at` 由舊到新。

到期數（`count_due_reviews`、`due_review_facets`）與第 2 步條件相同，含當日 sibling 排除，T1 的張數才對得上佇列實際可取的卡。

第 3、4 步只取前一天以前建立的新卡，且主線的 `vo.*`、`gr.*` 卡必須已 `item_intro`：第一次接觸在 `NewContent` 內完成（§7.3，RULINGS C04），結案後仍沒作答的卡才留到隔天，由 `Review` 或尾端收尾取用（§7.4）。`new_content_session` 打開就建卡，中途離開的卡還沒教過，留在 state＝0，隔天切片相同，`first_card` 照常出題。假名 `:read` 沒有 `first_card`，不受此限。今日起點為 `end_of_today_utc() - 1 天`。

### 6.5 假名熟練（curriculum §3.3）

假名由 `kana_submit` 回報作答，由 Rust 判定（§9.4）。熟練關與 FSRS 的關係：

- 只有 `kana_read`、`kana_listen`、`kana_confuse` 的作答計入熟練；`kana_match`、`minimal_pair`、`kana_word` 不計。
- 同一字連續答對 2 次，設 `mastered_at`。答錯時 `correct_run` 歸零，答慢不歸零。
- 建卡：字已 `item_intro` 或在今日快照的切片內時，熟練當下 `INSERT OR IGNORE` state＝0 的 `:read` 卡。K1 自由練習的字兩者都不是，只更新 `kana_mastery`，不影響計畫。
- 切片的 `complete_task` 寫 `item_intro`，並為切片內還沒有 `:read` 卡的字補建 state＝0 的卡，所以未達標的字不會進不了 FSRS。`kana_mastery` 只影響徽章與重練。
- 徽章：連續 2 次都在 3000 ms 內，設 `fast_badge_at`。`kana_listen` 由 Dart 從播放結束起算 `duration_ms`。設定 `kana_time_limit = false` 時不看時間，熟練即得徽章。
- 用 `kana_mastery` 表，不寫 `review_log`。
- 課完成條件（§7.3）與熟練無關：全部字已 `item_intro` 且該課規則卡讀過。

### 6.6 複習量佐證

以 rs-fsrs 預設參數模擬 180 天（單一 facet，記憶完全符合模型，Hard／Good／Easy 為 10／80／10%），每日新卡 N、第 91–180 天平均每日複習量：

| 每日新卡 | 第 1–30 天 | 31–60 | 61–90 | 91–180 | 比值 |
|---:|---:|---:|---:|---:|---:|
| 3 | 4.3 | 9.0 | 12.6 | 13.9 | 4.6 |
| 5 | 7.7 | 14.8 | 20.7 | 24.4 | 4.9 |
| 8 | 12.8 | 24.4 | 32.6 | 38.1 | 4.8 |
| 12 | 20.0 | 35.9 | 47.1 | 57.0 | 4.8 |
| 20 | 31.7 | 58.3 | 77.7 | 94.5 | 4.7 |

單一 facet 約 4.8 倍。加上 `listen`、`produce` 兩個次要 facet，落在 curriculum §11.4 假設的 6–10 倍合理。模擬的 Hard／Again 假設不代表真實使用者，上線後用 `review_log` 校正。

---

## 7. 學習計畫引擎

計畫是**由進度推導**的純函式，資料庫只存輸入與進度，不存排定的每日行程。錯過天數因此不需要任何補救寫入。

### 7.1 輸入

```rust
pub struct PlanInput {
    pub daily_minutes: u32,        // 必須等於某個 preset 的 minutes（10/20/30/45）
    pub weekday_mask: u8,          // bit0=週一 … bit6=週日，非 0
    pub start_level: StartLevel,   // Zero / Hiragana / Kana / Basic
    pub target_date: Option<NaiveDate>,
    pub known_kana_lessons: Vec<String>, // 只收 K、KK 課；「會一點假名」時略過已會的行
}
```

| start_level | 跳過 |
|---|---|
| `zero` | 無 |
| `hiragana` | `pos ≤ pos(le.k19)` |
| `kana` | 所有 `le.k*`、`le.kk*` |
| `basic` | 同上，再加 `pos ≤ pos(le.l07)` |

引導只送 `zero` 與 `hiragana`（「會一點假名」是 `zero` 加 `known_kana_lessons`）；`kana`、`basic` 保留給日後的分級測驗。

`create_plan` 與 `update_plan` 會把 `start_level` 跳過的 K／KK 課與 `known_kana_lessons` 寫成**略過**（`insert_plan` 的同一 transaction，冪等）：為該課每個假名寫 `item_intro`，不建卡；`lesson_progress` 設 `completed_date`＝今天、`skipped`＝1。干擾項（§8.2）因此可以用這些字。`plan_preview` 不寫入，只在記憶體內把這些課視為完成。

`active_plan(today)` 取 `effective_from ≤ today` 中最晚的計畫；時區往西造成邏輯日早於所有 `effective_from` 時，退回最早生效的計畫，不回 `NoActivePlan`。變更計畫 = `insert_plan` 新增一列（`plan_version` 為 append-only），`effective_from = today`，同日多筆取 id 最大者。進度不重置（curriculum §11.3-5）。同時重算 `plan_baseline`。`daily_minutes`、`weekday_mask`、`start_level` 改變或新增了略過紀錄時刪除今日快照，已完成的任務因為 key 帶內容 ID（§7.4）不會與新切片混淆；只改 `target_date` 時保留今日快照，否則完成今日任務後改目標日會多出新切片。

### 7.2 每日預算

```rust
pub struct DayBudget {
    pub split: Split,              // new / review / drill / listen 分鐘；只排複習的日子全部併入 review
    pub review_cap: u32,           // 見下方加權算法，已預留收尾新卡
    pub capacity: u32,             // 積壓判定用：階段配比、不扣收尾新卡（舊快照沒有時為 0）
    pub new_words_limit: u32,      // preset.new_words_per_day
    pub kana_chars_limit: u32,     // preset.kana_chars_per_day
    pub new_content: NewContentMode,
    pub recovery_reason: Option<RecoveryReason>,
    pub recovery_days: u32,        // 連續受限天數，寫入快照供隔天接續
}
pub enum NewContentMode { Full, Minimal, None }
```

- S2 直接用 `preset.split`。
- 其他階段：new／drill／listen = 分鐘 × 比例，四捨五入到 0.5 分，review 取餘數。階段由目前課的 `stage` 決定。游標走完全部已發布的課時，階段取 `course.order` 中最後一個 L 課的 `stage`，`next_slice` 回 None，不列 `NewContent`、`Integration`，複習與其餘任務照常。比例見 curriculum §11.2；S0 為 60／40／0／0，沒有演練與聽力額度，所以 S0 不會列出這兩項任務。

20 分鐘的例子：S0 為 12／8／0／0，S1 為 5／8／5／2，S2 為 4／9／4／3，S3 為 4／9／3／4（new／review／drill／listen）。

**`review_cap`**（單位是張，依題型加權）：

```text
total = floor(review 分鐘 × 60)
tail_card_limit = floor(total / 16)            // 收尾新卡至多用 review 秒數的一半（TAIL_SHARE_DIVISOR = 2）
review_seconds = total − min(tail_new_cards, tail_card_limit) × 8（不低於 0）
  tail_new_cards = 快照當下收尾可取的 state=0 卡（§7.4 的 new_cards，同一個查詢，建快照時不設上限）
依 (due_at, card_id) 走訪今日到期的 state=2 卡（audio_available=false 時排除 :listen）
  cost = 25 秒（use 卡）或 8 秒（其他自動判定卡）
  累加不超過 review_seconds 的張數為 n
到期卡走完仍有餘額時 n += floor(餘額 / 8)
review_cap = max(n, 1)
```

20 分鐘方案（review 9 分＝540 秒）：全為自動判定卡 67 張，全為 `use` 卡 21 張；收尾有 3 張新卡時，自動判定卡 64 張。先扣收尾新卡，是因為 §7.4 的 `Review` 估算會把 `new_cards × 8` 秒加回去：扣了之後 T1 的 `estimated_minutes` 不超過方案分鐘（只多四捨五入，curriculum §11.3-2）。

收尾預留至多 `tail_card_limit` 張（540 秒時 33 張），佇列第 3、4 步也以同一個數為當日上限（§6.4），`TaskDto::Review.new_cards` 不會超過它。沒有這個上限時，長期無聲後打開聲音的那天收尾新卡可達 297 張：預留把 `review_cap` 扣到 1、T1 顯示 47 分（20 分方案，review_rust R2-H1）。現在同一情況 `review_cap` 至少是半個 review 額度換算的張數，T1 仍在方案分鐘內；`p0_learning_loop_edges.rs` 的無聲學習者實測。

**`capacity`**：同一算法但不扣收尾新卡（`tail_new_cards = 0`），只用來判定積壓，`review_cap` 仍是當天的上限。收尾新卡多半是前一天新內容留下、今天一定會碰的卡，用扣過的 `review_cap` 判定會讓認真學習者更常受限：模擬實測 10 分方案的積壓日由 29 天增為 83 天（RULINGS O11）。

**新內容受限**，下列任一成立：

1. `ReviewBacklog`：到期複習數 > `2 × capacity`（§11.3-1）。到期數依當日 `audio_available` 計算。
2. `ReturnAfterBreak`：距最後一次學習計畫活動之間，**排定的學習日**連續 3 天以上未使用（§11.3-2），而且今天有卡可碰（到期卡或收尾新卡至少一張）。只算學習日，否則每週只排週一和週五的使用者，每週都會觸發。「最後一次學習計畫活動」看 `plan_active_dates`（§7.6），K1 自由練習與檢定不算，否則缺席中答一題就取消回鍋保護。「有卡可碰」是出口：什麼卡都沒有時今天做不了事、不會變成活躍日，判回鍋的話天天都是回鍋，永遠拿不到新內容（`rust/tests/return_after_break.rs`）。當天 `review_cap` 減半（`max(floor(cap / 2), 1)`），避免一次面對全部積壓；落在休息日也減半。
3. `UnseenNewCards`：`facet <> 'listen'`、`created_at` 早於今日起點、state＝0、priority 0、已 `item_intro` 的新卡數 > `new_words_limit`（消化不了就不再增加）。沒有 `item_intro` 的卡是中途離開 `NewContent` 留下的，還沒教過，由切片再教，不算積壓（§6.4）。假名的 `:read` 卡不計，因為字已在切片內練過，且假名階段一天可能教 8 行拗音。`same_form_zh` 的 `:listen` 卡不計，因為 `first_card` 只接觸 `recog`，這張卡第一次出現在隔天的複習，無聲模式下也不會被消化。

同時成立時的原因優先序為 `ReturnAfterBreak`、`ReviewBacklog`、`UnseenNewCards`。

`recovery_days` 接續上一筆快照（`latest_snapshot_before`）：學習日受限時 +1，不受限時歸 0，`ReturnAfterBreak` 當天固定為 1；非學習日維持前一筆的值，只有 `ReturnAfterBreak` 落在非學習日時歸 0，下個學習日才從 1 起算，缺席前累積的天數不帶過這段缺席（否則同一個人週六回來會比週一回來提早拿到新內容、複習上限也不同）。

非學習日也在第一次 `today_view` 時建快照、照同樣規則判定受限原因，但不算「積壓第幾天」（`recovery_days` 不遞增，RULINGS O12），所以週末打開 App 不會把「第 3 天起給最小切片」提早。休息日只列 `Review`，不切新內容，也不併入複習：`split` 用階段配比，`review_cap` 也用階段配比（回鍋落在休息日時再減半，回鍋日本來就該輕，`p0_learning_loop_edges.rs` 的 `RestDayReviewOnly`）。要改回「休息日也遞增、也併入」，刪掉 `budget.rs` 的 `recovery_days` 前兩個分支與 `Recovery::reviews_only` 的 `is_study_day` 條件。

| 受限狀態 | `new_content` |
|---|---|
| 不受限 | `Full` |
| `ReviewBacklog` 且到期數 > `BACKLOG_PAUSE_FACTOR × capacity`（`BACKLOG_PAUSE_FACTOR = 5`，RULINGS O12） | `None`，不論 `recovery_days` |
| 受限，`recovery_days ≤ 2` | `None`：當天新內容為 0 |
| 受限，`recovery_days ≥ 3` | `Minimal`：給最小切片（§7.3），之後每天都給，直到不再受限 |

到期數 > `2 × capacity` 的日子（積壓日）另有一項處置（RULINGS O11、O12；原本並列的「暫停專區」已隨專區移除，RULINGS O13）。判定只看到期數，不看原因標籤，所以到期數過線的回鍋日也算；`UnseenNewCards` 不會同時過線（優先序在 `ReviewBacklog` 之後）：

- **只排複習**：學習日積壓且 `new_content = None` 時，new、drill、listen 額度全部併入 review（`split = {new: 0, review: 方案分鐘, drill: 0, listen: 0}`），`review_cap` 用合併後的分鐘重算（同樣先扣收尾新卡），當天不列 `Drill`、`Listen`。回鍋日照樣併入，併入後的 `review_cap` 再減半（20 分方案、到期 300 張：150 張的一半 75）。受限與暫停線的判定仍用階段配比的 `capacity`。`Minimal` 日與休息日維持階段配比。

`ReviewBacklog` 的兩條線都用 `capacity`；`ReturnAfterBreak` 的減半用 `review_cap`。模擬實測（`rust/tests/p0_learning_loop.rs`）：答錯 30%、每週缺兩天的 20 分學習者，收尾後留到隔天的到期卡每天都 ≤ `3 × review_cap ＋ 兩次收尾之間新增的到期量`，最長 6 個日曆天沒有主線切片，第 1,110 天學完 L30；認真學習者 10 分方案的積壓日為 7 天，20、30、45 分為 0 天。這是移除專區後重跑的數字（RULINGS O13）；兩條線的選定見 RULINGS O12。

今天的結果寫入快照，凍結整天，所以開始學習後不會因為 `last_active` 改變而翻轉。

### 7.3 新內容切分（`slice.rs`）

游標 = `course.order` 中第一個未完成、未被 `start_level` 跳過的課。項目由 `items_by_lesson` 反查，已介紹與否看 `item_intro`。**不存切分結果**，所以換方案時會按新的額度重新切。全部已發布的課都完成時游標為 None（`current_lesson_id` 同），此後所有 `pos(…) ≤ pos(游標)`、`pos(…) < pos(游標)` 的條件一律成立。

```rust
pub struct CursorState {
    pub introduced: HashSet<String>,                 // item_intro
    pub completed: HashMap<String, NaiveDate>,       // lesson_progress.completed_date，含略過
    pub integration_days: HashMap<String, u32>,
    pub integration_dialogues: HashSet<String>,      // 已排過的實戰、常體版對話
}
pub struct SliceQuota { pub mode: NewContentMode, pub words: u32, pub kana: u32, pub integration_days_needed: u32 }

pub enum Slice {
    Kana { lesson_ids: Vec<String>, kana: Vec<String>, rules: Vec<String> },
    KanaRule { lesson_id: String, rules: Vec<String>, confusables: Vec<String> },
    Vocab { lesson_id: String, words: Vec<String>, grammar: Vec<String> },
    Integration { lesson_id: String, dialogue_id: Option<String>, phases: Vec<u32>, day_no: u32 },
}
pub fn next_slice(state: &CursorState, quota: &SliceQuota, content: &ContentStore) -> Option<Slice>;

pub const FIRST_KANA_BATCH: u32 = 3;
```

| 游標課的狀態 | 今日切片 |
|---|---|
| K／KK 課，還有未介紹的字 | `Kana`：依 `hiragana.json`、`katakana.json` 的陣列順序取字到額度用完。額度為 `kana_chars_per_day`；整個計畫的第一批（`le.k01` 還沒有任何 `item_intro`）固定 `FIRST_KANA_BATCH`。同一 `row` 的拗音計 1 額度且整行取，其他字計 1，`kind: mark` 計 0 且不進切片。當課取完而額度有剩，沿 `course.order` 繼續取下一個有新字的 K／KK 課，遇到無新字的課（K10、K16–K19）或 L 課即停。該課有規則卡時（KK07）併入第一個切片 |
| K／KK 課，無新字（K10、K16–K19） | `KanaRule`：整課一個切片，算一天 |
| L 課，還有未介紹的單字或文法 | `Vocab`：依 `lesson_order` 取至多 `new_words_limit` 個單字；文法點依「剩餘單字天數」（`max(1, ceil(剩餘字數 / new_words_limit))`）平均分配，先多後少 |
| L 課，都介紹完 | `Integration`：見下 |

**最小切片**（`NewContentMode::Minimal`）：假名或單字 3 筆，假名遇拗音時為 1 行；該課只剩文法時 1 個文法點；該課都介紹完時就是整合日，因為整合不增加新卡。

**整合日**：所需天數 `integration_days_needed` 為 10 分方案 2 天，其他 1 天。`phases` 是 S4 的階段：一般方案 `[1,2,3,4]`；10 分方案第 1 天 `[1,2]`、第 2 天 `[3,4]`，`day_no` 由 `integration_days_done + 1` 決定。

**對話輪替**：預設 `dialogue_id` 為該課主對話。已完成的 L 課數（不含略過的課）大於 0 且為 3 的倍數（每完成 3 課），且存在 `pos(lesson) ≤ pos(游標)`、尚未排過的實戰或常體版對話時，該課的整合日改排其中 `(pos(lesson), 檔案順序)` 最小的一篇，寫入 `lesson_progress.integration_dialogue`。主對話仍可從 S3 手動進入。

**例句與聽力的可用性**：一個句子只有在所有 `vo.*`、`gr.*` 引用都在已知集合內時才可用。`new_content_session` 內（例句與 `first_card` 的 `use` 候選），已知集合為 `item_intro` ∪ 本切片全部 `vo.*`、`gr.*`，與 R18 一致；`Listen`、`Drill` 與 `session_next` 的 `use` 卡只看 `item_intro`。R18 檢查每個切片日至少有一句可用。

**課的完成**：

| 課型 | 完成條件 | 時機 |
|---|---|---|
| K／KK | 全部非 `mark` 的字已 `item_intro`，且該課 `ka.rule.*` 已 `item_intro` | `complete_task` 當下；完成時一併補寫該課 `mark` 與 `ka.cf.*` 的 `item_intro` |
| L | 全部單字與文法已 `item_intro`，且整合日達到所需天數 | 最後一個整合日的 `complete_task` |

`Kana`、`KanaRule` 切片的 `complete_task` 只寫 `item_intro` 與補建 `:read` 卡（§6.5）。`Vocab` 切片的 `complete_task` 寫 `item_intro`，並 `INSERT OR IGNORE` `new_content_session` 應已建立的卡。

### 7.4 今日任務

`today_view` 當日首次呼叫時計算並寫入 `daily_plan_snapshot`：

```rust
pub enum DailyTask {
    Review { key: String, minutes: f64 },                                    // key = "review"
    NewContent { key: String, lesson_id: String, slice: Slice, minutes: f64 }, // key = "new:<第一個項目 ID>"
    Integration { key: String, lesson_id: String, dialogue_id: Option<String>, phases: Vec<u32>, minutes: f64 }, // key = "integration:<lesson_id>:<day_no>"
    Drill { key: String, lesson_ids: Vec<String>, question_count: u32, minutes: f64 }, // key = "drill"
    Listen { key: String, sentence_ids: Vec<String>, minutes: f64 },         // key = "listen"
    Checkpoint { key: String, milestone_id: String },                        // key = "checkpoint:<ms id>"
}
```

順序固定：`Review`、`NewContent` 或 `Integration`、`Drill`、`Listen`、`Checkpoint`。學習中的卡片與前幾天建立、尚未接觸的卡片於尾端收尾，不佔 key：`TodayViewDto.learning_tail` 是今天 `now + 20 分鐘` 內到期的學習中卡片數，加上 `session_next` 第 3、4 步（§6.4）此刻可取的 state=0 卡數（即 `TaskDto::Review.new_cards`）。Dart 在清單跑完後，`learning_tail > 0` 時持續呼叫 `session_next` 直到 `Done`。

沒有 `first_card` 的 state=0 卡（假名 `:read`、`same_form_zh` 的 `:listen`）都靠第 3、4 步第一次出現，只有這類卡的日子由收尾取用，不會一直停在 state=0。

`new_cards`（`SessionSummaryDto.new_cards` 同義）即時查詢：第 3 步可取的卡全部計入，第 4 步可取的卡不超過 `new_words_per_day` 減今日 priority 1 已做數，並排除 sibling；兩步合計不超過當日收尾上限減今日已接觸的收尾新卡（§6.4）；`audio_available = false` 時不含 `listen`。

非學習日只回 `Review`（若有到期）與 `next_study_date`。`Review` 的到期數即時查詢，不存快照。

| 任務 | 額度與內容 |
|---|---|
| `Review` | `done` = 已 `complete_task`，或 `due == 0 且 learning == 0`。`learning` 只計今天之前建立的學習中卡片，當天新內容產生的卡屬於 `learning_tail`，不會把已完成的 `Review` 翻回未完成。`new_cards` 不影響 `done`，只剩 state=0 卡時 `Review` 為 done，這些卡由收尾接觸。`minutes` 依題型估算（下文），不超過 `review_cap` 對應的時間 |
| `NewContent` | new 額度 |
| `Integration` | new＋drill＋listen 額度。當天不另列 `Drill`、`Listen` |
| `Drill` | 取目前課與前兩課的題目，只取內含 `vo.*`、`gr.*` 都已 `item_intro` 的題，以種子洗牌後依題型輪流取，`question_count = drill 分鐘 × 60 / 30`。候選為空時當天不列。游標走完時，「目前課與前兩課」改為最後三個 L 課 |
| `Listen` | 快照時取已可用（§7.3）的句子，目前課與前兩課優先，句數 = `listen 分鐘 × 60 / 20`。listen 額度不足 0.5 分、候選為空或 `audio_available = false` 時當天不列。游標走完時，「目前課與前兩課」改為最後三個 L 課 |
| `Checkpoint` | 里程碑所在課已完成（`skipped` 除外）、沒有 `logical_date ≥ completed_date(milestone.lesson)` 的 `milestone_result`、未 `checkpoint_dismiss` 時列出。引導時 placement 留下的較早紀錄不會擋住這個任務。`done` = 已 `complete_task`，或今天已有該里程碑的 `milestone_result`（從 P1 考完不經 `complete_task`） |

演練任務的作答**不更新 FSRS**（屬於密集練習，FSRS 由 `use` 卡負責），只累計 `drills_done`。

`session_next` 使用快照的 `DayBudget`；若快照還沒建立，先建立。

**估算分鐘**（`TaskDto` 的 `minutes` 與 `TodayViewDto.estimated_minutes`）：`Review` 為前 `review_cap` 張到期卡的 `cost` 總和加上 `new_cards × 8` 秒，換成分鐘後四捨五入到 0.5；其餘任務用快照的 `minutes`。`estimated_minutes` 是未完成任務的總和；`Review` 已 done 且 `new_cards > 0` 時，另加 `new_cards × 8` 秒（換成分鐘後同樣四捨五入到 0.5）。T1 顯示這個數字，不顯示預算。§7.2 的 `review_cap` 已先扣快照當下的收尾新卡，所以當天第一次 `today_view` 的 `estimated_minutes` ≤ 方案分鐘＋0.5（四捨五入）。之後 `due`、`new_cards` 即時變動，估算以當下為準。

`complete_task(task_key)` 依任務類型在單一 transaction 內完成：

| 任務 | 副作用 |
|---|---|
| `Review`、`Drill`、`Listen`、`Checkpoint` | 寫 `daily_task_done` |
| `NewContent` | §7.3 各切片規則，檢查課完成；寫 `daily_task_done` |
| `Integration` | `integration_days_done + 1`，寫 `integration_dialogue`，檢查課完成；寫 `daily_task_done` |

重複呼叫同一 key 是 no-op，未知的 key 回 `NotFound`。

`duration_ms` 是整段任務的時鐘，已包含逐題作答的時間，累加到 `study_ms` 時同一段時間只計一次：`Review` 不計（`submit_review` 已逐題累加），`NewContent` 扣除這批卡當天的 `review_log.duration_ms`，其餘任務全額計入。

**再學一批**（`learn_more`）：今日的 `Review`、`NewContent` 或 `Integration`、`Drill`、`Listen` 都已完成後，取下一個切片，把新的 `NewContent` 或 `Integration` 附加到今日快照。`can_learn_more` 只有在上述任務都完成、`new_content = Full`、今天是學習日、還有下一個切片時為 true，其他情況呼叫回 `InvalidInput`。隔天的快照由當時的 `item_intro` 重新計算，額度不因多學而變動。

**第一次使用**：`create_plan` 後呼叫 `today_view`，進 T2 的第一個 `NewContent`，走同一套任務模型。

### 7.5 里程碑預測與自動順延

```rust
pub struct Forecast {
    pub milestones: Vec<(MilestoneId, NaiveDate)>,
    pub main_end: Option<NaiveDate>,   // 已發布主線的最後一課完成日
}
pub fn forecast(state: &CursorState, today: NaiveDate, plan: &PlanInput, content: &ContentStore) -> Forecast;
```

從 `today` 開始（今天的切片若已完成，從下一個學習日起算），逐學習日模擬切片，直到每個里程碑所在的課完成。模擬與 `slice.rs` 共用同一份切分邏輯（`next_slice`），不模擬受限狀態與任務順序。所以實際完成日比預估晚的天數就是受限天數；認真學習者的受限天數靠 §7.2 的配比與「只排複習」壓低，模擬實測建立計畫時的預估誤差：主線 10／20／30／45 分為 +1.7%／0%／0%／0%（移除專區後重跑，RULINGS O13）。

`forecast` 只算 `ContentStore` 內已發布的內容。預設 `p0` 的四種方案 `main_end` 都有值，實測天數見 curriculum §11.4，由 `rust/tests/real_content_p0.rs` 釘成基準。

**完成後停在實際日期**：主線全部完成後 `main_end` 是最後一課的 `completed_date`，不隨今天往後移。

**順延是自然結果**：錯過 3 天，游標沒動，起算日晚了 3 天，後面日期整體後移（實測每筆正好差 3 天）。任務量不會累加（§11.3-2）。

每個里程碑回傳：

| 欄位 | 算法 |
|---|---|
| `forecast_date` | 預測 |
| `planned_date` | `plan_baseline` |
| `delay_days` | 兩者相減 |

有 `target_date` 時：`main_end ≤ target` 為 `OnTrack`，否則 `Behind`，並回傳 `suggested_minutes`＝可達標的最小 preset，都不夠時為 `None`。

spike 以簡化的「分鐘＋新字數」裝箱模型驗證了順延性質（尚未以 §7.3 的最終切分實作）：10 個（5,5）的課，每日 1 課；從 3 天後起算全部後移 3 天；週一三五計畫只落在學習日；超大的課（30,30）仍排入第一天，不會無窮迴圈。正式實作要用相同案例重測。

### 7.6 連續天數

活躍日（`active_dates`）：`daily_activity` 中答題數或完成課數 ≥ 1。答題數含 K1 自由練習的作答與檢定的題數，所以只做自由練習或只考檢定的日子也算活躍（RULINGS O12），只影響連續天數與統計。

學習計畫活動日（`plan_active_dates`）：§7.2 `ReturnAfterBreak` 的「最後活躍日」用這個，`reviews_done + new_done + relearn_done + lessons_done + shadow_*` ≥ 1，或當天有 `daily_task_done`。不看 `drills_done`，因為 K1 與檢定也累加在那裡；計畫內的演練以任務結案為準，只答幾題沒結案的日子不算（只影響回鍋判定）。定級檢定不是學習計畫的活動：否則新使用者考完隔 4 天才開始，沒有卡可複習、也拿不到新內容（RULINGS O12）。

```rust
pub fn current_streak(active: &BTreeSet<NaiveDate>, today: NaiveDate, is_study_day: impl Fn(NaiveDate) -> bool) -> u32 {
    let (Some(&first), Some(&last)) = (active.iter().next(), active.iter().next_back()) else { return 0 };
    let (mut cur, mut n) = (today.max(last), 0); // 時區往西時今天可能早於最後活躍日
    while cur >= first {
        if active.contains(&cur) { n += 1; }
        else if cur != today && is_study_day(cur) { break; }
        cur = cur.pred_opt().expect("date in range");
    }
    n
}
```

`is_study_day` 查當天生效的 `plan_version`，所以事後把休息日改多，不能回溯救回斷掉的連續天數。

| 活躍日 | 今天 | 計畫 | 結果 | 說明 |
|---|---|---|---:|---|
| 無 | 03-05 | 每天 | 0 | |
| 03-05 | 03-05 | 每天 | 1 | |
| 03-04 | 03-05 | 每天 | 1 | 今天還沒學，不算斷 |
| 03-03 | 03-05 | 每天 | 0 | 昨天缺席 |
| 03-03,04,05 | 03-05 | 每天 | 3 | |
| 03-02,04 | 03-05 | 一三五 | 2 | 休息日透明 |
| 03-02 | 03-05 | 一三五 | 0 | 週三缺席 |
| 03-02,03,04 | 03-04 | 一三五 | 3 | 休息日學習也算 |
| 03-02 | 03-03 | 一三五 | 1 | 今天休息 |
| 03-02 | 03-01 | 每天 | 1 | 時區往西，今天早於最後活躍日 |

（2026-03-02 為週一，上表實測通過。）最佳連續天數掃描 `active_dates` 一次即可，不存欄位。

---

## 8. 測驗與演練產生器

### 8.1 確定性

```rust
pub fn seed_for(session_seed: u32, card_id: &str) -> u64 { session_seed as u64 ^ fnv1a(card_id) }
```

用 `ChaCha8Rng::seed_from_u64` 與自寫 Fisher-Yates（取餘前先排除偏差區間）。**不用 `rand` 的 `shuffle`，也不用 `DefaultHasher`**：前者不保證跨版本的數值穩定，後者的演算法不保證穩定，黃金測試會壞。

實測：`fnv1a("vo.taberu:recog")` = 3117249249664061045；`ChaCha8Rng::seed_from_u64(0).next_u64()` = 13080132717333068652；種子 `42 ^ fnv` 洗牌 `[A..F]` 得 `[B,A,F,D,E,C]`。實作時保留這幾個黃金值。

`session_seed` 由 Dart 傳入。正常使用時用當日邏輯日期的 hash，同一天重開畫面題目相同。斷點續做只保證 FSRS 與假名熟練的寫入：演練、K2、S4 離開後以同 seed 重做，不記題目歷史。

### 8.2 假名題干擾項

`kana_read`（選讀音）／`kana_listen`（選字）的干擾項來自「已教字」，也就是 `item_intro` 加上目前這一批已呈現的字。`checkpoint_start` 的 K19、KK08 題，已教字改為 §8.5 的範圍（`pos ≤ pos(milestone.lesson)` 的該文字系統全部字），不看 `item_intro`。依序取：

1. 同 `ka.cf.*` 易混字組（`shape`、`cross_script`）的成員。
2. 同一行或同一段的字。
3. 其他字。

排除讀音相同的字（ぢ／じ、づ／ず、お／を），否則題目有兩個正解。`to_romaji_word` 結果必須不重複。

選項數為 `min(4, 可用字數 + 1)`，下限 2；第一批只有 3 字，所以第一題是三選一，保證考的是剛呈現過的字。`kana_listen` 只出 `listen_disabled = false` 的字，否則改出 `kana_read`。

`kana_confuse` 考讀音辨識，只出 `shape`、`cross_script` 字組，`kana_kanji` 與 `listen` 字組用於說明與 `minimal_pair`。正解一律是目標字（選項 id 為 `ka.*`，判定不變）：

- `shape`：題幹 `plain_text` 為目標字的羅馬字，`speech` 為該字讀音（`listen_disabled` 時省略，不自動播放）；選項只有該組的 `members`（不含 `literals`）。與目標字讀音相同的成員（お／を）不列為選項。至少要有 2 個已教成員。
- `cross_script`（か／カ）：題幹為同組另一種文字的對應字（`{ja:か}`），選項都是目標字的文字（カ 與其他片假名）。字組通常只有一對，另一種文字的同組字只有正解一個，所以干擾項依本節的三層規則，從已教的同文字字中取。對應字未教或沒有同文字的干擾項時不出題。

### 8.3 單字題干擾項

候選只限已 `item_intro` 的單字（`new_content_session` 內再加上本切片已呈現的字），排除 `retired` 的字。取三個，依序放寬直到滿額：

1. 同 `pos`、同 `topics[0]`。
2. 同 `pos`。

「同 `pos`」以 `Pos::family()` 比對：`v1_s`（只有 くれる）與 `v1` 同組，否則 くれる 找不到干擾項，會退回 `SelfGrade`。

每層內以種子洗牌。排除條件：`id` 相同、`kana` 相同、`zh` 任一項相同。少於 2 個干擾項時退回 `SelfGrade`。

單字題的 `SelfGrade.reveal` 由單字合成，不取 `examples`：`id` 為 `vo.*`，`display` 為 `surface`，`romaji` 同 `VocabSummaryDto.romaji`，`zh` 為 `zh` 以「、」串接，`style` 為 `neutral`，`words` 為單一 `WordDto`（`surface`、`kana`、`romaji` 同單字，`speech_kana` 為下述 `speech.kana`，`ruby` 由 `furigana(surface, kana)` 取得，`kana` 含空白時先去掉，`refs` 與 `ref_id` 為該字，`gloss_zh` 為 None，`is_punct` 為 false，`is_known` 依 §9.4），`speech` 依 §3.3 單字列。`Produce` 相同。

### 8.4 手寫演練（`drills/*.json`）

干擾項已由內容撰寫，程式只洗牌與轉換：

| type | `QuestionBodyDto` | 選項 id 與判定 |
|---|---|---|
| `particle_fill` | `Choice`：`blanks[0].choices`，帶 `blank_word_index`；`plain_text` 為句子中文（正解常靠語境決定） | `c<i>`，正解為 `blanks[0]` 對應的詞 |
| `zh_to_ja_choice`、`situation_response` | `Choice`：`answer`＋`distractors`，答後顯示 `why_zh` | `a`、`d<i>` |
| `listen_meaning`、`false_friend` | `Choice`：`choices_zh` | `c<i>`，`answer_index` 在洗牌前換成穩定 id |
| `reorder` | `Reorder`：詞塊由 §3.3 切出，`accept_orders` 全部接受 | 作答須是完整排列，比對排出的詞塊文字，所以外觀相同的詞塊可以互換 |
| `substitution` | `Choice`，少於 2 個相異選項時 `Reorder` | `variant` 是 `rows` 的索引，見下 |
| `conjugate` | `Typing` | `variant` 是 `lemmas` 的索引，答案由 §4.7 生成 |
| `register_convert` | `Reorder`：顯示 `from`，排出 `to` | `to` 的詞序 |
| `minimal_pair` | `Choice` 二選一，只播音 | `variant` 為 0（播 `a`）或 1（播 `b`），選項 `a`、`b` |
| `kana_word` | `mode` 為 `choice`：`Choice`；`typing`：`Typing` | `c<i>`；打字比對 `word` |
| `shadowing` | `Shadow` | 不判定 |

**`minimal_pair` 的 `listen_disabled`**：`listen_disabled = true` 的 `minimal_pair` 一律不出題，`kana_session`、`new_content_session`（`Rule` 後與 K11–K15 切片後的 `KanaQuiz`）、`drill_session`、`checkpoint_start` 都排除，`Drill` 任務的候選與 `question_count` 也不計；`RuleCardDto.drill_ids`、`SoundGroupDto.test_drill_ids` 也濾掉這些題。濾完沒有題時，`Rule` 後不產生 `KanaQuiz` 步驟。實機檢查的結果回寫這個欄位就生效，不需改程式（curriculum §10.1）。`ka.sg.*` 的 `pairs[].listen_disabled` 是另一個欄位，只控制 S2 的播放，不影響 `minimal_pair` 出題。

`kana_read`、`kana_listen`、`kana_confuse`、`kana_match` 由程式依表生成（`quiz/kana_quiz.rs`）：選項 id 是 `ka.*` ID，`kana_match` 為 `Match` body，5 對。

**`substitution`**：依種子選一列 `rows`，存成 `variant`。題幹顯示該列 `zh` 與展開的句框，選項用同一 slot 其他列的值，slot 取相異值最多的那個（同數取鍵名最後者）。值相同的列去重後保留第一列，選項 id 為 `r<列索引>`，判定時比對該 slot 的值。`blank_word_index` 指向該 slot 在展開後的詞索引。相異選項少於 2 個時改出 `Reorder`。

Reorder 洗牌後若與任一 `accept_orders` 相同，就循環位移 1 格，直到不同；所有排列都合法時（少數兩詞塊的題）直接回傳。

`audio_first: true` 的 `Reorder` 帶 `hide_text_until_answered = true`：Dart 先只顯示播放鈕，播完才顯示詞塊，答題後才顯示完整句子。

`QuestionDto` 同時帶 `correct_option_id`，讓 UI 立即回饋，但**判定以 Rust 為準**。option id 在洗牌前決定（程式產生的是項目 ID，手寫的是 `c0`、`c1`），所以判定不必重新產生題目，也不受洗牌影響。含隨機變體的題目（`substitution`、`conjugate`、`minimal_pair`）把選到的索引放在 `QuestionRefDto.variant`，作答時帶回，Rust 依此重算正解。索引超出範圍回 `InvalidInput`。`Match` 是唯一由 Dart 判定的題型：`kana_match` 的配對在畫面上逐對確認，`AnswerPayload::Match` 只回報結果，且不計入假名熟練。

自動補的 `listen_meaning`（§6.1、§7.4）：`QuestionRefDto` 的 `drill_id` 為 `None`、`content_id` 為句子 ID；選項 id 是 `s:<句子 ID>`，干擾項是其他可用句子的中文（同課優先，排除中文相同者），少於 1 個干擾項時不出題。

每題帶 `focus_ids`（題目的 `targets`；程式生成題為該項目 ID，自動補題見下），Dart 用 `peek` 取得語法重點，答題後和全文、假名、中文一次展開。

`content_id`：手寫題為 `targets[0]`，程式生成題為該項目 ID，`use` 卡為卡片的 `content_id`，自動補的 `listen_meaning` 與 `listen_session` 的 `Shadowing` 為句子 ID。`focus_ids`：自動補題為句子 `t` 內的 `gr.*` ref，依出現順序去重，不含 `se.*`。

### 8.5 檢定

檢定是該課完成後的附加任務，不是課型，不阻擋游標。`milestone.lesson` 是檢定所在課的唯一來源。

`checkpoint_start(milestone_id, seed, audio_available)`：

- K19、KK08（`ms.hira`、`ms.kata`）：只抽假名與規則題（`kana_read`、`kana_listen`、`kana_word`、`minimal_pair`），範圍是 `pos ≤ pos(milestone.lesson)` 的該文字系統全部字（不含 `kind: mark`），不看 `item_intro`，所以引導時的畢業考不需要計畫。`minimal_pair` 依 §8.4 排除 `listen_disabled` 的題。
- L 課：從 `pos ≤ pos(milestone.lesson)` 且已 `item_intro` 的累積內容抽 `milestone.questions` 題，文法與單字各半，新近（最後 3 課）與較舊的內容各半。檢定不出自動補題，所以 `weak_ids` 只會是 `ka.*`、`vo.*`、`gr.*`。

題數不足時回傳實際抽到的題數。

`checkpoint_finish(milestone_id, answers)`：每筆 `AnswerDto` 由 Rust 判定，`correct / total ≥ pass_ratio` 為通過，寫 `milestone_result`（append-only），同一個 transaction 把題數累加到當天的 `drills_done`（RULINGS O12），回傳分數與弱項（答錯題目的 `content_id`）。未通過只建議複習，不鎖任何內容。檢定不寫 FSRS。

`checkpoint_dismiss(milestone_id)`：寫 `milestone_dismissed`，該里程碑不再列入 `Checkpoint` 任務，也不影響游標；之後仍可從計畫頁手動開始。

### 8.6 `QuestionType` 對照

`question_type` 是無欄位 enum（§9.5），由 FRB 產生 Dart enum，Dart 的 `optionLanguageOf` 依此窮舉。

| 值（`review_log` 存 snake_case） | Body | 選項語言 | 需要語音 | 計入假名熟練 |
|---|---|---|---|---|
| `Recog` | `Choice`／`SelfGrade` | 中文 | | |
| `VocabListen` | `Choice`／`SelfGrade` | 中文 | 是 | |
| `Produce` | `SelfGrade` | 無 | | |
| `KanaRead` | `Choice` | 羅馬字 | | 是 |
| `KanaListen` | `Choice` | 日文 | 是 | 是 |
| `KanaMatch` | `Match` | 無（左假名右羅馬字） | | |
| `KanaConfuse` | `Choice` | 日文 | | 是 |
| `MinimalPair` | `Choice` | 中文（`a_zh`、`b_zh`） | 是（`listen_disabled = true` 的題一律不出，§8.4） | |
| `KanaWord` | `Choice`／`Typing` | 中文 | | |
| `Substitution` | `Choice`／`Reorder` | 日文 | | |
| `Reorder` | `Reorder` | 無 | `audio_first` 時 | |
| `ParticleFill` | `Choice` | 日文 | | |
| `ZhToJaChoice` | `Choice` | 日文 | | |
| `ListenMeaning` | `Choice` | 中文 | 是 | |
| `SituationResponse` | `Choice` | 日文 | | |
| `Conjugate` | `Typing` | 無 | | |
| `RegisterConvert` | `Reorder` | 無 | | |
| `Shadowing` | `Shadow` | 無 | 是 | |
| `FalseFriend` | `Choice` | 中文 | | |

退回 `SelfGrade` 的 `Recog`、`VocabListen` 不改 `question_type`，`use` 卡的例句退回也記為 `Recog`（§6.1）。

---

## 9. 給 Dart 的 API

本節是 Dart 介面的唯一來源：函式簽章與 DTO 以此為準，`flutter-app.md` 的 Repository 表只是把這裡的函式包起來。

### 9.1 映射規則（實測）

| Rust | Dart | 規則 |
|---|---|---|
| 一般 `fn` | `Future<T>` | 在 FRB 執行緒池上跑（實測執行緒無名，300 次並行寫入用到 24 個執行緒）。**資料庫操作一律用這種** |
| `async fn` | `Future<T>` | 跑在 tokio worker（實測 `tokio-runtime-worker`）。**不要用**：rusqlite 是阻塞的，會卡住 tokio |
| `#[frb(sync)]` | 同步回傳 | 在呼叫端執行緒跑，只能用於不碰鎖與 IO 的微秒級函式 |
| `pub(crate)`、`#[frb(ignore)]` | 不生成 | 實測 |
| `DateTime<Utc>` | `DateTime`（`isUtc`） | 時刻 |
| `String` `"YYYY-MM-DD"` | `String` | **所有日期** |
| `i32`、`u32` | `int` | 預設數值型別 |
| `i64` | `PlatformInt64`（原生為 `int`） | 少用 |
| `f64` | `double` | |
| `Option<T>`、`Vec<T>`、tuple | `T?`、`List<T>`、record | 實測 |
| 無欄位 enum | Dart `enum` | |
| 帶欄位 enum | freezed sealed class，`Foo_Bar` | 實測 pattern matching |
| `Result<T, E>` | 拋出 `E`（實作 `FrbException`） | 實測 |
| panic | 拋 `PanicException`（訊息含 backtrace） | 實測，不可直接顯示 |

不要用 `u64`、`usize`（對應 `BigInt` 或平台相關）；不要用泛型 DTO，每種分頁各定義一個。

### 9.2 錯誤型別

```rust
#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("not found: {entity} {id}")] NotFound { entity: String, id: String },
    #[error("invalid input: {field}")]   InvalidInput { field: String, reason: String },
    #[error("stale card: {card_id}")]    StaleCard { card_id: String },
    #[error("no active plan")]           NoActivePlan,
    #[error("content corrupt: {file}")]  ContentCorrupt { file: String, detail: String },
    #[error("migration failed")]         MigrationFailed { from_version: i32, message: String },
    #[error("storage: {message}")]       Storage { message: String },
    #[error("internal: {message}")]      Internal { message: String },
}
```

Dart 依變體顯示繁中文案，`message`／`detail` 只寫 log，不顯示給使用者。`StaleCard` 代表連點，Dart 靜默忽略並取下一題。

### 9.3 不透明型別

```rust
#[frb(opaque)]
pub struct AppCore { deps: Deps }
```

`CoreConfig`、`AppCore::open` 回傳 `AppCore`，Dart 用 Riverpod 等持有這個 handle。

```rust
pub struct CoreConfig {
    pub db_path: String,
    pub utc_offset_minutes: i32,
    /// 僅測試用：設定後使用 FixedClock。
    pub fixed_now_utc: Option<DateTime<Utc>>,
}
```

### 9.4 函式清單

所有 `impl AppCore` 的方法都是 `&self`，回傳 `Result<T, CoreError>`，下列省略 `Result` 外層。

```rust
// api/core.rs
pub fn open(config: CoreConfig) -> AppCore;
pub fn set_utc_offset(&self, minutes: i32);
pub fn settings(&self) -> SettingsDto;
pub fn update_settings(&self, patch: SettingsPatchDto) -> SettingsDto;
pub fn display_policy(&self, context: DisplayContext) -> DisplayPolicyDto;
pub fn reset_all(&self);                                     // 關閉連線、刪檔、重建（§5.5）

// api/content_api.rs
pub fn course_overview(&self) -> CourseOverviewDto;
pub fn lesson_detail(&self, lesson_id: String) -> LessonDetailDto;
pub fn kana_chart(&self, script: KanaScript) -> Vec<KanaGroupDto>;
pub fn kana_detail(&self, kana_id: String) -> KanaDetailDto;
pub fn rule_card(&self, rule_id: String) -> RuleCardDto;
pub fn sound_groups(&self) -> Vec<SoundGroupDto>;
pub fn vocab_page(&self, filter: VocabFilterDto, offset: u32, limit: u32) -> VocabPageDto;
pub fn vocab_detail(&self, vocab_id: String) -> VocabDetailDto;
pub fn search_vocab(&self, query: String, limit: u32) -> Vec<VocabSummaryDto>;
pub fn set_vocab_flags(&self, vocab_id: String, flags: VocabFlagsDto) -> VocabSummaryDto;
pub fn vocab_topics(&self) -> Vec<TopicDto>;
pub fn grammar_list(&self, stage: Option<String>, query: Option<String>) -> Vec<GrammarSummaryDto>;
pub fn grammar_detail(&self, grammar_id: String) -> GrammarDetailDto;
pub fn note_list(&self, kind: NoteKind) -> Vec<NoteDto>;
pub fn sentence(&self, sentence_id: String) -> SentenceDto;
pub fn dialogues(&self) -> Vec<DialogueSummaryDto>;
pub fn dialogue_detail(&self, dialogue_id: String) -> DialogueDto;
pub fn peek(&self, ref_id: String) -> PeekDto;

// api/session_api.rs
pub fn session_summary(&self, audio_available: bool) -> SessionSummaryDto;
pub fn session_next(&self, session_seed: u32, audio_available: bool) -> SessionNextDto;
pub fn submit_answer(&self, answer: AnswerDto) -> AnswerResultDto;
pub fn kana_session(&self, lesson_id: String, session_seed: u32, audio_available: bool) -> Vec<QuestionDto>;
pub fn kana_submit(&self, reference: QuestionRefDto, response: AnswerPayload, duration_ms: u32) -> KanaSubmitResultDto;

// api/today_api.rs
pub fn today_view(&self, audio_available: bool) -> TodayViewDto;
pub fn complete_task(&self, task_key: String, duration_ms: u32, audio_available: bool) -> TodayViewDto;
pub fn learn_more(&self, audio_available: bool) -> TodayViewDto;
pub fn new_content_session(&self, task_key: String, session_seed: u32, audio_available: bool) -> NewContentSessionDto;
pub fn listen_session(&self, task_key: String, session_seed: u32, audio_available: bool) -> Vec<QuestionDto>;

// api/plan_api.rs
pub fn create_plan(&self, input: PlanInputDto) -> PlanViewDto;
pub fn update_plan(&self, input: PlanInputDto) -> PlanViewDto;
pub fn plan_view(&self) -> PlanViewDto;
pub fn plan_preview(&self, input: PlanInputDto) -> PlanViewDto;   // 只計算，不寫入
pub fn calendar(&self, weeks: u32) -> Vec<CalendarDayDto>;
pub fn stats_overview(&self) -> StatsDto;
pub fn activity_range(&self, from_date: String, to_date: String) -> Vec<DayActivityDto>;

// api/drill_api.rs
pub fn drill_session(&self, filter: DrillFilterDto, session_seed: u32, audio_available: bool) -> Vec<QuestionDto>;
pub fn grade_drill(&self, question: QuestionRefDto, response: AnswerPayload) -> DrillResultDto;
pub fn checkpoint_start(&self, milestone_id: String, session_seed: u32, audio_available: bool) -> Vec<QuestionDto>;
pub fn checkpoint_finish(&self, milestone_id: String, answers: Vec<AnswerDto>) -> CheckpointResultDto;
pub fn checkpoint_dismiss(&self, milestone_id: String, audio_available: bool) -> TodayViewDto;

// api/tools_api.rs（#[frb(sync)]，自由函式）
pub fn romaji_input_preview(input: String) -> String;     // 打字即時預覽，失敗回原字串
pub fn romanize_reading(reading: String, mode: ReadingMode) -> Option<String>;
pub fn parse_mixed_text(input: String) -> Vec<MixedSpanDto>; // {ja:…} 標記，語法錯誤時整段回 Zh

// api/core.rs（自由函式，一般 fn）。給 DB 打不開時的「重設資料」，不需要 AppCore
pub fn delete_database(db_path: String) -> Result<(), CoreError>; // 刪 .db、-wal、-shm
```

以下是語意需要說明的函式。

**`audio_available`**：Dart 傳入，值為「語音引擎可用且不在無聲模式」。`false` 時排除需語音的 facet 與題目（§8.6「需要語音」欄），這些卡不計入到期數、不計入積壓判定（§7.2），`Listen` 任務不列出。沒有 Skip，也不寫 FSRS，所以到期的 `:listen` 卡不會無限重現，語音恢復後照常排入。

**`new_content_session(task_key, session_seed, audio_available)`**：回傳今日 `NewContent` 任務的學習步驟，Dart 依序呈現。`task_key` 必須是快照裡的 `NewContent`，否則回 `NotFound`。

- 呼叫時以 `INSERT OR IGNORE` 建立切片內單字的 `recog`（`same_form_zh` 另建 `listen`）與文法的 `use` 卡，state＝0。可重複呼叫，已離開 state＝0 的卡 `first_card` 為 `None`，所以中途離開能從斷點繼續。
- `Vocab`、`Grammar` 步驟帶 `first_card`，Dart 呈現與播音後立即出一題，以 `submit_answer` 寫入。卡片當場離開 state＝0，這是第一次接觸。
- 單字步驟依 `lesson_order` 排在文法之前。例句只含 §7.3 的可用句子，已知集合包含本切片。
- 假名切片：每 3 字（不拆拗音行）一批，先逐字呈現 `Kana` 步驟，再接該批的 `KanaQuiz`；每字兩題（`kana_read` 一題，`kana_listen` 或第二題 `kana_read`），作答用 `kana_submit`。
- K11–K15 的假名切片（S0 沒有演練額度，清濁、半濁、拗音的最小對立靠這裡進主流程，curriculum §1、T12）：所有假名題之後再接一個 `KanaQuiz`，放切片涉及的每課 2–3 題 `minimal_pair`；切片教完該課最後一個字時，再接 1 題該課的 `kana_word`（`quiz/slice_drill.rs`）。選題是確定性的，不看 `session_seed`（種子只決定播 a 還是 b）：依字序把每題派給一個字，字先取自己的題（目標字裡課內較晚教的那個字），沒有就取排隊的題，目標字都不在本課的題一開始就排隊。切片取自己的字派到的題，上限 3 題，所以不論額度怎麼切，同一題不會被兩個切片選到，未考過的題自然優先。派到的題不足 2 題時補到 2 題：先補沒有派到字的題，再由字序尾端往回補。一律排除 `retired`、`listen_disabled` 與目標字未教的題，無聲模式排除 `minimal_pair`。濾完沒有題時不產生 `KanaQuiz`。沒有新增 DTO 欄位與資料表。
- K10：`Confusable` 步驟接 `kana_confuse`。K16–K19：`Rule` 步驟接該卡 `drills` 的 `minimal_pair`（排除規則見 §8.4）；K19 另含 `accent` 語音示範組。

**`listen_session(task_key, session_seed, audio_available)`**：回傳今日 `Listen` 任務的題目，順序依快照的 `sentence_ids` 以種子洗牌，每 3 題的第 3 題是 `Shadowing`，其餘是自動補的 `ListenMeaning`（§8.4）。作答用 `grade_drill`，不寫 FSRS。`audio_available = false` 時回空陣列。

**`kana_session(lesson_id, ...)`**：只供 K1 自由練習，不影響計畫。

**`kana_submit(reference, response, duration_ms)`**：`reference` 由題目帶回，Rust 判定對錯，累計 §6.5 的熟練並回傳 `mastery`。`minimal_pair`、`kana_word`、`kana_match` 也走這裡，`mastery` 為 `None`。`Match` 的 `all_correct` 是 Dart 判定的唯一例外。每次作答都累加 `drills_done`，T3 的題數由此而來，K1 自由練習也算，作答的日子因此是活躍日（§7.6，RULINGS O12）。K1 自由練習不推進計畫（RULINGS C06）。

**`complete_task`**：§7.4。

**`learn_more`（再學一批）**：§7.4。`TodayViewDto.can_learn_more` 為 true 時才能呼叫，回傳附加新任務後的 `TodayViewDto`。

**`checkpoint_finish(milestone_id, answers)`**：逐筆由 Rust 判定（§8.5），回傳 `CheckpointResultDto.weak_ids`。`answers` 為空回 `InvalidInput`，同一題的 `reference` 重複時只算第一筆。**`checkpoint_dismiss`**：§8.5，對應檢定畫面的「先略過」。

**`note_list(kind)`**：回傳該類全部未淘汰的筆記，依檔案順序，供 N1 筆記畫面（`/learn/notes`）。`NoteKind::Term` 就是術語筆記清單，文法頁的 `terms` 也點入同一份資料。`p0a` 回空陣列；預設 `p0` 五類依序為 60、120、20、20、12 則（同形異義、字形對照、讀音規律、語言轉移、術語；筆數取自 `content_tool --stage p0 stats`，`rust/tests/real_content_p0.rs` 驗證五類都不低於 curriculum §14）。

**`dialogues()`**：回傳全部未淘汰的對話，`kind` 為 `Lesson`、`Extra`、`Casual`。`DialogueSummaryDto.locked` 為 `pos(lesson) > pos(游標)`；游標走完全部已發布的課時一律 false。

**`peek(ref_id)`**：`vo.*`、`ka.*` 的 `title` 為純日文；其餘為原始 `title_zh`，保留標記。Dart 依前綴選元件（flutter-app.md §3.7）。

| `ref_id` | `title` | `kana` | `romaji` | `summary_zh` |
|---|---|---|---|---|
| `vo.*` | `surface` | `kana` | 同 `VocabSummaryDto.romaji` | `zh` 以「、」串接 |
| `ka.hira.*`、`ka.kata.*` | `char` | None | 同 `KanaCellDto.romaji` | `hint_zh` |
| `ka.cf.*` | `members` 的 `char` 與 `literals[].text` 以「／」串接 | None | None | `diff_zh` |
| `ka.rule.*` | `examples[0].text` | None | None | `title_zh` |
| `ka.sg.*` | `pairs[0].a`、`pairs[0].b` 以「／」串接 | None | None | `title_zh` |
| `gr.*` | `title_zh` | None | None | `meaning_zh` |

其他前綴回 `NotFound`。`lesson_id` 為該項目的 `lesson`。

**`search_vocab(query, limit)`**：`limit` 限 1–200，輸入去頭尾空白後為空則回空陣列。比對方式依輸入判斷：

| 輸入 | 比對 |
|---|---|
| 含假名 | `to_hiragana` 後去空白，比對 `vocab.kana`（去空白） |
| 全為拉丁字母 | 先 `romaji_to_hiragana` 比對 `kana`；同時比對由 `kana` 推導的羅馬字（去空白、撇號），轉換失敗時只用羅馬字比對 |
| 其他（漢字、中文） | 比對 `surface` 與 `zh` 的每一項 |

排序：完全相等、前綴相符、包含，同級依 `(pos(lesson), lesson_order)`。`retired` 排除。

**`vocab_topics`**：`id` 為 `topics[0]`，`title_zh` 取 curriculum §4.2 的「內容」欄（`app/vocab.rs` 的 `TOPIC_TITLES` 常數表，查無時回 slug 本身），`count` 依 `topics[0]` 計，排除 `retired`。`count` 為 0 的主題不列出。

**`grammar_list(stage, query)`**：`query` 比對去掉 `{ja:}` 標記後的 `title_zh`、`pattern`、`meaning_zh`，拉丁字母先轉假名（比照 `search_vocab`）。`status` 由 `item_intro` 與 `use` 卡狀態推導，不存蓋章狀態。

**`set_vocab_flags(vocab_id, flags)`**：`vocab_flag` 與卡片異動在單一 transaction 內寫入。`known = true` 把該字所有卡片設 `suspended = 1`（尚未介紹的字同時寫 `item_intro`，切片會跳過）；字若在今日快照的切片內，`new_content_session` 建卡後立刻暫停，`complete_task` 也不替已會的字建卡，所以不會進複習。`known = false` 解除暫停：字所在的課尚未完成（`pos(lesson) ≥ pos(游標)`）且卡都沒作答過時，刪除標已會留下的 `item_intro`，字回到正常切片，不建卡；否則沿用原有的卡，沒有任何卡才建立 `recog`。`starred` 只影響篩選。

**`plan_preview(input)`**：回傳的 `PlanViewDto` 帶 `main_forecast_end`（已發布主線完成日）。`create_plan` 等寫入類函式也回傳相同形狀。

**`display_policy(context)`**：依 `lesson_id` 所屬的課計算（curriculum §10.2），不受目前進度影響；查不到課回 `NotFound`。K1 五十音表不呼叫此函式，`KanaCellDto.romaji` 永遠有值。

| 內容 | `romaji` | `furigana` | `word_spacing` |
|---|---|---|---|
| K、KK 課 | `Shown` | `All` | false |
| L01–L04 | `ShownToggleable` | `All` | true |
| L05–L06 | `TapToReveal` | `All` | true |
| L07–L08 | `TapToReveal` | `All` | false |
| L09–L30 | `LongPressOnly`，`ms.kata` 未通過且 `romaji_off_confirmed = false` 時為 `TapToReveal` | `All` | false |
| L31 起 | `Hidden`，同條件時為 `TapToReveal` | `UnknownOnly` | false |

使用者設定（`romaji_override`、`furigana_override`）優先。`WordDto.is_known` 為 `ref_id` 對應卡片已是 `state=Review` 且 `scheduled_days ≥ 21`。「僅未熟單字」時，由 Dart 依 `is_known` 隱藏 `ruby`。

### 9.5 DTO

```rust
// ---------- 句子與語音 ----------
pub struct SpeechDto { pub text: String, pub kana: String }      // §3.3；行動平台送 text，Linux 送 kana
pub struct SentenceDto {
    pub id: String, pub display: String, pub romaji: String, pub zh: String,
    pub style: String, pub words: Vec<WordDto>, pub speech: SpeechDto,
}
pub struct WordDto {
    pub surface: String, pub kana: String, pub romaji: String, pub speech_kana: String,
    pub ruby: Vec<RubyPartDto>, pub refs: Vec<String>,
    pub ref_id: Option<String>,                                  // 第一個非 @ 的 ref，供 peek
    pub gloss_zh: Option<String>,                                // @new 的中文釋義
    pub is_punct: bool, pub is_known: bool,
}
pub struct RubyPartDto { pub base: String, pub ruby: Option<String> }
pub enum MixedSpanDto { Zh { text: String }, Ja { text: String, ruby: Vec<RubyPartDto> } }
pub enum ReadingMode { Word, Sentence }

// ---------- 課程 ----------
pub enum ContentStage { P0a, P0, Full }
pub enum LessonStatus { NotStarted, Current, Done, Skipped }
pub struct StageDto { pub id: String, pub title_zh: String }
pub struct LessonSummaryDto {
    pub id: String, pub stage_id: String, pub title_zh: String, pub can_do_zh: String,
    pub dialogue_id: Option<String>, pub milestone_id: Option<String>, pub status: LessonStatus,
}
pub struct CourseOverviewDto {
    pub content_stage: ContentStage, pub stages: Vec<StageDto>, pub lessons: Vec<LessonSummaryDto>,
    pub current_lesson_id: Option<String>,
    pub notes_available: bool,                                   // 內容就緒才露出入口
}
pub struct LessonDetailDto {
    pub summary: LessonSummaryDto, pub kana: Vec<KanaCellDto>, pub rules: Vec<RuleCardDto>,
    pub words: Vec<VocabSummaryDto>, pub grammar: Vec<GrammarSummaryDto>, pub dialogue: Option<DialogueSummaryDto>,
    pub integration_days_done: u32, pub integration_days_needed: u32,
}

// ---------- 假名 ----------
pub enum KanaScript { Hiragana, Katakana }
pub enum KanaKindDto { Basic, Dakuten, Yoon, Extended, Mark }
pub enum KanaStatus { NotStarted, Learning, Mastered }
pub enum ConfusableKindDto { Shape, CrossScript, KanaKanji, Listen }
pub enum SoundGroupKindDto { Voicing, Length, Sokuon, Yoon, Accent }
pub struct KanaCellDto {
    pub id: String, pub ch: String, pub romaji: String, pub kind: KanaKindDto, pub status: KanaStatus,
    pub fast_badge: bool, pub speech: SpeechDto, pub listen_disabled: bool,
}
pub struct KanaRowDto { pub cells: Vec<Option<KanaCellDto>> }    // None 為保留對位的空格
pub struct KanaGroupDto { pub title_zh: String, pub columns: u32, pub rows: Vec<KanaRowDto> }
pub struct KanaExampleDto { pub surface: String, pub zh: String, pub speech: SpeechDto }
pub struct KanaDetailDto {
    pub cell: KanaCellDto, pub lesson_id: String, pub origin_kanji: Option<String>, pub hint_zh: String,
    pub example_words: Vec<KanaExampleDto>, pub confusables: Vec<ConfusableDto>, pub rule_id: Option<String>,
}
pub struct LiteralDto { pub text: String, pub zh: String, pub speech: SpeechDto }
pub struct ConfusableDto {
    pub id: String, pub kind: ConfusableKindDto, pub members: Vec<KanaCellDto>,
    pub literals: Vec<LiteralDto>, pub diff_zh: String,
}
pub struct RuleExampleDto { pub text: String, pub zh: String, pub beats: Vec<String>, pub speech: SpeechDto }
pub struct RuleCardDto {
    pub id: String, pub lesson_id: String, pub title_zh: String, pub body_zh: String,
    pub examples: Vec<RuleExampleDto>, pub sound_groups: Vec<SoundGroupDto>, pub drill_ids: Vec<String>,
}
pub struct SoundSideDto { pub text: String, pub kana: Option<String>, pub zh: String, pub speech: SpeechDto }
pub struct SoundPairDto { pub a: SoundSideDto, pub b: SoundSideDto, pub listen_disabled: bool }
pub struct SoundGroupDto {
    pub id: String, pub lesson_id: String, pub kind: SoundGroupKindDto, pub title_zh: String, pub body_zh: String,
    pub pairs: Vec<SoundPairDto>, pub test_drill_ids: Vec<String>,
}

// ---------- 單字 ----------
pub enum SrsStateLabel { NotStarted, Learning, Review, Mastered } // Mastered：state=Review 且 scheduled_days ≥ 21
pub enum JlptLevel { N5, N4, Beyond }
pub enum UseLevelDto { Safe, FriendsOnly, RecognizeOnly }
pub enum TransitivityDto { Transitive, Intransitive, Both }
pub struct VocabRefDto { pub id: String, pub surface: String, pub kana: String, pub zh: Vec<String> }
pub struct VocabSummaryDto {
    pub id: String, pub surface: String, pub kana: String, pub romaji: String,
    pub zh: Vec<String>, pub pos: String, pub lesson_id: String, pub srs_state: SrsStateLabel,
    pub speech: SpeechDto, pub known: bool, pub starred: bool,
}
pub struct ConjugationDto { pub form: String, pub surface: String, pub kana: String } // form：活用形的中文名稱，MixedText（{ja:て}形），Dart 用 MixedText 顯示
pub struct VocabDetailDto {
    pub summary: VocabSummaryDto, pub accent: Option<u8>, pub jlpt: JlptLevel, pub use_level: UseLevelDto,
    pub trans: Option<TransitivityDto>, pub same_form_zh: bool, pub hook_zh: Option<String>, pub trap_zh: Option<String>,
    pub pair: Option<VocabRefDto>, pub reading_family: Vec<VocabRefDto>,
    pub examples: Vec<SentenceDto>, pub notes: Vec<NoteDto>, pub conjugations: Vec<ConjugationDto>,
}
pub struct VocabPageDto { pub items: Vec<VocabSummaryDto>, pub total: u32 }
pub struct VocabFilterDto {
    pub topic: Option<String>, pub pos: Option<String>, pub jlpt: Option<String>, pub lesson_id: Option<String>,
    pub only_introduced: bool, pub only_starred: bool, pub srs_state: Option<SrsStateLabel>,
}
pub struct VocabFlagsDto { pub known: bool, pub starred: bool }
pub struct TopicDto { pub id: String, pub title_zh: String, pub count: u32 }

// ---------- 文法與筆記 ----------
pub enum GrammarStatus { NotStarted, Introduced, Practiced }     // Introduced：已 item_intro；Practiced：use 卡 reps ≥ 1
pub struct GrammarRefDto { pub id: String, pub title_zh: String }
pub struct GrammarSummaryDto {
    pub id: String, pub title_zh: String, pub pattern: String, pub meaning_zh: String,
    pub lesson_id: String, pub stage_id: String, pub jlpt: JlptLevel, pub status: GrammarStatus,
}
pub struct FormationRowDto { pub from: String, pub to: String }
pub struct GrammarDetailDto {
    pub summary: GrammarSummaryDto, pub explain_zh: String, pub compare_zh: String, pub trap_zh: Option<String>,
    pub formation: Vec<FormationRowDto>, pub register: String, pub requires: Vec<GrammarRefDto>,
    pub examples: Vec<SentenceDto>, pub contrast: Vec<GrammarRefDto>, pub terms: Vec<NoteDto>,
}
pub enum NoteKind { FalseFriend, Shinjitai, Reading, Transfer, Term }
pub struct ReadingExampleDto { pub hanzi: String, pub tai: String, pub ja: String }
pub enum NoteDto {
    FalseFriend { id: String, surface: String, ja_zh: String, misread_zh: String, vocab_id: Option<String> },
    Shinjitai { id: String, ja: String, zh_tw: String, kind: String, vocab_ids: Vec<String> },
    Reading { id: String, title_zh: String, body_zh: String, examples: Vec<ReadingExampleDto>, caveat_zh: String },
    Transfer { id: String, title_zh: String, zh_pattern: String, wrong: String, right: String, explain_zh: String },
    Term { id: String, term: String, aka_zh: Option<String>, body_zh: String, grammar_ids: Vec<String> },
}

// ---------- 對話 ----------
pub enum DialogueKindDto { Lesson, Extra, Casual }
pub struct DialogueSummaryDto {
    pub id: String, pub kind: DialogueKindDto, pub lesson_id: String,
    pub scene_zh: String, pub goal_zh: String, pub locked: bool,
}
pub struct DialogueRoleDto { pub id: String, pub name_zh: String, pub voice: String }
pub struct DialogueTurnDto { pub role: String, pub sentence: SentenceDto, pub note_zh: Option<String> }
pub struct DialogueDto {
    pub id: String, pub kind: DialogueKindDto, pub lesson_id: String, pub style: String,
    pub scene_zh: String, pub goal_zh: String, pub roles: Vec<DialogueRoleDto>, pub turns: Vec<DialogueTurnDto>,
    pub focus_ids: Vec<String>, pub quiz_drill_ids: Vec<String>, // 取題用 drill_session 的 DrillFilterDto.drill_ids
}
pub struct PeekDto {
    pub ref_id: String, pub title: String, pub kana: Option<String>, pub romaji: Option<String>,
    pub summary_zh: String, pub lesson_id: Option<String>,
}

// ---------- 題目與作答 ----------
pub enum Rating { Again, Hard, Good, Easy }
pub enum ShadowLevel { Kept, Almost, Lost }                      // 跟上了／差一點／跟不上
pub enum QuestionType {
    Recog, VocabListen, Produce,
    KanaRead, KanaListen, KanaMatch, KanaConfuse, MinimalPair, KanaWord,
    Substitution, Reorder, ParticleFill, ZhToJaChoice, ListenMeaning, SituationResponse,
    Conjugate, RegisterConvert, Shadowing, FalseFriend,
}
pub struct SessionSummaryDto {
    pub due_reviews: u32, pub learning: u32, pub new_cards: u32,
    pub reviews_done_today: u32, pub review_cap: u32,
}
pub enum SessionNextDto {
    Card { card: SessionCardDto },
    Done { next_due_at: Option<DateTime<Utc>> },
}
pub struct SessionCardDto {
    pub card_id: String, pub expected_reps: i32, pub facet: String,
    pub question: QuestionDto, pub rating_previews: Vec<RatingPreviewDto>,
    pub remaining_estimate: u32,
}
pub struct RatingPreviewDto { pub rating: Rating, pub interval_minutes: i64 }

pub struct QuestionDto {
    pub question_type: QuestionType,
    pub reference: QuestionRefDto,
    pub prompt: PromptDto,
    pub body: QuestionBodyDto,
    pub explain_zh: Option<String>,
    pub focus_ids: Vec<String>,                                  // 答後顯示的語法重點，用 peek 取內容
}
pub struct QuestionRefDto {
    pub question_type: QuestionType,                             // 與 QuestionDto 相同，作答時帶回
    pub card_id: Option<String>, pub drill_id: Option<String>, pub content_id: String,
    pub variant: Option<u32>,                                    // rows／lemmas 索引，minimal_pair 的 a／b（§8.4）
}
pub struct PromptDto {
    pub instruction_zh: String, pub text: Option<SentenceDto>,
    pub plain_text: Option<String>,                              // MixedText 字串，規則見本節末
    pub speech: Option<SpeechDto>, pub autoplay: bool, pub hide_text_until_answered: bool,
}
pub enum QuestionBodyDto {
    Choice { options: Vec<OptionDto>, correct_option_id: String, blank_word_index: Option<u32> },
    Reorder { chunks: Vec<ChunkDto>, accept_orders: Vec<Vec<u32>> },
    Typing { expected_reading: String, placeholder_zh: String },
    Match { pairs: Vec<MatchPairDto> },
    SelfGrade { reveal: SentenceDto },                           // 單字題由單字合成（§8.3），use 卡退回時為例句（§6.1）
    Shadow { reveal: SentenceDto },
}
pub struct OptionDto {
    pub id: String, pub text: String, pub sentence: Option<SentenceDto>,
    pub speech: Option<SpeechDto>, pub why_zh: Option<String>,
}
pub struct ChunkDto { pub index: u32, pub text: String }
pub struct MatchPairDto { pub left_id: String, pub left: String, pub right_id: String, pub right: String }

pub struct AnswerDto {
    pub reference: QuestionRefDto, pub expected_reps: i32,
    pub response: AnswerPayload, pub hint_used: bool,
    pub attempts: u32, pub duration_ms: u32,
}
pub enum AnswerPayload {
    Choice { option_id: String },
    Reorder { order: Vec<u32> },
    Typing { input: String },
    Match { all_correct: bool },
    SelfGrade { rating: Rating },
    Shadow { level: ShadowLevel },
}
pub struct AnswerResultDto {
    pub is_correct: bool, pub rating: Rating, pub next_due_in_minutes: i64,
    pub correct_display: String,                                 // MixedText 字串，規則見本節末
    pub reveal: Option<SentenceDto>, pub unlocked_cards: u32,
}
pub struct DrillResultDto {
    pub is_correct: bool, pub correct_display: String, pub explain_zh: Option<String>,
    pub why_zh: Option<String>, pub reveal: Option<SentenceDto>,
}
pub struct KanaMasteryDto { pub kana_id: String, pub run: u32, pub required: u32, pub mastered: bool, pub fast_badge: bool }
pub struct KanaSubmitResultDto { pub is_correct: bool, pub correct_display: String, pub mastery: Option<KanaMasteryDto> }
pub struct DrillFilterDto {
    pub task_key: Option<String>, pub lesson_id: Option<String>, pub target: Option<String>,
    pub drill_ids: Vec<String>, pub count: u32,
}
pub struct CheckpointResultDto {
    pub milestone_id: String, pub correct: u32, pub total: u32, pub score_percent: u32,
    pub passed: bool, pub weak_ids: Vec<String>,
}

// ---------- 新內容 ----------
pub struct NewContentSessionDto {
    pub task_key: String, pub lesson_id: String, pub title_zh: String, pub steps: Vec<NewContentStepDto>,
}
pub enum NewContentStepDto {
    Kana { detail: KanaDetailDto },
    Rule { card: RuleCardDto },
    Confusable { group: ConfusableDto },
    KanaQuiz { questions: Vec<QuestionDto> },
    Vocab { detail: VocabDetailDto, first_card: Option<SessionCardDto> },
    Grammar { detail: GrammarDetailDto, first_card: Option<SessionCardDto> },
}

// ---------- 計畫與今日 ----------
pub enum StartLevel { Zero, Hiragana, Kana, Basic }
pub struct PlanInputDto {
    pub daily_minutes: u32, pub weekdays: Vec<u32>,              // 1=週一 … 7=週日
    pub start_level: StartLevel, pub target_date: Option<String>,
    pub known_kana_lessons: Vec<String>,
}
pub struct PlanViewDto {
    pub input: PlanInputDto, pub current_lesson_id: Option<String>, pub stage_id: Option<String>,
    pub milestones: Vec<MilestoneDto>,                           // 只含已發布內容，UI 依此動態繪製
    pub main_forecast_end: Option<String>,
    pub status: PlanStatus, pub suggested_minutes: Option<u32>,
}
pub struct MilestoneDto {
    pub id: String, pub title_zh: String, pub lesson_id: String,
    pub pass_ratio: f64, pub questions: u32,                     // app/plan.rs 由 MilestoneDef 帶入
    pub forecast_date: Option<String>, pub planned_date: Option<String>, pub delay_days: i32,
    pub best_score_percent: Option<u32>, pub passed: bool, pub dismissed: bool,
}
pub enum PlanStatus { NoTarget, OnTrack, Behind }

pub struct TodayViewDto {
    pub logical_date: String, pub is_study_day: bool, pub next_study_date: Option<String>,
    pub tasks: Vec<TaskDto>, pub budget: BudgetDto, pub streak: u32,
    pub recovery_reason: Option<RecoveryReason>, pub minimal_new: bool,
    pub learning_tail: u32, pub estimated_minutes: f64, pub can_learn_more: bool,
}
pub enum RecoveryReason { ReviewBacklog, ReturnAfterBreak, UnseenNewCards }
pub struct BudgetDto {
    pub new_minutes: f64, pub review_minutes: f64, pub drill_minutes: f64, pub listen_minutes: f64,
    pub review_cap: u32, pub capacity: u32, pub new_words_limit: u32, pub kana_chars_limit: u32,
}
pub enum TaskDto {
    Review { key: String, due: u32, learning: u32, new_cards: u32, minutes: f64, done: bool },
    NewContent { key: String, lesson_id: String, title_zh: String, words: u32, grammar: u32, kana: u32, rules: u32, minutes: f64, done: bool },
    Integration { key: String, lesson_id: String, title_zh: String, dialogue_id: Option<String>, phases: Vec<u32>, minutes: f64, done: bool },
    Drill { key: String, questions: u32, minutes: f64, done: bool },
    Listen { key: String, sentences: u32, minutes: f64, done: bool },
    Checkpoint { key: String, milestone_id: String, done: bool },
}

pub struct StatsDto {
    pub streak_current: u32, pub streak_best: u32, pub total_reviews: u32,
    pub cards_new: u32, pub cards_learning: u32, pub cards_review: u32, pub cards_mastered: u32,
    pub kana_mastered: u32, pub vocab_introduced: u32, pub grammar_introduced: u32,
}
pub struct DayActivityDto { pub date: String, pub answers: u32, pub lessons: u32, pub study_minutes: f64 }
pub struct CalendarDayDto { pub date: String, pub is_study_day: bool, pub is_active: bool, pub lesson_ids: Vec<String>, pub milestone_id: Option<String> }

// ---------- 設定與顯示 ----------
pub enum ThemeMode { System, Light, Dark }
pub enum RomajiMode { Shown, ShownToggleable, TapToReveal, LongPressOnly, Hidden }
pub enum FuriganaMode { All, UnknownOnly }
pub struct DisplayContext { pub lesson_id: String }
pub struct DisplayPolicyDto { pub romaji: RomajiMode, pub furigana: FuriganaMode, pub word_spacing: bool }
pub struct SettingsDto {
    pub day_rollover_hour: u32, pub desired_retention: f64,
    pub romaji_override: Option<RomajiMode>, pub furigana_override: Option<FuriganaMode>,
    pub tts_rate: f64, pub autoplay: bool, pub voice_id: Option<String>, pub theme_mode: ThemeMode,
    pub silent_mode: bool,                 // 無聲模式；Dart 據此算 audio_available
    pub kana_time_limit: bool,             // 無障礙：false 時假名不看 3 秒時限
    pub show_rating_intervals: bool,       // 評分鈕是否顯示間隔數字，預設 false
    pub romaji_off_confirmed: bool,        // 使用者確認 L09 起關閉羅馬字
    pub seen_question_hints: Vec<QuestionType>, // 已看過操作提示的題型
}
pub struct SettingsPatchDto {
    pub day_rollover_hour: Option<u32>, pub desired_retention: Option<f64>,
    pub romaji_override: Option<RomajiMode>, pub clear_romaji_override: bool,
    pub furigana_override: Option<FuriganaMode>, pub clear_furigana_override: bool,
    pub tts_rate: Option<f64>, pub autoplay: Option<bool>,
    pub voice_id: Option<String>, pub clear_voice_id: bool, pub theme_mode: Option<ThemeMode>,
    pub silent_mode: Option<bool>, pub kana_time_limit: Option<bool>,
    pub show_rating_intervals: Option<bool>, pub romaji_off_confirmed: Option<bool>,
    pub seen_question_hints: Option<Vec<QuestionType>>,
}
```

`PromptDto.plain_text` 與 `correct_display`（`AnswerResultDto`、`DrillResultDto`、`KanaSubmitResultDto`）一律是 MixedText 字串：中文與混合欄位保留 `{ja:}`，純日文由 Rust 包成 `{ja:…}`，含漢字時為 `{ja:表層|讀音}`，羅馬字不包。例如 `KanaRead` 的 `plain_text` 為 `{ja:あ}`，`KanaWord` 為 `{ja:いぬ}`，`FalseFriend` 為 `prompt_zh` 原文，`Conjugate` 的 `correct_display` 為 `{ja:食べて|たべて}`。Dart 一律用 `MixedText` 呈現（flutter-app.md §3.6）。

設定的預設值：`day_rollover_hour` 4、`desired_retention` 0.9、`tts_rate` 1.0、`autoplay` true、`theme_mode` System、`silent_mode` false、`kana_time_limit` true、`show_rating_intervals` false、`romaji_off_confirmed` false。

下一張的選取取決於剛才的評分（Again 的卡幾分鐘後回來、解鎖新 facet、上限），由 Rust 單一決定，Dart 不維護佇列，所以字卡是 `session_next` 逐張拉取。

### 9.6 作答流程

```text
Dart: session_next(seed, audio_available) → SessionCardDto
Dart: 依 question.body 顯示題目，使用者作答（評分列只在 SelfGrade 出現）
Dart: submit_answer(AnswerDto) ──► Rust:
  1. CardId 解析，讀卡（找不到 → NotFound；reps 不同 → StaleCard）
  2. 依 reference（drill_id、variant）從內容算出正解並判定（§4.5、§8.4）
  3. 轉評分（§6.2）
  4. SrsScheduler::review（§6.3）
  5. repo.apply_review（卡片＋log＋activity，單一 transaction）
  6. facets::unlocks → repo.insert_cards
  7. 回傳 AnswerResultDto
```

```text
新內容：
Dart: today_view → NewContent 的 key → new_content_session(key, seed, audio_available) → steps
  Kana：呈現（大字、播音、origin_kanji、hint_zh、例字）
  KanaQuiz：kana_submit → 累計熟練；熟練時建 :read 卡
  Vocab、Grammar：呈現、播音，first_card 不為 None 時出一題 → submit_answer（第一次接觸）
Dart: complete_task(key, duration_ms, audio_available) ──► Rust：寫 item_intro、補建卡、檢查課完成（§7.3）
```

---

## 10. 併發模型

實測結論：300 次並行 `insertRow` 走同一個 `Mutex<Connection>`，全部成功，用時 33 ms。

| 規則 | 理由 |
|---|---|
| 一個 `AppCore`，內部一條連線 `Mutex<Connection>` | `Connection` 是 `Send` 非 `Sync`；寫入量小，不需連線池 |
| `AppCore` 方法**只用 `&self`，永不用 `&mut self`** | FRB 對 `&self` 取共享鎖（實測生成碼 `lockable_decode_sync_ref`），`&mut self` 會獨占，把所有呼叫序列化 |
| 所有 DB 操作用一般 `fn` | 跑在執行緒池，不卡 UI 與 tokio |
| Mutex 只在 Repository 方法內持有，不跨內容查詢或題目產生 | 縮短持鎖時間 |
| 只有一把鎖 | 不會死鎖 |
| 寫入用 `BEGIN IMMEDIATE`，`apply_review` 有 `reps` 樂觀檢查 | 連點防護，兩個 `submit_answer` 只有一個成功 |
| 取鎖用 `lock().unwrap_or_else(PoisonError::into_inner)` | panic 時 `Transaction` 的 Drop 會回滾（實測），資料一致，可以繼續用 |
| `ContentStore` 放 `Arc`，唯讀 | 無鎖 |
| `Clock` 的時差用 `AtomicI32` | 無鎖 |
| `reset_all` 全程持有連線的 Mutex | 換檔期間不會有查詢打到記憶體庫（§5.5） |

**為何用 opaque handle，不用 `OnceLock`**：兩者實測都可行。`OnceLock` 在 hot restart 後 Rust 端的值會留著（實測第二次 `init` 拿到舊值），而且全域狀態讓測試無法隔離、無法注入 FixedClock。handle 是明確的依賴。

**Hot restart**：Dart 狀態歸零但 `.so` 仍在，舊 handle 的 Connection 不會關閉，直到行程結束。只影響開發期，WAL 加 `busy_timeout` 可容許兩條連線。`RustLib.init()` 在同一 Isolate 呼叫兩次會丟 `StateError`（實測），只呼叫一次。

---

## 11. 測試策略

目標：`cargo llvm-cov` 行覆蓋率 80% 以上。測試先行，先寫案例表再實作。

### 11.1 單元測試（各 crate 的 `tests/`，少數在模組內 `#[cfg(test)]`，FixedClock）

模組名稱的對應見 §1.3，例如 `content/sentence.rs` 的測試在 `rust/crates/jp_content/tests/sentence.rs`，`plan/budget.rs` 的在 `rust/crates/jp_plan/tests/budget.rs`。

| 模組 | 測試 |
|---|---|
| `kana/*` | §4.4 全部案例表；§4.5 判定表；`reading_mode_of` 分流（J08）；proptest：任意合法假名序列不 panic，非有損集合來回一致 |
| `content/sentence.rs` | §3.3 案例、錯誤案例、詞塊切分、TTS 的 は→わ 替換、`tts` 解析順序、`@name` 強制 `kana`、`@new` 的 `gloss_zh` |
| `content/mixed.rs` | `{ja:…}` 的切分、含讀音、語法錯誤整段回 `Zh` |
| `content/filter.rs` | 三個階段的過濾、`p0a` 的 `course.stages` 只回 `st.s0`、`st.s1`、軟引用修剪、硬引用缺失回 `ContentCorrupt` |
| `grammar/conjugate.rs` | §4.7 全部形式×動詞類別表、敬語例外、`vs` 語幹與 `vo.suru` 的 `legal_stems` |
| `clock.rs` | §2 邊界表、分割不重疊的性質測試 |
| `srs/scheduler.rs` | §0.3 排程表、F1 校正、F2 時鐘倒退（1/10/100 天）不產生 NaN 與負值、Infinity 被 guard 擋下、Fuzz 確定性 |
| `srs/facets.rs` | 解鎖門檻、`recognize_only` 不建 `produce`、`same_form_zh` 的 `listen` 為 priority 0、`use` 候選少於 3 題時自動補題 |
| `srs/queue.rs` | 優先序、`review_cap`、sibling 排除（含 priority 1 新卡，priority 0 新卡不受影響）、提前學習、`audio_available = false` 排除 `listen`、當日建立的新卡不進第 3、4 步、第 3、4 步合計的當日收尾上限（`new_cards` 也不超過剩餘上限） |
| `srs/kana_mastery.rs` | 連續 2 次熟練、答慢不歸零、徽章與 `kana_time_limit`、自由練習不建卡 |
| `plan/budget.rs` | 各 stage×preset 分鐘表（含 S0 60／40／0／0）、`tail_card_limit` 與收尾預留上限（160 張只預留 33 張）、`review_cap` 加權、三種受限、`recovery_days` 接續與 `Minimal`、回鍋首日減半、游標走完全部已發布的課（`p0a` 學完 KK08）時階段取最後一個 L 課、不列 `NewContent`／`Integration`、`Drill`／`Listen` 取最後三個 L 課 |
| `plan/slice.rs` | `kana_chars_per_day`、第一批 3 字、拗音行計 1 額度且整行取、跨課與遇無新字課即停、`mark` 不佔額度、K10／K16–K19 整課一切片、`lesson_order` 切分、最小切片、10 分方案的兩天整合、對話輪替、換方案重切 |
| `plan/forecast.rs` | §7.5 的順延、學習日、超大課、達標與建議分鐘、`p0a` 的主線完成日 |
| `plan/streak.rs` | §7.6 全表、plan_version 變更 |
| `quiz/*` | 黃金值、同種子同結果、干擾項無重複且只來自已 `item_intro` 的項目（K19、KK08 檢定除外）、`variant` 判定、`substitution` 選項與去重、自動補 `listen_meaning`、`listen_disabled` 的 `minimal_pair` 不出題（四個取題函式，且 `drill_ids`、`test_drill_ids` 已濾掉）、K11–K15 切片手寫題（`jp_quiz/tests/slice_drill.rs` 夾具與 `rust/tests/kana_slice_drills_real_content.rs` 真實內容）、`item_intro` 為空時 `ms.hira` 的 `kana_read` 仍有 4 個選項、Reorder 不與正解相同 |

### 11.2 整合測試（`rust/tests/` 與各 crate 的 `tests/`，`tempfile` 暫存資料庫）

下表的 `migrations.rs`、`schema_constraints.rs` 在 `rust/crates/jp_store/tests/`，`content_schema.rs`、`content_lint.rs` 在 `rust/crates/jp_content/tests/`，其餘在 `rust/tests/`。

| 檔案 | 內容 |
|---|---|
| `migrations.rs` | 從空庫遷移、重跑冪等、失敗回滾版本、高版本拒絕 |
| `schema_constraints.rs` | append-only 觸發器、STRICT、CHECK、外鍵 |
| `review_flow.rs` | 新卡→學習→複習完整流程、log 筆數與 activity、連點 `StaleCard`、panic 後回滾 |
| `plan_flow.rs` | 建計畫→今日→完成→隔日；連錯 5 天；快照凍結；同日改計畫；20 分方案連續 30 天正常使用不觸發 `UnseenNewCards`；`audio_available = false` 連續 10 天學同形字不觸發 `UnseenNewCards`；當天同形字超過上限且用過「再學一批」，隔天不觸發；受限滿 2 天後第 3 天給最小切片；再學一批；`checkpoint_dismiss`；`known_kana_lessons` 略過；20 分方案第 2 天 `due = 0`、`learning = 0`、`new_cards = 3` 時 `Review.done = true`、`learning_tail = 3`，`session_next` 回 `KanaRead` 的卡；placement 未過、學完 K19 後，下一次建立快照的 `today_view` 列出 `ms.hira` 的 `Checkpoint` |
| `new_content_flow.rs` | `new_content_session` 的卡片建立與斷點續做、`first_card` 當場離開 state＝0、L01 第一個切片的步驟 `examples` 非空、文法有演練題時 `first_card` 不退回 `SelfGrade`、K 切片熟練與補建卡、K／KK 課完成條件 |
| `reset.rs` | `reset_all` 後資料清空、觸發器不干擾、連線可繼續使用 |
| `content_schema.rs` | 解析 `docs/design/curriculum.md` §12.4–12.6 的 JSON 範例，全部能反序列化成 §3.2 的 struct |
| `content_api.rs` | 用完整夾具 `rust/crates/jp_content/tests/fixtures/full/`（`load_full_fixture`）驗證內容查詢的 API，含對話清單的 `locked`、`note_list` 五類與筆記入口旗標（`p0a` 階段的內容沒有筆記；預設 `p0` 的真實內容另見下表） |
| `concurrency.rs` | 多執行緒同時 `submit_answer` |
| `content_lint.rs` | R01–R25（curriculum §13），在 `rust/crates/jp_content/tests/`。真實內容的範圍依環境變數 `CONTENT_STAGE`，未設時為預設 `p0`（`disk::resolve_stage`） |

真實內容的回歸測試。每個檔案在測試內寫死階段，不受 `CONTENT_STAGE` 影響；`p0` 的測試經 `tests/common/real.rs` 載入嵌入的 `CONTENT_FILES`（同一執行檔快取一次），可答性斷言在 `tests/common/answerable.rs`：

| 檔案 | 階段 | 內容 |
|---|---|---|
| `real_content_p0.rs` | `p0` | `course_overview` 為 P0、課程到 L30、筆記入口露出（O7）；各類別筆數不低於 curriculum §14 的 `p0` 欄；`note_list` 五類與單字、文法的筆記引用；`dialogues()` 的主對話、實戰、常體版詳情與測驗出題；`plan_preview` 四種方案的主線完成天數釘成基準（curriculum §11.4） |
| `real_content_p0_slices.rs` | `p0` | 10／20／30／45 分各一：L01–L30 每個 `vo.*`、`gr.*` 依 `lesson_order` 恰好介紹一次、沒有空天與超額、每課單字切片數、文法先多後少、整合日天數與階段（§7.3）、主對話與輪替的實戰與常體版；`plan_preview` 的主線天數等於 `learn_more` 實走片數；對話輪替的整個 `(lesson_id, dialogue_id)` 序列與 §7.3 推算相同 |
| `real_content_p0_drills.rs` | `p0` | L08–L30 全部課程演練經 `drill_session` 出題後都可答；無聲模式剛好拿掉需要語音的題（§8.6） |
| `p0_learning_loop.rs` | `p0` | 零基礎的學習者每天做完今日任務，走到主線 L30 完成再多走 60 天，逐日檢查 §7 的不變量（條文在 `tests/common/loop_invariants.rs`，執行與報表在 `tests/common/loop_run.rs`）。含暫停線（到期數 > 5 × `capacity` 的積壓日不給主線切片，積壓第 3 天起未過線給最小切片）、只排複習的日子 `review_cap` > `capacity`（回鍋日減半，不比）、`review_cap` 不塌成 1。長模擬標 `#[ignore]`，預設 `cargo test` 只跑其中 1 個；以 `cargo test --release --test p0_learning_loop -- --ignored` 執行，不含建置約兩到三分鐘 |
| `p0_learning_loop_edges.rs` | `p0` | 主模擬沒走過的受限路徑：前 300 天無聲之後有聲（收尾新卡分散、T1 不超過方案）、週一到週五的計畫週末也打開 App（休息日只列 `Review`，複習上限用階段配比，`recovery_days` 不遞增）、每 6 週消失 8 天（`ReturnAfterBreak`，到期數過線時只排複習）、週一到週五加每 40 天消失 8 天（回鍋日輪流落在一週的每一天，含休息日）。全部標 `#[ignore]`，release 不含建置約一分鐘 |
| `return_after_break.rs` | 夾具 | §7.2 回鍋的邊界：定級檢定之後隔幾天才開始仍有新內容、缺席中答一題 K1 或考一次檢定不取消回鍋保護、回鍋日沒有卡時不會天天判回鍋 |
| `activity_accounting.rs` | 夾具 | T3 的學習時間與題數（§7.4、§7.6）：時間只算一次，題數照實際作答；K1 自由練習與只考檢定的日子算活躍日，K1 不推進計畫 |
| `curriculum_days_real_content.rs` | `p0a` | 主線天數（145／91／66／53 天）、整合日的主對話、每種題型的判定 |
| `kana_slice_drills_real_content.rs` | `p0a` | K11–K15 切片後接的 `minimal_pair`、`kana_word` |
| `kana_chart_real_content.rs` | `p0a` | 五十音圖的圖表順序與教學順序 |
| `real_content_regressions.rs` | `p0a` | 排序題的合法語序、助詞題干擾項、活用表與主題的顯示字串 |

L08 以後與筆記的真實內容只有上表 `p0` 的檔案涵蓋；`p0a` 的四個檔案仍只驗證 L01–L07 與假名。

### 11.3 內容驗證（`content_lint.rs`、`content_lint_rules.rs`）

實作 curriculum §13 全部規則，並追加 Rust 端需要的檢查：

| 規則 | 檢查 |
|---|---|
| RC1 | 每個 `kana`、`t` 內的讀音都能通過 `to_romaji_word` |
| RC2 | 每個語素的 `furigana` 恰一解（R08） |
| RC3 | `を` 只能單獨成詞；單字 `kana` 內的 `を` 也要獨立 |
| RC4 | 未切分的固定語（詞本身出現在 §4.3 的固定語表，例如 `こんにちは`、`では`）報錯，必須寫成 `こんにち は`、`で は` |
| RC5 | 詞尾是 は／へ 且去掉後是已知單字讀音的詞報錯（`わたしは` 忘了切開），例外放 `lint/unsplit_allow.txt` |
| RC6 | 純假名單獨成詞的 `は`、`へ` 若 ref 是 `vo.*`，必須在固定語白名單，否則要寫漢字（`歯`） |
| RC7 | `conjugate` 的每個 `lemmas` 都能產生該 `form`，且該 `form` 不在單字的 `conj_omit` |
| RC8 | 每個 `Choice` 題選項去重後至少 2 個 |
| RC9 | 每個 `gr.*` 至少有一題能當 `use` 卡使用 |
| RC10 | 必填陣列非空：`zh`、`topics`、`targets`、`rows`、`turns`、`roles`、`pairs`、`blanks`、`distractors`、`choices_zh`、`lemmas`、`accept_orders`、`ka.rule.*` 的 `examples`（`peek` 取 `examples[0]`，§9.4） |
| RC11 | 每個 L 課都有主對話（`lesson.dialogue` 非 null），每篇主對話都被某一課引用；`dialogue` 指向不存在項目由 R03 回報。種子夾具（`count_policy.txt` 為 `seed`）略過 |

### 11.4 FFI 冒煙測試（Dart）

`test/ffi/core_ffi_test.dart` 用真實 `.so`（實測可行，無需裝置）：

```dart
await RustLib.init(externalLibrary: ExternalLibrary.open('rust/target/release/libjp_core.so'));
```

驗證：並行寫入、`CoreError` 變體可捕捉、panic 轉 `PanicException` 且之後仍可用、`DateTime` 來回、sealed DTO 的 `switch`，以及 `course_overview` 為預設的 `p0`（筆記入口露出、課程到 L30）。CI 先 `cargo build --release`；`.so` 是預設切換前的舊建置時，階段斷言會失敗。

### 11.5 CI 指令

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo llvm-cov -p jp_core --ignore-filename-regex 'frb_generated' --fail-under-lines 80
flutter_rust_bridge_codegen generate && git diff --exit-code lib/src/rust rust/src/frb_generated.rs
cargo build --release && flutter test
# §1.4 的離線檢查，規則見 reuse-and-verification.md §9.12
flutter build apk --release
python3 tools/verify/check_offline.py --apk build/app/outputs/flutter-apk/app-release.apk --require-apk
```

本機沒有 Android SDK 時，不帶參數執行 `python3 tools/verify/check_offline.py`，L07 會印 SKIP。

覆蓋率指令以預設 `p0` 執行，`--ignore-filename-regex 'frb_generated'` 排除 FRB 產生的 `rust/src/frb_generated.rs`（llvm-cov 計 8,247 行，Rust 測試覆蓋 0%）。2026-11-10 第二輪修正後實測（預設 `p0`）：排除後 lines 98.91%（3,401 行，未覆蓋 37 行）、functions 98.02%（505 個，未覆蓋 10 個）、regions 94.94%，結束碼 0。同日稍早以同一份 profile 比較過不排除的情況：TOTAL lines 28.87%（11,647 行，未覆蓋 8,284 行），結束碼 1。2026-11-16 移除專區後（RULINGS O13）重量排除後的數字：lines 98.94%（3,028 行，未覆蓋 32 行）、functions 98.19%（443 個，未覆蓋 8 個）、regions 94.93%，結束碼 0。

`cargo test --workspace` 的真實內容 lint（`content_lint.rs` 的 `real_content_passes_lint`）走預設 `p0`；`p0a` 要另設 `CONTENT_STAGE=p0a` 執行。`full` 的 lint 門檻在該階段內容就緒後再加進 CI，指令相同，只換 `CONTENT_STAGE`。

---

## 12. 風險與暫不實作

### 12.1 尚未驗證

| 項目 | 風險 | 驗證方式 |
|---|---|---|
| Android／iOS 建置 | 本機無 SDK。bundled SQLite 需 NDK clang，rustup target 由 cargokit 處理；`rust_builder` 的 podspec 用 `-force_load` | 有 SDK 的環境優先跑 `flutter build apk` 與 iOS 建置 |
| 手機啟動時間 | 只測過 x86；內容解析預期可接受 | 中階 Android 實機量測 `open` |
| FSRS 預設參數 | 假設值來自 Anki 使用者，初學者與選擇題可能偏樂觀 | 累積 `review_log` 後評估 |

### 12.2 暫不實作

| 功能 | 之後的做法 |
|---|---|
| 本機每日提醒 | P1；本機通知，不需網路。Rust 端不需改動，排程由 Dart 依 `plan_view` 設定 |
| 備份匯出與匯入 | P1；`VACUUM INTO`（實測可用），經系統分享匯出 |
| 錄音回放 | P1；`ShadowLevel` 與 `shadow_*` 統計已就緒，錄音由 Dart 側外掛處理 |
| 手寫描紅與筆順 | P1；curriculum §14 |
| VOICEVOX | P1 評估，見 reuse-and-verification.md |
| 術語卡的首次彈窗 | P1；術語筆記已列在 `note_list(NoteKind::Term)`，從文法頁點入 |
| 同步與帳號 | 新的 `Repository` 實作 |
| 撤銷上一次評分 | log 仍 append-only，加補償列並還原卡片快照 |
| FSRS 個人化參數 | 換 fsrs 6.x，用 `review_log` 訓練 |
| 單卡暫停與手動編輯 | 整字的「已會」已用 `suspended` 實作（§9.4），單一 facet 的暫停之後再開 |

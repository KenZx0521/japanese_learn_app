# 離線日文學習 App

Flutter 前端＋內嵌 Rust 核心（flutter_rust_bridge 2.13.0）。沒有伺服器，也不連網（`docs/design/RULINGS.md` O8）。

預設建置的內容是 `p0`：假名、L01–L30、232 則筆記，以及實戰與常體版對話（數量見 `curriculum.md` §14）。對外只說「本版到 L30」、「涵蓋參考 N5 範圍」（RULINGS O7）。舊的垂直切片 `p0a`（假名與入門七課）仍可用 `CONTENT_STAGE=p0a` 建置。程式只在 Linux 桌面驗證過，Android、iOS 還沒建置。

| 文件 | 內容 |
|---|---|
| `docs/PRD.md` | 產品範圍、階段定義、明確不做的項目 |
| `docs/TASKS.md` | 已完成、待辦、待裁決、目前的驗證結果 |
| `docs/TTS_DEVICE_CHECKLIST.md` | 語音的實機檢查清單與結果回寫方式 |

設計文件在 `docs/design/`，衝突時以 `RULINGS.md` 為最高依據：

| 文件 | 權威範圍 |
|---|---|
| `rust-core.md` | Rust 核心；§9 是 Dart 介面的唯一來源 |
| `curriculum.md` | 內容欄位與教學規則 |
| `flutter-app.md`（含 `-architecture`、`-tts`、`-testing`） | UI 流程與 design tokens |
| `reuse-and-verification.md` | 驗證工具與字型子集流程 |

## 專案結構

```text
lib/                     Flutter 程式碼
  src/rust/              FRB 產生的 Dart，不手改
test/                    Flutter 測試（test/support/ 是假後端與 pumpApp，test/ffi/ 走真實 .so）
integration_test/        真實 Rust＋真實內容的端到端旅程
assets/                  打包字型子集、授權文字、紙紋
rust/                    Cargo workspace 根，同時是 jp_core package
  src/api/               Dart 介面、DTO、CoreError（FRB 只掃描這裡）
  src/app/               API 與領域 crate 之間的組裝層
  src/frb_generated.rs   FRB 產生，不手改
  crates/
    jp_lang/             假名與羅馬字、動詞變化、Clock、確定性亂數
    jp_content/          內容載入（build.rs 嵌入 rust/content/）、內容 lint
    jp_store/            SQLite、Repository traits、record 型別
    jp_srs/              間隔重複（rs-fsrs 包裝）
    jp_plan/             學習計畫引擎
    jp_quiz/             測驗與演練產生器
  tools/content_tool/    開發用內容驗證 CLI，不進 App
  content/               內容 JSON（編譯時嵌入）
  clippy.toml            禁用 Utc::now、Local::now、Card::new，時間一律經 Clock 注入
rust_builder/            cargokit 與各平台建置殼，由 FRB 產生
tools/verify/            離線保證檢查（check_offline.py）、外部驗證資料下載（fetch_data.sh）
tools/fonts/             字元集與字型子集（make_charset.py）
tools/licenses/          Rust 套件授權清單（make_rust_crates.py）
docs/design/             設計文件
```

crate 的依賴方向由編譯器強制：

```text
jp_core（根）→ { jp_plan, jp_quiz, jp_srs, jp_content, jp_store } → jp_lang
jp_plan、jp_quiz → jp_srs → { jp_store, jp_content }
```

`jp_store` 不依賴 `jp_content`。`content_tool` 依賴 `jp_lang` 與 `jp_content`（開啟 `tooling` feature），App 不依賴它。各 crate 的模組見 `docs/design/rust-core.md` §1.3。

## 需要的工具

| 工具 | 版本 | 用途 |
|---|---|---|
| Flutter | 3.47.9（Dart 3.13.7） | App 建置 |
| Rust | 1.99.1，含 clippy、rustfmt | 核心建置 |
| flutter_rust_bridge_codegen | 2.13.0 | `cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked` |
| cargo-expand | 最新版 | codegen 需要；未安裝時 `generate` 會自動安裝 |
| clang、cmake、ninja、pkg-config、GTK 3 開發套件 | | Linux 桌面建置 |
| python3 | 3.x | 離線檢查與授權清單腳本，只用標準函式庫 |
| fonttools | | 只有重建字型子集時需要（`pip install fonttools`） |
| xvfb | | 無螢幕環境跑整合測試或啟動 Linux 版 |
| speech-dispatcher、日語模組 | | 在 Linux 上聽語音（選用）；`sudo apt install speech-dispatcher-espeak-ng` |
| cargo-llvm-cov | | 量測覆蓋率（選用）；`cargo install cargo-llvm-cov`、`rustup component add llvm-tools-preview` |

Android 與 iOS 需要各自的 SDK。專案只完成設定，從未實際建置過。

## 常用指令

以下從專案根目錄執行；`cargo` 指令需先 `cd rust`。

### 初次設定

```bash
flutter pub get
```

### 產生 FFI 綁定

修改 `rust/src/api/` 的公開介面後執行。需要時會自動跑 `build_runner` 產生 freezed 程式碼。

```bash
flutter_rust_bridge_codegen generate
```

### 測試與靜態檢查

```bash
cd rust
cargo test --workspace                                   # 全部 Rust 測試（2026-11-16：1,257 通過、23 略過）
cargo test -p jp_lang                                    # 單一 crate
# 學習迴路長模擬（標 #[ignore]，不含建置，release 約兩分半與一分鐘），規則見 rust-core.md §11.2，量測見 RULINGS O13
cargo test --release --test p0_learning_loop -- --ignored
cargo test --release --test p0_learning_loop_edges -- --ignored
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --all                                          # 只檢查不改檔：cargo fmt --all -- --check
cargo llvm-cov -p jp_lang --fail-under-lines 80          # 單一 crate 覆蓋率
# jp_core 要排除 FRB 產生的 frb_generated.rs，否則總數被它拉到 30% 以下
cargo llvm-cov -p jp_core --ignore-filename-regex 'frb_generated' --fail-under-lines 80
cd ..

flutter analyze
dart format --output=none --set-exit-if-changed lib test integration_test
cargo build --release --manifest-path rust/Cargo.toml    # test/ffi 要用 release 的 .so
flutter test --no-pub                                    # 含 golden，基準在 Linux 上產生（2026-11-16：1,430 通過）
# test/ffi/core_ffi_test.dart 斷言預設的 p0；.so 是舊建置（例如 p0a），或 Rust 介面改過（例如 BudgetDto 多了 capacity）卻沒重建時會失敗，先重建再跑

# 真實 Rust＋真實內容的端到端旅程，需要 xvfb，說明見 integration_test/README.md（七個檔、15 個測試，約 14 分鐘）
bash integration_test/run_all.sh
# 文案守門（O7）的純文字規則，不開 App
flutter --show-test-device test integration_test/support/p0_copy_rules_test.dart -d flutter-tester
```

`flutter test integration_test -d linux` 不能一次跑多個檔案，第二個檔案起會 `Unable to start the app`，請用 `run_all.sh`。

### 內容工具

`content_tool` 從專案根目錄執行，不會進 App。`--stage` 預設讀環境變數 `CONTENT_STAGE`，沒有時為 `p0`（`jp_content::disk::DEFAULT_STAGE`）。

```bash
CT="cargo run -q --manifest-path rust/Cargo.toml -p content_tool --"

$CT --stage p0 lint                  # 內容規則 R01–R25、RC1–RC11
$CT --stage p0 verify                # 外部資料比對、假名、字型、授權；--strict 時警告也算失敗
$CT --stage p0 stats                 # 各類別筆數與該階段目標
$CT --stage p0 coverage              # 涵蓋率報告，寫到 build/verify/
$CT --stage p0 charset               # 字元集素材，寫到 build/verify/chars_*.txt
$CT available le.l03                 # 到某課為止可用的單字與文法

bash tools/verify/fetch_data.sh      # verify 需要的外部資料，下載到 .verify-cache/，唯一會連網的開發步驟
```

驗證工具的完整規則在 `docs/design/reuse-and-verification.md` §9。

### 字型子集與授權清單

介面文字或內容改動後，用字可能超出子集，`verify` 的 F 系列規則會失敗。

```bash
$CT --stage p0 charset
python3 tools/fonts/make_charset.py --subset   # 需要 fonttools，缺上游字型時加 --download
python3 tools/licenses/make_rust_crates.py     # Rust 相依變動後更新；--check 只比對
```

### 建置與執行

```bash
cargo build --manifest-path rust/Cargo.toml --workspace  # 只建 Rust
flutter build linux                                      # 產物在 build/linux/x64/release/bundle/
flutter run -d linux

# 無螢幕環境確認啟動不崩潰（exit 124 表示撐滿 10 秒）
xvfb-run -a timeout 10 build/linux/x64/release/bundle/japanese_learn_app
```

release 建置不讀環境變數 `JLA_DATA_DIR`（`lib/core/backend/frb/frb_boot_gateway.dart`，只有 debug、profile 讀），上面的冒煙會用預設的應用程式資料目錄（`getApplicationSupportDirectory()`），與平常執行的 App 共用資料。要用空的資料目錄，改跑 debug 建置並設 `JLA_DATA_DIR=$(mktemp -d)`，或用整合測試的 `boot_test.dart`。

Linux 上 App 優先載入打包在執行檔旁的 `bundle/lib/libjp_core.so`（`lib/core/backend/frb/native_library.dart`），不會因為在專案根目錄 `flutter run -d linux` 而載到 `rust/target/release/` 的舊建置；只有 bundle 裡沒有這個檔時才交回 FRB 預設的搜尋順序。`test/ffi/core_ffi_test.dart` 刻意直接載入 `rust/target/release/libjp_core.so`，跑它之前仍要先 `cargo build --release`。

### CONTENT_STAGE

決定內容的發布範圍，為建置時環境變數，可用值 `p0a`、`p0`（預設）、`full`，範圍定義見 `curriculum.md` §14。預設值寫在兩處，必須一致：`rust/crates/jp_content/build.rs` 的 `DEFAULT_STAGE`（App 嵌入的階段）與 `rust/crates/jp_content/src/disk.rs` 的 `DEFAULT_STAGE`（`content_tool` 與 lint 測試），`disk.rs` 的單元測試會比對兩者。無效值會讓建置失敗，改值後會自動重建。所有階段的內容檔都會嵌入，載入時才依階段過濾。

`rust/content/` 目前寫到 `p0`。`course.json` 已列出 L31–L48，但對應的對話、單字還不存在，所以 `full` 載入內容時會失敗（`content corrupt: le.l31: R03 dialogue 指向不存在的項目（di.can_you_speak）`），`content_tool --stage full charset` 同樣無法執行。

```bash
flutter build linux                     # 預設 p0
CONTENT_STAGE=p0a flutter build linux   # 只含假名與入門七課的舊切片
```

整合測試會先檢查 App 載入的是 `p0`。App 在 Linux 優先載入 bundle 內的函式庫（見「建置與執行」）；`rust/target/release/libjp_core.so` 若是預設切換前建的舊檔（`p0a`），只會影響 `test/ffi` 與 bundle 缺檔時的 FRB 預設搜尋，說明見 `integration_test/README.md`。

### 離線保證檢查

檢查 Rust、Dart 相依沒有 HTTP／TLS client，Android release manifest 沒有 `INTERNET` 權限，原始碼沒有使用網路類別。exit 0 通過、1 違規、2 環境問題。

```bash
python3 tools/verify/check_offline.py

# Android release 建置之後，連 APK 一併檢查
python3 tools/verify/check_offline.py --apk build/app/outputs/flutter-apk/app-release.apk --require-apk
```

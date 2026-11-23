# 第三方授權聲明

App 內的「設定 › 授權」以 `LicenseRegistry` 顯示相同內容（`lib/app/font_licenses.dart`）。

## 打包字型（SIL Open Font License 1.1）

三款字型皆已子集化，屬 OFL 定義的 Modified Version，仍以 OFL 1.1 釋出。授權全文放在 `assets/fonts/licenses/`。

| 字型 | 著作權 | 授權檔 |
|---|---|---|
| Klee One（Regular、SemiBold） | Copyright 2020 The Klee Project Authors | `assets/fonts/licenses/OFL-KleeOne.txt` |
| Noto Sans TC（400、700 靜態實例） | Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source' | `assets/fonts/licenses/OFL-NotoSansTC.txt` |
| Noto Serif TC（800 靜態實例） | Copyright 2012 Google Inc. All Rights Reserved. | `assets/fonts/licenses/OFL-NotoSerifTC.txt` |

「Klee」是 Fontworks 的商標，本 App 僅作內部 family 名稱，不用於產品名稱。

子集產生方式見 `docs/design/reuse-and-verification.md` §5.3 與 `tools/fonts/make_charset.py`。

## Rust 核心套件

App 內嵌的 Rust 核心（`jp_core`）所用的第三方 crate 名稱、版本與授權列於 `assets/licenses/rust_crates.txt`，由 `tools/licenses/make_rust_crates.py` 依 `cargo metadata` 產生，App 內的「設定 › 授權」可檢視。清單不含開發相依與內容工具專用的 crate。

## JLPT 參考級別

單字的參考級別（`jlpt` 欄位，僅 `n5`、`n4`、`beyond` 三種標籤）：參考級別參照 Jonathan Waller 的 JLPT Resources（CC BY）整理，非官方資料。

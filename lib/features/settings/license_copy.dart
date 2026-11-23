import 'package:material_ui/material_ui.dart' show immutable;

@immutable
final class FontLicenseInfo {
  const FontLicenseInfo(this.name, this.copyright, this.file);
  final String name, copyright, file;
}

// 著作權行照抄上游 OFL.txt（reuse §5.5）。
const fontLicenses = [
  FontLicenseInfo(
    'Klee One',
    'Copyright 2020 The Klee Project Authors',
    'OFL-KleeOne.txt',
  ),
  FontLicenseInfo(
    'Noto Sans TC',
    "Copyright 2014-2021 Adobe (http://www.adobe.com/), "
        "with Reserved Font Name 'Source'",
    'OFL-NotoSansTC.txt',
  ),
  FontLicenseInfo(
    'Noto Serif TC',
    'Copyright 2012 Google Inc. All Rights Reserved.',
    'OFL-NotoSerifTC.txt',
  ),
];

const ofLicenseLine = 'SIL Open Font License 1.1，已子集化';

const rustCratesAsset = 'assets/licenses/rust_crates.txt';
const rustCratesTitle = 'Rust 套件';
const rustCratesSubtitle = '內建 Rust 套件的名稱、版本與授權';

const fontTrademarkNote = '「Klee」是 Fontworks 的商標，本 App 僅作內部字型名稱，不用於產品名稱。';

/// `font_licenses.dart` 註冊的條目標籤；套件清單要排除，避免和字型區重複。
const fontRegistrySuffix = '（已子集化）';

// 主動標示，無義務但避免爭議。文字逐字依 reuse §2.4，「未收錄」不可省略。
const jmdictStatement =
    '單字拼寫與讀音於開發時參照 JMdict 校對。JMdict 由 Electronic Dictionary '
    'Research and Development Group 製作，以 CC BY-SA 4.0 授權'
    '（https://www.edrdg.org/jmdict/j_jmdict.html）。本 App 未收錄 JMdict 資料。';

// reuse §3.3-5：`jlpt` 標籤來自此清單，使用者看得到。
const jlptReferenceStatement =
    '參考級別參照 Jonathan Waller 的 JLPT Resources（CC BY）整理，非官方資料。';

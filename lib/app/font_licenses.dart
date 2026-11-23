import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;

const _fontLicenses = {
  'Klee One': 'OFL-KleeOne.txt',
  'Noto Sans TC': 'OFL-NotoSansTC.txt',
  'Noto Serif TC': 'OFL-NotoSerifTC.txt',
};

const _jlptNotice = '參考級別參照 Jonathan Waller 的 JLPT Resources（CC BY）整理，非官方資料。';

/// 子集字型屬 OFL 的 Modified Version，要附授權全文（reuse §5.5）；
/// `jlpt` 欄位的來源標示也一併登錄，與 THIRD_PARTY_NOTICES.md 同步（reuse §3.3、§10）。
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: file) in _fontLicenses.entries) {
      final text = await rootBundle.loadString('assets/fonts/licenses/$file');
      yield LicenseEntryWithLineBreaks(['$name（已子集化）'], text);
    }
    yield LicenseEntryWithLineBreaks(['JLPT 參考級別'], _jlptNotice);
  });
}

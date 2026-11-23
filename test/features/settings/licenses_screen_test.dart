import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/features/settings/license_copy.dart';
import 'package:japanese_learn_app/features/settings/licenses_screen.dart';
import 'package:japanese_learn_app/features/settings/rust_crates.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';

void main() {
  tearDown(LicenseRegistry.reset);

  Future<void> pumpLicenses(
    WidgetTester tester, {
    double width = 375,
    double textScale = 1,
  }) => pumpApp(
    tester,
    backend: FakeBackend(),
    child: const LicensesScreen(),
    extraOverrides: [
      fontLicenseTextProvider.overrideWith(
        (ref, file) async => 'OFL body of $file',
      ),
    ],
    width: width,
    textScale: textScale,
    height: 1800,
  );

  testWidgets('列出三款字型與上游著作權行', (tester) async {
    await pumpLicenses(tester);
    expect(find.text('Klee One'), findsOneWidget);
    expect(find.text('Noto Sans TC'), findsOneWidget);
    expect(find.text('Noto Serif TC'), findsOneWidget);
    expect(
      find.textContaining('Copyright 2020 The Klee Project Authors'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        "Copyright 2014-2021 Adobe (http://www.adobe.com/), "
        "with Reserved Font Name 'Source'",
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Copyright 2012 Google Inc. All Rights Reserved.'),
      findsOneWidget,
    );
    expect(find.textContaining('SIL Open Font License 1.1'), findsWidgets);
  });

  testWidgets('點字型開啟 OFL 全文', (tester) async {
    await pumpLicenses(tester);
    await tester.tap(find.text('Klee One'));
    await tester.pumpAndSettle();
    expect(find.text('OFL body of OFL-KleeOne.txt'), findsOneWidget);
  });

  testWidgets('授權全文讀取失敗時可重試', (tester) async {
    var calls = 0;
    await pumpApp(
      tester,
      backend: FakeBackend(),
      child: const LicensesScreen(),
      extraOverrides: [
        fontLicenseTextProvider.overrideWith((ref, file) async {
          calls++;
          if (calls == 1) throw StateError('missing');
          return 'OFL 內文';
        }),
      ],
      height: 1800,
    );
    await tester.tap(find.text('Klee One'));
    await tester.pumpAndSettle();
    expect(find.text('重試'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.text('OFL 內文'), findsOneWidget);
  });

  testWidgets('JMdict 聲明逐字且註明未收錄', (tester) async {
    await pumpLicenses(tester);
    expect(
      find.text(
        '單字拼寫與讀音於開發時參照 JMdict 校對。JMdict 由 Electronic Dictionary '
        'Research and Development Group 製作，以 CC BY-SA 4.0 授權'
        '（https://www.edrdg.org/jmdict/j_jmdict.html）。本 App 未收錄 JMdict 資料。',
      ),
      findsOneWidget,
    );
  });

  testWidgets('列出參考級別來源', (tester) async {
    await pumpLicenses(tester);
    expect(
      find.text('參考級別參照 Jonathan Waller 的 JLPT Resources（CC BY）整理，非官方資料。'),
      findsOneWidget,
    );
  });

  testWidgets('列出 LicenseRegistry 的套件，字型不重複', (tester) async {
    LicenseRegistry.addLicense(
      () => Stream.fromIterable(const [
        LicenseEntryWithLineBreaks(['riverpod'], 'MIT text'),
        LicenseEntryWithLineBreaks(['Klee One（已子集化）'], 'OFL'),
      ]),
    );
    await pumpLicenses(tester);
    await tester.scrollUntilVisible(find.text('riverpod'), 200);
    expect(find.text('riverpod'), findsOneWidget);
    expect(find.text('Klee One（已子集化）'), findsNothing);

    await tester.tap(find.text('riverpod'));
    await tester.pumpAndSettle();
    expect(find.text('MIT text'), findsOneWidget);
  });

  testWidgets('Rust 核心套件可點開，列出名稱、版本與授權', (tester) async {
    await pumpApp(
      tester,
      backend: FakeBackend(),
      child: const LicensesScreen(),
      extraOverrides: [
        rustCrateListProvider.overrideWith(
          (ref) async => const [
            RustCrateInfo('rusqlite', '0.41.1', 'MIT'),
            RustCrateInfo('chrono', '0.4.45', 'MIT OR Apache-2.0'),
          ],
        ),
      ],
      height: 1800,
    );
    expect(find.text(rustCratesTitle), findsOneWidget);

    await tester.tap(find.text(rustCratesTitle));
    await tester.pumpAndSettle();

    expect(find.text('rusqlite 0.41.1'), findsOneWidget);
    expect(find.text('chrono 0.4.45'), findsOneWidget);
    expect(find.text('MIT OR Apache-2.0'), findsOneWidget);
  });

  testWidgets('Rust 清單讀取失敗時可重試', (tester) async {
    var calls = 0;
    await pumpApp(
      tester,
      backend: FakeBackend(),
      child: const LicensesScreen(),
      extraOverrides: [
        rustCrateListProvider.overrideWith((ref) async {
          calls++;
          if (calls == 1) throw StateError('missing');
          return const [RustCrateInfo('rusqlite', '0.41.1', 'MIT')];
        }),
      ],
      height: 1800,
    );
    await tester.tap(find.text(rustCratesTitle));
    await tester.pumpAndSettle();
    expect(find.text('重試'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.text('rusqlite 0.41.1'), findsOneWidget);
  });

  testWidgets('沒有套件資料時顯示空狀態', (tester) async {
    await pumpLicenses(tester);
    expect(find.text('這個版本沒有額外的套件授權資料。'), findsOneWidget);
  });

  testWidgets('寬 320、字級 1.5 倍不溢位', (tester) async {
    await pumpLicenses(tester, width: 320, textScale: 1.5);
    expect(tester.takeException(), isNull);
    expect(find.byType(Text), findsWidgets);
  });
}

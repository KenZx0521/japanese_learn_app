// 裁決 11：使用者看得到的 App 名稱統一。applicationId 維持原樣。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_backend.dart';
import '../support/pump_app.dart';

const _name = '日文學習';

void main() {
  testWidgets('MaterialApp 標題', (tester) async {
    await pumpApp(tester, backend: FakeBackend(), location: '/today');

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, _name);
  });

  test('Android、iOS、Linux 的顯示名稱', () {
    String read(String path) => File(path).readAsStringSync();

    expect(
      read('android/app/src/main/AndroidManifest.xml'),
      contains('android:label="$_name"'),
    );
    final plist = read('ios/Runner/Info.plist');
    for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
      expect(
        RegExp('<key>$key</key>\\s*<string>$_name</string>').hasMatch(plist),
        isTrue,
        reason: key,
      );
    }
    final linux = read('linux/runner/my_application.cc');
    expect(linux, contains('gtk_header_bar_set_title(header_bar, "$_name")'));
    expect(linux, contains('gtk_window_set_title(window, "$_name")'));
  });
}

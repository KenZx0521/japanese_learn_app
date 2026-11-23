import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/features/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';
import 'settings_harness.dart';

void main() {
  Future<void> openReset(WidgetTester tester, FakeBackend backend) async {
    await pumpApp(
      tester,
      backend: backend,
      child: const SettingsScreen(),
      height: 1400,
    );
    await tapRow(tester, find.text('清除全部進度'));
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('第一段要明確確認，取消不清除', (tester) async {
    final backend = settingsBackend();
    await openReset(tester, backend);
    expect(find.text('清除全部進度？'), findsOneWidget);
    expect(find.textContaining('都會刪除'), findsOneWidget);

    await tapText(tester, '先不要');
    expect(backend.settings.resetAllStub.calls, isEmpty);
    expect(find.text('清除全部進度？'), findsNothing);
  });

  testWidgets('第二段沒輸入「清除」時不能執行', (tester) async {
    final backend = settingsBackend();
    await openReset(tester, backend);
    await tapText(tester, '繼續');

    await tester.enterText(find.byType(TextField), '清楚');
    await tester.pumpAndSettle();
    await tapText(tester, '清除全部進度');
    expect(backend.settings.resetAllStub.calls, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('輸入「清除」後呼叫 reset_all 並回到引導', (tester) async {
    final backend = settingsBackend();
    final container = await pumpApp(
      tester,
      backend: backend,
      child: const SettingsScreen(),
      height: 1400,
    );
    await tapRow(tester, find.text('清除全部進度'));
    await tapText(tester, '繼續');

    await tester.enterText(find.byType(TextField), '清除');
    await tester.pumpAndSettle();
    await tapText(tester, '清除全部進度');

    expect(backend.settings.resetAllStub.calls, hasLength(1));
    expect(container.read(onboardingDoneProvider).value, isFalse);
    expect(backend.settings.loadStub.calls.length, greaterThanOrEqualTo(2));
  });

  testWidgets('Storage 失敗時提示重新啟動', (tester) async {
    final backend = settingsBackend();
    backend.settings.resetAllStub.throws(const StorageFailure());
    await openReset(tester, backend);
    await tapText(tester, '繼續');
    await tester.enterText(find.byType(TextField), '清除');
    await tester.pumpAndSettle();
    await tapText(tester, '清除全部進度');

    expect(find.textContaining('請重新啟動 App'), findsOneWidget);
  });

  testWidgets('其他失敗保留資料並可再試', (tester) async {
    final backend = settingsBackend();
    backend.settings.resetAllStub.throws(const UnexpectedFailure());
    await openReset(tester, backend);
    await tapText(tester, '繼續');
    await tester.enterText(find.byType(TextField), '清除');
    await tester.pumpAndSettle();
    await tapText(tester, '清除全部進度');
    expect(find.textContaining('資料還在'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    backend.settings.resetAllStub.answers((_) {});
    await tapText(tester, '清除全部進度');
    expect(backend.settings.resetAllStub.calls, hasLength(2));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/features/plan/about_level_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';
import 'plan_fixtures.dart';

void main() {
  FakeBackend backendWith(ContentStage stage) {
    final backend = FakeBackend();
    backend.course.overviewStub.returns(overview(stage: stage));
    return backend;
  }

  String pageText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
      .join('\n');

  testWidgets('p0a 只談假名與入門七課', (tester) async {
    await pumpApp(
      tester,
      backend: backendWith(ContentStage.p0A),
      child: const AboutLevelScreen(),
      height: 2000,
    );
    final text = pageText(tester);
    expect(text, contains('這一版涵蓋假名與入門七課。'));
    for (final banned in ['N4', '看懂日劇', '聽懂日劇', '專區', 'L30']) {
      expect(text, isNot(contains(banned)), reason: banned);
    }
  });

  testWidgets('p0 列出各目標的實際狀態，不含 N4', (tester) async {
    await pumpApp(
      tester,
      backend: backendWith(ContentStage.p0),
      child: const AboutLevelScreen(),
      height: 3000,
    );
    final text = pageText(tester);
    expect(text, contains('本版到 L30，涵蓋參考 N5 範圍。'));
    expect(text, contains('日常對話'));
    expect(text, contains('做不到'));
    expect(text, isNot(contains('N4')));
    expect(text, isNot(contains('L48')));
  });

  testWidgets('full 列出 N4 基準', (tester) async {
    await pumpApp(
      tester,
      backend: backendWith(ContentStage.full),
      child: const AboutLevelScreen(),
      height: 3000,
    );
    final text = pageText(tester);
    expect(text, contains('完整版到 L48。'));
    expect(text, contains('N4 總分 90 以上為 A2'));
  });

  testWidgets('讀取失敗可重試', (tester) async {
    final backend = FakeBackend();
    backend.course.overviewStub.throws(const ContentFailure());
    await pumpApp(tester, backend: backend, child: const AboutLevelScreen());
    expect(find.byType(ErrorSlip), findsOneWidget);

    backend.course.overviewStub.returns(overview());
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorSlip), findsNothing);
    expect(find.text('這一版涵蓋假名與入門七課。'), findsOneWidget);
  });

  testWidgets('字級 1.5 倍、寬 320 不溢位', (tester) async {
    await pumpApp(
      tester,
      backend: backendWith(ContentStage.full),
      child: const AboutLevelScreen(),
      width: 320,
      textScale: 1.5,
    );
    expect(tester.takeException(), isNull);
  });
}

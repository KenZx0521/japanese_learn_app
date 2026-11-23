import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/design/widgets/back_line.dart';
import 'package:japanese_learn_app/design/widgets/paper_scaffold.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump_app.dart';

/// 從第一頁推一頁出來，第二頁放 [child]。
Widget _pushable(Widget child) => Builder(
  builder: (context) => TextButton(
    onPressed: () => Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => PaperScaffold(body: child),
      ),
    ),
    child: const Text('第一頁'),
  ),
);

void main() {
  group('BackLine', () {
    testWidgets('顯示文字，點擊呼叫 onBack', (tester) async {
      var backs = 0;
      await pumpApp(
        tester,
        child: Column(
          children: [BackLine(onBack: () => backs++, label: '離開')],
        ),
      );

      await tester.tap(find.text('離開'));

      expect(backs, 1);
    });

    testWidgets('點擊範圍至少 48dp 高（review_f F9）', (tester) async {
      await pumpApp(
        tester,
        child: Wrap(children: [BackLine(onBack: () {})]),
      );

      expect(
        tester.getSize(find.byType(BackLine)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('箭頭和文字一起顯示，不撐滿寬度', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        child: Wrap(children: [BackLine(onBack: () {})]),
      );

      expect(find.text('返回'), findsOneWidget);
      expect(find.bySemanticsLabel('返回'), findsOneWidget);
      expect(tester.getSize(find.byType(BackLine)).width, lessThan(375));
      handle.dispose();
    });
  });

  group('PopBackLine', () {
    testWidgets('沒有上一頁時不顯示', (tester) async {
      await pumpApp(tester, child: const PopBackLine());

      expect(find.text('返回'), findsNothing);
    });

    testWidgets('有上一頁時顯示，點擊回上一頁', (tester) async {
      await pumpApp(tester, child: _pushable(const PopBackLine()));
      await tester.tap(find.text('第一頁'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(find.byType(PopBackLine), findsNothing);
      expect(find.text('第一頁'), findsOneWidget);
    });
  });

  group('PageBackLink', () {
    testWidgets('V1／V2／V3／N1 統一為箭頭加「返回」', (tester) async {
      await pumpApp(tester, child: const PageBackLink(fallback: '/today'));

      expect(find.text('返回'), findsOneWidget);
    });

    testWidgets('可帶別的文字（K2 的「離開」）', (tester) async {
      await pumpApp(
        tester,
        child: const PageBackLink(fallback: '/today', label: '離開'),
      );

      expect(find.text('離開'), findsOneWidget);
    });

    testWidgets('不在路由內時點擊不會出錯', (tester) async {
      await pumpApp(tester, child: const PageBackLink(fallback: '/today'));

      await tester.tap(find.byType(PageBackLink));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}

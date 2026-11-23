import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/features/vocab/vocab_topics_screen.dart';
import 'package:japanese_learn_app/features/vocab/widgets/vocab_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';
import 'vocab_fixtures.dart';

const _topics = [
  TopicDto(id: 'food', titleZh: '食物', count: 12),
  TopicDto(id: 'school', titleZh: '學校', count: 8),
];

FakeBackend _backend() {
  final backend = FakeBackend();
  backend.vocab.topicsStub.returns(_topics);
  return backend;
}

Future<void> _pump(WidgetTester tester, FakeBackend backend) =>
    pumpApp(tester, backend: backend, child: const VocabTopicsScreen());

String _location(WidgetTester tester, Type screen) =>
    GoRouter.of(tester.element(find.byType(screen)))
        .routerDelegate
        .currentConfiguration
        .uri
        .toString();

void main() {
  testWidgets('列出主題與篇數', (tester) async {
    await _pump(tester, _backend());

    expect(find.text('食物'), findsOneWidget);
    expect(find.text('學校'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('點主題進 V2 並帶 topic', (tester) async {
    final backend = _backend();
    backend.vocab.pageStub.returns(const VocabPageDto(items: [], total: 0));

    await pumpApp(tester, backend: backend, location: AppRoutes.vocab);
    await tester.tap(find.text('食物'));
    await tester.pumpAndSettle();

    expect(find.byType(VocabTopicsScreen), findsNothing);
    expect(filterOf(backend.vocab.pageStub.calls.single).topic, 'food');
  });

  testWidgets('全部單字入口進 V2，不帶主題', (tester) async {
    final backend = _backend();
    backend.vocab.pageStub.returns(const VocabPageDto(items: [], total: 0));

    await pumpApp(tester, backend: backend, location: AppRoutes.vocab);
    await tester.tap(find.text('全部單字'));
    await tester.pumpAndSettle();

    final filter = filterOf(backend.vocab.pageStub.calls.single);
    expect(filter.topic, isNull);
    expect(filter.onlyIntroduced, isFalse);
  });

  testWidgets('主題載入中顯示骨架，資料到了才換掉', (tester) async {
    final backend = _backend();
    final gate = Completer<void>();
    backend.vocab.topicsStub.gate = gate.future;

    await pumpApp(
      tester,
      backend: backend,
      child: const VocabTopicsScreen(),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(SkeletonLines), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('食物'), findsOneWidget);
    expect(find.byType(SkeletonLines), findsNothing);
  });

  testWidgets('主題載入失敗顯示 ErrorSlip，重試成功', (tester) async {
    final backend = _backend();
    backend.vocab.topicsStub.throws(const StorageFailure());

    await _pump(tester, backend);
    expect(find.byType(ErrorSlip), findsOneWidget);

    backend.vocab.topicsStub.returns(_topics);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorSlip), findsNothing);
    expect(find.text('食物'), findsOneWidget);
  });

  group('搜尋', () {
    testWidgets('輸入停頓 200ms 才查詢，只查最後一次', (tester) async {
      final backend = _backend();
      await _pump(tester, backend);

      await tester.enterText(find.byType(TextField), 'ne');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.enterText(find.byType(TextField), 'neko');
      await tester.pump(const Duration(milliseconds: 199));
      expect(backend.vocab.searchStub.calls, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(backend.vocab.searchStub.calls, [
        ['neko', 50],
      ]);
    });

    testWidgets('結果用單字列，並收起主題', (tester) async {
      final backend = _backend();
      backend.vocab.searchStub.returns([wordAt(1), wordAt(2)]);
      await _pump(tester, backend);

      await tester.enterText(find.byType(TextField), 'kana');
      await tester.pumpAndSettle(const Duration(milliseconds: 250));

      expect(find.byType(VocabRow), findsNWidgets(2));
      expect(find.text('語1'), findsOneWidget);
      expect(find.text('食物'), findsNothing);
    });

    testWidgets('沒有結果時給提示', (tester) async {
      final backend = _backend();
      await _pump(tester, backend);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle(const Duration(milliseconds: 250));

      expect(find.text('找不到，試試中文、假名或羅馬字'), findsOneWidget);
    });

    testWidgets('清除後回到主題，不留舊結果', (tester) async {
      final backend = _backend();
      backend.vocab.searchStub.returns([wordAt(1)]);
      await _pump(tester, backend);

      await tester.enterText(find.byType(TextField), 'kana');
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      await tester.tap(find.bySemanticsLabel('清除搜尋'));
      await tester.pumpAndSettle();

      expect(find.byType(VocabRow), findsNothing);
      expect(find.text('食物'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('注音選字中不查詢，選定後才查', (tester) async {
      final backend = _backend();
      await _pump(tester, backend);

      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ㄇㄠ',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(backend.vocab.searchStub.calls, isEmpty);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '貓',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      expect(backend.vocab.searchStub.calls.single.first, '貓');
    });

    testWidgets('查詢失敗顯示 ErrorSlip，重試同一個查詢', (tester) async {
      final backend = _backend();
      backend.vocab.searchStub.throws(const StorageFailure());
      await _pump(tester, backend);

      await tester.enterText(find.byType(TextField), 'neko');
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.vocab.searchStub.returns([wordAt(1)]);
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(find.byType(VocabRow), findsOneWidget);
      expect(backend.vocab.searchStub.calls.last.first, 'neko');
    });

    testWidgets('點結果進單字詳情', (tester) async {
      final backend = _backend();
      backend.vocab.searchStub.returns([wordAt(1)]);
      backend.vocab.detailStub.returns(detailFixture(summary: wordAt(1)));

      await pumpApp(tester, backend: backend, location: AppRoutes.vocab);
      await tester.enterText(find.byType(TextField), 'kana');
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      await tester.tap(find.text('語1'));
      await tester.pumpAndSettle();

      expect(backend.vocab.detailStub.calls.single, ['vo.w1']);
    });
  });

  testWidgets('320 寬、字級 2.0 倍不溢位', (tester) async {
    final backend = _backend();
    backend.vocab.searchStub.returns([wordAt(1)]);

    await pumpApp(
      tester,
      backend: backend,
      child: const VocabTopicsScreen(),
      width: 320,
      textScale: 2,
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'kana');
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    expect(find.byType(VocabRow), findsOneWidget);
  });

  testWidgets('主題列互動目標至少 48dp', (tester) async {
    await pumpApp(
      tester,
      backend: _backend(),
      child: const VocabTopicsScreen(),
    );
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('搜尋不寫進路由網址', (tester) async {
    final backend = _backend();
    await pumpApp(tester, backend: backend, location: AppRoutes.vocab);
    expect(_location(tester, VocabTopicsScreen), AppRoutes.vocab);
  });
}

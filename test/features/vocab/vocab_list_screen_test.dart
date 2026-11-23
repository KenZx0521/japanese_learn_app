import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/features/vocab/vocab_list_screen.dart';
import 'package:japanese_learn_app/features/vocab/widgets/vocab_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';
import 'vocab_fixtures.dart';

const _screen = VocabListScreen(onlyIntroduced: false, onlyStarred: false);

List<VocabSummaryDto> _words(int count, {String lessonId = 'le.l01'}) => [
  for (var i = 0; i < count; i++) wordAt(i, lessonId: lessonId),
];

FakeBackend _backendWith(List<VocabSummaryDto> all) {
  final backend = FakeBackend();
  backend.vocab.pageStub.answers((args) => pageOf(all, args));
  backend.vocab.topicsStub.returns(const []);
  return backend;
}

void main() {
  testWidgets('每列顯示單字、假名、意思、課次與狀態', (tester) async {
    final backend = _backendWith([
      wordAt(1, lessonId: 'le.l05', srs: SrsStateLabel.learning),
    ]);

    await pumpApp(tester, backend: backend, child: _screen);

    expect(find.text('語1'), findsOneWidget);
    expect(find.text('かな1'), findsOneWidget);
    expect(find.textContaining('意思1'), findsOneWidget);
    expect(find.textContaining('第 5 課'), findsWidgets);
    expect(find.text('學習中'), findsWidgets);
  });

  testWidgets('依課分段，換課時多一個小標', (tester) async {
    final backend = _backendWith([
      wordAt(1, lessonId: 'le.k03'),
      wordAt(2, lessonId: 'le.k03'),
      wordAt(3, lessonId: 'le.l01'),
    ]);

    await pumpApp(tester, backend: backend, child: _screen);

    expect(find.widgetWithText(Semantics, '平假名第 3 課'), findsWidgets);
    expect(find.text('平假名第 3 課'), findsOneWidget);
    expect(find.text('第 1 課'), findsOneWidget);
  });

  testWidgets('第一次取用預設條件：offset 0、limit 50', (tester) async {
    final backend = _backendWith(_words(3));

    await pumpApp(tester, backend: backend, child: _screen);

    final call = backend.vocab.pageStub.calls.single;
    final filter = filterOf(call);
    expect(call.sublist(1), [0, 50]);
    expect(filter.onlyIntroduced, isFalse);
    expect(filter.onlyStarred, isFalse);
    expect(filter.srsState, isNull);
    expect(filter.topic, isNull);
  });

  testWidgets('建構子參數帶入篩選條件', (tester) async {
    final backend = _backendWith(_words(1));

    await pumpApp(
      tester,
      backend: backend,
      child: const VocabListScreen(
        topic: 'food',
        onlyIntroduced: true,
        onlyStarred: true,
        srs: 'learning',
      ),
    );

    final filter = filterOf(backend.vocab.pageStub.calls.single);
    expect(filter.topic, 'food');
    expect(filter.onlyIntroduced, isTrue);
    expect(filter.onlyStarred, isTrue);
    expect(filter.srsState, SrsStateLabel.learning);
  });

  testWidgets('不認得的 srs 參數等於沒有篩選', (tester) async {
    final backend = _backendWith(_words(1));

    await pumpApp(
      tester,
      backend: backend,
      child: const VocabListScreen(
        onlyIntroduced: false,
        onlyStarred: false,
        srs: 'bogus',
      ),
    );

    expect(filterOf(backend.vocab.pageStub.calls.single).srsState, isNull);
  });

  group('篩選', () {
    testWidgets('「只看學過的」重新取第一頁', (tester) async {
      final backend = _backendWith(_words(3));
      await pumpApp(tester, backend: backend, child: _screen);

      await tester.tap(find.text('只看學過的'));
      await tester.pumpAndSettle();

      final last = backend.vocab.pageStub.calls.last;
      expect(filterOf(last).onlyIntroduced, isTrue);
      expect(last.sublist(1), [0, 50]);
    });

    testWidgets('熟練度單選，再點一次取消', (tester) async {
      final backend = _backendWith(_words(3));
      await pumpApp(tester, backend: backend, child: _screen);

      await tester.tap(find.text('熟練'));
      await tester.pumpAndSettle();
      expect(
        filterOf(backend.vocab.pageStub.calls.last).srsState,
        SrsStateLabel.mastered,
      );

      await tester.tap(find.text('未學').first);
      await tester.pumpAndSettle();
      expect(
        filterOf(backend.vocab.pageStub.calls.last).srsState,
        SrsStateLabel.notStarted,
      );

      await tester.tap(find.text('未學').first);
      await tester.pumpAndSettle();
      expect(filterOf(backend.vocab.pageStub.calls.last).srsState, isNull);
    });

    testWidgets('篩選寫進網址', (tester) async {
      final backend = _backendWith(_words(1));
      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.vocabList(topic: 'food'),
      );

      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();

      final screen = tester.widget<VocabListScreen>(
        find.byType(VocabListScreen),
      );
      expect(screen.topic, 'food');
      expect(screen.onlyStarred, isTrue);
      expect(screen.onlyIntroduced, isFalse);
    });

    testWidgets('篩選沒有結果時給提示', (tester) async {
      final backend = _backendWith(const []);

      await pumpApp(tester, backend: backend, child: _screen);

      expect(find.text('沒有符合的單字'), findsOneWidget);
    });
  });

  group('分頁', () {
    testWidgets('大量資料只建出看得到的列', (tester) async {
      final backend = _backendWith(_words(2000));

      await pumpApp(tester, backend: backend, child: _screen);

      expect(find.byType(VocabRow).evaluate().length, lessThan(40));
      expect(find.text('語49'), findsNothing);
      expect(backend.vocab.pageStub.calls, hasLength(1));
    });

    testWidgets('往下捲取下一頁，offset 接在已載入筆數後面', (tester) async {
      final backend = _backendWith(_words(120));
      await pumpApp(tester, backend: backend, child: _screen);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();

      final offsets = backend.vocab.pageStub.calls.map((c) => c[1]).toList();
      expect(offsets.take(2), [0, 50]);
    });

    testWidgets('已全部載入後不再取', (tester) async {
      final backend = _backendWith(_words(10));
      await pumpApp(tester, backend: backend, child: _screen);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();

      expect(backend.vocab.pageStub.calls, hasLength(1));
    });

    testWidgets('下一頁失敗時保留已載入的列，可重試', (tester) async {
      final all = _words(120);
      final backend = _backendWith(all);
      await pumpApp(tester, backend: backend, child: _screen);

      backend.vocab.pageStub.throws(const StorageFailure());
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorSlip), findsOneWidget);
      expect(find.byType(VocabRow), findsWidgets);

      backend.vocab.pageStub.answers((args) => pageOf(all, args));
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorSlip), findsNothing);
      expect(backend.vocab.pageStub.calls.last[1], 50);
    });

    testWidgets('連續捲動不重複取同一頁', (tester) async {
      final backend = _backendWith(_words(120));
      final gate = Completer<void>();
      await pumpApp(tester, backend: backend, child: _screen);

      backend.vocab.pageStub.gate = gate.future;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();
      final offsets = backend.vocab.pageStub.calls.map((c) => c[1]).toList();
      expect(offsets.toSet(), hasLength(offsets.length));
    });
  });

  testWidgets('載入中顯示骨架', (tester) async {
    final backend = _backendWith(_words(1));
    final gate = Completer<void>();
    backend.vocab.pageStub.gate = gate.future;

    await pumpApp(tester, backend: backend, child: _screen, settle: false);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(SkeletonLines), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(VocabRow), findsOneWidget);
  });

  testWidgets('第一頁失敗顯示 ErrorSlip，重試成功', (tester) async {
    final backend = _backendWith(_words(1));
    backend.vocab.pageStub.throws(const StorageFailure());

    await pumpApp(tester, backend: backend, child: _screen);
    expect(find.byType(ErrorSlip), findsOneWidget);

    backend.vocab.pageStub.answers((args) => pageOf(_words(1), args));
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.byType(VocabRow), findsOneWidget);
  });

  testWidgets('列與篩選都有標籤、互動目標足夠', (tester) async {
    final backend = _backendWith([wordAt(1, srs: SrsStateLabel.learning)]);
    await pumpApp(tester, backend: backend, child: _screen);
    final handle = tester.ensureSemantics();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });

  testWidgets('點列進單字詳情', (tester) async {
    final backend = _backendWith([wordAt(7)]);
    backend.vocab.detailStub.returns(detailFixture(summary: wordAt(7)));

    await pumpApp(tester, backend: backend, location: AppRoutes.vocabList());
    await tester.tap(find.text('語7'));
    await tester.pumpAndSettle();

    expect(backend.vocab.detailStub.calls.single, ['vo.w7']);
  });

  testWidgets('主題頁顯示主題名稱', (tester) async {
    final backend = _backendWith(_words(1));
    backend.vocab.topicsStub.returns(const [
      TopicDto(id: 'food', titleZh: '食物', count: 1),
    ]);

    await pumpApp(
      tester,
      backend: backend,
      child: const VocabListScreen(
        topic: 'food',
        onlyIntroduced: false,
        onlyStarred: false,
      ),
    );

    expect(find.text('食物'), findsOneWidget);
  });

  testWidgets('320 寬、字級 2.0 倍不溢位', (tester) async {
    final backend = _backendWith([
      wordAt(1, lessonId: 'le.l05', known: true, starred: true),
    ]);

    await pumpApp(
      tester,
      backend: backend,
      child: _screen,
      width: 320,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(VocabRow), findsOneWidget);
  });
}

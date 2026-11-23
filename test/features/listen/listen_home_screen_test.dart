import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/app_text.dart';
import 'package:japanese_learn_app/features/listen/listen_home_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

TaskDto _listenTask({bool done = false}) =>
    TaskDto.listen(key: 'listen', sentences: 6, minutes: 2, done: done);

void main() {
  testWidgets('一定有語音示範與對話入口', (tester) async {
    await pumpApp(tester, child: const ListenHomeScreen());

    expect(find.text('聽說'), findsOneWidget);
    expect(find.text('語音示範'), findsOneWidget);
    expect(find.text('對話'), findsOneWidget);
  });

  // 專區已移除（RULINGS O13）：p0 內容、進度過了 L21 也只有「練習」一區。
  testWidgets('沒有專區區塊，看不到日劇與歌曲專區的入口', (tester) async {
    final backend = FakeBackend();
    backend.course.overviewStub.returns(
      const CourseOverviewDto(
        contentStage: ContentStage.p0,
        stages: [],
        lessons: [],
        currentLessonId: 'le.l22',
        notesAvailable: true,
      ),
    );
    backend.today.todayStub.returns(todayFixture(tasks: [_listenTask()]));

    await pumpApp(tester, backend: backend, child: const ListenHomeScreen());

    expect(find.text('今天的聽力'), findsOneWidget);
    expect(find.text('語音示範'), findsOneWidget);
    expect(find.text('對話'), findsOneWidget);
    expect(
      tester
          .widgetList<EyebrowText>(find.byType(EyebrowText))
          .map((e) => e.data),
      ['練習'],
    );
    for (final removed in ['專區', '日劇', '歌曲', '日文歌', '語音由裝置合成']) {
      expect(
        find.textContaining(removed, findRichText: true),
        findsNothing,
        reason: removed,
      );
    }
  });

  testWidgets('今天有聽力任務時出現入口', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(todayFixture(tasks: [_listenTask()]));

    await pumpApp(tester, backend: backend, child: const ListenHomeScreen());

    expect(find.text('今天的聽力'), findsOneWidget);
    expect(find.text('6 句，含跟讀'), findsOneWidget);
  });

  testWidgets('聽力任務做完就不顯示', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(
      todayFixture(tasks: [_listenTask(done: true)]),
    );

    await pumpApp(tester, backend: backend, child: const ListenHomeScreen());

    expect(find.text('今天的聽力'), findsNothing);
  });

  testWidgets('語音不可用時顯示橫幅', (tester) async {
    await pumpApp(
      tester,
      tts: FakeTtsEngine(
        availability: const TtsAvailability(TtsAvailabilityKind.engineMissing),
      ),
      child: const ListenHomeScreen(),
    );

    expect(find.text('語音無法使用，聽力題暫時不出現'), findsOneWidget);
    expect(find.text('設定語音'), findsOneWidget);
  });

  testWidgets('無聲模式常駐橫幅', (tester) async {
    await pumpApp(
      tester,
      settings: settingsFixture(silentMode: true),
      child: const ListenHomeScreen(),
    );

    expect(find.textContaining('無聲模式'), findsOneWidget);
  });

  testWidgets('今日讀不到時入口還在，可重試', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.throws(const StorageFailure());

    await pumpApp(tester, backend: backend, child: const ListenHomeScreen());

    expect(find.text('語音示範'), findsOneWidget);
    expect(find.text('今天的聽力暫時讀不到'), findsOneWidget);

    backend.today.todayStub.returns(todayFixture(tasks: [_listenTask()]));
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('今天的聽力暫時讀不到'), findsNothing);
    expect(find.text('今天的聽力'), findsOneWidget);
  });

  testWidgets('互動目標符合無障礙準則', (tester) async {
    final handle = tester.ensureSemantics();

    await pumpApp(tester, child: const ListenHomeScreen());

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('字級放大 1.5 倍不破版', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(todayFixture(tasks: [_listenTask()]));

    await pumpApp(
      tester,
      backend: backend,
      width: 320,
      textScale: 1.5,
      child: const ListenHomeScreen(),
    );

    expect(tester.takeException(), isNull);
  });

  group('路由', () {
    testWidgets('語音示範進 S2', (tester) async {
      final backend = FakeBackend();

      await pumpApp(tester, backend: backend, location: '/listen');
      await tester.tap(find.text('語音示範'));
      await tester.pumpAndSettle();

      expect(backend.listening.soundGroupsStub.calls, hasLength(1));
    });

    testWidgets('次層畫面可返回 S1', (tester) async {
      await pumpApp(tester, location: '/listen');
      await tester.tap(find.text('語音示範'));
      await tester.pumpAndSettle();
      expect(find.text('這一版還沒有語音示範。'), findsOneWidget);

      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(find.text('這一版還沒有語音示範。'), findsNothing);
      expect(find.text('對話'), findsOneWidget);
    });

    testWidgets('對話進 S3', (tester) async {
      final backend = FakeBackend();

      await pumpApp(tester, backend: backend, location: '/listen');
      await tester.tap(find.text('對話'));
      await tester.pumpAndSettle();

      expect(backend.listening.dialoguesStub.calls, hasLength(1));
    });
  });
}

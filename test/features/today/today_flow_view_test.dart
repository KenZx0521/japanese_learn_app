import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/core/tts/audio_available.dart';
import 'package:japanese_learn_app/core/tts/fake_tts_engine.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/stamp_overlay.dart';
import 'package:japanese_learn_app/features/today/done_view.dart';
import 'package:japanese_learn_app/features/today/expectation_view.dart';
import 'package:japanese_learn_app/features/today/flow/today_flow_view.dart';
import 'package:japanese_learn_app/features/today/today_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../quiz/quiz_fixtures.dart';
import 'today_flow_harness.dart';
import 'today_tasks.dart';

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.drills.gradeStub.returns(drillOk);
    backend.review.submitStub.returns(reviewOk());
    backend.vocab.detailStub.returns(vocabDetailFixture());
  });

  Future<ProviderContainer> pumpFlow(
    WidgetTester tester, {
    String? start,
    bool settle = true,
  }) => pumpApp(
    tester,
    backend: backend,
    location: AppRoutes.sessionToday(start: start),
    settle: settle,
  );

  group('Review', () {
    testWidgets('session_next 到 Done 才 complete_task，帶 key、ms、audio', (
      tester,
    ) async {
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      backend.review.nextStub.answers((_) {
        final calls = backend.review.nextStub.calls.length;
        return calls == 1 ? cardNext() : const SessionNextDto.done();
      });
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [reviewTask(done: true)]),
      );

      await pumpFlow(tester, start: 'review');

      await tapText(tester, '貓');
      expect(backend.today.completeTaskStub.calls, isEmpty);
      await tapText(tester, '繼續');

      final close = backend.today.completeTaskStub.calls.single;
      expect(close[0], 'review');
      expect(close[1], isA<int>());
      expect(close[2], isTrue);
      expect(find.byType(DoneView), findsOneWidget);
    });

    testWidgets('用 T2 的 seed 取卡，不另外讀今日資料，顯示剩餘張數', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      backend.review.nextStub.returns(cardNext());

      await pumpFlow(tester);

      expect(backend.review.nextStub.calls.single, [
        sessionSeed('2026-03-02'),
        true,
      ]);
      expect(backend.today.todayStub.calls, hasLength(1));
      expect(find.text('還有約 1 張'), findsOneWidget);
    });

    testWidgets('session_next 失敗時可重試，不結案', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      backend.review.nextStub.throws(const StorageFailure());

      await pumpFlow(tester);
      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.review.nextStub.returns(const SessionNextDto.done());
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [reviewTask(done: true)]),
      );
      await tapText(tester, '重試');

      expect(backend.today.completeTaskStub.calls, hasLength(1));
    });
  });

  group('任務列與流程', () {
    testWidgets('過場：顯示下一項，按繼續才換元件', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(), drillTask()]),
      );
      backend.review.nextStub.returns(const SessionNextDto.done());
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [reviewTask(done: true), drillTask()]),
      );
      backend.drills.sessionStub.returns([choiceQuestion()]);

      await pumpFlow(tester);

      expect(find.text('下一項'), findsOneWidget);
      expect(find.text('句型演練 3 分鐘'), findsOneWidget);
      expect(find.byType(StampOverlay), findsOneWidget);
      expect(backend.drills.sessionStub.calls, isEmpty);

      await tapText(tester, '繼續');

      expect(backend.drills.sessionStub.calls, hasLength(1));
      final filter =
          backend.drills.sessionStub.calls.single.first! as DrillFilterDto;
      expect(filter.taskKey, 'drill');
      expect(filter.count, 5);
    });

    testWidgets('過場的今天先到這回 T1，不呼叫後面的任務', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(), drillTask()]),
      );
      backend.review.nextStub.returns(const SessionNextDto.done());
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [reviewTask(done: true), drillTask()]),
      );

      await pumpFlow(tester);
      await tapText(tester, '今天先到這');

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(backend.drills.sessionStub.calls, isEmpty);
    });

    testWidgets('取題為空時略過，不 complete_task', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [listenTask(), drillTask()]),
      );
      backend.today.listenSessionStub.returns(const []);
      backend.drills.sessionStub.returns([choiceQuestion()]);

      await pumpFlow(tester);

      expect(backend.today.completeTaskStub.calls, isEmpty);
      expect(find.text('下一項'), findsOneWidget);
      expect(find.text('句型演練 3 分鐘'), findsOneWidget);
    });

    testWidgets('清單跑完 learning_tail > 0 時跑收尾，不再 complete_task', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask()], learningTail: 1),
      );
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [reviewTask(done: true)], learningTail: 1),
      );
      var round = 0;
      backend.review.nextStub.answers((_) {
        round++;
        return round == 1
            ? const SessionNextDto.done()
            : round == 2
            ? cardNext()
            : const SessionNextDto.done();
      });

      await pumpFlow(tester);
      await tapText(tester, '貓');
      await tapText(tester, '繼續');

      expect(backend.today.completeTaskStub.calls, hasLength(1));
      expect(find.byType(DoneView), findsOneWidget);
    });

    testWidgets('全部 done 且 tail > 0 時直接收尾', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(done: true)], learningTail: 2),
      );
      backend.review.nextStub.returns(const SessionNextDto.done());

      await pumpFlow(tester);

      expect(backend.today.completeTaskStub.calls, isEmpty);
      expect(find.byType(DoneView), findsOneWidget);
    });

    testWidgets('complete_task 失敗留在原地，重試帶同一耗時', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      backend.review.nextStub.returns(const SessionNextDto.done());
      backend.today.completeTaskStub.throws(const StorageFailure());

      await pumpFlow(tester);
      expect(find.byType(ErrorSlip), findsOneWidget);
      final first = backend.today.completeTaskStub.calls.single;

      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [reviewTask(done: true)]),
      );
      await tapText(tester, '重試');

      expect(backend.today.completeTaskStub.calls.last[1], first[1]);
      expect(find.byType(DoneView), findsOneWidget);
    });

    testWidgets('今日資料載入失敗可重試', (tester) async {
      backend.today.todayStub.throws(const StorageFailure());

      await pumpFlow(tester);
      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      backend.review.nextStub.gate = Completer<void>().future;
      await tester.tap(find.text('重試'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ErrorSlip), findsNothing);
      expect(backend.review.nextStub.calls, hasLength(1));
    });

    testWidgets('單項載入失敗可略過，其餘繼續', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [drillTask(), listenTask()]),
      );
      backend.drills.sessionStub.throws(const StorageFailure());
      backend.today.listenSessionStub.returns([choiceQuestion()]);

      await pumpFlow(tester);
      await tapText(tester, '略過這一項');

      expect(backend.today.completeTaskStub.calls, isEmpty);
      expect(find.textContaining('聽力'), findsOneWidget);
    });

    testWidgets('沒有要做的任務時不蓋章，可回 T1', (tester) async {
      await pumpFlow(tester);

      expect(find.text('現在沒有要做的任務。'), findsOneWidget);
      expect(find.byType(StampOverlay), findsNothing);
      await tapText(tester, '回到今日');
      expect(find.byType(TodayScreen), findsOneWidget);
    });
  });

  group('O6 誠實預期', () {
    Future<void> setUpFirstRun() async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [newContentTask(), drillTask()]),
      );
      backend.today.newContentStub.returns(kanaSession());
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [newContentTask(done: true), drillTask()]),
      );
      backend.firstRunMarker.flag = true;
    }

    testWidgets('旗標存在時第一個 NewContent 結案後出現，看完刪旗標再接下一項', (tester) async {
      await setUpFirstRun();

      await pumpFlow(tester, start: 'new:le.k01:0');
      await tapText(tester, '下一步');

      expect(find.byType(ExpectationView), findsOneWidget);
      expect(find.text('這一版涵蓋假名與入門七課。'), findsOneWidget);
      expect(find.text('下一項'), findsNothing);

      await tapText(tester, '知道了，繼續');

      expect(backend.firstRunMarker.flag, isFalse);
      expect(find.byType(ExpectationView), findsNothing);
      expect(find.text('下一項'), findsOneWidget);
    });

    testWidgets('沒有旗標時不出現', (tester) async {
      await setUpFirstRun();
      backend.firstRunMarker.flag = false;

      await pumpFlow(tester, start: 'new:le.k01:0');
      await tapText(tester, '下一步');

      expect(find.byType(ExpectationView), findsNothing);
      expect(find.text('下一項'), findsOneWidget);
    });

    testWidgets('O6 文案不提 N4 與看懂日劇（P0a）', (tester) async {
      await setUpFirstRun();

      await pumpFlow(tester, start: 'new:le.k01:0');
      await tapText(tester, '下一步');

      for (final banned in ['N4', '看懂日劇', '聽懂日劇']) {
        expect(find.textContaining(banned), findsNothing);
      }
    });

    testWidgets('O6 文案依 p0：本版到 L30、參考 N5，不提 N4 與 L31 以後', (tester) async {
      await setUpFirstRun();
      backend.course.overviewStub.returns(
        courseOverviewFixture(contentStage: ContentStage.p0),
      );

      await pumpFlow(tester, start: 'new:le.k01:0');
      await tapText(tester, '下一步');

      expect(find.text('本版到 L30，涵蓋參考 N5 範圍。'), findsOneWidget);
      expect(find.textContaining('開始讀懂朋友間的常體'), findsOneWidget);
      expect(find.textContaining('不評分發音'), findsOneWidget);
      for (final banned in ['入門七課', 'N4', 'L48', 'L31', '完整版']) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });

    testWidgets('Review 結案不觸發 O6', (tester) async {
      backend.firstRunMarker.flag = true;
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      backend.review.nextStub.returns(const SessionNextDto.done());
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [reviewTask(done: true)]),
      );

      await pumpFlow(tester);

      expect(find.byType(ExpectationView), findsNothing);
      expect(find.byType(DoneView), findsOneWidget);
    });
  });

  group('T3 完成頁', () {
    Future<void> pumpDone(WidgetTester tester) => pumpApp(
      tester,
      backend: backend,
      location: AppRoutes.sessionDone,
    ).then((_) {});

    testWidgets('蓋章、本週已學天數與今日數據', (tester) async {
      backend.today.todayStub.returns(todayFixture(canLearnMore: true));
      backend.plan.calendarStub.returns(const [
        CalendarDayDto(
          date: '2026-03-02',
          isStudyDay: true,
          isActive: true,
          lessonIds: [],
        ),
      ]);
      backend.plan.activityStub.returns(const [
        DayActivityDto(
          date: '2026-03-02',
          answers: 24,
          lessons: 1,
          studyMinutes: 12.5,
        ),
      ]);

      await pumpDone(tester);

      expect(
        tester.widget<StampOverlay>(find.byType(StampOverlay)).play,
        isTrue,
      );
      expect(find.text('本週已學 1 天'), findsOneWidget);
      expect(find.text('今天學了 13 分鐘，答了 24 題'), findsOneWidget);
      expect(backend.plan.activityStub.calls.single, [
        '2026-03-02',
        '2026-03-02',
      ]);
    });

    testWidgets('T3 學不到 1 分鐘時不顯示小數（裁決 U6）', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [newContentTask(done: true)]),
      );
      backend.plan.activityStub.returns(const [
        DayActivityDto(
          date: '2026-03-02',
          answers: 3,
          lessons: 0,
          studyMinutes: 0.2,
        ),
      ]);

      await pumpDone(tester);

      expect(find.text('今天學了 不到 1 分鐘，答了 3 題'), findsOneWidget);
      expect(find.textContaining('0.2'), findsNothing);
    });

    testWidgets('再學一批：learn_more 後帶新 key 重進 T2', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [newContentTask(done: true)], canLearnMore: true),
      );
      backend.today.learnMoreStub.returns(
        todayFixture(
          tasks: [
            newContentTask(done: true),
            newContentTask(key: 'new:2'),
          ],
        ),
      );
      backend.today.newContentStub.gate = Completer<void>().future;

      await pumpDone(tester);
      await tapText(tester, '再學一批');

      expect(backend.today.learnMoreStub.calls.single, [true]);
      expect(find.byType(TodayFlowView), findsOneWidget);
      expect(
        tester.widget<TodayFlowView>(find.byType(TodayFlowView)).start,
        'new:2',
      );
    });

    testWidgets('再學一批失敗時留在 T3 並可重試', (tester) async {
      backend.today.todayStub.returns(todayFixture(canLearnMore: true));
      backend.today.learnMoreStub.throws(const InvalidInputFailure());

      await pumpDone(tester);
      await tapText(tester, '再學一批');

      expect(find.byType(ErrorSlip), findsOneWidget);
      expect(find.byType(DoneView), findsOneWidget);
    });

    testWidgets('活動資料讀不到時仍顯示完成', (tester) async {
      backend.today.todayStub.returns(todayFixture());
      backend.plan.activityStub.throws(const StorageFailure());
      backend.plan.calendarStub.throws(const StorageFailure());

      await pumpDone(tester);

      expect(find.text('今天完成了'), findsOneWidget);
      expect(find.byType(ErrorSlip), findsNothing);
    });

    testWidgets('reduced motion 時蓋章仍播完（淡入）', (tester) async {
      backend.today.todayStub.returns(todayFixture());

      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionDone,
        disableAnimations: true,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('今天完成了'), findsWidgets);
    });

    testWidgets('回到今日', (tester) async {
      backend.today.todayStub.returns(todayFixture());

      await pumpDone(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tapText(tester, '回到今日');

      expect(find.byType(TodayScreen), findsOneWidget);
    });
  });

  group('T1 再學一批', () {
    testWidgets('全部完成的 T1 按再學一批進 T2', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(done: true)], canLearnMore: true),
      );
      backend.today.learnMoreStub.returns(
        todayFixture(
          tasks: [
            reviewTask(done: true),
            newContentTask(key: 'new:2'),
          ],
        ),
      );
      backend.today.newContentStub.gate = Completer<void>().future;

      await pumpApp(tester, backend: backend);
      await tapText(tester, '再學一批');

      expect(
        tester.widget<TodayFlowView>(find.byType(TodayFlowView)).start,
        'new:2',
      );
    });
  });

  group('語音閘門與無聲模式（§6.6）', () {
    testWidgets('無聲模式時 audio_available = false 傳給所有函式', (tester) async {
      backend.settings.current = settingsFixture(silentMode: true);
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(), newContentTask()]),
      );
      backend.review.nextStub.returns(const SessionNextDto.done());
      backend.today.newContentStub.returns(kanaSession());
      backend.today.completeTaskStub.answers((args) {
        return args.first == 'review'
            ? todayFixture(tasks: [reviewTask(done: true), newContentTask()])
            : todayFixture(
                tasks: [reviewTask(done: true), newContentTask(done: true)],
              );
      });

      await pumpFlow(tester);
      await tapText(tester, '繼續');
      await tapText(tester, '下一步');

      expect(backend.today.todayStub.calls.first, [false]);
      expect(backend.review.nextStub.calls.first.last, isFalse);
      expect(backend.today.newContentStub.calls.first.last, isFalse);
      for (final call in backend.today.completeTaskStub.calls) {
        expect(call.last, isFalse);
      }
    });

    testWidgets('探測完成前 T2 收不到 today_view', (tester) async {
      final probe = Completer<void>();
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      backend.review.nextStub.gate = Completer<void>().future;

      await pumpApp(
        tester,
        backend: backend,
        tts: FakeTtsEngine(probeGate: probe.future),
        location: AppRoutes.sessionToday(),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(backend.today.todayStub.calls, isEmpty);
      probe.complete();
      await tester.pump();
      await tester.pump();
      expect(backend.today.todayStub.calls.single, [true]);
    });

    testWidgets('中途切到無聲模式：同 seed 重取今日與當前任務', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [newContentTask()]));
      backend.today.newContentStub.returns(kanaSession());

      final container = await pumpFlow(tester, start: 'new:le.k01:0');

      await container
          .read(settingsProvider.notifier)
          .patch(settingsPatch(silentMode: true));
      await tester.pumpAndSettle();

      expect(container.read(audioAvailableProvider), isFalse);
      expect(backend.today.todayStub.calls.last, [false]);
      final calls = backend.today.newContentStub.calls;
      expect(calls.first[1], calls.last[1]);
      expect(calls.last.last, isFalse);
    });
  });

  group('語音改變時同 seed 重取', () {
    testWidgets('複習中切到無聲模式', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      backend.review.nextStub.returns(cardNext());

      final container = await pumpFlow(tester);
      await container
          .read(settingsProvider.notifier)
          .patch(settingsPatch(silentMode: true));
      await tester.pumpAndSettle();

      final calls = backend.review.nextStub.calls;
      expect(calls, hasLength(greaterThan(1)));
      expect(calls.last[0], calls.first[0]);
      expect(calls.last[1], isFalse);
    });

    testWidgets('聽力中切到無聲模式', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [listenTask()]));
      backend.today.listenSessionStub.returns([choiceQuestion()]);

      final container = await pumpFlow(tester);
      await container
          .read(settingsProvider.notifier)
          .patch(settingsPatch(silentMode: true));
      await tester.pumpAndSettle();

      final calls = backend.today.listenSessionStub.calls;
      expect(calls, hasLength(greaterThan(1)));
      expect(calls.last[1], calls.first[1]);
      expect(calls.last.last, isFalse);
    });
  });

  group('離開與續做', () {
    testWidgets('今天先到這回 T1 顯示繼續，不結案', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [newContentTask()]));
      backend.today.newContentStub.returns(kanaSession());

      await pumpFlow(tester, start: 'new:le.k01:0');
      await tester.tap(find.text('今天先到這'));
      await tester.pumpAndSettle();

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('繼續'), findsOneWidget);
      expect(backend.today.completeTaskStub.calls, isEmpty);
    });

    testWidgets('Esc 等同離開', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [newContentTask()]));
      backend.today.newContentStub.returns(kanaSession());

      await pumpFlow(tester, start: 'new:le.k01:0');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(TodayScreen), findsOneWidget);
    });
  });

  group('版面', () {
    testWidgets('T3 在 320 寬、1.5 倍字級不溢位', (tester) async {
      backend.today.todayStub.returns(todayFixture(canLearnMore: true));

      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionDone,
        width: 320,
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('過場在 320 寬、1.5 倍字級不溢位', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(), drillTask()]),
      );
      backend.review.nextStub.returns(const SessionNextDto.done());
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [reviewTask(done: true), drillTask()]),
      );

      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
        width: 320,
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('L3 的教學卡在 320 寬、1.5 倍字級不溢位', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [newContentTask()]));
      backend.today.newContentStub.returns(kanaSession());

      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(start: 'new:le.k01:0'),
        width: 320,
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('互動目標 ≥48dp', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(), drillTask()]),
      );
      backend.review.nextStub.returns(const SessionNextDto.done());
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [reviewTask(done: true), drillTask()]),
      );

      await pumpFlow(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  testWidgets('T3 按回到今日後路由是 /today', (tester) async {
    backend.today.todayStub.returns(todayFixture());
    await pumpApp(tester, backend: backend, location: AppRoutes.sessionDone);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tapText(tester, '回到今日');

    final router = GoRouter.of(tester.element(find.byType(TodayScreen)));
    expect(router.state.matchedLocation, '/today');
  });
}

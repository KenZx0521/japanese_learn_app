// T1／T2／T3 之間的回歸：資料過期、換日、略過的結尾、鍵盤與語音收尾。
import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/tts/fake_tts_engine.dart';
import 'package:japanese_learn_app/core/tts/audio_available.dart';
import 'package:japanese_learn_app/core/tts/tts_controller.dart';
import 'package:japanese_learn_app/core/tts/tts_engine.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/stamp_overlay.dart';
import 'package:japanese_learn_app/features/today/done_view.dart';
import 'package:japanese_learn_app/features/today/today_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../quiz/quiz_fixtures.dart';
import 'today_flow_harness.dart';
import 'today_tasks.dart';

CalendarDayDto _day(String date, {required bool active}) => CalendarDayDto(
  date: date,
  isStudyDay: true,
  isActive: active,
  lessonIds: const [],
);

SessionNextDto _card(QuestionDto question) => SessionNextDto.card(
  card: SessionCardDto(
    cardId: 'vo.neko:produce',
    expectedReps: 0,
    facet: 'produce',
    question: question,
    ratingPreviews: const [],
    remainingEstimate: 1,
  ),
);

Future<void> _settleTransition(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  group('本週已學天數（SA-02）', () {
    testWidgets('完成唯一任務後 T3 與回到的 T1 都算進今天', (tester) async {
      final backend = FakeBackend();
      var studied = false;
      backend.today.todayStub.answers(
        (_) => todayFixture(tasks: [reviewTask(done: studied)]),
      );
      backend.plan.calendarStub.answers(
        (_) => [_day('2026-03-02', active: studied)],
      );
      backend.today.completeTaskStub.answers((_) {
        studied = true;
        return todayFixture(tasks: [reviewTask(done: true)]);
      });
      await pumpApp(tester, backend: backend);
      expect(find.textContaining('本週已學 0 天'), findsOneWidget);

      await tester.tap(find.text('開始').first);
      await _settleTransition(tester);

      expect(find.byType(DoneView), findsOneWidget);
      expect(find.text('本週已學 1 天'), findsOneWidget);

      await tester.tap(find.text('回到今日'));
      await tester.pumpAndSettle();
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.textContaining('本週已學 1 天'), findsOneWidget);
    });
  });

  group('回到 T1 重新取資料（SA-06）', () {
    testWidgets('系統返回鍵離開 T2 後，已完成的任務不再顯示「開始」', (tester) async {
      final backend = FakeBackend();
      var doneFirst = false;
      backend.today.todayStub.answers(
        (_) => todayFixture(
          tasks: [
            reviewTask(done: doneFirst),
            drillTask(),
          ],
        ),
      );
      backend.drills.sessionStub.returns([choiceQuestion()]);
      backend.today.completeTaskStub.answers((_) {
        doneFirst = true;
        return todayFixture(tasks: [reviewTask(done: true), drillTask()]);
      });
      await pumpApp(tester, backend: backend);
      await tester.tap(find.text('開始').first);
      await _settleTransition(tester);
      expect(find.text('這一項完成了。'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(HankoBadge), findsOneWidget);
    });

    testWidgets('聽說分頁回來時今天的聽力入口跟著更新', (tester) async {
      final backend = FakeBackend();
      var listenDone = false;
      backend.today.todayStub.answers(
        (_) => todayFixture(tasks: [listenTask(done: listenDone)]),
      );
      final container = await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.listen,
      );
      expect(find.text('今天的聽力'), findsOneWidget);

      unawaited(container.read(appRouterProvider).push(AppRoutes.planAbout));
      await tester.pumpAndSettle();
      listenDone = true;
      container.read(appRouterProvider).pop();
      await tester.pumpAndSettle();

      expect(find.text('今天的聽力'), findsNothing);
    });
  });

  group('換日（SA-04）', () {
    testWidgets('回前景發現換日：停止舊任務並提示回到今日', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [drillTask()]));
      backend.drills.sessionStub.returns([choiceQuestion()]);
      final container = await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(start: 'drill'),
      );
      expect(find.text('貓'), findsOneWidget);

      backend.today.todayStub.returns(
        todayFixture(logicalDate: '2026-03-03', tasks: [drillTask()]),
      );
      container.read(resumeTickProvider.notifier).bump();
      await tester.pumpAndSettle();

      expect(find.text('日期已經換了。'), findsOneWidget);
      expect(find.text('貓'), findsNothing);
      await tapText(tester, '回到今日');
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(backend.today.completeTaskStub.calls, isEmpty);
    });

    testWidgets('回前景還是同一天：作答不受影響', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [drillTask()]));
      backend.drills.sessionStub.returns([choiceQuestion()]);
      final container = await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(start: 'drill'),
      );

      container.read(resumeTickProvider.notifier).bump();
      await tester.pumpAndSettle();

      expect(find.text('貓'), findsOneWidget);
      expect(find.text('日期已經換了。'), findsNothing);
    });

    testWidgets('語音改變時若同時換日，走換日提示', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [drillTask()]));
      backend.drills.sessionStub.returns([choiceQuestion()]);
      final tts = FakeTtsEngine();
      final container = await pumpApp(
        tester,
        backend: backend,
        tts: tts,
        location: AppRoutes.sessionToday(start: 'drill'),
      );

      backend.today.todayStub.returns(
        todayFixture(logicalDate: '2026-03-03', tasks: [drillTask()]),
      );
      tts.availability = const TtsAvailability(
        TtsAvailabilityKind.engineMissing,
      );
      await container.read(ttsAvailabilityProvider.notifier).reprobe();
      await tester.pumpAndSettle();

      expect(find.text('日期已經換了。'), findsOneWidget);
    });
  });

  group('complete_task 回 NotFound（rust.F8）', () {
    testWidgets('重新載入今日並離開任務，不卡在重試', (tester) async {
      final backend = FakeBackend();
      var refreshed = false;
      backend.today.todayStub.answers(
        (_) => todayFixture(tasks: [if (!refreshed) reviewTask(), drillTask()]),
      );
      backend.today.completeTaskStub.answers((_) {
        refreshed = true;
        throw const NotFoundFailure();
      });
      backend.drills.sessionStub.returns([choiceQuestion()]);
      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
      );
      await _settleTransition(tester);

      expect(find.byType(ErrorSlip), findsNothing);
      expect(find.text('貓'), findsOneWidget);
    });
  });

  group('略過不是完成（SA-07）', () {
    testWidgets('略過後的過場寫「先略過」，不蓋章', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(
        todayFixture(tasks: [newContentTask(), drillTask()]),
      );
      backend.today.newContentStub.throws(const StorageFailure());
      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
      );

      await tapText(tester, '略過這一項');

      expect(find.text('這一項先略過。'), findsOneWidget);
      expect(find.text('這一項完成了。'), findsNothing);
      expect(find.byType(StampOverlay), findsNothing);
      expect(backend.today.completeTaskStub.calls, isEmpty);
    });

    testWidgets('略過最後一項不進完成頁', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [newContentTask()]));
      backend.today.newContentStub.throws(const StorageFailure());
      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
      );

      await tapText(tester, '略過這一項');

      expect(find.byType(DoneView), findsNothing);
      expect(find.text('今天完成了'), findsNothing);
      expect(find.text('今天有項目沒做完。'), findsOneWidget);
      await tapText(tester, '回到今日');
      expect(find.byType(TodayScreen), findsOneWidget);
    });
  });

  group('鍵盤焦點（SA-05）', () {
    testWidgets('打字題自動取得焦點並叫出鍵盤', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [drillTask()]));
      backend.drills.sessionStub.returns([typingQuestion()]);
      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final edit = tester.widget<EditableText>(find.byType(EditableText));
      expect(edit.focusNode.hasPrimaryFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('自評題空白鍵翻面', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      backend.review.nextStub.returns(_card(selfGradeQuestion()));
      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.text('記得'), findsOneWidget);
    });

    testWidgets('回饋條 Enter 前進', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [drillTask()]));
      backend.drills.sessionStub.returns([choiceQuestion()]);
      backend.drills.gradeStub.returns(drillOk);
      await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('貓').first);
      await tester.pumpAndSettle();
      expect(find.text('繼續'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(backend.today.completeTaskStub.calls, hasLength(1));
    });

    testWidgets('上層有別的路由時 Esc 不離開 T2', (tester) async {
      final backend = FakeBackend();
      backend.today.todayStub.returns(todayFixture(tasks: [drillTask()]));
      backend.drills.sessionStub.returns([choiceQuestion()]);
      final container = await pumpApp(
        tester,
        backend: backend,
        location: AppRoutes.sessionToday(),
      );
      unawaited(container.read(appRouterProvider).push(AppRoutes.planAbout));
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      final before = router.state.uri.toString();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), before);
    });
  });

  testWidgets('教學卡自動播放中離開 T2 會停止語音（SA-10）', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(todayFixture(tasks: [newContentTask()]));
    backend.today.newContentStub.returns(kanaSession());
    final tts = FakeTtsEngine(autoComplete: false);
    final container = await pumpApp(
      tester,
      backend: backend,
      tts: tts,
      location: AppRoutes.sessionToday(),
      settings: settingsFixture(autoplay: true),
      settle: false,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(ttsControllerProvider), isA<TtsSpeaking>());

    await tester.tap(find.text('今天先到這').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(container.read(ttsControllerProvider), isA<TtsIdle>());
  });
}

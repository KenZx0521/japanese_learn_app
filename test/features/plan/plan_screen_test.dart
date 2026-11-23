import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/milestone_rail.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/features/plan/plan_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';
import 'plan_fixtures.dart';

void main() {
  FakeBackend backendWith({
    PlanViewDto? view,
    CourseOverviewDto? course,
    List<CalendarDayDto>? calendar,
  }) {
    final backend = FakeBackend();
    backend.plan.viewStub.returns(view ?? planView());
    backend.course.overviewStub.returns(course ?? overview());
    backend.plan.calendarStub.returns(calendar ?? fourWeeks());
    return backend;
  }

  Finder richText(String text) => find.text(text, findRichText: true);

  group('狀態', () {
    testWidgets('載入超過 200ms 顯示骨架', (tester) async {
      final backend = backendWith();
      final gate = Future<void>.delayed(const Duration(seconds: 1));
      backend.plan.viewStub.gate = gate;
      await pumpApp(
        tester,
        backend: backend,
        child: const PlanScreen(),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(SkeletonLines), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(SkeletonLines), findsNothing);
    });

    testWidgets('失敗顯示 ErrorSlip，重試後恢復', (tester) async {
      final backend = backendWith();
      backend.plan.viewStub.throws(const StorageFailure());
      await pumpApp(tester, backend: backend, child: const PlanScreen());
      expect(find.byType(ErrorSlip), findsOneWidget);
      expect(find.textContaining('資料暫時寫不進去'), findsOneWidget);

      backend.plan.viewStub.returns(planView());
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorSlip), findsNothing);
      expect(find.text('目前位置'), findsOneWidget);
    });

    testWidgets('沒有計畫時導回新手引導', (tester) async {
      final backend = backendWith();
      backend.plan.viewStub.throws(const NoPlanFailure());
      final container = await pumpApp(
        tester,
        backend: backend,
        child: const PlanScreen(),
      );
      expect(container.read(onboardingDoneProvider).value, isFalse);
    });
  });

  group('里程碑線', () {
    testWidgets('點數等於已發布里程碑數，已達成蓋章', (tester) async {
      final backend = backendWith(
        view: planView(
          milestones: [
            milestone(id: 'ms.hira', passed: true, best: 90),
            milestone(id: 'ms.kata', title: '片假名'),
            milestone(id: 'ms.survive', title: '生存日語'),
          ],
        ),
      );
      await pumpApp(tester, backend: backend, child: const PlanScreen());

      final rail = tester.widget<MilestoneRail>(find.byType(MilestoneRail));
      expect(rail.milestones, hasLength(3));
      expect(
        find.descendant(
          of: find.byType(MilestoneRail),
          matching: find.byType(HankoBadge),
        ),
        findsOneWidget,
      );
    });

    testWidgets('點開顯示門檻、題數、最佳成績、粗估日與開始檢定', (tester) async {
      final backend = backendWith(
        view: planView(milestones: [milestone(best: 85)]),
      );
      await pumpApp(tester, backend: backend, child: const PlanScreen());

      await tester.tap(richText('平假名').first);
      await tester.pumpAndSettle();

      expect(find.text('建議門檻 80%'), findsOneWidget);
      expect(find.text('共 20 題'), findsOneWidget);
      expect(find.text('最佳成績 85%'), findsOneWidget);
      expect(find.text('預計 12/20（粗估）'), findsOneWidget);
      expect(find.text('開始檢定'), findsOneWidget);
    });

    testWidgets('略過的里程碑說明可隨時開始', (tester) async {
      final backend = backendWith(
        view: planView(milestones: [milestone(dismissed: true)]),
      );
      await pumpApp(tester, backend: backend, child: const PlanScreen());
      await tester.tap(richText('平假名').first);
      await tester.pumpAndSettle();
      expect(find.text('已略過，可隨時開始'), findsOneWidget);
      expect(find.text('尚未考過'), findsOneWidget);
    });

    testWidgets('開始檢定進入 D3 路由', (tester) async {
      final backend = backendWith(view: planView(milestones: [milestone()]));
      await pumpApp(tester, backend: backend, location: '/plan');
      await tester.tap(richText('平假名').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('開始檢定'));
      await tester.pumpAndSettle();
      expect(find.text('開始檢定'), findsNothing);
      expect(find.text('目前位置'), findsNothing);
    });
  });

  group('目前位置與完成日', () {
    testWidgets('顯示課次、課名與 p0a 的粗估完成日', (tester) async {
      await pumpApp(tester, backend: backendWith(), child: const PlanScreen());
      expect(find.text('第 3 課'), findsOneWidget);
      expect(richText('自我介紹'), findsOneWidget);
      expect(find.text('假名與入門七課約在 3/15 完成（粗估）'), findsOneWidget);
      expect(find.textContaining('專區'), findsNothing);
      expect(find.textContaining('N4'), findsNothing);
    });

    testWidgets('p0 顯示本版到 L30 的粗估完成日', (tester) async {
      final backend = backendWith(course: overview(stage: ContentStage.p0));
      await pumpApp(tester, backend: backend, child: const PlanScreen());
      expect(find.text('本版到 L30，約在 3/15 完成（粗估）'), findsOneWidget);
      expect(find.textContaining('專區'), findsNothing);
    });

    testWidgets('課程走完時顯示複習照常', (tester) async {
      final backend = backendWith(view: planView(current: null, mainEnd: null));
      await pumpApp(tester, backend: backend, child: const PlanScreen());
      expect(find.text('這一版的內容都學完了，複習照常'), findsOneWidget);
    });

    testWidgets('落後時一鍵套用建議分鐘，保留其他欄位', (tester) async {
      final current = planInput(minutes: 10, targetDate: '2027-01-31');
      final backend = backendWith(
        view: planView(
          status: PlanStatus.behind,
          suggested: 30,
          input: current,
        ),
      );
      backend.plan.updateStub.returns(planView(status: PlanStatus.onTrack));
      await pumpApp(tester, backend: backend, child: const PlanScreen());

      expect(find.textContaining('每天 30 分鐘'), findsWidgets);
      await tester.tap(find.text('改成每天 30 分鐘'));
      await tester.pumpAndSettle();

      final sent = backend.plan.updateStub.calls.single.single! as PlanInputDto;
      expect(sent.dailyMinutes, 30);
      expect(sent.targetDate, '2027-01-31');
      expect(sent.knownKanaLessons, ['le.k01']);
      expect(backend.plan.viewStub.calls.length, greaterThan(1));
    });

    testWidgets('落後且沒有建議時不給一鍵套用', (tester) async {
      final backend = backendWith(view: planView(status: PlanStatus.behind));
      await pumpApp(tester, backend: backend, child: const PlanScreen());
      expect(find.textContaining('趕不上目標日期'), findsOneWidget);
      expect(find.textContaining('改成每天'), findsNothing);
    });

    testWidgets('一鍵套用失敗時留在原頁並顯示訊息', (tester) async {
      final backend = backendWith(
        view: planView(status: PlanStatus.behind, suggested: 30),
      );
      backend.plan.updateStub.throws(const StorageFailure());
      await pumpApp(tester, backend: backend, child: const PlanScreen());
      await tester.tap(find.text('改成每天 30 分鐘'));
      await tester.pumpAndSettle();
      expect(find.textContaining('資料暫時寫不進去'), findsOneWidget);
    });
  });

  group('四週月曆', () {
    testWidgets('取四週，已學的日子蓋章，非學習日留白', (tester) async {
      final backend = backendWith(
        calendar: fourWeeks(activeOffsets: {0, 1}, restOffsets: {5, 6}),
      );
      await pumpApp(tester, backend: backend, child: const PlanScreen());

      expect(backend.plan.calendarStub.calls.single, [4]);
      expect(find.text('本週已學 2 天'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('11 月 2 日.*已學習')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('11 月 7 日')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('11 月 9 日.*學習日')), findsOneWidget);
    });

    testWidgets('休息日自由練習仍然蓋章', (tester) async {
      final backend = backendWith(
        calendar: fourWeeks(activeOffsets: {5}, restOffsets: {5}),
      );
      await pumpApp(tester, backend: backend, child: const PlanScreen());
      expect(find.bySemanticsLabel(RegExp('11 月 7 日.*已學習')), findsOneWidget);
    });

    testWidgets('今天的格子有語意標記', (tester) async {
      final now = DateTime.now().subtract(const Duration(hours: 4));
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final backend = backendWith(calendar: fourWeeks(monday: monday));
      await pumpApp(tester, backend: backend, child: const PlanScreen());
      expect(find.bySemanticsLabel(RegExp('今天')), findsOneWidget);
    });

    testWidgets('連續天數只用小字呈現', (tester) async {
      await pumpApp(tester, backend: backendWith(), child: const PlanScreen());
      expect(find.text('連續 3 天，最長 5 天'), findsOneWidget);
    });
  });

  group('統計與導覽', () {
    testWidgets('顯示累積數字', (tester) async {
      await pumpApp(tester, backend: backendWith(), child: const PlanScreen());
      await tester.scrollUntilVisible(find.text('累積複習'), 200);
      expect(find.bySemanticsLabel('熟練假名 10'), findsOneWidget);
      expect(find.bySemanticsLabel('認識單字 5'), findsOneWidget);
      expect(find.bySemanticsLabel('累積複習 42'), findsOneWidget);
    });

    testWidgets('關於程度進入 P2', (tester) async {
      final backend = backendWith();
      await pumpApp(tester, backend: backend, location: '/plan');
      await tester.scrollUntilVisible(find.text('這個程度能帶你到哪裡'), 200);
      await tester.tap(find.text('這個程度能帶你到哪裡'));
      await tester.pumpAndSettle();
      expect(find.text('關於程度'), findsOneWidget);
    });

    testWidgets('回到分頁時重新取得資料', (tester) async {
      final backend = backendWith();
      await pumpApp(tester, backend: backend, location: '/plan');
      final before = backend.plan.viewStub.calls.length;

      await tester.tap(find.bySemanticsLabel(RegExp('設定')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('計畫')).first);
      await tester.pumpAndSettle();

      expect(backend.plan.viewStub.calls.length, greaterThan(before));
    });
  });

  group('版面', () {
    for (final (width, scale) in [(320.0, 1.5), (320.0, 1.0), (768.0, 1.5)]) {
      testWidgets('寬 $width、字級 $scale 不溢位', (tester) async {
        final backend = backendWith(
          view: planView(
            status: PlanStatus.behind,
            suggested: 30,
            milestones: [
              milestone(passed: true),
              milestone(id: 'ms.kata', title: '片假名'),
              milestone(id: 'ms.survive', title: '生存日語'),
            ],
          ),
          course: overview(stage: ContentStage.p0),
          calendar: fourWeeks(activeOffsets: {0, 1, 2}, restOffsets: {6}),
        );
        await pumpApp(
          tester,
          backend: backend,
          child: const PlanScreen(),
          width: width,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('深色模式可渲染', (tester) async {
      await pumpApp(
        tester,
        backend: backendWith(),
        child: const PlanScreen(),
        dark: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('計畫'), findsOneWidget);
    });
  });
}

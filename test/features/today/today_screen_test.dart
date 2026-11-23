import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/features/today/flow/today_flow_view.dart';
import 'package:japanese_learn_app/features/today/today_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'today_tasks.dart';

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend());

  Future<void> pumpToday(WidgetTester tester, {FakeTtsEngine? tts}) async {
    await pumpApp(
      tester,
      backend: backend,
      tts: tts,
      child: const TodayScreen(),
    );
  }

  group('狀態', () {
    testWidgets('載入超過 200ms 顯示骨架', (tester) async {
      final gate = Completer<void>();
      backend.today.todayStub.gate = gate.future;

      await pumpApp(
        tester,
        backend: backend,
        child: const TodayScreen(),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SkeletonLines), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('探測完成前收不到 today_view', (tester) async {
      final probe = Completer<void>();
      final tts = FakeTtsEngine(probeGate: probe.future);

      await pumpApp(
        tester,
        backend: backend,
        tts: tts,
        child: const TodayScreen(),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(backend.today.todayStub.calls, isEmpty);
      probe.complete();
      await tester.pumpAndSettle();
      expect(backend.today.todayStub.calls.single, [true]);
    });

    testWidgets('錯誤時 ErrorSlip 可重試', (tester) async {
      backend.today.todayStub.throws(const StorageFailure());

      await pumpToday(tester);
      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorSlip), findsNothing);
      expect(find.textContaining('複習'), findsWidgets);
    });

    testWidgets('休息日顯示今天休息與下次學習日', (tester) async {
      backend.today.todayStub.returns(
        todayFixtureRest(nextStudyDate: '2026-03-04'),
      );

      await pumpToday(tester);

      expect(find.text('今天休息'), findsOneWidget);
      expect(find.textContaining('3/4'), findsOneWidget);
      expect(find.text('自由練習'), findsOneWidget);
    });

    testWidgets('學習日沒有任務時有空狀態與練習入口', (tester) async {
      await pumpToday(tester);

      expect(find.text('今天把學過的再練熟。'), findsOneWidget);
      expect(find.text('自由練習'), findsOneWidget);
    });
  });

  group('任務列', () {
    testWidgets('當前項有開始鈕，其餘只有列；第一列標出分鐘', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(
          tasks: [reviewTask(due: 16, learning: 2), newContentTask()],
        ),
      );

      await pumpToday(tester);

      expect(find.text('開始'), findsOneWidget);
      expect(find.text('18 張 · 2.5 分'), findsOneWidget);
      expect(find.text('3 字 · 6 分'), findsOneWidget);
    });

    testWidgets('已完成項蓋小章', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(done: true), newContentTask()]),
      );

      await pumpToday(tester);

      expect(find.byType(HankoBadge), findsOneWidget);
    });

    testWidgets('Checkpoint 用查回來的標題', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [checkpointTask()]));
      backend.plan.viewStub.returns(
        planViewFixture(milestones: [milestoneFixture(titleZh: '平假名畢業')]),
      );

      await pumpToday(tester);

      expect(find.text('平假名畢業'), findsOneWidget);
    });

    // integ F1：里程碑副標是內容的 title_zh，可能帶 {ja:} 標記，要走 MixedText。
    testWidgets('Checkpoint 標題的 {ja:} 標記不原樣露出', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [checkpointTask()]));
      backend.plan.viewStub.returns(
        planViewFixture(
          milestones: [milestoneFixture(titleZh: '數一數 {ja:〜てる}')],
        ),
      );

      await pumpToday(tester);

      expect(find.textContaining('{ja:', findRichText: true), findsNothing);
      expect(find.textContaining('數一數', findRichText: true), findsOneWidget);
      expect(find.textContaining('〜てる', findRichText: true), findsOneWidget);
    });

    testWidgets('全部 done 且 learning_tail > 0 時出現收尾列', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(done: true)], learningTail: 3),
      );

      await pumpToday(tester);

      expect(find.text('收尾'), findsOneWidget);
      expect(find.text('3 張'), findsOneWidget);
      expect(find.text('開始'), findsOneWidget);
    });

    testWidgets('recovery 文案與無聲模式常駐說明', (tester) async {
      backend.today.todayStub.returns(
        TodayViewDto(
          logicalDate: '2026-03-02',
          isStudyDay: true,
          tasks: [reviewTask()],
          budget: budgetFixture(),
          streak: 1,
          recoveryReason: RecoveryReason.returnAfterBreak,
          minimalNew: false,
          learningTail: 0,
          estimatedMinutes: 5,
          canLearnMore: false,
        ),
      );
      backend.settings.current = settingsFixture(silentMode: true);

      await pumpToday(tester);

      expect(find.text('歡迎回來。今天先複習，主線新內容暫停。'), findsOneWidget);
      expect(find.textContaining('無聲模式'), findsOneWidget);
    });

    // review_rc RC5：休息日清單是空的時，不叫人「今天先看完」。
    for (final (reason, copy) in [
      (RecoveryReason.unseenNewCards, '前幾天的新內容'),
      (RecoveryReason.returnAfterBreak, '歡迎回來'),
    ]) {
      testWidgets('休息日沒有任務時不顯示 $copy', (tester) async {
        backend.today.todayStub.returns(
          TodayViewDto(
            logicalDate: '2026-03-03',
            isStudyDay: false,
            tasks: [reviewTask(due: 0, learning: 0, done: true)],
            budget: budgetFixture(),
            streak: 1,
            recoveryReason: reason,
            minimalNew: false,
            learningTail: 0,
            estimatedMinutes: 0,
            canLearnMore: false,
          ),
        );

        await pumpToday(tester);

        expect(find.textContaining(copy), findsNothing);
        expect(find.textContaining('今天沒有排定的任務'), findsOneWidget);
      });
    }

    testWidgets('休息日還有複習可做時照常顯示受限文案', (tester) async {
      backend.today.todayStub.returns(
        TodayViewDto(
          logicalDate: '2026-03-03',
          isStudyDay: false,
          tasks: [reviewTask()],
          budget: budgetFixture(),
          streak: 1,
          recoveryReason: RecoveryReason.returnAfterBreak,
          minimalNew: false,
          learningTail: 0,
          estimatedMinutes: 5,
          canLearnMore: false,
        ),
      );

      await pumpToday(tester);

      expect(find.text('歡迎回來。今天先複習，主線新內容暫停。'), findsOneWidget);
    });

    // review_fc F3：積壓日照常列出檢定，文案不說「只複習」。
    testWidgets('積壓日的文案與照常列出的檢定一致', (tester) async {
      backend.today.todayStub.returns(
        TodayViewDto(
          logicalDate: '2026-03-02',
          isStudyDay: true,
          tasks: [reviewTask(), checkpointTask()],
          budget: budgetFixture(),
          streak: 1,
          recoveryReason: RecoveryReason.reviewBacklog,
          minimalNew: false,
          learningTail: 0,
          estimatedMinutes: 20,
          canLearnMore: false,
        ),
      );

      await pumpToday(tester);

      expect(find.text('複習累積了一些，今天的時間先給複習，主線新內容暫停。'), findsOneWidget);
      expect(find.textContaining('只複習'), findsNothing);
      expect(find.text('里程碑檢定'), findsOneWidget);
    });
  });

  group('全部完成', () {
    testWidgets('顯示完成章與再學一批', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(done: true)], canLearnMore: true),
      );

      await pumpToday(tester);

      expect(find.text('再學一批'), findsOneWidget);
      expect(find.text('不影響明天的安排'), findsOneWidget);
      expect(find.bySemanticsLabel('今天完成了'), findsOneWidget);
    });

    testWidgets('can_learn_more 為 false 時沒有再學一批', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(done: true)]),
      );

      await pumpToday(tester);

      expect(find.text('再學一批'), findsNothing);
    });
  });

  group('romaji 確認列（§3.7）', () {
    testWidgets('到 L09 且 ms.kata 未過時可收起', (tester) async {
      backend.plan.viewStub.returns(
        planViewFixture(
          currentLessonId: 'le.l09',
          milestones: [milestoneFixture(id: 'ms.kata', titleZh: '片假名')],
        ),
      );
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));

      await pumpToday(tester);

      expect(find.textContaining('片假名還沒考過'), findsOneWidget);
      await tester.tap(find.text('收起來'));
      await tester.pumpAndSettle();

      expect(backend.settings.current.romajiOffConfirmed, isTrue);
      expect(find.textContaining('片假名還沒考過'), findsNothing);
    });

    testWidgets('先留著之後本日不再問', (tester) async {
      backend.plan.viewStub.returns(
        planViewFixture(
          currentLessonId: 'le.l09',
          milestones: [milestoneFixture(id: 'ms.kata', titleZh: '片假名')],
        ),
      );
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));

      await pumpToday(tester);
      await tester.tap(find.text('先留著'));
      await tester.pumpAndSettle();

      expect(find.textContaining('片假名還沒考過'), findsNothing);
      expect(backend.settings.current.romajiOffConfirmed, isFalse);
    });

    testWidgets('L01 不顯示', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [reviewTask()]));

      await pumpToday(tester);

      expect(find.textContaining('片假名還沒考過'), findsNothing);
    });
  });

  group('導頁', () {
    testWidgets('按開始進 T2，帶該任務的 key', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [reviewTask(), newContentTask()]),
      );
      // 卡在取牌，留在 T2 才看得到
      final gate = Completer<void>();
      backend.review.nextStub.gate = gate.future;

      await pumpApp(tester, backend: backend);
      await tester.tap(find.text('開始'));
      await tester.pumpAndSettle();

      expect(find.byType(TodayFlowView), findsOneWidget);
      expect(
        tester.widget<TodayFlowView>(find.byType(TodayFlowView)).start,
        'review',
      );
    });

    testWidgets('NoPlan 導回引導', (tester) async {
      backend.today.todayStub.throws(const NoPlanFailure());

      final container = await pumpApp(tester, backend: backend);

      expect(container.read(onboardingDoneProvider).value, isFalse);
    });

    testWidgets('字級 1.5 倍 320 寬不溢位', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(
          tasks: [
            reviewTask(due: 16),
            newContentTask(titleZh: '很長的新內容名稱很長的新內容名稱'),
          ],
        ),
      );

      await pumpApp(
        tester,
        backend: backend,
        child: const TodayScreen(),
        width: 320,
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
    });
  });
}

TodayViewDto todayFixtureRest({required String nextStudyDate}) => TodayViewDto(
  logicalDate: '2026-03-02',
  isStudyDay: false,
  nextStudyDate: nextStudyDate,
  tasks: const [],
  budget: budgetFixture(),
  streak: 3,
  minimalNew: false,
  learningTail: 0,
  estimatedMinutes: 0,
  canLearnMore: false,
);

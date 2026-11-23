import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/tts/fake_tts_engine.dart';
import 'package:japanese_learn_app/design/widgets/censor_bar.dart';
import 'package:japanese_learn_app/design/widgets/kana_teach_card.dart';
import 'package:japanese_learn_app/features/dialogue/dialogue.dart';
import 'package:japanese_learn_app/features/listen/listen.dart';
import 'package:japanese_learn_app/features/today/done_view.dart';

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

  group('六種任務', () {
    testWidgets('NewContent：Kana 呈現 → complete_task', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [newContentTask()]));
      backend.today.newContentStub.returns(kanaSession());
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [newContentTask(done: true)]),
      );

      await pumpFlow(tester, start: 'new:le.k01:0');

      expect(find.byType(KanaTeachCard), findsOneWidget);
      final args = backend.today.newContentStub.calls.single;
      expect(args[0], 'new:le.k01:0');
      expect(args[1], sessionSeed('2026-03-02'));

      await tapText(tester, '下一步');
      expect(find.byType(DoneView), findsOneWidget);
    });

    testWidgets('Listen 用 listen_session，作答 grade_drill', (tester) async {
      backend.today.todayStub.returns(todayFixture(tasks: [listenTask()]));
      backend.today.listenSessionStub.returns([choiceQuestion()]);
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [listenTask(done: true)]),
      );

      await pumpFlow(tester);

      expect(find.byType(ListenSessionView), findsOneWidget);
      expect(backend.today.listenSessionStub.calls.single, [
        'listen',
        sessionSeed('2026-03-02'),
        true,
      ]);
      await tapText(tester, '貓');
      expect(backend.drills.gradeStub.calls, hasLength(1));
    });

    testWidgets('Listen 載入失敗可略過，不結案', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [listenTask(), drillTask()]),
      );
      backend.today.listenSessionStub.throws(const StorageFailure());

      await pumpFlow(tester);
      await tapText(tester, '略過這一項');

      expect(backend.today.completeTaskStub.calls, isEmpty);
      expect(find.text('句型演練 3 分鐘'), findsOneWidget);
    });

    testWidgets('Listen 沒語音且沒題目時說明原因，略過不結案', (tester) async {
      backend.settings.current = settingsFixture(silentMode: true);
      backend.today.todayStub.returns(
        todayFixture(tasks: [listenTask(), drillTask()]),
      );
      backend.today.listenSessionStub.returns(const []);

      await pumpFlow(tester);
      expect(find.text('現在沒有語音，聽力先略過。'), findsOneWidget);

      await tapText(tester, '略過這一項');

      expect(backend.today.completeTaskStub.calls, isEmpty);
      expect(find.text('句型演練 3 分鐘'), findsOneWidget);
    });

    testWidgets('Integration 沒有 dialogue_id 時跑 D2（lesson、count 10）', (
      tester,
    ) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [integrationTask(dialogueId: null)]),
      );
      backend.drills.sessionStub.returns([choiceQuestion()]);

      await pumpFlow(tester);

      final filter =
          backend.drills.sessionStub.calls.single.first! as DrillFilterDto;
      expect(filter.lessonId, 'le.l01');
      expect(filter.count, 10);
    });

    testWidgets('Integration 只跑排定的段落，用 S4 元件，跑完直接結案', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(
          tasks: [
            integrationTask(phases: const [2]),
          ],
        ),
      );
      backend.listening.dialogueStub.returns(flowDialogue());
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [integrationTask(done: true)]),
      );

      await pumpFlow(tester);

      expect(find.byType(DialogueRunner), findsOneWidget);
      expect(find.text('盲聽'), findsNothing);
      expect(find.text('逐詞'), findsOneWidget);
      expect(find.text('中文'), findsOneWidget);

      await tapText(tester, '完成這段');

      expect(backend.today.completeTaskStub.calls, hasLength(1));
      expect(find.byType(DoneView), findsOneWidget);
    });

    testWidgets('無聲模式略過盲聽段', (tester) async {
      backend.settings.current = settingsFixture(silentMode: true);
      backend.today.todayStub.returns(todayFixture(tasks: [integrationTask()]));
      backend.listening.dialogueStub.returns(flowDialogue());

      await pumpFlow(tester);

      expect(find.bySemanticsLabel(RegExp('盲聽，已略過')), findsOneWidget);
      expect(find.text('現在沒有語音，這一段只顯示文字。'), findsOneWidget);
    });

    testWidgets('盲聽：伏字條不放日文，連播全篇，接演練題並帶 T2 的 seed', (tester) async {
      final tts = FakeTtsEngine();
      backend.today.todayStub.returns(
        todayFixture(
          tasks: [
            integrationTask(phases: const [1]),
          ],
        ),
      );
      backend.listening.dialogueStub.returns(
        flowDialogue(quiz: const ['dr.1']),
      );
      backend.drills.sessionStub.returns([choiceQuestion()]);
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [integrationTask(done: true)]),
      );

      await pumpApp(
        tester,
        backend: backend,
        tts: tts,
        location: AppRoutes.sessionToday(),
        settle: false,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.textContaining('学生'), findsNothing);
      expect(find.byType(CensorBar), findsNWidgets(2));
      expect(tts.spoken, hasLength(2));

      await tapText(tester, '做題目');
      final call = backend.drills.sessionStub.calls.single;
      expect((call.first! as DrillFilterDto).drillIds, ['dr.1']);
      expect(call[1], sessionSeed('2026-03-02'));

      await tapText(tester, '貓');
      expect(backend.today.completeTaskStub.calls, isEmpty);
      await tapText(tester, '繼續');
      expect(backend.today.completeTaskStub.calls, hasLength(1));
    });

    testWidgets('角色扮演走完才結案，且只結案一次', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(
          tasks: [
            integrationTask(phases: const [4]),
          ],
        ),
      );
      backend.listening.dialogueStub.returns(flowDialogue());
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [integrationTask(done: true)]),
      );

      await pumpApp(
        tester,
        backend: backend,
        tts: FakeTtsEngine(autoComplete: false),
        location: AppRoutes.sessionToday(),
        disableAnimations: true,
      );
      expect(find.text('選一個角色，輪到你時開口說。'), findsOneWidget);

      await tester.tap(find.text('小明'));
      await tester.pump();
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('下一句'));
        await tester.pump();
        await tester.pumpAndSettle();
      }
      expect(backend.today.completeTaskStub.calls, isEmpty);

      await tester.tap(find.text('完成這段'));
      await tester.pumpAndSettle();

      expect(backend.today.completeTaskStub.calls, hasLength(1));
      expect(find.byType(DoneView), findsOneWidget);
    });

    testWidgets('對話載入失敗可略過', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [integrationTask(), drillTask()]),
      );
      backend.listening.dialogueStub.throws(const NotFoundFailure());

      await pumpFlow(tester);
      await tapText(tester, '略過這一項');

      expect(backend.today.completeTaskStub.calls, isEmpty);
    });

    testWidgets('Checkpoint：先略過用 checkpoint_dismiss，接下一項', (tester) async {
      backend.today.todayStub.returns(
        todayFixture(tasks: [checkpointTask(), drillTask()]),
      );
      backend.drills.checkpointStartStub.returns([choiceQuestion()]);
      backend.drills.checkpointDismissStub.returns(
        todayFixture(tasks: [drillTask()]),
      );
      backend.plan.viewStub.returns(
        planViewFixture(milestones: [milestoneFixture(titleZh: '平假名畢業')]),
      );

      await pumpFlow(tester);
      expect(find.text('平假名畢業'), findsOneWidget);

      await tapText(tester, '先略過');

      expect(backend.drills.checkpointDismissStub.calls.single, [
        'ms.hira',
        true,
      ]);
      expect(backend.today.completeTaskStub.calls, isEmpty);
      expect(find.text('下一項'), findsOneWidget);
    });

    testWidgets('Checkpoint 作答：checkpoint_finish 後才 complete_task', (
      tester,
    ) async {
      backend.today.todayStub.returns(todayFixture(tasks: [checkpointTask()]));
      backend.drills.checkpointStartStub.returns([choiceQuestion()]);
      backend.drills.checkpointFinishStub.returns(
        const CheckpointResultDto(
          milestoneId: 'ms.hira',
          correct: 1,
          total: 1,
          scorePercent: 100,
          passed: true,
          weakIds: [],
        ),
      );
      backend.today.completeTaskStub.returns(
        todayFixture(tasks: [checkpointTask(done: true)]),
      );

      await pumpFlow(tester);
      await tapText(tester, '開始');
      await tapText(tester, '貓');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(backend.today.completeTaskStub.calls, isEmpty);
      await tapText(tester, '繼續');

      expect(
        backend.today.completeTaskStub.calls.single.first,
        'checkpoint:ms.hira',
      );
    });
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/kana_teach_card.dart';
import 'package:japanese_learn_app/features/onboarding/onboarding_draft.dart';
import 'package:japanese_learn_app/features/onboarding/steps/level_step.dart';
import 'package:japanese_learn_app/features/onboarding/steps/time_step.dart';
import 'package:japanese_learn_app/features/onboarding/steps/voice_step.dart';
import 'package:japanese_learn_app/features/today/flow/today_flow_view.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../quiz/quiz_fixtures.dart';
import '../today/today_tasks.dart';

LessonSummaryDto _lesson(String id, String title) => LessonSummaryDto(
  id: id,
  stageId: 'st.s0',
  titleZh: title,
  canDoZh: '',
  status: LessonStatus.notStarted,
);

CourseOverviewDto _overviewWithKanaLessons() => _overviewOf(ContentStage.p0A);

CourseOverviewDto _overviewOf(ContentStage stage) => CourseOverviewDto(
  contentStage: stage,
  stages: const [],
  lessons: [
    _lesson('le.k01', 'あ行'),
    _lesson('le.k02', 'か行'),
    _lesson('le.k10', '清音回顧'),
    _lesson('le.k16', '促音'),
    _lesson('le.l01', '第一課'),
  ],
  currentLessonId: null,
  notesAvailable: false,
);

Finder _text(String text) => find.text(text);

/// 步驟頭的進度格：「第 N 步，共 4 步」底下帶框線的方格，一步一格。
Finder _stepTicks(int step) => find.descendant(
  of: find.bySemanticsLabel('第 $step 步，共 4 步'),
  matching: find.byWidgetPredicate(
    (widget) => widget is Container && widget.decoration is BoxDecoration,
  ),
);

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  late FakeBackend backend;
  late ProviderContainer container;

  setUp(() {
    backend = FakeBackend();
    backend.course.overviewStub.returns(_overviewWithKanaLessons());
    backend.today.todayStub.returns(
      todayFixture(tasks: [newContentTask(), reviewTask()]),
    );
    backend.today.newContentStub.returns(
      NewContentSessionDto(
        taskKey: 'new:le.k01:0',
        lessonId: 'le.k01',
        titleZh: 'あ行',
        steps: [NewContentStepDto.kana(detail: kanaDetailFixture())],
      ),
    );
    backend.today.completeTaskStub.returns(
      todayFixture(tasks: [newContentTask(done: true)]),
    );
  });

  Future<void> pumpWelcome(
    WidgetTester tester, {
    FakeTtsEngine? tts,
    String location = '/welcome',
  }) async {
    container = await pumpApp(
      tester,
      backend: backend,
      tts: tts,
      location: location,
      onboarded: false,
    );
  }

  Future<void> walkToVoice(WidgetTester tester) async {
    await _tap(tester, '開始');
    await _tap(tester, '完全沒學過');
    await _tap(tester, '下一步');
    await _tap(tester, '下一步');
  }

  group('第一次打開到第一批假名（最重要的路徑）', () {
    testWidgets('O1→O5→create_plan→today_view→L3，不經過 T1', (tester) async {
      final tts = FakeTtsEngine();
      await pumpWelcome(tester, tts: tts);

      expect(_text('從五十音開始。'), findsOneWidget);
      await walkToVoice(tester);

      expect(_text('聽得到聲音嗎？'), findsOneWidget);
      expect(tts.spoken.map((r) => r.text), contains('こんにちは'));

      await _tap(tester, '聽得到');
      await _tap(tester, '開始第一課');

      expect(find.byType(TodayFlowView), findsOneWidget);
      expect(
        tester.widget<TodayFlowView>(find.byType(TodayFlowView)).start,
        'new:le.k01:0',
      );
      expect(find.byType(KanaTeachCard), findsOneWidget);
      expect(backend.firstRunMarker.flag, isTrue);
      expect(backend.plan.createStub.calls, hasLength(1));
    });

    testWidgets('完全沒學過：PlanInputDto 是 Zero 與空清單', (tester) async {
      await pumpWelcome(tester);
      await walkToVoice(tester);
      await _tap(tester, '聽得到');
      await _tap(tester, '開始第一課');

      final input =
          backend.plan.createStub.calls.single.single! as PlanInputDto;
      expect(input.startLevel, StartLevel.zero);
      expect(input.knownKanaLessons, isEmpty);
      expect(input.dailyMinutes, 20);
      expect(input.weekdays, [1, 2, 3, 4, 5, 6, 7]);
    });

    testWidgets('create_plan 失敗時留在 O5，重試成功才進 L3', (tester) async {
      await pumpWelcome(tester);
      await walkToVoice(tester);
      await _tap(tester, '聽得到');
      backend.plan.createStub.throws(const StorageFailure());
      await _tap(tester, '開始第一課');

      expect(find.byType(ErrorSlip), findsOneWidget);
      expect(backend.firstRunMarker.flag, isFalse);

      backend.plan.createStub.returns(planViewFixture());
      await _tap(tester, '重試');

      expect(find.byType(TodayFlowView), findsOneWidget);
    });

    testWidgets('today_view 失敗後重試不會重複 create_plan', (tester) async {
      await pumpWelcome(tester);
      await walkToVoice(tester);
      await _tap(tester, '聽得到');
      backend.today.todayStub.throws(const StorageFailure());
      await _tap(tester, '開始第一課');

      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.today.todayStub.returns(todayFixture(tasks: [newContentTask()]));
      await _tap(tester, '重試');

      expect(backend.plan.createStub.calls, hasLength(1));
      expect(find.byType(TodayFlowView), findsOneWidget);
    });

    testWidgets('今天不是學習日時建立計畫後回 T1', (tester) async {
      await pumpWelcome(tester);
      await walkToVoice(tester);
      await _tap(tester, '聽得到');
      backend.today.todayStub.returns(todayFixture(isStudyDay: false));
      await _tap(tester, '開始第一課');

      expect(find.byType(TodayFlowView), findsNothing);
      expect(find.text('今天休息'), findsOneWidget);
    });
  });

  // 反向回歸：學習目標步驟（原 O2）已移除，路徑不重新編號。
  group('沒有學習目標步驟', () {
    testWidgets('歡迎頁按開始直接進 O3，進度格是 4 格', (tester) async {
      await pumpWelcome(tester);

      expect(_stepTicks(1), findsNWidgets(4));
      expect(_text('一／四'), findsOneWidget);

      await _tap(tester, '開始');

      expect(
        container.read(appRouterProvider).state.uri.toString(),
        '/welcome/o3',
      );
      expect(find.byType(LevelStep), findsOneWidget);
      expect(_text('你學過日文嗎？'), findsOneWidget);
      expect(_stepTicks(2), findsNWidgets(4));
      expect(_text('二／四'), findsOneWidget);
      for (final removed in ['你對什麼最有興趣？', '日劇', '日文歌']) {
        expect(find.textContaining(removed), findsNothing, reason: removed);
      }
      expect(backend.settings.patchStub.calls, isEmpty);
    });
  });

  group('O3 程度', () {
    test('K10、K16–K19 不列入', () {
      expect(isSkippableKanaLesson('le.k01'), isTrue);
      expect(isSkippableKanaLesson('le.k09'), isTrue);
      expect(isSkippableKanaLesson('le.k10'), isFalse);
      expect(isSkippableKanaLesson('le.k11'), isTrue);
      expect(isSkippableKanaLesson('le.k15'), isTrue);
      expect(isSkippableKanaLesson('le.k16'), isFalse);
      expect(isSkippableKanaLesson('le.k19'), isFalse);
      expect(isSkippableKanaLesson('le.l01'), isFalse);
    });

    testWidgets('會一點假名：勾選的課進 known_kana_lessons，Zero', (tester) async {
      await pumpWelcome(tester, location: '/welcome/o3');

      await _tap(tester, '會一點假名');
      expect(_text('清音回顧'), findsNothing);
      await _tap(tester, 'あ行');

      expect(find.byType(LevelStep), findsOneWidget);
      final draft = container.read(onboardingDraftProvider);
      expect(draft.toPlanInput().knownKanaLessons, ['le.k01']);
      expect(draft.startLevel, StartLevel.zero);
    });

    testWidgets('課程清單載入失敗可重試', (tester) async {
      backend.course.overviewStub.throws(const ContentFailure());
      await pumpWelcome(tester, location: '/welcome/o3');

      await _tap(tester, '會一點假名');
      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.course.overviewStub.returns(_overviewWithKanaLessons());
      await _tap(tester, '重試');
      expect(_text('か行'), findsOneWidget);
    });
  });

  group('畢業考', () {
    setUp(() {
      backend.drills.checkpointStartStub.returns([choiceQuestion()]);
    });

    Future<void> takePlacement(WidgetTester tester) async {
      await _tap(tester, '開始');
      await _tap(tester, '貓');
    }

    testWidgets('audio 固定 false、seed 0；通過時 Hiragana', (tester) async {
      backend.drills.checkpointFinishStub.returns(
        const CheckpointResultDto(
          milestoneId: 'ms.hira',
          correct: 18,
          total: 20,
          scorePercent: 90,
          passed: true,
          weakIds: [],
        ),
      );
      await pumpWelcome(tester, location: '/welcome/o3');
      await _tap(tester, '平假名都會');
      await _tap(tester, '去考一次');

      expect(_text('平假名畢業考'), findsOneWidget);
      expect(backend.drills.checkpointStartStub.calls.single, [
        'ms.hira',
        0,
        false,
      ]);

      await takePlacement(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await _tap(tester, '下一步');

      expect(find.byType(TimeStep), findsOneWidget);
      final draft = container.read(onboardingDraftProvider);
      expect(draft.startLevel, StartLevel.hiragana);
    });

    testWidgets('未通過：Zero，提示可改選，不扣進度', (tester) async {
      backend.drills.checkpointFinishStub.returns(
        const CheckpointResultDto(
          milestoneId: 'ms.hira',
          correct: 5,
          total: 20,
          scorePercent: 25,
          passed: false,
          weakIds: ['gr.wa'],
        ),
      );
      await pumpWelcome(tester, location: '/welcome/o3');
      await _tap(tester, '平假名都會');
      await _tap(tester, '去考一次');

      await takePlacement(tester);

      expect(find.textContaining('不扣任何進度'), findsOneWidget);
      expect(find.textContaining('會一點假名'), findsOneWidget);
      // 畢業考不列弱項，也不呼叫 peek
      expect(find.text('練這題'), findsNothing);

      await _tap(tester, '下一步');
      final draft = container.read(onboardingDraftProvider);
      expect(draft.startLevel, StartLevel.zero);
    });
  });

  group('O4 每天多久', () {
    testWidgets('預設 20 分鐘，改變時重算粗估，一律標明粗估', (tester) async {
      backend.plan.previewStub.returns(_planWithEnd());
      await pumpWelcome(tester, location: '/welcome/o4');

      expect(find.textContaining('假名與入門七課約在 8/12 完成（粗估）'), findsOneWidget);
      final firstCall =
          backend.plan.previewStub.calls.first.single! as PlanInputDto;
      expect(firstCall.dailyMinutes, 20);

      await _tap(tester, '45 分鐘');

      final last = backend.plan.previewStub.calls.last.single! as PlanInputDto;
      expect(last.dailyMinutes, 45);
    });

    testWidgets('全部學習日都取消時不能下一步', (tester) async {
      backend.plan.previewStub.returns(_planWithEnd());
      await pumpWelcome(tester, location: '/welcome/o4');

      for (final day in ['週一', '週二', '週三', '週四', '週五', '週六', '週日']) {
        await _tap(tester, day);
      }

      expect(_text('至少選一天'), findsOneWidget);
      await tester.tap(_text('下一步'));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceStep), findsNothing);
    });

    testWidgets('粗估失敗不擋下一步', (tester) async {
      backend.plan.previewStub.throws(const StorageFailure());
      await pumpWelcome(tester, location: '/welcome/o4');

      expect(find.textContaining('不影響開始'), findsOneWidget);
      await _tap(tester, '下一步');
      expect(find.byType(VoiceStep), findsOneWidget);
    });

    testWidgets('p0 的粗估寫本版到 L30，不沿用 p0a 的範圍', (tester) async {
      backend.course.overviewStub.returns(_overviewOf(ContentStage.p0));
      backend.plan.previewStub.returns(_planWithEnd());
      await pumpWelcome(tester, location: '/welcome/o4');

      expect(_text('本版到 L30，約在 8/12 完成（粗估）'), findsOneWidget);
      expect(find.textContaining('專區'), findsNothing);
      expect(find.textContaining('入門七課'), findsNothing);
      expect(find.textContaining('N4'), findsNothing);
      expect(find.textContaining('L48'), findsNothing);
    });
  });

  group('O5 語音檢查', () {
    testWidgets('探測中顯示正在確認語音', (tester) async {
      final probe = Completer<void>();
      final tts = FakeTtsEngine(probeGate: probe.future);
      await pumpApp(
        tester,
        backend: backend,
        tts: tts,
        location: '/welcome/o5',
        onboarded: false,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(_text('正在確認語音'), findsOneWidget);
      probe.complete();
      await tester.pumpAndSettle();
      expect(_text('聽得到'), findsOneWidget);
    });

    testWidgets('按聽不到時停在本步，只有兩個明確出口，沒有略過', (tester) async {
      await pumpWelcome(tester, location: '/welcome/o5');

      await _tap(tester, '聽不到');

      expect(_text('現在設定'), findsOneWidget);
      expect(_text('先用無聲模式'), findsOneWidget);
      expect(_text('開始第一課'), findsNothing);
      expect(find.textContaining('之後隨時可以在設定開回來'), findsOneWidget);
    });

    testWidgets('探測失敗時直接展開說明', (tester) async {
      final tts = FakeTtsEngine(
        availability: const TtsAvailability(
          TtsAvailabilityKind.voiceNotDownloaded,
        ),
      );
      await pumpWelcome(tester, tts: tts, location: '/welcome/o5');

      expect(_text('現在設定'), findsOneWidget);
      expect(_text('聽得到'), findsNothing);
    });

    testWidgets('先用無聲模式：寫 silent_mode，傳 audio false，可開始', (tester) async {
      await pumpWelcome(tester, location: '/welcome/o5');
      await _tap(tester, '聽不到');

      await _tap(tester, '先用無聲模式');

      expect(backend.settings.current.silentMode, isTrue);
      await _tap(tester, '開始第一課');

      expect(backend.today.todayStub.calls.first, [false]);
      expect(backend.today.newContentStub.calls.single.last, isFalse);
      expect(find.byType(TodayFlowView), findsOneWidget);
    });

    testWidgets('現在設定開 VoiceHelpSheet，探測成功就回到試聽', (tester) async {
      final tts = FakeTtsEngine(
        availability: const TtsAvailability(
          TtsAvailabilityKind.voiceNotDownloaded,
        ),
      );
      await pumpWelcome(tester, tts: tts, location: '/welcome/o5');

      await _tap(tester, '現在設定');
      expect(find.textContaining('語音資料'), findsOneWidget);

      tts.availability = const TtsAvailability(TtsAvailabilityKind.ready);
      await tester.tap(find.text('現在設定').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新檢查'));
      await tester.pumpAndSettle();

      expect(_text('聽得到'), findsOneWidget);
      expect(tts.spoken.map((r) => r.text), contains('こんにちは'));
    });

    testWidgets('播放失敗（TtsError）視同聽不到', (tester) async {
      final tts = FakeTtsEngine()..speakError = Exception('boom');
      await pumpWelcome(tester, tts: tts, location: '/welcome/o5');

      expect(_text('現在設定'), findsOneWidget);
    });

    testWidgets('無聲模式已開時直接說明並可開始', (tester) async {
      backend.settings.current = settingsFixture(silentMode: true);

      await pumpWelcome(tester, location: '/welcome/o5');

      expect(_text('已改用無聲模式。'), findsOneWidget);
      expect(_text('開始第一課'), findsOneWidget);
    });
  });

  group('O7 誠實範圍', () {
    for (final location in ['/welcome', '/welcome/o4']) {
      testWidgets('P0a 的 $location 不提 N4 與看懂日劇', (tester) async {
        backend.plan.previewStub.returns(_planWithEnd());

        await pumpWelcome(tester, location: location);

        for (final banned in ['N4', '看懂日劇', '聽懂日劇']) {
          expect(find.textContaining(banned), findsNothing);
        }
      });
    }
  });

  group('字級與版面', () {
    testWidgets('O4 在 320 寬、1.5 倍字級不溢位', (tester) async {
      backend.plan.previewStub.returns(_planWithEnd());

      await pumpApp(
        tester,
        backend: backend,
        location: '/welcome/o4',
        onboarded: false,
        width: 320,
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('O1 在 320 寬、1.5 倍字級不溢位', (tester) async {
      await pumpApp(
        tester,
        backend: backend,
        location: '/welcome',
        onboarded: false,
        width: 320,
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('互動目標', () {
    testWidgets('O5 的按鈕達 48dp', (tester) async {
      await pumpWelcome(tester, location: '/welcome/o5');

      expect(tester.getSize(find.text('聽得到')).height, greaterThan(0));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  testWidgets('create 完成時 onboardingDone 變 true', (tester) async {
    await pumpWelcome(tester);
    await walkToVoice(tester);
    await _tap(tester, '聽得到');
    await _tap(tester, '開始第一課');

    expect(container.read(onboardingDoneProvider).value, isTrue);
  });
}

PlanViewDto _planWithEnd() => PlanViewDto(
  input: planInputFixture(),
  currentLessonId: 'le.k01',
  milestones: const [],
  mainForecastEnd: '2026-08-12',
  status: PlanStatus.onTrack,
);

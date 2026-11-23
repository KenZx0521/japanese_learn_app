import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../grammar/grammar_fixtures.dart';
import '../quiz/quiz_fixtures.dart';
import '../quiz/quiz_harness.dart';

GoRouter _router(ProviderContainer c) => c.read(appRouterProvider);

String _path(ProviderContainer c) => _router(c).state.uri.toString();

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  String? location,
  FakeTtsEngine? tts,
  SettingsDto? settings,
  double width = 375,
  double height = 800,
  double textScale = 1,
  bool settle = true,
}) => pumpApp(
  tester,
  backend: backend,
  tts: tts,
  location: location ?? AppRoutes.sessionDrill(lesson: 'le.l01'),
  settings: settings ?? allHintsSeen(),
  width: width,
  height: height,
  textScale: textScale,
  settle: settle,
);

QuestionDto _second() => choiceQuestion(
  body: choiceBodyFixture(
    options: [optionFixture('a', '書'), optionFixture('b', '筆')],
  ),
  reference: refFixture(QuestionType.recog, contentId: 'vo.hon', drillId: 'b'),
);

Future<void> _answer(WidgetTester tester, String option) async {
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
  await tester.tap(find.text('繼續'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.drills.sessionStub.returns([choiceQuestion(), _second()]);
    backend.drills.gradeStub.returns(drillOk);
    backend.peek.peekStub.returns(peekGrammar);
    backend.course.overviewStub.returns(
      overviewFixture(lessons: [lessonFixture('le.l01')]),
    );
  });

  group('取題', () {
    testWidgets('依課取 10 題，seed 來自邏輯日', (tester) async {
      await _pump(tester, backend);

      final [filter, seed, audio] = backend.drills.sessionStub.calls.single;
      final dto = filter! as DrillFilterDto;
      expect(dto.lessonId, 'le.l01');
      expect(dto.target, isNull);
      expect(dto.drillIds, isEmpty);
      expect(dto.count, 10);
      expect(seed, sessionSeed('2026-03-02'));
      expect(audio, isTrue);
    });

    testWidgets('target 參數', (tester) async {
      await _pump(
        tester,
        backend,
        location: AppRoutes.sessionDrill(target: 'gr.wa'),
      );

      final dto =
          backend.drills.sessionStub.calls.single.first! as DrillFilterDto;
      expect(dto.target, 'gr.wa');
      expect(dto.lessonId, isNull);
      expect(dto.count, 10);
    });

    testWidgets('指定題組時全部都出', (tester) async {
      await _pump(
        tester,
        backend,
        location: AppRoutes.sessionDrill(drills: ['dr.a', 'dr.b']),
      );

      final dto =
          backend.drills.sessionStub.calls.single.first! as DrillFilterDto;
      expect(dto.drillIds, ['dr.a', 'dr.b']);
      expect(dto.count, 0);
    });

    testWidgets('語音探測完成前停在骨架，不取題', (tester) async {
      final probe = Completer<void>();
      await _pump(
        tester,
        backend,
        tts: FakeTtsEngine(probeGate: probe.future),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(backend.drills.sessionStub.calls, isEmpty);
      expect(find.byType(SkeletonLines), findsOneWidget);

      probe.complete();
      await tester.pumpAndSettle();
      expect(backend.drills.sessionStub.calls, hasLength(1));
      expect(find.text('貓'), findsOneWidget);
    });

    testWidgets('改成無聲模式時以同 seed 重取', (tester) async {
      final container = await _pump(tester, backend);
      final firstSeed = backend.drills.sessionStub.calls.single[1];

      await container
          .read(settingsProvider.notifier)
          .patch(settingsPatch(silentMode: true));
      await tester.pumpAndSettle();

      final calls = backend.drills.sessionStub.calls;
      expect(calls, hasLength(2));
      expect(calls.last[1], firstSeed);
      expect(calls.last[2], isFalse);
    });

    testWidgets('回到前景更新今日資料時不重取，回合不重置', (tester) async {
      final container = await _pump(tester, backend);
      await _answer(tester, '貓');
      expect(find.text('書'), findsOneWidget);

      container.read(resumeTickProvider.notifier).bump();
      await tester.pumpAndSettle();

      expect(backend.today.todayStub.calls, hasLength(2));
      expect(backend.drills.sessionStub.calls, hasLength(1));
      expect(find.text('書'), findsOneWidget);
    });
  });

  group('作答', () {
    testWidgets('全對後顯示結果', (tester) async {
      await _pump(tester, backend);

      await _answer(tester, '貓');
      await _answer(tester, '書');

      expect(find.text('第一次就答對 2 題，共 2 題'), findsOneWidget);
      expect(find.byType(HankoBadge), findsOneWidget);
      expect(backend.drills.gradeStub.calls, hasLength(2));
    });

    testWidgets('答錯者本回合末重出，成績只算第一次', (tester) async {
      backend.drills.gradeStub.answers(
        (args) => args[1] == const AnswerPayload.choice(optionId: 'b')
            ? drillWrong()
            : drillOk,
      );
      await _pump(tester, backend);

      await _answer(tester, '狗');
      await _answer(tester, '書');
      expect(find.text('貓'), findsOneWidget);
      await _answer(tester, '貓');

      expect(find.text('第一次就答對 1 題，共 2 題'), findsOneWidget);
      expect(backend.drills.gradeStub.calls, hasLength(3));
    });

    testWidgets('再做一次：同一批題目，不重取', (tester) async {
      await _pump(tester, backend);
      await _answer(tester, '貓');
      await _answer(tester, '書');

      await tester.tap(find.text('再做一次'));
      await tester.pumpAndSettle();

      expect(find.text('貓'), findsOneWidget);
      expect(find.text('繼續'), findsNothing);
      expect(backend.drills.sessionStub.calls, hasLength(1));
    });

    testWidgets('判定失敗留在本題，可重試', (tester) async {
      backend.drills.gradeStub.throws(const StorageFailure());
      await _pump(tester, backend);

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.drills.gradeStub.returns(drillOk);
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.text('繼續'), findsOneWidget);
    });
  });

  group('離開', () {
    testWidgets('中途離開再進來，以同 seed 從頭做', (tester) async {
      final container = await _pump(
        tester,
        backend,
        location: AppRoutes.drills,
      );
      final path = AppRoutes.sessionDrill(lesson: 'le.l01');
      unawaited(_router(container).push(path));
      await tester.pumpAndSettle();
      await _answer(tester, '貓');
      expect(find.text('書'), findsOneWidget);

      await tester.tap(find.text('離開'));
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.drills);

      unawaited(_router(container).push(path));
      await tester.pumpAndSettle();

      final calls = backend.drills.sessionStub.calls;
      expect(calls, hasLength(2));
      expect(calls[1][1], calls[0][1]);
      expect(find.text('貓'), findsOneWidget);
    });

    testWidgets('沒有上一頁時回 D1', (tester) async {
      final container = await _pump(tester, backend);

      await tester.tap(find.text('離開'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.drills);
    });

    testWidgets('Esc 離開', (tester) async {
      final container = await _pump(tester, backend);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.drills);
    });

    testWidgets('完成回到進來的地方', (tester) async {
      final container = await _pump(
        tester,
        backend,
        location: AppRoutes.drills,
      );
      unawaited(
        _router(container).push(AppRoutes.sessionDrill(lesson: 'le.l01')),
      );
      await tester.pumpAndSettle();
      await _answer(tester, '貓');
      await _answer(tester, '書');

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.drills);
    });
  });

  group('狀態', () {
    testWidgets('這課沒有題目', (tester) async {
      backend.drills.sessionStub.returns(const []);
      await _pump(tester, backend);

      expect(find.text('這課目前沒有題目'), findsOneWidget);
      expect(find.text('回去'), findsOneWidget);
    });

    testWidgets('因無聲模式沒題時說明原因', (tester) async {
      backend.drills.sessionStub.returns(const []);
      await _pump(
        tester,
        backend,
        settings: applyPatch(allHintsSeen(), settingsPatch(silentMode: true)),
      );

      expect(backend.drills.sessionStub.calls.single[2], isFalse);
      expect(find.textContaining('無聲模式'), findsOneWidget);
    });

    testWidgets('語音不可用且沒題時說明原因', (tester) async {
      backend.drills.sessionStub.returns(const []);
      await _pump(
        tester,
        backend,
        tts: FakeTtsEngine(
          availability: const TtsAvailability(
            TtsAvailabilityKind.engineMissing,
          ),
        ),
      );

      expect(find.textContaining('語音無法使用'), findsOneWidget);
    });

    testWidgets('取題失敗可重試', (tester) async {
      backend.drills.sessionStub.throws(const StorageFailure());
      await _pump(tester, backend);
      expect(find.byType(ErrorSlip), findsOneWidget);
      expect(find.text('離開'), findsOneWidget);

      backend.drills.sessionStub.returns([choiceQuestion()]);
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.text('貓'), findsOneWidget);
    });

    testWidgets('今日資料失敗時，重試也會重取今日', (tester) async {
      backend.today.todayStub.throws(const StorageFailure());
      await _pump(tester, backend);
      expect(find.byType(ErrorSlip), findsOneWidget);
      expect(backend.drills.sessionStub.calls, isEmpty);

      backend.today.todayStub.returns(todayFixture());
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.text('貓'), findsOneWidget);
    });
  });

  group('顯示', () {
    testWidgets('ShownToggleable 時右上可收起羅馬字', (tester) async {
      backend.drills.sessionStub.returns([
        choiceQuestion(prompt: promptFixture(text: sentenceFixture())),
      ]);
      backend.settings.displayPolicyStub.returns(
        displayPolicyFixture(romaji: RomajiMode.shownToggleable),
      );
      await _pump(tester, backend);

      expect(find.text('watashi'), findsWidgets);
      await tester.tap(find.text('收起羅馬字'));
      await tester.pumpAndSettle();
      expect(find.text('watashi'), findsNothing);
    });

    testWidgets('其他模式沒有開關', (tester) async {
      await _pump(tester, backend);
      expect(find.text('收起羅馬字'), findsNothing);
    });

    testWidgets('320 寬、1.5 倍字級：作答與結果頁都不溢位', (tester) async {
      await _pump(tester, backend, width: 320, textScale: 1.5, height: 640);
      expect(tester.takeException(), isNull);

      await _answer(tester, '貓');
      await _answer(tester, '書');
      expect(tester.takeException(), isNull);
      expect(find.text('完成'), findsOneWidget);
    });
  });
}

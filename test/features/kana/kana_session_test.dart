import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/tts/audio_available.dart';
import 'package:japanese_learn_app/design/widgets/confusable_view.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/kana_teach_card.dart';
import 'package:japanese_learn_app/design/widgets/rule_card_view.dart';
import 'package:japanese_learn_app/features/kana/kana_chart_screen.dart';
import 'package:japanese_learn_app/features/kana/kana_session_screen.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'kana_fixtures.dart';

const _lessonId = 'le.k01';

KanaCellDto _a({KanaStatus status = KanaStatus.notStarted}) =>
    kanaCellFixture(status: status);
KanaCellDto _i({KanaStatus status = KanaStatus.notStarted}) =>
    kanaCellFixture(id: 'ka.hira.i', ch: 'い', romaji: 'i', status: status);

QuestionDto _readA() => kanaRead('ka.hira.a', 'あ', correct: 'a');
QuestionDto _readI() => kanaRead('ka.hira.i', 'い', correct: 'i');

Future<void> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  FakeTtsEngine? tts,
  bool settle = true,
  SettingsDto? settings,
}) => pumpApp(
  tester,
  backend: backend,
  tts: tts,
  settle: settle,
  settings: settings ?? seenHints(),
  child: const KanaSessionScreen(lessonId: _lessonId),
);

void _stubLesson(
  FakeBackend backend, {
  List<KanaCellDto>? cells,
  List<QuestionDto>? questions,
}) {
  final kana = cells ?? [_a(), _i()];
  backend.course.lessonStub.returns(lessonOf(kana));
  backend.kana.sessionStub.returns(questions ?? [_readA(), _readI()]);
  backend.kana.submitStub.returns(kanaRight);
  stubDetails(backend, [
    detailOf(_a()),
    detailOf(_i(), origin: '以', hint: '{ja:い}：嘴角拉開'),
  ]);
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.text('下一步'));
  await tester.pumpAndSettle();
}

Future<void> _answer(WidgetTester tester, String option) async {
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
  await tester.tap(find.text('繼續'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend());

  testWidgets('先逐字教未學的字，看完才進測驗', (tester) async {
    final tts = FakeTtsEngine();
    _stubLesson(backend);
    await _pump(tester, backend, tts: tts);

    expect(find.byType(KanaTeachCard), findsOneWidget);
    expect(find.text('先認字 1／2'), findsOneWidget);
    expect(find.text('あ'), findsOneWidget);
    expect(find.byType(QuizSessionView), findsNothing);
    expect(tts.spoken.single.id, 'ka.hira.a');

    await _next(tester);
    expect(find.text('先認字 2／2'), findsOneWidget);
    expect(find.text('い'), findsOneWidget);
    expect(tts.spoken.last.id, 'ka.hira.i');

    await _next(tester);
    expect(find.byType(KanaTeachCard), findsNothing);
    final quiz = tester.widget<QuizSessionView>(find.byType(QuizSessionView));
    expect(quiz.grader, isA<KanaGrader>());
    expect(quiz.requeueWrong, isTrue);
    expect(quiz.fallbackLessonId, _lessonId);
    expect(backend.kana.detailStub.calls, [
      ['ka.hira.a'],
      ['ka.hira.i'],
    ]);
  });

  testWidgets('全都學過時直接測驗', (tester) async {
    _stubLesson(
      backend,
      cells: [
        _a(status: KanaStatus.learning),
        _i(status: KanaStatus.mastered),
      ],
    );
    await _pump(tester, backend);

    expect(find.byType(KanaTeachCard), findsNothing);
    expect(find.byType(QuizSessionView), findsOneWidget);
    expect(backend.kana.detailStub.calls, isEmpty);
  });

  testWidgets('跨課易混題的目標字沒學過時也先教，再教字組', (tester) async {
    final nu = kanaCellFixture(id: 'ka.hira.nu', ch: 'ぬ', romaji: 'nu');
    const diff = '{ja:ぬ} 收筆有圈';
    final group = ConfusableDto(
      id: 'ka.cf.nu_me',
      kind: ConfusableKindDto.shape,
      members: [nu],
      literals: const [],
      diffZh: diff,
    );
    backend.course.lessonStub.returns(
      lessonOf([_a(status: KanaStatus.learning)]),
    );
    backend.kana.sessionStub.returns([
      kanaConfuse('ka.hira.nu', 'nu', explain: diff),
    ]);
    backend.kana.submitStub.returns(kanaRight);
    stubDetails(backend, [
      detailOf(nu, confusables: [group]),
    ]);
    await _pump(tester, backend);

    expect(find.byType(KanaTeachCard), findsOneWidget);
    expect(find.text('ぬ'), findsOneWidget);
    await _next(tester);
    expect(find.byType(ConfusableView), findsOneWidget);
    await _next(tester);
    expect(find.byType(QuizSessionView), findsOneWidget);
  });

  testWidgets('規則課未完成時先看規則卡（第一題不會考沒看過的內容）', (tester) async {
    backend.course.lessonStub.returns(
      lessonOf(const [], id: 'le.k17', rules: [ruleCardFixture()]),
    );
    backend.kana.sessionStub.returns([_readA()]);
    backend.kana.submitStub.returns(kanaRight);
    stubDetails(backend, [detailOf(_a(status: KanaStatus.learning))]);
    await _pump(tester, backend);

    expect(find.byType(RuleCardView), findsOneWidget);
    expect(find.text('測試一下'), findsNothing);
    await _next(tester);
    expect(find.byType(QuizSessionView), findsOneWidget);
  });

  testWidgets('語音探測完成前不取題，完成後才帶 audio 取題', (tester) async {
    final gate = Completer<void>();
    _stubLesson(backend);
    final tts = FakeTtsEngine(probeGate: gate.future);
    await _pump(tester, backend, tts: tts, settle: false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(backend.kana.sessionStub.calls, isEmpty);
    expect(find.bySemanticsLabel('載入中'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(backend.kana.sessionStub.calls.single[2], isTrue);
  });

  testWidgets('無聲模式傳 audio=false', (tester) async {
    _stubLesson(backend);
    await _pump(tester, backend, settings: settingsFixture(silentMode: true));
    expect(backend.kana.sessionStub.calls.single[2], isFalse);
  });

  testWidgets('語音恢復時用同 seed 重新取題，教學進度不重來', (tester) async {
    _stubLesson(backend);
    final tts = FakeTtsEngine(
      availability: const TtsAvailability(TtsAvailabilityKind.engineMissing),
    );
    final container = await pumpApp(
      tester,
      backend: backend,
      tts: tts,
      settings: seenHints(),
      child: const KanaSessionScreen(lessonId: _lessonId),
    );
    await _next(tester);
    expect(find.text('先認字 2／2'), findsOneWidget);
    final firstCall = backend.kana.sessionStub.calls.single;
    expect(firstCall[2], isFalse);

    tts.availability = const TtsAvailability(TtsAvailabilityKind.ready);
    await container.read(ttsAvailabilityProvider.notifier).reprobe();
    await tester.pumpAndSettle();

    final calls = backend.kana.sessionStub.calls;
    expect(calls, hasLength(2));
    expect(calls.last[1], firstCall[1]);
    expect(calls.last[2], isTrue);
    expect(find.text('先認字 2／2'), findsOneWidget);
  });

  testWidgets('沒有題目時顯示「這批都熟了」', (tester) async {
    _stubLesson(
      backend,
      cells: [_a(status: KanaStatus.mastered)],
      questions: const [],
    );
    await _pump(tester, backend);

    expect(find.text('這批都熟了'), findsOneWidget);
    expect(find.text('回上一頁'), findsOneWidget);
  });

  testWidgets('語音不可用導致沒有題目時說明原因並可設定語音', (tester) async {
    _stubLesson(
      backend,
      cells: [_a(status: KanaStatus.mastered)],
      questions: const [],
    );
    await _pump(tester, backend, settings: settingsFixture(silentMode: true));

    expect(find.text('這批都熟了'), findsNothing);
    expect(find.text('這一課的題目都要聽聲音，打開語音就能練。'), findsOneWidget);
    expect(find.text('設定語音'), findsOneWidget);
  });

  testWidgets('教完才發現沒有題目也不會卡住', (tester) async {
    _stubLesson(backend, cells: [_a()], questions: const []);
    await _pump(tester, backend);

    await _next(tester);
    expect(find.byType(KanaTeachCard), findsNothing);
    expect(find.text('這批都熟了'), findsOneWidget);
  });

  testWidgets('取題失敗顯示 ErrorSlip，可重試也可回上一頁', (tester) async {
    _stubLesson(backend);
    backend.kana.sessionStub.throws(const ContentFailure());
    await _pump(tester, backend);

    expect(find.byType(ErrorSlip), findsOneWidget);
    expect(find.text('回上一頁'), findsOneWidget);

    backend.kana.sessionStub.returns([_readA()]);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorSlip), findsNothing);
    expect(find.byType(KanaTeachCard), findsOneWidget);
  });

  testWidgets('教學內容讀不到時顯示 ErrorSlip', (tester) async {
    _stubLesson(backend);
    backend.kana.detailStub.throws(const NotFoundFailure());
    await _pump(tester, backend);
    expect(find.byType(ErrorSlip), findsOneWidget);
  });

  testWidgets('答完顯示成績，再練一次會重跑同一批題', (tester) async {
    _stubLesson(
      backend,
      cells: [_a(status: KanaStatus.learning)],
      questions: [_readA()],
    );
    backend.kana.submitStub.returns(
      const KanaSubmitResultDto(
        isCorrect: true,
        correctDisplay: 'a',
        mastery: KanaMasteryDto(
          kanaId: 'ka.hira.a',
          run: 2,
          required_: 2,
          mastered: true,
          fastBadge: false,
        ),
      ),
    );
    await _pump(tester, backend);

    await _answer(tester, 'a');
    expect(find.text('答對 1／1 題'), findsOneWidget);
    expect(find.text('這回合熟練了 1 個字'), findsOneWidget);
    expect(backend.kana.submitStub.calls, hasLength(1));

    await tester.tap(find.text('再練一次'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizSessionView), findsOneWidget);
    await _answer(tester, 'a');
    expect(backend.kana.submitStub.calls, hasLength(2));
    expect(backend.kana.sessionStub.calls, hasLength(1));
  });

  testWidgets('按完成回到五十音表', (tester) async {
    _stubLesson(
      backend,
      cells: [_a(status: KanaStatus.learning)],
      questions: [_readA()],
    );
    stubCharts(backend);
    await pumpApp(
      tester,
      backend: backend,
      location: AppRoutes.kanaSession(_lessonId),
      settings: seenHints(),
    );

    await _answer(tester, 'a');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.byType(KanaChartScreen), findsOneWidget);
    expect(find.byType(KanaSessionScreen), findsNothing);
  });

  testWidgets('教學卡播放中離開會停止語音', (tester) async {
    _stubLesson(backend);
    stubCharts(backend);
    final tts = FakeTtsEngine(autoComplete: false);
    await pumpApp(
      tester,
      backend: backend,
      tts: tts,
      location: AppRoutes.kanaSession(_lessonId),
      settings: seenHints(),
      settle: false,
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
    final before = tts.stopCount;

    await tester.tap(find.text('離開'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(tts.stopCount, greaterThan(before));
  });

  testWidgets('離開鈕在教學中可退出，不需確認', (tester) async {
    _stubLesson(backend);
    stubCharts(backend);
    await pumpApp(
      tester,
      backend: backend,
      location: AppRoutes.kanaSession(_lessonId),
      settings: seenHints(),
    );

    await tester.tap(find.text('離開'));
    await tester.pumpAndSettle();

    expect(find.byType(KanaChartScreen), findsOneWidget);
  });

  testWidgets('320 寬、字級 1.5 倍不破版', (tester) async {
    _stubLesson(backend);
    await pumpApp(
      tester,
      backend: backend,
      settings: seenHints(),
      width: 320,
      height: 640,
      textScale: 1.5,
      child: const KanaSessionScreen(lessonId: _lessonId),
    );
    expect(tester.takeException(), isNull);
    await _next(tester);
    expect(tester.takeException(), isNull);
  });
}

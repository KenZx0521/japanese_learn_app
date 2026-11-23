import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/features/session/cards/card_runner.dart';
import 'package:japanese_learn_app/features/session/cards/cards_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../../support/fake_backend.dart';
import '../../../support/fake_tts_engine.dart';
import '../../../support/fixtures.dart';
import '../../../support/pump_app.dart';
import '../../quiz/quiz_fixtures.dart';
import '../../quiz/quiz_harness.dart';

SessionCardDto _card(
  String id, {
  int reps = 0,
  int remaining = 3,
  QuestionDto? question,
}) => SessionCardDto(
  cardId: id,
  expectedReps: reps,
  facet: 'recog',
  question:
      question ??
      choiceQuestion(
        reference: refFixture(
          QuestionType.recog,
          contentId: 'ka.$id',
          cardId: id,
        ),
      ),
  ratingPreviews: const [],
  remainingEstimate: remaining,
);

SessionNextDto _next(String id, {int reps = 0, int remaining = 3}) =>
    SessionNextDto.card(
      card: _card(id, reps: reps, remaining: remaining),
    );

/// 依序回傳 [results]，最後一個重複。
void _sequence(FakeBackend backend, List<SessionNextDto> results) {
  var index = 0;
  backend.review.nextStub.answers((_) {
    final value = results[index < results.length ? index : results.length - 1];
    index++;
    return value;
  });
}

Future<FakeBackend> _pumpScreen(
  WidgetTester tester,
  List<SessionNextDto> results, {
  FakeBackend? backend,
  double width = 375,
  double textScale = 1,
  bool settle = true,
}) async {
  final fake = backend ?? FakeBackend();
  final settings = allHintsSeen();
  fake.settings.current = settings;
  fake.settings.displayPolicyStub.returns(displayPolicyFixture());
  fake.review.submitStub.returns(reviewOk());
  _sequence(fake, results);
  await pumpApp(
    tester,
    backend: fake,
    settings: settings,
    child: const CardsScreen(),
    width: width,
    textScale: textScale,
    settle: settle,
  );
  return fake;
}

Future<void> _answerAndContinue(WidgetTester tester) async {
  await tester.tap(find.text('貓'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('繼續'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('用 logical_date 算 seed，帶語音可用性取卡', (tester) async {
    final backend = await _pumpScreen(tester, [_next('c1')]);

    final call = backend.review.nextStub.calls.first;
    expect(call[0], sessionSeed('2026-03-02'));
    expect(call[1], isTrue);
  });

  testWidgets('答完一張後用同 seed 取下一張', (tester) async {
    final backend = await _pumpScreen(tester, [
      _next('c1'),
      _next('c2', remaining: 2),
      const SessionNextDto.done(),
    ]);

    await _answerAndContinue(tester);

    expect(backend.review.submitStub.calls, hasLength(1));
    final answer = backend.review.submitStub.calls.single.single! as AnswerDto;
    expect(answer.reference.cardId, 'c1');
    expect(backend.review.nextStub.calls, hasLength(2));
    expect(find.textContaining('2'), findsWidgets);
  });

  testWidgets('顯示剩餘張數', (tester) async {
    await _pumpScreen(tester, [_next('c1', remaining: 7)]);

    expect(find.textContaining('還有約 7 張'), findsOneWidget);
  });

  testWidgets('第一次取卡就 Done：顯示空狀態與下次到期時間', (tester) async {
    final due = DateTime(2026, 3, 3, 9, 5);
    final backend = FakeBackend();
    await _pumpScreen(tester, [
      SessionNextDto.done(nextDueAt: due.toUtc()),
    ], backend: backend);

    expect(find.text('目前沒有到期卡片'), findsOneWidget);
    expect(find.textContaining('3 月 3 日'), findsOneWidget);
    expect(find.textContaining('09:05'), findsOneWidget);
  });

  testWidgets('沒有下次到期時間時不顯示時間', (tester) async {
    await _pumpScreen(tester, [const SessionNextDto.done()]);

    expect(find.text('目前沒有到期卡片'), findsOneWidget);
    expect(find.textContaining('下次'), findsNothing);
  });

  testWidgets('第一張載入中顯示骨架', (tester) async {
    final backend = FakeBackend();
    final gate = Completer<void>();
    backend.review.nextStub.gate = gate.future;
    await _pumpScreen(tester, [_next('c1')], backend: backend, settle: false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SkeletonLines), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('貓'), findsOneWidget);
  });

  testWidgets('取卡失敗顯示 ErrorSlip，重試後繼續', (tester) async {
    final backend = FakeBackend();
    await _pumpScreen(tester, [_next('c1')], backend: backend);
    backend.review.nextStub.throws(const StorageFailure());
    await _answerAndContinue(tester);

    expect(find.byType(ErrorSlip), findsOneWidget);

    _sequence(backend, [_next('c2')]);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('貓'), findsOneWidget);
    expect(find.byType(ErrorSlip), findsNothing);
  });

  testWidgets('寫入失敗留在本卡，可重試', (tester) async {
    final backend = FakeBackend();
    await _pumpScreen(tester, [_next('c1')], backend: backend);
    backend.review.submitStub.throws(const StorageFailure());

    await tester.tap(find.text('貓'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorSlip), findsOneWidget);
    expect(backend.review.nextStub.calls, hasLength(1));

    backend.review.submitStub.returns(reviewOk());
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.text('繼續'), findsOneWidget);
  });

  testWidgets('StaleCard 靜默取下一張', (tester) async {
    final backend = FakeBackend();
    await _pumpScreen(tester, [_next('c1'), _next('c2')], backend: backend);
    backend.review.submitStub.throws(const StaleCardFailure());

    await tester.tap(find.text('貓'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorSlip), findsNothing);
    expect(backend.review.nextStub.calls, hasLength(2));
  });

  testWidgets('自評型卡片能翻面、評分，再取下一張', (tester) async {
    final backend = FakeBackend();
    final settings = allHintsSeen();
    backend.settings.current = settings;
    backend.settings.displayPolicyStub.returns(displayPolicyFixture());
    backend.review.submitStub.returns(reviewOk());
    backend.vocab.detailStub.returns(vocabDetailFixture());
    _sequence(backend, [
      SessionNextDto.card(
        card: _card('vo.neko:p', question: selfGradeQuestion()),
      ),
      const SessionNextDto.done(),
    ]);

    await pumpApp(
      tester,
      backend: backend,
      settings: settings,
      child: const CardsScreen(),
    );
    await tester.tap(find.text('翻面看答案'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('記得'));
    await tester.pumpAndSettle();

    final answer = backend.review.submitStub.calls.single.single! as AnswerDto;
    expect(answer.response, const AnswerPayload.selfGrade(rating: Rating.good));
    expect(answer.expectedReps, 0);
  });

  group('語音閘門', () {
    testWidgets('語音探測完成前不取卡', (tester) async {
      final backend = FakeBackend();
      final settings = allHintsSeen();
      backend.settings.current = settings;
      backend.settings.displayPolicyStub.returns(displayPolicyFixture());
      _sequence(backend, [_next('c1')]);
      final probe = Completer<void>();
      await pumpApp(
        tester,
        backend: backend,
        tts: FakeTtsEngine(probeGate: probe.future),
        settings: settings,
        child: const CardsScreen(),
        settle: false,
      );
      await tester.pump();

      expect(backend.review.nextStub.calls, isEmpty);

      probe.complete();
      await tester.pumpAndSettle();
      expect(backend.review.nextStub.calls, hasLength(1));
    });

    testWidgets('無聲模式傳 audio_available = false', (tester) async {
      final backend = FakeBackend();
      final settings = applyPatch(
        allHintsSeen(),
        settingsPatch(silentMode: true),
      );
      backend.settings.current = settings;
      backend.settings.displayPolicyStub.returns(displayPolicyFixture());
      _sequence(backend, [_next('c1')]);

      await pumpApp(
        tester,
        backend: backend,
        settings: settings,
        child: const CardsScreen(),
      );

      expect(backend.review.nextStub.calls.first[1], isFalse);
    });
  });

  group('路由', () {
    Future<FakeBackend> pumpRoute(
      WidgetTester tester,
      List<SessionNextDto> results,
    ) async {
      final backend = FakeBackend();
      final settings = allHintsSeen();
      backend.settings.current = settings;
      backend.settings.displayPolicyStub.returns(displayPolicyFixture());
      backend.review.submitStub.returns(reviewOk());
      _sequence(backend, results);
      await pumpApp(
        tester,
        backend: backend,
        settings: settings,
        location: AppRoutes.sessionCards,
      );
      return backend;
    }

    Uri locationOf(WidgetTester tester) =>
        GoRouter.of(tester.element(find.byType(Navigator).first))
            .routerDelegate
            .currentConfiguration
            .uri;

    testWidgets('答完至少一張後 Done 進完成頁', (tester) async {
      await pumpRoute(tester, [_next('c1'), const SessionNextDto.done()]);

      await _answerAndContinue(tester);

      expect(locationOf(tester).path, AppRoutes.sessionDone);
    });

    testWidgets('一張都沒答就 Done 時留在本頁的空狀態', (tester) async {
      await pumpRoute(tester, [const SessionNextDto.done()]);

      expect(locationOf(tester).path, AppRoutes.sessionCards);
      expect(find.text('目前沒有到期卡片'), findsOneWidget);
    });

    testWidgets('Esc 離開', (tester) async {
      await pumpRoute(tester, [_next('c1')]);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(locationOf(tester).path, AppRoutes.today);
    });

    testWidgets('離開回今日', (tester) async {
      final backend = await pumpRoute(tester, [_next('c1')]);
      expect(find.text('離開'), findsOneWidget);

      await tester.tap(find.text('離開'));
      await tester.pumpAndSettle();

      expect(locationOf(tester).path, AppRoutes.today);
      expect(backend.review.submitStub.calls, isEmpty);
    });
  });

  testWidgets('CardRunner 跑完回報答題張數', (tester) async {
    final backend = FakeBackend();
    final settings = allHintsSeen();
    backend.settings.current = settings;
    backend.settings.displayPolicyStub.returns(displayPolicyFixture());
    backend.review.submitStub.returns(reviewOk());
    _sequence(backend, [_next('c1'), _next('c2'), const SessionNextDto.done()]);
    CardRunSummary? summary;

    await pumpApp(
      tester,
      backend: backend,
      settings: settings,
      child: CardRunner(onDone: (s) => summary = s),
    );
    await _answerAndContinue(tester);
    await _answerAndContinue(tester);

    expect(summary?.answered, 2);
  });

  testWidgets('CardRunner 帶 seed 時用它取卡，不讀今日資料', (tester) async {
    final backend = FakeBackend();
    final settings = allHintsSeen();
    backend.settings.current = settings;
    backend.settings.displayPolicyStub.returns(displayPolicyFixture());
    _sequence(backend, [_next('c1')]);

    await pumpApp(
      tester,
      backend: backend,
      settings: settings,
      child: CardRunner(seed: 42, onDone: (_) {}),
    );

    expect(backend.review.nextStub.calls.first[0], 42);
    expect(backend.today.todayStub.calls, isEmpty);
  });

  testWidgets('CardRunner 重新掛載時重新取卡，不沿用上一輪的 Done', (tester) async {
    final backend = FakeBackend();
    final settings = allHintsSeen();
    backend.settings.current = settings;
    backend.settings.displayPolicyStub.returns(displayPolicyFixture());
    _sequence(backend, [const SessionNextDto.done()]);
    final run = ValueNotifier(0);
    addTearDown(run.dispose);
    final reports = <int>[];

    await pumpApp(
      tester,
      backend: backend,
      settings: settings,
      child: ValueListenableBuilder<int>(
        valueListenable: run,
        builder: (_, value, _) => CardRunner(
          key: ValueKey(value),
          seed: 7,
          onDone: (_) => reports.add(value),
        ),
      ),
    );
    expect(reports, [0]);

    // 同一幀換掉舊的：T2 的複習結案後馬上進收尾就是這樣
    run.value = 1;
    await tester.pumpAndSettle();

    expect(reports, [0, 1]);
    expect(backend.review.nextStub.calls, hasLength(2));
  });

  testWidgets('320 寬、字級 2.0 倍不溢位', (tester) async {
    await _pumpScreen(tester, [_next('c1')], width: 320, textScale: 2);

    expect(tester.takeException(), isNull);
  });
}

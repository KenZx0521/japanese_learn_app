// SA-09：同一幀連點時不能重複送出判定；SA-12：R 重播題目。
import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';
import 'package:japanese_learn_app/features/quiz/quiz_session_controller.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import 'quiz_fixtures.dart';
import 'quiz_harness.dart';

void main() {
  late FakeBackend backend;
  late ProviderContainer container;
  late QuizSessionArgs args;

  setUp(() {
    backend = FakeBackend();
    container = ProviderContainer(
      overrides: repositoryOverrides(backend.repositories),
    );
    addTearDown(container.dispose);
    args = QuizSessionArgs(
      questions: [choiceQuestion()],
      grader: const DrillGrader(),
    );
    final subscription = container.listen(quizSessionProvider(args), (_, _) {});
    addTearDown(subscription.close);
  });

  test('判定中再次送出不會重送', () async {
    final gate = Completer<void>();
    backend.drills.gradeStub
      ..returns(drillOk)
      ..gate = gate.future;
    final controller = container.read(quizSessionProvider(args).notifier);

    final first = controller.submit(
      const AnswerPayload.choice(optionId: 'a'),
      durationMs: 10,
    );
    final second = controller.submit(
      const AnswerPayload.choice(optionId: 'b'),
      durationMs: 10,
    );
    gate.complete();
    await Future.wait([first, second]);

    expect(backend.drills.gradeStub.calls, hasLength(1));
  });

  test('沒有儲存失敗時 retry 不送判定', () async {
    backend.drills.gradeStub.returns(drillOk);
    final controller = container.read(quizSessionProvider(args).notifier);

    await controller.retry();

    expect(backend.drills.gradeStub.calls, isEmpty);
  });

  test('失敗後 retry 只重送一次', () async {
    backend.drills.gradeStub.throws(const StorageFailure());
    final controller = container.read(quizSessionProvider(args).notifier);
    await controller.submit(
      const AnswerPayload.choice(optionId: 'a'),
      durationMs: 10,
    );
    backend.drills.gradeStub.returns(drillOk);

    final retry = controller.retry();
    final doubled = controller.retry();
    await Future.wait([retry, doubled]);

    expect(backend.drills.gradeStub.calls, hasLength(2));
  });

  group('R 重播（§4.6）', () {
    const speech = SpeechDto(text: '猫', kana: 'ねこ');

    testWidgets('題幹有語音時重播一次', (tester) async {
      final tts = FakeTtsEngine();
      await pumpQuiz(
        tester,
        [
          choiceQuestion(
            type: QuestionType.vocabListen,
            prompt: promptFixture(speech: speech),
          ),
        ],
        backend: backend,
        tts: tts,
        settings: allHintsSeen(autoplay: false),
      );
      final before = tts.spoken.length;

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();

      expect(tts.spoken.length, before + 1);
    });

    testWidgets('打字題的 r 是輸入，不重播', (tester) async {
      final tts = FakeTtsEngine();
      await pumpQuiz(
        tester,
        [
          questionFixture(
            QuestionType.vocabListen,
            typingBodyFixture(),
            prompt: promptFixture(speech: speech),
          ),
        ],
        backend: backend,
        tts: tts,
        settings: allHintsSeen(autoplay: false),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final before = tts.spoken.length;

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();

      expect(tts.spoken.length, before);
    });
  });
}

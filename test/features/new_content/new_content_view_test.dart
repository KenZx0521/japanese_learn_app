import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/tts/fake_tts_engine.dart';
import 'package:japanese_learn_app/design/widgets/confusable_view.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/grammar_teach_card.dart';
import 'package:japanese_learn_app/design/widgets/kana_teach_card.dart';
import 'package:japanese_learn_app/design/widgets/rule_card_view.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/design/widgets/vocab_teach_card.dart';
import 'package:japanese_learn_app/features/new_content/new_content_view.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../quiz/quiz_fixtures.dart';

NewContentSessionDto _session(List<NewContentStepDto> steps) =>
    NewContentSessionDto(
      taskKey: 'new:le.k01:0',
      lessonId: 'le.k01',
      titleZh: 'あ行',
      steps: steps,
    );

QuestionDto _kanaQuestion() => choiceQuestion(
  type: QuestionType.kanaRead,
  body: choiceBodyFixture(
    options: [optionFixture('a', 'a'), optionFixture('b', 'i')],
  ),
  prompt: promptFixture(plainText: 'あ'),
  reference: refFixture(QuestionType.kanaRead, contentId: 'ka.hira.a'),
);

SessionCardDto _card() => SessionCardDto(
  cardId: 'vo.neko:recog',
  expectedReps: 2,
  facet: 'recog',
  question: choiceQuestion(reference: refFixture(QuestionType.recog)),
  ratingPreviews: const [],
  remainingEstimate: 0,
);

const _kanaResult = KanaSubmitResultDto(isCorrect: true, correctDisplay: 'a');

void main() {
  late FakeBackend backend;
  late int completed;

  setUp(() {
    backend = FakeBackend();
    completed = 0;
    backend.kana.submitStub.returns(_kanaResult);
    backend.review.submitStub.returns(reviewOk());
  });

  Future<void> pumpView(
    WidgetTester tester, {
    FakeTtsEngine? tts,
    VoidCallback? onSkip,
  }) async {
    await pumpApp(
      tester,
      backend: backend,
      tts: tts,
      child: NewContentView(
        taskKey: 'new:le.k01:0',
        lessonId: 'le.k01',
        seed: 7,
        onComplete: () => completed++,
        onSkip: onSkip,
      ),
    );
  }

  group('狀態', () {
    testWidgets('載入超過 200ms 顯示骨架', (tester) async {
      final gate = Completer<void>();
      backend.today.newContentStub
        ..gate = gate.future
        ..returns(_session(const []));

      await pumpApp(
        tester,
        backend: backend,
        settle: false,
        child: NewContentView(
          taskKey: 'k',
          lessonId: 'le.k01',
          seed: 1,
          onComplete: () {},
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SkeletonLines), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('沒有步驟時直接結案', (tester) async {
      backend.today.newContentStub.returns(_session(const []));

      await pumpView(tester);

      expect(completed, 1);
    });

    testWidgets('載入失敗 ErrorSlip 可重試，也可略過', (tester) async {
      backend.today.newContentStub.throws(const StorageFailure());
      var skipped = 0;

      await pumpView(tester, onSkip: () => skipped++);

      expect(find.byType(ErrorSlip), findsOneWidget);
      await tester.tap(find.text('略過這一項'));
      expect(skipped, 1);

      backend.today.newContentStub.returns(_session(const []));
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(completed, 1);
    });

    testWidgets('呼叫時帶 seed 與語音可用性', (tester) async {
      backend.today.newContentStub.returns(_session(const []));

      await pumpView(tester);

      expect(backend.today.newContentStub.calls.single, [
        'new:le.k01:0',
        7,
        true,
      ]);
    });

    testWidgets('無聲模式 audio_available 傳 false', (tester) async {
      backend.today.newContentStub.returns(_session(const []));
      backend.settings.current = settingsFixture(silentMode: true);

      await pumpView(tester);

      expect(backend.today.newContentStub.calls.single.last, isFalse);
    });
  });

  group('六種步驟', () {
    testWidgets('Kana 先教，再 KanaQuiz，走 kana_submit，全部完成才結案', (tester) async {
      final tts = FakeTtsEngine();
      backend.today.newContentStub.returns(
        _session([
          NewContentStepDto.kana(detail: kanaDetailFixture()),
          NewContentStepDto.kanaQuiz(questions: [_kanaQuestion()]),
        ]),
      );

      await pumpView(tester, tts: tts);

      expect(find.byType(KanaTeachCard), findsOneWidget);
      expect(tts.spoken.map((r) => r.text), contains('あ'));
      expect(completed, 0);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();

      expect(backend.kana.submitStub.calls, hasLength(1));
      expect(completed, 1);
    });

    testWidgets('K11–K15 切片後的 minimal_pair、打字 kana_word 都能作答，走 kana_submit', (
      tester,
    ) async {
      const pair = SpeechDto(text: 'かき', kana: 'かき');
      backend.today.newContentStub.returns(
        _session([
          NewContentStepDto.kanaQuiz(
            questions: [
              choiceQuestion(
                type: QuestionType.minimalPair,
                reference: refFixture(
                  QuestionType.minimalPair,
                  contentId: 'dr.k11.mpr.001',
                  drillId: 'dr.k11.mpr.001',
                  variant: 0,
                ),
                prompt: promptFixture(speech: pair, hide: true, autoplay: true),
                body: choiceBodyFixture(
                  options: [
                    optionFixture('a', '柿子', speech: pair),
                    optionFixture(
                      'b',
                      '鑰匙',
                      speech: const SpeechDto(text: 'かぎ', kana: 'かぎ'),
                    ),
                  ],
                ),
              ),
              questionFixture(
                QuestionType.kanaWord,
                typingBodyFixture(expected: 'かぎ'),
                prompt: promptFixture(plainText: '{ja:かぎ}'),
                reference: refFixture(
                  QuestionType.kanaWord,
                  contentId: 'dr.k11.kwd.001',
                  drillId: 'dr.k11.kwd.001',
                ),
              ),
            ],
          ),
        ]),
      );

      await pumpView(tester, tts: FakeTtsEngine());

      await tester.tap(find.text('柿子'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'kagi');
      await tester.pump();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();

      expect(backend.kana.submitStub.calls, hasLength(2));
      expect(completed, 1);
    });

    testWidgets('Rule、Confusable 依序呈現', (tester) async {
      backend.today.newContentStub.returns(
        _session([
          NewContentStepDto.rule(card: ruleCardFixture()),
          NewContentStepDto.confusable(group: confusableFixture()),
        ]),
      );

      await pumpView(tester);
      expect(find.byType(RuleCardView), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfusableView), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(completed, 1);
    });

    testWidgets('Vocab 有 first_card 按考一題，走 submit_answer', (tester) async {
      backend.today.newContentStub.returns(
        _session([
          NewContentStepDto.vocab(
            detail: vocabDetailFixture(),
            firstCard: _card(),
          ),
        ]),
      );
      backend.vocab.detailStub.returns(vocabDetailFixture());

      await pumpView(tester);
      expect(find.byType(VocabTeachCard), findsOneWidget);

      await tester.tap(find.text('考一題'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();

      final answer =
          backend.review.submitStub.calls.single.single! as AnswerDto;
      expect(answer.expectedReps, 2);
      expect(completed, 1);
    });

    testWidgets('Grammar 無 first_card 時按下一步結束', (tester) async {
      backend.today.newContentStub.returns(
        _session([
          NewContentStepDto.vocab(detail: vocabDetailFixture()),
          NewContentStepDto.vocab(
            detail: vocabDetailFixture(),
            firstCard: _card(),
          ),
          NewContentStepDto.grammar(detail: grammarDetailFixture()),
        ]),
      );
      backend.vocab.detailStub.returns(vocabDetailFixture());

      await pumpView(tester);
      // 開頭 first_card = None 的單字已跳過
      expect(find.text('考一題'), findsOneWidget);

      await tester.tap(find.text('考一題'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();

      expect(find.byType(GrammarTeachCard), findsOneWidget);
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(completed, 1);
    });
  });
}

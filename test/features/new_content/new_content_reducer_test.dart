import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/new_content/new_content_reducer.dart';

import '../../support/fixtures.dart';
import '../quiz/quiz_fixtures.dart';

const _rating = <RatingPreviewDto>[];

SessionCardDto _card() => SessionCardDto(
  cardId: 'vo.neko:recog',
  expectedReps: 0,
  facet: 'recog',
  question: choiceQuestion(),
  ratingPreviews: _rating,
  remainingEstimate: 0,
);

NewContentStepDto _kana() =>
    NewContentStepDto.kana(detail: kanaDetailFixture());
NewContentStepDto _quiz({List<QuestionDto>? questions}) =>
    NewContentStepDto.kanaQuiz(questions: questions ?? [choiceQuestion()]);
NewContentStepDto _vocab({bool withCard = true}) => NewContentStepDto.vocab(
  detail: vocabDetailFixture(),
  firstCard: withCard ? _card() : null,
);
NewContentStepDto _grammar({bool withCard = false}) =>
    NewContentStepDto.grammar(
      detail: grammarDetailFixture(),
      firstCard: withCard ? _card() : null,
    );

void main() {
  group('斷點續做', () {
    test('開頭連續 first_card = None 的單字、文法步驟跳過', () {
      final run = NewContentRun.start([
        _vocab(withCard: false),
        _grammar(),
        _vocab(),
        _grammar(),
      ]);

      expect(run.index, 2);
      expect(run.finished, isFalse);
    });

    test('假名步驟沒有斷點，從頭開始', () {
      final run = NewContentRun.start([_kana(), _quiz(), _vocab()]);

      expect(run.index, 0);
    });

    test('跳過到全部沒有內容時直接結束', () {
      final run = NewContentRun.start([_vocab(withCard: false), _grammar()]);

      expect(run.finished, isTrue);
    });

    test('沒有步驟時直接結束', () {
      expect(NewContentRun.start(const []).finished, isTrue);
    });
  });

  group('步驟前進', () {
    test('Kana 按下一步就前進', () {
      final run = reduceNewContent(
        NewContentRun.start([_kana(), _quiz()]),
        const NewContentTeachDone(),
      );

      expect(run.index, 1);
      expect(run.part, NewContentPart.teach);
    });

    test('有 first_card 的單字先進考題部分，答完才前進', () {
      var run = NewContentRun.start([_vocab(), _grammar()]);

      run = reduceNewContent(run, const NewContentTeachDone());
      expect(run.index, 0);
      expect(run.part, NewContentPart.firstCard);
      expect(run.currentCard, isNotNull);

      run = reduceNewContent(run, const NewContentQuizDone());
      expect(run.index, 1);
      expect(run.part, NewContentPart.teach);
    });

    test('first_card = None 的單字下一步直接前進', () {
      final run = reduceNewContent(
        NewContentRun.start([_kana(), _vocab(withCard: false), _kana()])
            .copy(index: 1),
        const NewContentTeachDone(),
      );

      expect(run.index, 2);
    });

    test('KanaQuiz 答完前進，最後一步結束', () {
      var run = NewContentRun.start([_kana(), _quiz()]);
      run = reduceNewContent(run, const NewContentTeachDone());

      run = reduceNewContent(run, const NewContentQuizDone());

      expect(run.finished, isTrue);
    });

    test('空的 KanaQuiz 不算步驟', () {
      final run = NewContentRun.start([
        _quiz(questions: const []),
        _kana(),
        _quiz(questions: const []),
      ]);

      expect(run.steps.length, 1);
      expect(run.steps.single, isA<NewContentStepDto_Kana>());
    });

    test('進度比例', () {
      final run = reduceNewContent(
        NewContentRun.start([_kana(), _quiz(), _kana(), _quiz()]),
        const NewContentTeachDone(),
      );

      expect(run.progress, 0.25);
    });
  });
}

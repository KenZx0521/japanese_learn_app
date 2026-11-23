import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/quiz/model/quiz_reducer.dart';
import 'package:japanese_learn_app/features/quiz/model/quiz_run_state.dart';
import 'package:japanese_learn_app/features/quiz/model/quiz_verdict.dart';

import 'quiz_fixtures.dart';

const _choiceA = AnswerPayload.choice(optionId: 'a');
const _right = QuizVerdict(isCorrect: true, correctDisplay: '貓');
const _wrong = QuizVerdict(isCorrect: false, correctDisplay: '貓');

QuizRunState _start(
  List<QuestionDto> questions, {
  bool requeueWrong = false,
  bool collect = false,
}) => QuizRunState.initial(
  questions,
  QuizRules(requeueWrong: requeueWrong, collectAnswers: collect),
);

QuizRunState _apply(QuizRunState state, List<QuizEvent> events) =>
    events.fold(state, reduceQuestionRun);

const QuizEvent _submit = QuizAnswerSubmitted(_choiceA, 1200);

void main() {
  group('reduceQuestionRun：一般流程', () {
    test('起始停在第一題作答中', () {
      final state = _start([choiceQuestion(), choiceQuestion()]);
      expect(state.index, 0);
      expect(state.phase, isA<QuizAnswering>());
      expect(state.total, 2);
      expect(state.completedCount, 0);
    });

    test('送出後進入判定中，帶著作答內容與耗時', () {
      final state = reduceQuestionRun(_start([choiceQuestion()]), _submit);
      final phase = state.phase as QuizGrading;
      expect(phase.payload, _choiceA);
      expect(phase.durationMs, 1200);
    });

    test('判定完顯示回饋，並寫入紀錄', () {
      final state = _apply(_start([choiceQuestion()]), [
        _submit,
        const QuizGradeSucceeded(_right),
      ]);
      expect((state.phase as QuizShowingFeedback).verdict, _right);
      expect(state.records.single.verdict, _right);
      expect(state.completedCount, 1);
    });

    test('繼續進到下一題，最後一題結束', () {
      var state = _apply(_start([choiceQuestion(), choiceQuestion()]), [
        _submit,
        const QuizGradeSucceeded(_right),
        const QuizAdvanceRequested(),
      ]);
      expect(state.index, 1);
      expect(state.phase, isA<QuizAnswering>());

      state = _apply(state, [
        _submit,
        const QuizGradeSucceeded(_right),
        const QuizAdvanceRequested(),
      ]);
      expect(state.phase, isA<QuizFinished>());
    });

    test('連點：判定中再送出會被忽略', () {
      final once = reduceQuestionRun(_start([choiceQuestion()]), _submit);
      final twice = reduceQuestionRun(
        once,
        const QuizAnswerSubmitted(AnswerPayload.choice(optionId: 'b'), 9),
      );
      expect(identical(twice, once), isTrue);
    });
  });

  group('reduceQuestionRun：不顯示回饋的情況', () {
    test('SelfGrade 判定後直接下一題', () {
      final state = _apply(_start([selfGradeQuestion(), choiceQuestion()]), [
        const QuizAnswerSubmitted(
          AnswerPayload.selfGrade(rating: Rating.good),
          900,
        ),
        const QuizGradeSucceeded(_right),
      ]);
      expect(state.index, 1);
      expect(state.phase, isA<QuizAnswering>());
      expect(state.records.single.payload, isA<AnswerPayload_SelfGrade>());
    });

    test('Shadow 判定後直接下一題，最後一題時結束', () {
      final state = _apply(_start([shadowQuestion()]), [
        const QuizAnswerSubmitted(
          AnswerPayload.shadow(level: ShadowLevel.almost),
          900,
        ),
        const QuizGradeSucceeded(_right),
      ]);
      expect(state.phase, isA<QuizFinished>());
    });

    test('檢定：不判定也不顯示回饋，累積 AnswerDto（expected_reps = 0）', () {
      final question = choiceQuestion(
        reference: refFixture(
          QuestionType.substitution,
          drillId: 'dr.9',
          variant: 2,
        ),
      );
      final state = _apply(
        _start([question, choiceQuestion()], collect: true),
        [_submit],
      );
      expect(state.index, 1);
      expect(state.phase, isA<QuizAnswering>());

      final done = _apply(state, [_submit]);
      expect(done.phase, isA<QuizFinished>());
      final first = done.outcome.answers.first;
      expect(first.reference, question.reference);
      expect(first.expectedReps, 0);
      expect(first.response, _choiceA);
      expect(first.hintUsed, isFalse);
      expect(first.attempts, 1);
      expect(first.durationMs, 1200);
      expect(done.records.first.verdict, isNull);
    });
  });

  group('reduceQuestionRun：答錯重出', () {
    test('答錯者在本回合末重出一次', () {
      final state = _apply(
        _start([choiceQuestion(), choiceQuestion()], requeueWrong: true),
        [_submit, const QuizGradeSucceeded(_wrong)],
      );
      expect(state.total, 3);
      expect(state.entries.last.isRetry, isTrue);
      expect(state.entries.last.question, state.entries.first.question);
    });

    test('重出的題再答錯不會無限重出', () {
      final state = _apply(_start([choiceQuestion()], requeueWrong: true), [
        _submit,
        const QuizGradeSucceeded(_wrong),
        const QuizAdvanceRequested(),
        _submit,
        const QuizGradeSucceeded(_wrong),
      ]);
      expect(state.total, 2);
    });

    test('沒開重出時不追加', () {
      final state = _apply(_start([choiceQuestion()]), [
        _submit,
        const QuizGradeSucceeded(_wrong),
      ]);
      expect(state.total, 1);
    });

    test('Match 不重出（不是逐字判定）', () {
      final state = _apply(_start([matchQuestion()], requeueWrong: true), [
        const QuizAnswerSubmitted(AnswerPayload.match(allCorrect: false), 500),
        const QuizGradeSucceeded(_wrong),
      ]);
      expect(state.total, 1);
    });
  });

  group('reduceQuestionRun：寫入失敗', () {
    test('失敗進 saveFailed，保留作答內容', () {
      final state = _apply(_start([choiceQuestion()]), [
        _submit,
        const QuizGradeFailed(StorageFailure()),
      ]);
      final phase = state.phase as QuizSaveFailed;
      expect(phase.payload, _choiceA);
      expect(phase.durationMs, 1200);
      expect(phase.failure, isA<StorageFailure>());
      expect(state.records, isEmpty);
    });

    test('重試回到判定中，內容不變', () {
      final state = _apply(_start([choiceQuestion()]), [
        _submit,
        const QuizGradeFailed(StorageFailure()),
        const QuizRetryRequested(),
      ]);
      final phase = state.phase as QuizGrading;
      expect(phase.payload, _choiceA);
      expect(phase.durationMs, 1200);
    });

    test('StaleCard 靜默前進，不留紀錄', () {
      final state = _apply(_start([choiceQuestion(), choiceQuestion()]), [
        _submit,
        const QuizStaleIgnored(),
      ]);
      expect(state.index, 1);
      expect(state.records, isEmpty);
      expect(state.phase, isA<QuizAnswering>());
    });

    test('StaleCard 在最後一題時結束', () {
      final state = _apply(_start([choiceQuestion()]), [
        _submit,
        const QuizStaleIgnored(),
      ]);
      expect(state.phase, isA<QuizFinished>());
    });
  });

  group('QuizOutcome', () {
    test('答對數只算第一次作答，重出的不計', () {
      final state = _apply(_start([choiceQuestion()], requeueWrong: true), [
        _submit,
        const QuizGradeSucceeded(_wrong),
        const QuizAdvanceRequested(),
        _submit,
        const QuizGradeSucceeded(_right),
        const QuizAdvanceRequested(),
      ]);
      expect(state.outcome.firstTryCount, 1);
      expect(state.outcome.firstTryCorrect, 0);
      expect(state.outcome.records, hasLength(2));
    });
  });

  test('reducer 不改動傳入的狀態', () {
    final state = _start([choiceQuestion()]);
    final before = state.entries.length;
    reduceQuestionRun(state, _submit);
    expect(state.phase, isA<QuizAnswering>());
    expect(state.entries.length, before);
  });
}

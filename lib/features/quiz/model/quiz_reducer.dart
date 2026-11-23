import '../../../core/backend/frb/dto.dart';
import 'answer_factory.dart';
import 'quiz_run_state.dart';
import 'quiz_verdict.dart';

/// 作答回合的唯一狀態轉移。純函式，時間與判定結果都由事件帶入。
QuizRunState reduceQuestionRun(QuizRunState state, QuizEvent event) =>
    switch (event) {
      QuizAnswerSubmitted() => _submit(state, event),
      QuizGradeSucceeded(:final verdict) => _graded(state, verdict),
      QuizGradeFailed() => _failed(state, event),
      QuizRetryRequested() => _retry(state),
      QuizAdvanceRequested() => _advance(state),
      QuizStaleIgnored() => _stale(state),
    };

QuizRunState _submit(QuizRunState state, QuizAnswerSubmitted event) {
  final entry = state.current;
  if (state.phase is! QuizAnswering || entry == null) return state;
  if (!state.rules.collectAnswers) {
    return state.copyWith(phase: QuizGrading(event.payload, event.durationMs));
  }
  return _next(
    state.copyWith(
      records: [..._recordsOf(state, entry, event.payload, event.durationMs)],
      answers: [
        ...state.answers,
        buildAnswer(
          entry.question.reference,
          event.payload,
          expectedReps: 0,
          durationMs: event.durationMs,
        ),
      ],
    ),
  );
}

List<QuizAnswerRecord> _recordsOf(
  QuizRunState state,
  QuizEntry entry,
  AnswerPayload payload,
  int durationMs, {
  QuizVerdict? verdict,
}) => [
  ...state.records,
  QuizAnswerRecord(
    question: entry.question,
    payload: payload,
    durationMs: durationMs,
    isRetry: entry.isRetry,
    verdict: verdict,
  ),
];

QuizRunState _graded(QuizRunState state, QuizVerdict verdict) {
  final phase = state.phase;
  final entry = state.current;
  if (phase is! QuizGrading || entry == null) return state;
  final recorded = state.copyWith(
    records: _recordsOf(
      state,
      entry,
      phase.payload,
      phase.durationMs,
      verdict: verdict,
    ),
    entries: _shouldRequeue(state, entry, verdict)
        ? List.unmodifiable([
            ...state.entries,
            QuizEntry(question: entry.question, isRetry: true),
          ])
        : null,
  );
  if (_skipsFeedback(entry.question.body)) return _next(recorded);
  return recorded.copyWith(
    phase: QuizShowingFeedback(phase.payload, phase.durationMs, verdict),
  );
}

bool _shouldRequeue(QuizRunState state, QuizEntry entry, QuizVerdict verdict) =>
    state.rules.requeueWrong &&
    !verdict.isCorrect &&
    !entry.isRetry &&
    _canRequeue(entry.question.body);

/// Match 不是逐字判定；自評與跟讀沒有「答錯」。
bool _canRequeue(QuestionBodyDto body) => switch (body) {
  QuestionBodyDto_Choice() ||
  QuestionBodyDto_Reorder() ||
  QuestionBodyDto_Typing() => true,
  QuestionBodyDto_Match() ||
  QuestionBodyDto_SelfGrade() ||
  QuestionBodyDto_Shadow() => false,
};

/// 自評與跟讀按完就換下一題，沒有對錯要回饋。
bool _skipsFeedback(QuestionBodyDto body) => switch (body) {
  QuestionBodyDto_SelfGrade() || QuestionBodyDto_Shadow() => true,
  QuestionBodyDto_Choice() ||
  QuestionBodyDto_Reorder() ||
  QuestionBodyDto_Typing() ||
  QuestionBodyDto_Match() => false,
};

QuizRunState _failed(QuizRunState state, QuizGradeFailed event) {
  final phase = state.phase;
  if (phase is! QuizGrading) return state;
  return state.copyWith(
    phase: QuizSaveFailed(phase.payload, phase.durationMs, event.failure),
  );
}

QuizRunState _retry(QuizRunState state) {
  final phase = state.phase;
  if (phase is! QuizSaveFailed) return state;
  return state.copyWith(phase: QuizGrading(phase.payload, phase.durationMs));
}

QuizRunState _advance(QuizRunState state) =>
    state.phase is QuizShowingFeedback ? _next(state) : state;

QuizRunState _stale(QuizRunState state) =>
    state.phase is QuizGrading ? _next(state) : state;

QuizRunState _next(QuizRunState state) {
  final next = state.index + 1;
  if (next >= state.entries.length) {
    return state.copyWith(index: next, phase: const QuizFinished());
  }
  return state.copyWith(index: next, phase: const QuizAnswering());
}

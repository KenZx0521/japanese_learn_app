import 'package:material_ui/material_ui.dart' show immutable;

import '../../../core/backend/failures.dart';
import '../../../core/backend/frb/dto.dart';
import 'quiz_verdict.dart';

/// 回合的規則，建立後不變。
@immutable
final class QuizRules {
  const QuizRules({this.requeueWrong = false, this.collectAnswers = false});

  /// D2、K2：答錯者本回合末重出一次（§3.3、§3.6）。
  final bool requeueWrong;

  /// D3：不判定、不顯示回饋，累積 `AnswerDto`（§3.6）。
  final bool collectAnswers;
}

@immutable
final class QuizEntry {
  const QuizEntry({required this.question, this.isRetry = false});
  final QuestionDto question;
  final bool isRetry;
}

@immutable
sealed class QuizPhase {
  const QuizPhase();
}

final class QuizAnswering extends QuizPhase {
  const QuizAnswering();
}

final class QuizGrading extends QuizPhase {
  const QuizGrading(this.payload, this.durationMs);
  final AnswerPayload payload;
  final int durationMs;
}

final class QuizShowingFeedback extends QuizPhase {
  const QuizShowingFeedback(this.payload, this.durationMs, this.verdict);
  final AnswerPayload payload;
  final int durationMs;
  final QuizVerdict verdict;
}

final class QuizSaveFailed extends QuizPhase {
  const QuizSaveFailed(this.payload, this.durationMs, this.failure);
  final AnswerPayload payload;
  final int durationMs;
  final AppFailure failure;
}

final class QuizFinished extends QuizPhase {
  const QuizFinished();
}

/// 不可變的回合狀態，只經由 `reduceQuestionRun` 轉移。
@immutable
final class QuizRunState {
  const QuizRunState({
    required this.entries,
    required this.index,
    required this.phase,
    required this.rules,
    this.records = const [],
    this.answers = const [],
  });

  factory QuizRunState.initial(List<QuestionDto> questions, QuizRules rules) =>
      QuizRunState(
        entries: List.unmodifiable([
          for (final question in questions) QuizEntry(question: question),
        ]),
        index: 0,
        phase: questions.isEmpty ? const QuizFinished() : const QuizAnswering(),
        rules: rules,
      );

  final List<QuizEntry> entries;
  final int index;
  final QuizPhase phase;
  final QuizRules rules;
  final List<QuizAnswerRecord> records;
  final List<AnswerDto> answers;

  QuizEntry? get current => index < entries.length ? entries[index] : null;

  int get total => entries.length;

  /// 進度條用：回饋中的這題算已完成。
  int get completedCount => switch (phase) {
    QuizFinished() => total,
    QuizShowingFeedback() => index + 1,
    QuizAnswering() || QuizGrading() || QuizSaveFailed() => index,
  };

  QuizOutcome get outcome => QuizOutcome(records: records, answers: answers);

  QuizRunState copyWith({
    List<QuizEntry>? entries,
    int? index,
    QuizPhase? phase,
    List<QuizAnswerRecord>? records,
    List<AnswerDto>? answers,
  }) => QuizRunState(
    entries: entries ?? this.entries,
    index: index ?? this.index,
    phase: phase ?? this.phase,
    rules: rules,
    records: records ?? this.records,
    answers: answers ?? this.answers,
  );
}

@immutable
sealed class QuizEvent {
  const QuizEvent();
}

final class QuizAnswerSubmitted extends QuizEvent {
  const QuizAnswerSubmitted(this.payload, this.durationMs);
  final AnswerPayload payload;
  final int durationMs;
}

final class QuizGradeSucceeded extends QuizEvent {
  const QuizGradeSucceeded(this.verdict);
  final QuizVerdict verdict;
}

final class QuizGradeFailed extends QuizEvent {
  const QuizGradeFailed(this.failure);
  final AppFailure failure;
}

final class QuizRetryRequested extends QuizEvent {
  const QuizRetryRequested();
}

final class QuizAdvanceRequested extends QuizEvent {
  const QuizAdvanceRequested();
}

/// `StaleCard` 代表連點，靜默略過（§3.4）。
final class QuizStaleIgnored extends QuizEvent {
  const QuizStaleIgnored();
}

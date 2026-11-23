import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/failures.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/local_log.dart';
import '../../core/backend/providers.dart';
import 'model/answer_factory.dart';
import 'model/quiz_reducer.dart';
import 'model/quiz_run_state.dart';
import 'model/quiz_verdict.dart';
import 'quiz_grader.dart';

/// family 參數。不覆寫 `==`，用 identity：同一個畫面實例持有同一份。
final class QuizSessionArgs {
  QuizSessionArgs({
    required this.questions,
    required this.grader,
    this.requeueWrong = false,
  });

  final List<QuestionDto> questions;
  final QuizGrader grader;
  final bool requeueWrong;

  QuizRules get rules => QuizRules(
    requeueWrong: requeueWrong,
    collectAnswers: grader is CheckpointCollector,
  );
}

final quizSessionProvider = NotifierProvider.autoDispose
    .family<QuizSessionController, QuizRunState, QuizSessionArgs>(
      QuizSessionController.new,
    );

/// 先 reduce 更新畫面，再 await 寫入；失敗進 saveFailed 顯示重試（architecture §5.2）。
class QuizSessionController extends Notifier<QuizRunState> {
  QuizSessionController(this.args);

  final QuizSessionArgs args;

  @override
  QuizRunState build() => QuizRunState.initial(args.questions, args.rules);

  void _dispatch(QuizEvent event) => state = reduceQuestionRun(state, event);

  /// 作答只在 `QuizAnswering` 有效：同一幀連點時，第二次不能再送一次判定。
  Future<void> submit(AnswerPayload payload, {required int durationMs}) async {
    if (state.phase is! QuizAnswering) return;
    _dispatch(QuizAnswerSubmitted(payload, durationMs));
    await _gradeCurrent();
  }

  Future<void> retry() async {
    if (state.phase is! QuizSaveFailed) return;
    _dispatch(const QuizRetryRequested());
    await _gradeCurrent();
  }

  void advance() => _dispatch(const QuizAdvanceRequested());

  Future<void> _gradeCurrent() async {
    final phase = state.phase;
    final entry = state.current;
    if (phase is! QuizGrading || entry == null) return;
    try {
      final verdict = await _grade(entry.question.reference, phase);
      if (ref.mounted) _dispatch(QuizGradeSucceeded(verdict));
    } on StaleCardFailure {
      if (ref.mounted) _dispatch(const QuizStaleIgnored());
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (ref.mounted) _dispatch(QuizGradeFailed(failure));
    }
  }

  Future<QuizVerdict> _grade(QuestionRefDto reference, QuizGrading phase) {
    final grader = args.grader;
    return switch (grader) {
      DrillGrader() =>
        ref
            .read(drillRepositoryProvider)
            .grade(reference, phase.payload)
            .then(verdictFromDrill),
      KanaGrader() =>
        ref
            .read(kanaRepositoryProvider)
            .submit(reference, phase.payload, phase.durationMs)
            .then(verdictFromKana),
      ReviewGrader(:final expectedReps) =>
        ref
            .read(reviewRepositoryProvider)
            .submit(
              buildAnswer(
                reference,
                phase.payload,
                expectedReps: expectedReps,
                durationMs: phase.durationMs,
              ),
            )
            .then(verdictFromReview),
      // reducer 已攔下，檢定模式不會進到判定中
      CheckpointCollector() => throw StateError('檢定不逐題判定'),
    };
  }
}

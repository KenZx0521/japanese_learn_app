import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/frb/dto.dart';
import 'model/quiz_verdict.dart';

/// 作答寫到哪裡（architecture §5.3「作答對應」）。由呼叫端選，
/// `QuizSessionController` 用 switch 窮舉。
@immutable
sealed class QuizGrader {
  const QuizGrader();
}

/// D2、聽力任務、G2 小測驗：`grade_drill`。
final class DrillGrader extends QuizGrader {
  const DrillGrader();
}

/// K2、L3 的 `KanaQuiz`：`kana_submit`。
final class KanaGrader extends QuizGrader {
  const KanaGrader();
}

/// V4、L3 的 `first_card`：`submit_answer`。[expectedReps] 取自 `SessionCardDto`。
final class ReviewGrader extends QuizGrader {
  const ReviewGrader({required this.expectedReps});
  final int expectedReps;
}

/// D3：只累積作答，結束時由 `checkpoint_finish` 一次判定。
final class CheckpointCollector extends QuizGrader {
  const CheckpointCollector();
}

QuizVerdict verdictFromDrill(DrillResultDto result) => QuizVerdict(
  isCorrect: result.isCorrect,
  correctDisplay: result.correctDisplay,
  explainZh: result.explainZh,
  whyZh: result.whyZh,
  reveal: result.reveal,
);

QuizVerdict verdictFromKana(KanaSubmitResultDto result) => QuizVerdict(
  isCorrect: result.isCorrect,
  correctDisplay: result.correctDisplay,
  mastery: result.mastery,
);

QuizVerdict verdictFromReview(AnswerResultDto result) => QuizVerdict(
  isCorrect: result.isCorrect,
  correctDisplay: result.correctDisplay,
  reveal: result.reveal,
  nextDueInMinutes: result.nextDueInMinutes.toInt(),
  unlockedCards: result.unlockedCards,
);

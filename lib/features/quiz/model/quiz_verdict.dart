import 'package:material_ui/material_ui.dart' show immutable;

import '../../../core/backend/frb/dto.dart';

/// 三種判定 API 的共同結果，以 Rust 回傳為準（§3.6）。
@immutable
final class QuizVerdict {
  const QuizVerdict({
    required this.isCorrect,
    this.correctDisplay = '',
    this.explainZh,
    this.whyZh,
    this.reveal,
    this.mastery,
    this.nextDueInMinutes,
    this.unlockedCards = 0,
  });

  final bool isCorrect;

  /// MixedText 字串；Match 為空字串。
  final String correctDisplay;
  final String? explainZh, whyZh;
  final SentenceDto? reveal;

  /// 只有計入熟練的假名題有值。
  final KanaMasteryDto? mastery;

  /// 只有 `submit_answer` 有值。
  final int? nextDueInMinutes;
  final int unlockedCards;
}

/// 一次作答。檢定模式由 Rust 最後判定，[verdict] 為 null。
@immutable
final class QuizAnswerRecord {
  const QuizAnswerRecord({
    required this.question,
    required this.payload,
    required this.durationMs,
    required this.isRetry,
    this.verdict,
  });

  final QuestionDto question;
  final AnswerPayload payload;
  final int durationMs;
  final bool isRetry;
  final QuizVerdict? verdict;
}

/// 整回合的結果，交給呼叫端決定下一步。
@immutable
final class QuizOutcome {
  const QuizOutcome({required this.records, required this.answers});

  final List<QuizAnswerRecord> records;

  /// 檢定累積的作答，傳給 `checkpoint_finish`；其他模式為空。
  final List<AnswerDto> answers;

  Iterable<QuizAnswerRecord> get _firstTries =>
      records.where((record) => !record.isRetry);

  int get firstTryCount => _firstTries.length;

  int get firstTryCorrect =>
      _firstTries.where((r) => r.verdict?.isCorrect ?? false).length;
}

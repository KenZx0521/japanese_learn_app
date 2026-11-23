import '../../../core/backend/frb/dto.dart';

/// `reference` 原樣帶回（含 `variant`），Dart 不解讀（architecture §5.3）。
AnswerDto buildAnswer(
  QuestionRefDto reference,
  AnswerPayload payload, {
  required int expectedReps,
  required int durationMs,
}) => AnswerDto(
  reference: reference,
  expectedReps: expectedReps,
  response: payload,
  hintUsed: false,
  attempts: 1,
  durationMs: durationMs,
);

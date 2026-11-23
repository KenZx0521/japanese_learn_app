import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/frb/dto.dart';

enum NewContentPart { teach, firstCard }

/// L3 的步驟進度（§3.10）。[start] 處理斷點續做與空的 `KanaQuiz`。
@immutable
final class NewContentRun {
  const NewContentRun._({
    required this.steps,
    required this.index,
    required this.part,
  });

  factory NewContentRun.start(List<NewContentStepDto> steps) {
    final kept = steps.where((step) => !_isEmptyQuiz(step)).toList();
    var index = 0;
    while (index < kept.length && _isAlreadyAnswered(kept[index])) {
      index++;
    }
    return NewContentRun._(
      steps: List.unmodifiable(kept),
      index: index,
      part: NewContentPart.teach,
    );
  }

  final List<NewContentStepDto> steps;
  final int index;
  final NewContentPart part;

  bool get finished => index >= steps.length;

  NewContentStepDto? get current => finished ? null : steps[index];

  SessionCardDto? get currentCard => switch (current) {
    NewContentStepDto_Vocab(:final firstCard) ||
    NewContentStepDto_Grammar(:final firstCard) => firstCard,
    _ => null,
  };

  double get progress => steps.isEmpty ? 1 : index / steps.length;

  NewContentRun copy({int? index, NewContentPart? part}) => NewContentRun._(
    steps: steps,
    index: index ?? this.index,
    part: part ?? this.part,
  );

  static bool _isEmptyQuiz(NewContentStepDto step) =>
      step is NewContentStepDto_KanaQuiz && step.questions.isEmpty;

  /// 開頭連續 `first_card = None` 的 Vocab、Grammar 已經答過（§3.10）。
  static bool _isAlreadyAnswered(NewContentStepDto step) => switch (step) {
    NewContentStepDto_Vocab(:final firstCard) ||
    NewContentStepDto_Grammar(:final firstCard) => firstCard == null,
    _ => false,
  };
}

@immutable
sealed class NewContentEvent {
  const NewContentEvent();
}

/// 呈現類步驟按「下一步」或「考一題」。
final class NewContentTeachDone extends NewContentEvent {
  const NewContentTeachDone();
}

/// `KanaQuiz` 或 `first_card` 答完。
final class NewContentQuizDone extends NewContentEvent {
  const NewContentQuizDone();
}

NewContentRun reduceNewContent(NewContentRun run, NewContentEvent event) =>
    switch (event) {
      NewContentTeachDone() =>
        run.currentCard == null
            ? run.copy(index: run.index + 1, part: NewContentPart.teach)
            : run.copy(part: NewContentPart.firstCard),
      NewContentQuizDone() => run.copy(
        index: run.index + 1,
        part: NewContentPart.teach,
      ),
    };

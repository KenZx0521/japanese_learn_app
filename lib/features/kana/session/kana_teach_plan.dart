import 'package:material_ui/material_ui.dart' show immutable;

import '../../../core/backend/frb/dto.dart';

/// K2 測驗前要呈現的內容（§3.3 先教後考）。
@immutable
sealed class KanaTeachStep {
  const KanaTeachStep();
}

final class KanaCharStep extends KanaTeachStep {
  const KanaCharStep(this.detail);
  final KanaDetailDto detail;
}

final class KanaRuleStep extends KanaTeachStep {
  const KanaRuleStep(this.card);
  final RuleCardDto card;
}

final class KanaConfusableStep extends KanaTeachStep {
  const KanaConfusableStep(this.group);
  final ConfusableDto group;
}

bool _isKanaCharId(String id) =>
    id.startsWith('ka.hira.') || id.startsWith('ka.kata.');

/// 題目實際會考到的字。`kana_session` 的易混題可能考別課的字（字組的成員），
/// 只看本課會漏掉，第一題就可能考到沒看過的字。
Set<String> kanaTargetsOf(List<QuestionDto> questions) => {
  for (final question in questions) ...[
    if (_isKanaCharId(question.reference.contentId))
      question.reference.contentId,
    ...question.focusIds.where(_isKanaCharId),
  ],
};

/// 規則課（K16–K19）大多沒有新字，字的狀態看不出讀過沒，改看課的狀態：
/// 課已完成或略過就不再呈現；課內有字時，要有字還沒學過才呈現。
List<RuleCardDto> rulesToTeach(LessonDetailDto lesson) {
  final finished = switch (lesson.summary.status) {
    LessonStatus.done || LessonStatus.skipped => true,
    LessonStatus.notStarted || LessonStatus.current => false,
  };
  final hasNewChar = lesson.kana.any(
    (cell) => cell.status == KanaStatus.notStarted,
  );
  return finished || (lesson.kana.isNotEmpty && !hasNewChar)
      ? const []
      : lesson.rules;
}

/// [details] 只呈現尚未開始的字（維持傳入順序），之後是 [rules]；有 `kana_confuse`
/// 題的字組排在最後，比對 `explain_zh`（Rust 以字組的 `diff_zh` 當題目解說）。
List<KanaTeachStep> buildTeachSteps(
  List<KanaDetailDto> details,
  List<QuestionDto> questions, {
  List<RuleCardDto> rules = const [],
}) {
  final fresh = [
    for (final detail in details)
      if (detail.cell.status == KanaStatus.notStarted) detail,
  ];
  final freshById = {for (final detail in fresh) detail.cell.id: detail};
  final groups = <String, ConfusableDto>{};
  for (final question in questions) {
    if (question.questionType != QuestionType.kanaConfuse) continue;
    final confusables =
        freshById[question.reference.contentId]?.confusables ?? const [];
    for (final group in confusables) {
      if (group.diffZh == question.explainZh) {
        groups.putIfAbsent(group.id, () => group);
      }
    }
  }
  return [
    for (final detail in fresh) KanaCharStep(detail),
    for (final card in rules) KanaRuleStep(card),
    for (final group in groups.values) KanaConfusableStep(group),
  ];
}

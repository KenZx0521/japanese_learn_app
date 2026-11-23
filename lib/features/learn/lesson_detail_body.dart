import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/course_groups.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/hanko_badge.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/side_rule_note.dart';
import 'course_outline.dart';
import 'lesson_detail_sections.dart';

/// L2 主欄：標題、can-do、練習入口與內容。
class LessonDetailBody extends StatelessWidget {
  const LessonDetailBody({
    required this.detail,
    required this.wide,
    required this.romajiMode,
    super.key,
  });

  final LessonDetailDto detail;
  final bool wide;
  final RomajiMode? romajiMode;

  bool get _isEmpty =>
      !canPracticeKana(detail) &&
      detail.kana.isEmpty &&
      detail.rules.isEmpty &&
      detail.words.isEmpty &&
      detail.grammar.isEmpty &&
      detail.dialogue == null;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final summary = detail.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(summary: summary),
        const SizedBox(height: AppSpace.s5),
        SideRuleNote(title: '學完這一課', child: MixedText(summary.canDoZh)),
        const SizedBox(height: AppSpace.s5),
        _PracticeButtons(detail: detail),
        if (_isEmpty)
          AppText('這一課的內容還沒準備好', color: t.ink.secondary)
        else if (wide)
          LessonDetailSections.main(detail: detail, romajiMode: romajiMode)
        else
          LessonDetailSections.all(detail: detail, romajiMode: romajiMode),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.summary});

  final LessonSummaryDto summary;

  String? get _statusNote => switch (summary.status) {
    LessonStatus.current => '目前學到這一課',
    LessonStatus.notStarted => '還沒學到這一課，可以先看內容。',
    LessonStatus.skipped => '這一課略過了，想看隨時可以看。',
    LessonStatus.done => null,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final note = _statusNote;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(lessonNumberLabel(summary.id), scale: TypeScale.displayM),
              const SizedBox(height: AppSpace.s1),
              MixedText(summary.titleZh, scale: TypeScale.title),
              if (note != null) ...[
                const SizedBox(height: AppSpace.s1),
                AppText(note, scale: TypeScale.caption, color: t.ink.secondary),
              ],
            ],
          ),
        ),
        if (summary.status == LessonStatus.done) ...[
          const SizedBox(width: AppSpace.s3),
          const HankoBadge('済', size: 48, semanticLabel: '這一課學完了'),
        ],
      ],
    );
  }
}

/// 假名課進 K2，主線課進 D2。只有規則說明的假名課沒有題目，不顯示。
class _PracticeButtons extends StatelessWidget {
  const _PracticeButtons({required this.detail});

  final LessonDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final id = detail.summary.id;
    final (label, route) = switch ((
      canPracticeKana(detail),
      isMainLesson(id),
    )) {
      (true, _) => ('練這一課的假名', AppRoutes.kanaSession(id)),
      (_, true) => ('練這一課的句型', AppRoutes.sessionDrill(lesson: id)),
      _ => (null, null),
    };
    if (label == null || route == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: InkButton(
        label: label,
        onPressed: () => unawaited(context.push(route)),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/failures.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/local_log.dart';
import '../../../core/text/mixed_text.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/side_rule_note.dart';
import '../plan_providers.dart';
import '../scope_copy.dart';

/// 目前位置與完成日（§3.8 第 2 點）：一律標明粗估。
class PlanPosition extends StatelessWidget {
  const PlanPosition({required this.data, super.key});

  final PlanPageData data;

  @override
  Widget build(BuildContext context) {
    final view = data.view;
    final mainEnd = view.mainForecastEnd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CurrentLesson(
          lessonId: view.currentLessonId,
          lessons: data.overview.lessons,
        ),
        const SizedBox(height: AppSpace.s3),
        if (mainEnd != null) AppText(forecastLine(data.stage, mainEnd)),
        if (view.status == PlanStatus.behind) ...[
          const SizedBox(height: AppSpace.s4),
          _BehindNote(view: view),
        ],
      ],
    );
  }
}

class _CurrentLesson extends StatelessWidget {
  const _CurrentLesson({required this.lessonId, required this.lessons});

  final String? lessonId;
  final List<LessonSummaryDto> lessons;

  @override
  Widget build(BuildContext context) {
    final id = lessonId;
    if (id == null) {
      return const AppText('這一版的內容都學完了，複習照常', scale: TypeScale.title);
    }
    final title = lessons.where((l) => l.id == id).firstOrNull?.titleZh;
    final ordinal = lessonOrdinalOf(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ordinal != null)
          AppText(
            ordinal,
            scale: TypeScale.label,
            color: AppTokens.of(context).ink.secondary,
          ),
        if (title != null) MixedText(title, scale: TypeScale.title),
      ],
    );
  }
}

class _BehindNote extends ConsumerStatefulWidget {
  const _BehindNote({required this.view});
  final PlanViewDto view;

  @override
  ConsumerState<_BehindNote> createState() => _BehindNoteState();
}

class _BehindNoteState extends ConsumerState<_BehindNote> {
  bool _busy = false;
  String? _error;

  Future<void> _apply(int minutes) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await applyPlanInput(ref, withMinutes(widget.view.input, minutes));
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) setState(() => _error = failure.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggested = widget.view.suggestedMinutes;
    final error = _error;
    return SideRuleNote(
      title: '進度比目標慢一點',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            suggested == null
                ? '照現在的安排趕不上目標日期，每天時間拉到最長也一樣。可以放寬目標日期或增加學習日。'
                : '照現在的安排趕不上目標日期。改成每天 $suggested 分鐘就趕得上（粗估）。',
          ),
          if (suggested != null) ...[
            const SizedBox(height: AppSpace.s3),
            GhostButton(
              label: '改成每天 $suggested 分鐘',
              onPressed: _busy ? null : () => unawaited(_apply(suggested)),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: AppSpace.s2),
            Semantics(
              liveRegion: true,
              child: AppText(
                error,
                scale: TypeScale.caption,
                color: AppTokens.of(context).shu,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

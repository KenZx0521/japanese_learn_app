import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/course_groups.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/ruled_list.dart';

final _courseProvider = FutureProvider.autoDispose<CourseOverviewDto>(
  (ref) => ref.watch(courseRepositoryProvider).overview(),
);

/// D1 句型演練入口（§3.6）：依課列出，假名課在前，所以目前的課另外放最上面。
class DrillsEntryScreen extends ConsumerWidget {
  const DrillsEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageBackLink(fallback: AppRoutes.learn),
          const AppText('句型演練', scale: TypeScale.displayM),
          const SizedBox(height: AppSpace.s2),
          AppText('選一課來練。答錯的題目，這一輪最後會再出一次。', color: t.ink.secondary),
          const SizedBox(height: AppSpace.s6),
          AsyncBody<CourseOverviewDto>(
            value: ref.watch(_courseProvider),
            onRetry: () => ref.invalidate(_courseProvider),
            data: (overview) => _LessonGroups(overview: overview),
          ),
        ],
      ),
    );
  }
}

class _LessonGroups extends StatelessWidget {
  const _LessonGroups({required this.overview});
  final CourseOverviewDto overview;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (overview.lessons.isEmpty) {
      return AppText('這一版還沒有可以練的課', color: t.ink.secondary);
    }
    final current = overview.lessons
        .where((lesson) => lesson.id == overview.currentLessonId)
        .firstOrNull;
    final groups = groupByStage(
      overview.lessons,
      overview.stages,
      (lesson) => lesson.stageId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != null) ...[
          const EyebrowText('接著練'),
          const SizedBox(height: AppSpace.s2),
          RuledList(children: [_LessonTile(lesson: current)]),
          const SizedBox(height: AppSpace.s6),
        ],
        for (final (index, group) in groups.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpace.s6),
          MixedText(
            group.stage.titleZh,
            scale: TypeScale.label,
            color: t.ink.secondary,
          ),
          const SizedBox(height: AppSpace.s2),
          RuledList(
            children: [
              for (final lesson in group.items) _LessonTile(lesson: lesson),
            ],
          ),
        ],
      ],
    );
  }
}

/// 未學的課仍可點（不鎖定）；能不能出題由 Rust 決定，沒題時 D2 顯示空狀態。
class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson});
  final LessonSummaryDto lesson;

  String? get _statusText => switch (lesson.status) {
    LessonStatus.current => '目前',
    LessonStatus.done => '學完了',
    LessonStatus.skipped => '略過',
    LessonStatus.notStarted => null,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final faded = lesson.status == LessonStatus.notStarted;
    final status = _statusText;
    return RuledTile(
      title: MixedText(
        lessonHeadline(lesson),
        color: faded ? t.ink.tertiary : null,
      ),
      subtitle: MixedText(
        lesson.canDoZh,
        scale: TypeScale.caption,
        color: faded ? t.ink.tertiary : t.ink.secondary,
      ),
      trailing: status == null
          ? null
          : AppText(status, scale: TypeScale.label, color: t.ink.secondary),
      onTap: () =>
          unawaited(context.push(AppRoutes.sessionDrill(lesson: lesson.id))),
    );
  }
}

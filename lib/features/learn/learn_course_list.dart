import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/course_groups.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/ruled_list.dart';
import 'course_outline.dart';
import 'skip_slash.dart';

/// L1 的課程：依階段分組，目前所在的段落打開，其他收起。
class LearnCourseList extends StatelessWidget {
  const LearnCourseList({required this.overview, super.key});

  final CourseOverviewDto overview;

  @override
  Widget build(BuildContext context) {
    final stages = courseOutline(overview);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, stage) in stages.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpace.s6),
          _StageBlock(stage: stage, currentId: overview.currentLessonId),
        ],
      ],
    );
  }
}

class _StageBlock extends StatelessWidget {
  const _StageBlock({required this.stage, required this.currentId});

  final StageOutline stage;
  final String? currentId;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: MixedText(stage.stage.titleZh, scale: TypeScale.title),
          ),
          const SizedBox(width: AppSpace.s3),
          _CountLabel(finished: stage.finished, total: stage.total),
        ],
      ),
      const SizedBox(height: AppSpace.s2),
      for (final section in stage.sections)
        if (section.title == null)
          _LessonRows(lessons: section.lessons)
        else
          _FoldSection(
            key: ValueKey(section.title),
            section: section,
            currentId: currentId,
          ),
    ],
  );
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.finished, required this.total});

  final int finished, total;

  @override
  Widget build(BuildContext context) => AppText(
    '$finished／$total',
    scale: TypeScale.label,
    color: AppTokens.of(context).ink.secondary,
    semanticsLabel: '完成 $finished 課，共 $total 課',
  );
}

/// 預設只打開目前的課所在的段落；目前的課移進來時自動打開。
class _FoldSection extends StatefulWidget {
  const _FoldSection({
    required this.section,
    required this.currentId,
    super.key,
  });

  final LessonSection section;
  final String? currentId;

  @override
  State<_FoldSection> createState() => _FoldSectionState();
}

class _FoldSectionState extends State<_FoldSection> {
  late bool _open = widget.section.holds(widget.currentId);

  @override
  void didUpdateWidget(_FoldSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final holds = widget.section.holds(widget.currentId);
    if (holds && !oldWidget.section.holds(oldWidget.currentId)) {
      _open = true;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _FoldHeader(
        section: widget.section,
        open: _open,
        onTap: () => setState(() => _open = !_open),
      ),
      if (_open) _LessonRows(lessons: widget.section.lessons),
    ],
  );
}

class _FoldHeader extends StatelessWidget {
  const _FoldHeader({
    required this.section,
    required this.open,
    required this.onTap,
  });

  final LessonSection section;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final note = section.note;
    return Pressable(
      onTap: onTap,
      builder: (context, state) => ColoredBox(
        color: state.hovered ? t.paper.raised : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpace.s3,
            horizontal: AppSpace.s1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(section.title ?? '', scale: TypeScale.label),
                    if (note != null)
                      AppText(
                        note,
                        scale: TypeScale.caption,
                        color: t.ink.secondary,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              _CountLabel(
                finished: section.finished,
                total: section.lessons.length,
              ),
              const SizedBox(width: AppSpace.s3),
              AppText(
                open ? '收起' : '打開',
                scale: TypeScale.label,
                color: t.ink.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonRows extends StatelessWidget {
  const _LessonRows({required this.lessons});

  final List<LessonSummaryDto> lessons;

  @override
  Widget build(BuildContext context) => RuledList(
    children: [for (final lesson in lessons) _LessonRow(lesson: lesson)],
  );
}

/// 未到的課淡色但仍可點（不鎖定），狀態永遠有文字，色彩只是輔助。
class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson});

  final LessonSummaryDto lesson;

  bool get _isCurrent => lesson.status == LessonStatus.current;

  String get _statusText => switch (lesson.status) {
    LessonStatus.current => '目前',
    LessonStatus.done => '學完了',
    LessonStatus.skipped => '略過',
    LessonStatus.notStarted => '還沒到',
  };

  /// 假名課課名已經說明內容，只有主線課和目前的課要多一行 can-do。
  bool get _showsCanDo => _isCurrent || isMainLesson(lesson.id);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final faded = lesson.status == LessonStatus.notStarted;
    return RuledTile(
      leading: _StatusMark(status: lesson.status),
      title: MixedText(
        lessonHeadline(lesson),
        color: faded ? t.ink.tertiary : null,
      ),
      subtitle: _showsCanDo
          ? MixedText(
              lesson.canDoZh,
              scale: TypeScale.caption,
              color: faded ? t.ink.tertiary : t.ink.secondary,
            )
          : null,
      trailing: AppText(
        _statusText,
        scale: _isCurrent ? TypeScale.label : TypeScale.caption,
        color: _isCurrent ? t.ink.primary : t.ink.secondary,
      ),
      onTap: () => unawaited(context.push(AppRoutes.lesson(lesson.id))),
    );
  }
}

/// 列首的小方格：和最上面稿紙條同一套語言，目前的課用墨色實心。
class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.status});

  final LessonStatus status;

  static const _size = 10.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final fill = switch (status) {
      LessonStatus.current => t.ink.primary,
      LessonStatus.done => t.ink.secondary,
      LessonStatus.skipped => t.line.grid,
      LessonStatus.notStarted => null,
    };
    return ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: t.line.strong),
        ),
        child: status == LessonStatus.skipped
            ? CustomPaint(painter: SkipSlashPainter(color: t.ink.secondary))
            : null,
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
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
import 'course_outline.dart';
import 'skip_slash.dart';

/// L1 最上面：目前學到哪、整體走到哪、下一課是什麼。
class LearnCurrentBlock extends StatelessWidget {
  const LearnCurrentBlock({required this.overview, super.key});

  final CourseOverviewDto overview;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (overview.lessons.isEmpty) {
      return AppText('這一版還沒有課程內容', color: t.ink.secondary);
    }
    final currentId = overview.currentLessonId;
    if (currentId == null) return const _AllDone();
    final index = overview.lessons.indexWhere((l) => l.id == currentId);
    if (index < 0) return const SizedBox.shrink();
    return _CurrentLesson(
      lesson: overview.lessons[index],
      position: index + 1,
      lessons: overview.lessons,
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: AppText('這一版的內容都學完了，複習照常。')),
      SizedBox(width: AppSpace.s3),
      HankoBadge('済', size: 48, semanticLabel: '全部學完了'),
    ],
  );
}

class _CurrentLesson extends StatelessWidget {
  const _CurrentLesson({
    required this.lesson,
    required this.position,
    required this.lessons,
  });

  final LessonSummaryDto lesson;
  final int position;
  final List<LessonSummaryDto> lessons;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final next = lessonAfter(lessons, lesson.id);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.ink.primary, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProgressLine(position: position, total: lessons.length),
            const SizedBox(height: AppSpace.s2),
            MixedText(lessonHeadline(lesson), scale: TypeScale.title),
            const SizedBox(height: AppSpace.s1),
            MixedText(lesson.canDoZh, color: t.ink.secondary),
            const SizedBox(height: AppSpace.s3),
            _CourseStrip(lessons: lessons, currentId: lesson.id),
            const SizedBox(height: AppSpace.s4),
            InkButton(
              label: '看課程詳情',
              onPressed: () =>
                  unawaited(context.push(AppRoutes.lesson(lesson.id))),
            ),
            if (next != null) ...[
              const SizedBox(height: AppSpace.s2),
              MixedText(
                '下一課：${lessonHeadline(next)}',
                scale: TypeScale.caption,
                color: t.ink.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.position, required this.total});

  final int position, total;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: AppSpace.s3,
      runSpacing: AppSpace.s1,
      children: [
        const EyebrowText('目前課程'),
        AppText(
          '進度 $position／$total',
          scale: TypeScale.label,
          color: AppTokens.of(context).ink.secondary,
        ),
      ],
    ),
  );
}

/// 一課一格的稿紙條，依學習順序，看得出假名課與主線課走到哪。進度已有文字，
/// 這裡只是裝飾。朱色只留給目前這一格（§4.1）。
class _CourseStrip extends StatelessWidget {
  const _CourseStrip({required this.lessons, required this.currentId});

  final List<LessonSummaryDto> lessons;
  final String currentId;

  static const _cell = 14.0;
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + _gap) / (_cell + _gap))
            .floor()
            .clamp(1, lessons.length);
        final rows = (lessons.length / columns).ceil();
        return ExcludeSemantics(
          child: SizedBox(
            height: rows * _cell + (rows - 1) * _gap,
            width: double.infinity,
            child: CustomPaint(
              painter: _StripPainter(
                fills: [
                  for (final lesson in lessons)
                    lesson.id == currentId ? t.shu : _fillOf(t, lesson.status),
                ],
                skipped: [
                  for (final lesson in lessons)
                    lesson.status == LessonStatus.skipped,
                ],
                border: t.line.grid,
                slash: t.ink.secondary,
                columns: columns,
                cell: _cell,
                gap: _gap,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 略過用 `line.grid` 再加斜線：`paper.sunken` 在深色模式和紙面幾乎同色，
  /// 看起來跟未開始的空格一樣；`line.strong` 又太接近已完成的墨色。
  Color? _fillOf(AppTokens t, LessonStatus status) => switch (status) {
    LessonStatus.done => t.ink.secondary,
    LessonStatus.skipped => t.line.grid,
    LessonStatus.current || LessonStatus.notStarted => null,
  };
}

class _StripPainter extends CustomPainter {
  const _StripPainter({
    required this.fills,
    required this.skipped,
    required this.border,
    required this.slash,
    required this.columns,
    required this.cell,
    required this.gap,
  });

  final List<Color?> fills;
  final List<bool> skipped;
  final Color border, slash;
  final int columns;
  final double cell, gap;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = border
      ..style = PaintingStyle.stroke;
    for (final (index, fill) in fills.indexed) {
      final rect = Rect.fromLTWH(
        (index % columns) * (cell + gap),
        (index ~/ columns) * (cell + gap),
        cell,
        cell,
      );
      if (fill != null) canvas.drawRect(rect, Paint()..color = fill);
      if (skipped[index]) drawSkipSlash(canvas, rect, slash);
      canvas.drawRect(rect, line);
    }
  }

  @override
  bool shouldRepaint(_StripPainter oldDelegate) =>
      oldDelegate.columns != columns ||
      oldDelegate.border != border ||
      oldDelegate.slash != slash ||
      !listEquals(oldDelegate.fills, fills) ||
      !listEquals(oldDelegate.skipped, skipped);
}

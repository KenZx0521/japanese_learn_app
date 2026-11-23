import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/hanko_badge.dart';
import '../../design/widgets/ruled_list.dart';
import 'today_copy.dart';
import 'today_providers.dart';

/// 任務清單：順序由 Rust 固定，第一個未完成的項目展開成主要動作（§3.2）。
class TodayTaskList extends ConsumerWidget {
  const TodayTaskList({required this.view, super.key});

  final TodayViewDto view;

  static const _rowStampSize = 28.0;

  TaskDto? _currentOf(List<TaskDto> tasks) {
    for (final task in tasks) {
      if (!task.done) return task;
    }
    return null;
  }

  void _start(BuildContext context, String? key) =>
      unawaited(context.push(AppRoutes.sessionToday(start: key)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = visibleTasks(view);
    final current = _currentOf(tasks);
    final inProgress = ref.watch(taskInProgressProvider);
    return RuledList(
      children: [
        for (final (index, task) in tasks.indexed)
          _TaskRow(
            task: task,
            ordinal: ordinalLabel(index),
            reviewCap: view.budget.reviewCap,
            actionLabel: task.key == current?.key
                ? (inProgress == task.key ? '繼續' : '開始')
                : null,
            onStart: () => _start(context, task.key),
          ),
        if (current == null && view.learningTail > 0)
          _TailRow(
            count: view.learningTail,
            ordinal: ordinalLabel(tasks.length),
            onStart: () => _start(context, null),
          ),
      ],
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({
    required this.task,
    required this.ordinal,
    required this.reviewCap,
    required this.actionLabel,
    required this.onStart,
  });

  final TaskDto task;
  final String ordinal;
  final int reviewCap;

  /// 非 null 代表當前項，展開主要動作。
  final String? actionLabel;
  final VoidCallback onStart;

  String _detail(WidgetRef ref) => switch (task) {
    TaskDto_Checkpoint(:final milestoneId) => taskDetail(
      task,
      reviewCap: reviewCap,
      milestoneTitle: ref.watch(milestoneTitleProvider(milestoneId)).value,
    ),
    _ => taskDetail(task, reviewCap: reviewCap),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final action = actionLabel;
    final muted = task.done;
    return RuledTile(
      leading: AppText(
        ordinal,
        scale: TypeScale.title,
        color: muted ? t.ink.tertiary : t.ink.secondary,
      ),
      title: MixedText(
        taskTitle(task),
        color: muted ? t.ink.tertiary : t.ink.primary,
      ),
      subtitle: _subtitle(ref, t, muted),
      trailing: _trailing(action),
      onTap: muted ? null : onStart,
    );
  }

  /// 里程碑的副標是內容的 `title_zh`，可能帶 `{ja:}` 標記（flutter-app §7.3）。
  bool get _detailFromContent => task is TaskDto_Checkpoint;

  Widget? _subtitle(WidgetRef ref, AppTokens t, bool muted) {
    final detail = _detail(ref);
    if (detail.isEmpty) return null;
    final color = muted ? t.ink.tertiary : t.ink.secondary;
    if (_detailFromContent) {
      return MixedText(detail, scale: TypeScale.caption, color: color);
    }
    return AppText(detail, scale: TypeScale.caption, color: color);
  }

  Widget? _trailing(String? action) {
    // 只剩收尾新卡時後端回 done，但今天還沒碰過，不蓋完成章
    if (isTailOnlyReview(task)) return null;
    if (task.done) {
      return const HankoBadge(
        '済',
        size: TodayTaskList._rowStampSize,
        semanticLabel: '已完成',
        muted: true,
      );
    }
    return action == null ? null : _ActionPill(label: action);
  }
}

/// 整列就是按鈕（≥48dp），這裡只是視覺上的主要動作，避免按鈕包按鈕。
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s4,
        vertical: AppSpace.s2,
      ),
      decoration: BoxDecoration(
        color: t.ink.primary,
        borderRadius: AppRadii.r1,
      ),
      child: AppText(label, scale: TypeScale.label, color: t.paper.base),
    );
  }
}

class _TailRow extends StatelessWidget {
  const _TailRow({
    required this.count,
    required this.ordinal,
    required this.onStart,
  });

  final int count;
  final String ordinal;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return RuledTile(
      leading: AppText(ordinal, scale: TypeScale.title, color: t.ink.secondary),
      title: const AppText('收尾'),
      subtitle: AppText(
        '$count 張',
        scale: TypeScale.caption,
        color: t.ink.secondary,
      ),
      trailing: const _ActionPill(label: '開始'),
      onTap: onStart,
    );
  }
}

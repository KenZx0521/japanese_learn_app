import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/genko_grid.dart';
import '../../../design/widgets/hanko_badge.dart';
import '../scope_copy.dart';

const _daysPerWeek = 7;
const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

/// 窄版是正方形格；寬螢幕時格寬跟著內容寬，列高維持月曆的比例。
const _maxCellHeight = 80.0;

/// 四週月曆（§3.8）：`calendar` 從本週一起算，學過的日子蓋小章，
/// 沒學也不是學習日的格子留白。
class PlanCalendar extends ConsumerWidget {
  const PlanCalendar({required this.days, required this.stats, super.key});

  final List<CalendarDayDto> days;
  final StatsDto stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final rollover = ref.watch(
      settingsProvider.select((s) => s.value?.dayRolloverHour ?? 4),
    );
    final today = logicalDateOf(DateTime.now(), rollover);
    final thisWeek = days.take(_daysPerWeek).where((d) => d.isActive).length;
    final hasMilestone = days.any((d) => d.milestoneId != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('本週已學 $thisWeek 天'),
        AppText(
          '連續 ${stats.streakCurrent} 天，最長 ${stats.streakBest} 天',
          scale: TypeScale.caption,
          color: t.ink.secondary,
        ),
        const SizedBox(height: AppSpace.s3),
        const _WeekHeader(),
        GenkoGrid(
          columns: _daysPerWeek,
          maxCellHeight: _maxCellHeight,
          children: [for (final day in days) _cellOf(day, today)],
        ),
        if (hasMilestone) ...[
          const SizedBox(height: AppSpace.s2),
          _MilestoneLegend(color: t.ai),
        ],
      ],
    );
  }

  Widget? _cellOf(CalendarDayDto day, String today) {
    final isToday = day.date == today;
    if (!day.isStudyDay && !day.isActive && !isToday) return null;
    return _DayCell(day: day, isToday: isToday);
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final cell = PaperLayout.cell(
          constraints.maxWidth,
          columns: _daysPerWeek,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in _weekdayLabels)
              SizedBox(
                width: cell,
                child: AppText(
                  label,
                  scale: TypeScale.caption,
                  textAlign: TextAlign.center,
                  color: AppTokens.of(context).ink.secondary,
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.isToday});

  final CalendarDayDto day;
  final bool isToday;

  static const _stampRatio = 0.5;
  static const _flagSize = 6.0;

  DateTime get _date => DateTime.parse(day.date);

  /// 每月第一天標月份，其餘只寫日。
  String get _dayLabel => _date.day == 1 ? '${_date.month}/1' : '${_date.day}';

  String get _semanticLabel {
    final parts = [
      '${_date.month} 月 ${_date.day} 日',
      if (isToday) '今天',
      if (day.isStudyDay) '學習日',
      if (day.isActive) '已學習',
      if (day.milestoneId != null) '預計有檢定',
    ];
    return parts.join('，');
  }

  Widget _dayNumber(AppTokens t) => Positioned(
    left: AppSpace.s1,
    top: 2,
    right: AppSpace.s1,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: AppText(
        _dayLabel,
        scale: TypeScale.caption,
        color: t.ink.secondary,
      ),
    ),
  );

  Widget _milestoneFlag(AppTokens t) => Positioned(
    top: AppSpace.s1,
    right: AppSpace.s1,
    child: SizedBox.square(
      dimension: _flagSize,
      child: ColoredBox(color: t.ai),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      label: _semanticLabel,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) => Container(
            decoration: isToday
                ? BoxDecoration(
                    border: Border.all(color: t.ink.primary, width: 2),
                  )
                : null,
            child: Stack(
              children: [
                _dayNumber(t),
                if (day.milestoneId != null) _milestoneFlag(t),
                if (day.isActive)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: HankoBadge(
                      '学',
                      size: constraints.biggest.shortestSide * _stampRatio,
                      semanticLabel: '已學習',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MilestoneLegend extends StatelessWidget {
  const _MilestoneLegend({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox.square(dimension: 8, child: ColoredBox(color: color)),
      const SizedBox(width: AppSpace.s2),
      Expanded(
        child: AppText(
          '預計有里程碑檢定',
          scale: TypeScale.caption,
          color: AppTokens.of(context).ink.secondary,
        ),
      ),
    ],
  );
}

import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/milestone_rail.dart';
import '../../../design/widgets/ruled_list.dart';
import '../../../design/widgets/sheet_frame.dart';
import '../adjust/plan_adjust_sheet.dart';
import '../plan_providers.dart';
import 'milestone_sheet.dart';
import 'plan_calendar.dart';
import 'plan_position.dart';
import 'plan_stats.dart';

class PlanOverview extends StatelessWidget {
  const PlanOverview({required this.data, super.key});

  final PlanPageData data;

  void _openMilestone(BuildContext context, MilestoneDto milestone) =>
      unawaited(
        showPaperSheet<void>(
          context,
          child: MilestoneSheet(
            milestone: milestone,
            onStart: () {
              Navigator.of(context).pop();
              unawaited(
                context.push(AppRoutes.sessionCheckpoint(milestone.id)),
              );
            },
          ),
        ),
      );

  void _openAdjust(BuildContext context) => unawaited(
    showPaperSheet<void>(
      context,
      child: PlanAdjustSheet(current: data.view, stage: data.stage),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final milestones = data.view.milestones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (milestones.isNotEmpty) ...[
          _Section(
            label: '里程碑',
            child: _MilestoneStrip(
              milestones: milestones,
              onSelect: (m) => _openMilestone(context, m),
            ),
          ),
          const SizedBox(height: AppSpace.s6),
        ],
        _Section(
          label: '目前位置',
          child: PlanPosition(data: data),
        ),
        const SizedBox(height: AppSpace.s7),
        _Section(
          label: '四週月曆',
          child: PlanCalendar(days: data.calendar, stats: data.stats),
        ),
        const SizedBox(height: AppSpace.s6),
        InkButton(label: '調整計畫', onPressed: () => _openAdjust(context)),
        const SizedBox(height: AppSpace.s7),
        _Section(
          label: '累積紀錄',
          child: PlanStats(stats: data.stats),
        ),
        const SizedBox(height: AppSpace.s5),
        RuledList(
          children: [
            RuledTile.text(
              '這個程度能帶你到哪裡',
              onTap: () => unawaited(context.push(AppRoutes.planAbout)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(header: true, child: EyebrowText(label)),
      const SizedBox(height: AppSpace.s3),
      child,
    ],
  );
}

/// 完整版有 8 個里程碑，窄螢幕平分會小於 48dp，改成可橫向捲動。
class _MilestoneStrip extends StatelessWidget {
  const _MilestoneStrip({required this.milestones, required this.onSelect});

  final List<MilestoneDto> milestones;
  final ValueChanged<MilestoneDto> onSelect;

  static const _nodeWidth = 88.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wanted = milestones.length * _nodeWidth;
      final rail = MilestoneRail(milestones: milestones, onSelect: onSelect);
      if (wanted <= constraints.maxWidth) return rail;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: wanted, child: rail),
      );
    },
  );
}

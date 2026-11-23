import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/text/mixed_text.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/hanko_badge.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../scope_copy.dart';

/// 點開里程碑（§3.8）：檢定是課後附加任務，通過與否都不擋進度。
class MilestoneSheet extends StatelessWidget {
  const MilestoneSheet({
    required this.milestone,
    required this.onStart,
    super.key,
  });

  final MilestoneDto milestone;
  final VoidCallback onStart;

  String get _thresholdLine => '建議門檻 ${(milestone.passRatio * 100).round()}%';

  String get _bestLine {
    final best = milestone.bestScorePercent;
    return best == null ? '尚未考過' : '最佳成績 $best%';
  }

  String? get _forecastLine {
    final date = milestone.forecastDate;
    return date == null ? null : '預計 ${monthDayOf(date)}（粗估）';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final forecast = _forecastLine;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MixedText(milestone.titleZh, scale: TypeScale.title),
            ),
            if (milestone.passed)
              const HankoBadge('済', size: 48, semanticLabel: '已通過'),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        AppText(_thresholdLine),
        AppText('共 ${milestone.questions} 題'),
        AppText(_bestLine),
        if (forecast != null) AppText(forecast),
        if (milestone.dismissed && !milestone.passed) ...[
          const SizedBox(height: AppSpace.s2),
          AppText(
            '已略過，可隨時開始',
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
        ],
        const SizedBox(height: AppSpace.s5),
        InkButton(label: '開始檢定', onPressed: onStart, expanded: true),
      ],
    );
  }
}

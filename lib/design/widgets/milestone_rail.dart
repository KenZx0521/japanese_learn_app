import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../tokens.dart';
import 'hanko_badge.dart';
import 'pressable.dart';

/// 里程碑線（§3.8）：點數等於已發布里程碑數，已達成的蓋章。
class MilestoneRail extends StatelessWidget {
  const MilestoneRail({required this.milestones, this.onSelect, super.key});

  final List<MilestoneDto> milestones;
  final ValueChanged<MilestoneDto>? onSelect;

  static const _nodeSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: PaperLayout.minTarget / 2 - 0.5,
          child: ExcludeSemantics(
            child: Container(height: 1, color: t.line.strong),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final milestone in milestones)
              Expanded(
                child: _MilestoneNode(
                  milestone: milestone,
                  onTap: onSelect == null ? null : () => onSelect!(milestone),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MilestoneNode extends StatelessWidget {
  const _MilestoneNode({required this.milestone, this.onTap});
  final MilestoneDto milestone;
  final VoidCallback? onTap;

  String get _stateLabel {
    if (milestone.passed) return '已通過';
    if (milestone.dismissed) return '已略過，可隨時開始';
    return '尚未通過';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      semanticHint: _stateLabel,
      builder: (context, state) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
        child: Column(
          children: [
            SizedBox(
              height: PaperLayout.minTarget,
              child: Center(child: _marker(t, state)),
            ),
            MixedText(
              milestone.titleZh,
              scale: TypeScale.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _marker(AppTokens t, PressState state) {
    if (milestone.passed) {
      return const HankoBadge(
        '済',
        size: MilestoneRail._nodeSize,
        semanticLabel: '已通過',
      );
    }
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: state.hovered ? t.paper.raised : t.paper.base,
        border: Border.all(
          color: state.pressed ? t.ink.primary : t.line.strong,
          width: 1.5,
        ),
      ),
    );
  }
}

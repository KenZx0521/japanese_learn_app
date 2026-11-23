import 'package:material_ui/material_ui.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../model/dialogue_run.dart';

enum _CellState { upcoming, current, done, skipped }

/// 頂部的「一二三四」（§3.7）。只畫這次要跑的階段，無聲略過的淡色標示。
class PhaseStrip extends StatelessWidget {
  const PhaseStrip({required this.run, super.key});

  final DialogueRun run;

  _CellState _stateOf(int phase) {
    if (!run.visible.contains(phase)) return _CellState.skipped;
    final current = run.phase;
    if (current == null || phase < current) return _CellState.done;
    return phase == current ? _CellState.current : _CellState.upcoming;
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final phase in run.requested)
        Expanded(
          child: _Cell(phase: phase, state: _stateOf(phase)),
        ),
    ],
  );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.phase, required this.state});

  final int phase;
  final _CellState state;

  static String _status(_CellState state) => switch (state) {
    _CellState.upcoming => '尚未開始',
    _CellState.current => '進行中',
    _CellState.done => '已完成',
    _CellState.skipped => '已略過',
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final current = state == _CellState.current;
    final muted = state == _CellState.skipped || state == _CellState.upcoming;
    final name = dialoguePhaseNames[phase] ?? '';
    return Semantics(
      label: '第${dialoguePhaseNumerals[phase]}段 $name，${_status(state)}',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: current ? t.ink.primary : Colors.transparent,
              border: Border.all(
                color: state == _CellState.skipped
                    ? t.line.grid
                    : (muted ? t.line.strong : t.ink.primary),
              ),
            ),
            child: AppText(
              dialoguePhaseNumerals[phase] ?? '',
              scale: TypeScale.label,
              color: current
                  ? t.paper.base
                  : (muted ? t.ink.tertiary : t.ink.primary),
            ),
          ),
          const SizedBox(height: AppSpace.s1),
          AppText(
            name,
            scale: TypeScale.caption,
            textAlign: TextAlign.center,
            color: current ? t.ink.primary : t.ink.secondary,
          ),
        ],
      ),
    );
  }
}

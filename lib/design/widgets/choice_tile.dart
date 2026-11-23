import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'pressable.dart';

enum ChoiceTileState { idle, selected, correct, wrong, dimmed }

/// 選項（§4.4）。對錯用 ○／× 形狀與語意文字，色彩僅輔助。
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    required this.child,
    this.state = ChoiceTileState.idle,
    this.onTap,
    this.semanticLabel,
    this.dense = false,
    super.key,
  });

  final Widget child;
  final ChoiceTileState state;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// 一排放很多個窄選項時（如每天分鐘數）縮小左右留白。
  final bool dense;

  String get _stateHint => switch (state) {
    ChoiceTileState.correct => '答對',
    ChoiceTileState.wrong => '答錯',
    ChoiceTileState.selected => '已選擇',
    ChoiceTileState.idle || ChoiceTileState.dimmed => '',
  };

  Color _borderColor(AppTokens t, PressState press) => switch (state) {
    ChoiceTileState.correct => t.moegi,
    ChoiceTileState.wrong => t.shu,
    ChoiceTileState.selected => t.ink.primary,
    ChoiceTileState.dimmed => t.line.grid,
    ChoiceTileState.idle => press.hovered ? t.ink.primary : t.line.strong,
  };

  /// 判定態框線 2、未作答 1，用內距補回，高度不變，選項不會跳動。
  double get _borderWidth => state == ChoiceTileState.idle ? 1 : 2;

  EdgeInsets get _padding {
    final offset = _borderWidth - 1;
    return EdgeInsets.symmetric(
      horizontal: (dense ? AppSpace.s2 : AppSpace.s4) - offset,
      vertical: AppSpace.s3 - offset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      selected: state == ChoiceTileState.selected,
      semanticLabel: semanticLabel,
      semanticHint: _stateHint.isEmpty ? null : _stateHint,
      builder: (context, press) => PressNudge(
        pressed: press.pressed,
        child: Opacity(
          opacity: state == ChoiceTileState.dimmed ? 0.55 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: PaperLayout.minTarget),
            padding: _padding,
            decoration: BoxDecoration(
              color: press.hovered ? t.paper.raised : t.paper.base,
              borderRadius: AppRadii.r1,
              border: Border.all(
                color: _borderColor(t, press),
                width: _borderWidth,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: child),
                if (state == ChoiceTileState.correct)
                  _Mark(correct: true, color: t.moegi),
                if (state == ChoiceTileState.wrong)
                  _Mark(correct: false, color: t.shu),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.correct, required this.color});
  final bool correct;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size.square(22),
      painter: _MarkPainter(correct: correct, color: color),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.correct, required this.color});
  final bool correct;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final s = size.width;
    if (correct) {
      canvas.drawCircle(Offset(s / 2, s / 2), s * 0.38, paint);
      return;
    }
    canvas
      ..drawLine(Offset(s * 0.2, s * 0.2), Offset(s * 0.8, s * 0.8), paint)
      ..drawLine(Offset(s * 0.8, s * 0.2), Offset(s * 0.2, s * 0.8), paint);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.correct != correct || oldDelegate.color != color;
}

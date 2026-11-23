import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../motion.dart';
import '../tokens.dart';
import 'pressable.dart';

/// 翻面容器（§3.4、§4.4）：Y 軸翻轉 280ms；reduced motion 改 120ms 交叉淡入。
/// 語意順序隨面切換，翻過去的那面不進語意樹。
class FlipCard extends StatefulWidget {
  const FlipCard({
    required this.front,
    required this.back,
    required this.flipped,
    this.onFlip,
    super.key,
  });

  final Widget front, back;
  final bool flipped;
  final VoidCallback? onFlip;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.flipped ? 1 : 0,
  );

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipped != widget.flipped) {
      final motion = AppMotion.of(context).flip;
      _controller.animateTo(
        widget.flipped ? 1 : 0,
        duration: motion.duration,
        curve: motion.curve,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final reduced = AppMotion.of(context).reduced;
    return Pressable(
      onTap: widget.onFlip,
      semanticHint: widget.onFlip == null ? null : '翻面',
      builder: (context, state) => DecoratedBox(
        decoration: t.raised(strong: state.hovered),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => reduced
              ? _crossFade(_controller.value)
              : _rotate(_controller.value),
        ),
      ),
    );
  }

  Widget _face(Widget child, {required bool visible}) => ExcludeSemantics(
    excluding: !visible,
    child: IgnorePointer(ignoring: !visible, child: child),
  );

  Widget _crossFade(double value) => Stack(
    children: [
      Opacity(
        opacity: 1 - value,
        child: _face(widget.front, visible: value < 0.5),
      ),
      Opacity(
        opacity: value,
        child: _face(widget.back, visible: value >= 0.5),
      ),
    ],
  );

  Widget _rotate(double value) {
    final showBack = value >= 0.5;
    final angle = value * math.pi;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateY(angle);
    final child = showBack
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: _face(widget.back, visible: true),
          )
        : _face(widget.front, visible: true);
    return Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: child,
    );
  }
}

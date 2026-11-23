import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../motion.dart';
import 'hanko_badge.dart';

/// 全頁蓋章（§4.2）：scale 1.4→1、旋轉 -8°→-6°、透明度 0→1。
/// `play` 轉為 true 時播放，播完自動淡去，全程不擋互動。
class StampOverlay extends StatefulWidget {
  const StampOverlay({
    required this.play,
    this.text = '済',
    this.size = 120,
    this.onDone,
    super.key,
  });

  final bool play;
  final String text;
  final double size;
  final VoidCallback? onDone;

  @override
  State<StampOverlay> createState() => _StampOverlayState();
}

class _StampOverlayState extends State<StampOverlay>
    with SingleTickerProviderStateMixin {
  static const _holdFor = Duration(milliseconds: 700);
  static const _startScale = 1.4;
  static const _extraTilt = -2 * math.pi / 180;

  late final AnimationController _stamp = AnimationController(vsync: this);
  Timer? _holdTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.play) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void didUpdateWidget(StampOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) _run();
  }

  Future<void> _run() async {
    if (!mounted) return;
    final motion = AppMotion.of(context).stamp;
    setState(() => _visible = true);
    _stamp.duration = motion.duration;
    await _stamp.forward(from: 0).orCancel.catchError((Object _) {});
    if (!mounted) return;
    _holdTimer = Timer(_holdFor, _fadeOut);
  }

  void _fadeOut() {
    if (!mounted) return;
    setState(() => _visible = false);
    widget.onDone?.call();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _stamp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: motion.base.duration,
          child: Center(
            child: AnimatedBuilder(
              animation: _stamp,
              child: HankoBadge(widget.text, size: widget.size),
              builder: (context, child) {
                final curved = motion.stamp.curve.transform(_stamp.value);
                final remaining = 1 - curved;
                return Opacity(
                  opacity: _stamp.value.clamp(0.0, 1.0),
                  child: motion.reduced
                      ? child
                      : Transform.rotate(
                          angle: _extraTilt * remaining,
                          child: Transform.scale(
                            scale: 1 + (_startScale - 1) * remaining,
                            child: child,
                          ),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

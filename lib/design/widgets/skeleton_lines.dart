import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../motion.dart';
import '../tokens.dart';

/// 載入骨架：文字行高的 `paper.sunken` 細條，不用轉圈（§2.3）。
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({this.lines = 3, super.key});
  final int lines;

  static const _widths = [1.0, 0.82, 0.64, 0.9, 0.72];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      label: '載入中',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s3),
                child: FractionallySizedBox(
                  widthFactor: _widths[i % _widths.length],
                  child: Container(height: 14, color: t.paper.sunken),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 超過 200ms 才顯示子元件，快速載入時不閃爍。
class DelayedReveal extends StatefulWidget {
  const DelayedReveal({required this.child, super.key});
  final Widget child;

  @override
  State<DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<DelayedReveal> {
  Timer? _timer;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(AppMotion.of(context).skeletonDelay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.child : const SizedBox.shrink();
}

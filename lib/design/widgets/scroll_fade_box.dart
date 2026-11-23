import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

const _fadeHeight = 28.0;

/// 限高捲動區：下方還有內容時底部淡出，提示可往下捲（裁切文字才不像 bug）。
/// [fadeColor] 預設 `paper.raised`，要跟底色相同。
class ScrollFadeBox extends StatefulWidget {
  const ScrollFadeBox({
    required this.maxHeight,
    required this.child,
    this.fadeColor,
    super.key,
  });

  final double maxHeight;
  final Widget child;
  final Color? fadeColor;

  @override
  State<ScrollFadeBox> createState() => _ScrollFadeBoxState();
}

class _ScrollFadeBoxState extends State<ScrollFadeBox> {
  bool _moreBelow = false;

  void _update(ScrollMetrics metrics) {
    final more = metrics.extentAfter > 1;
    if (more != _moreBelow) setState(() => _moreBelow = more);
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    _update(notification.metrics);
    return false;
  }

  bool _onScroll(ScrollNotification notification) {
    _update(notification.metrics);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.fadeColor ?? AppTokens.of(context).paper.raised;
    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: _onMetrics,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: SingleChildScrollView(child: widget.child),
            ),
          ),
        ),
        if (_moreBelow)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _fadeHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('feedback-more-below'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color.withValues(alpha: 0), color],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

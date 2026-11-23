import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../motion.dart';
import '../tokens.dart';

@immutable
final class PressState {
  const PressState({
    required this.hovered,
    required this.focused,
    required this.pressed,
    required this.enabled,
  });
  final bool hovered, focused, pressed, enabled;
}

typedef PressBuilder = Widget Function(BuildContext context, PressState state);

/// 所有可互動元件的底層：鍵盤、滑鼠、觸控的 hover／focus／pressed 狀態、
/// 2px `ai` 焦點框、≥48dp 目標與按鈕語意都在這裡（§4.4、§4.6）。
class Pressable extends StatefulWidget {
  const Pressable({
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.attributedLabel,
    this.semanticHint,
    this.selected,
    this.toggled,
    this.minSize = PaperLayout.minTarget,
    this.focusNode,
    this.autofocus = false,
    this.customActions,
    super.key,
  });

  final PressBuilder builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 有值時取代子元件語意；無值時子元件的文字併入按鈕。
  final String? semanticLabel;

  /// 含日文時用它標 ja，優先於 [semanticLabel]。
  final AttributedString? attributedLabel;
  final String? semanticHint;
  final bool? selected;
  final bool? toggled;
  final double minSize;
  final FocusNode? focusNode;
  final bool autofocus;
  final Map<CustomSemanticsAction, VoidCallback>? customActions;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _handleActivate() => widget.onTap?.call();

  @override
  Widget build(BuildContext context) {
    final state = PressState(
      hovered: _hovered && _enabled,
      focused: _focused && _enabled,
      pressed: _pressed && _enabled,
      enabled: _enabled,
    );
    return Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.attributedLabel == null ? widget.semanticLabel : null,
      attributedLabel: widget.attributedLabel,
      hint: widget.semanticHint,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      customSemanticsActions: widget.customActions,
      child: _detector(_content(state)),
    );
  }

  Widget _content(PressState state) => ConstrainedBox(
    constraints: BoxConstraints(
      minWidth: widget.minSize,
      minHeight: widget.minSize,
    ),
    child: CustomPaint(
      foregroundPainter: state.focused
          ? _FocusRingPainter(AppTokens.of(context).ai)
          : null,
      child: widget.builder(context, state),
    ),
  );

  Widget _detector(Widget content) => FocusableActionDetector(
    enabled: _enabled,
    focusNode: widget.focusNode,
    autofocus: widget.autofocus,
    mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
    onShowHoverHighlight: (value) => setState(() => _hovered = value),
    onShowFocusHighlight: (value) => setState(() => _focused = value),
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          _handleActivate();
          return null;
        },
      ),
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _enabled ? (_) => _setPressed(true) : null,
      onTapUp: _enabled ? (_) => _setPressed(false) : null,
      onTapCancel: _enabled ? () => _setPressed(false) : null,
      child: widget.semanticLabel == null && widget.attributedLabel == null
          ? content
          : ExcludeSemantics(child: content),
    ),
  );
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect((Offset.zero & size).inflate(1), paint);
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 按下時下移 1px（§4.4），只動 transform。
class PressNudge extends StatelessWidget {
  const PressNudge({required this.pressed, required this.child, super.key});
  final bool pressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context).fast;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: pressed ? 1 : 0),
      duration: motion.duration,
      curve: motion.curve,
      child: child,
      builder: (context, y, child) =>
          Transform.translate(offset: Offset(0, y), child: child),
    );
  }
}

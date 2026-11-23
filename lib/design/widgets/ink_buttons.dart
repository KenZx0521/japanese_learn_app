import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'app_text.dart';
import 'pressable.dart';

enum _ButtonTone { ink, ghost, shu }

@immutable
final class _ButtonColors {
  const _ButtonColors(this.fill, this.foreground, this.border);
  final Color fill, foreground;
  final Color? border;
}

class _BaseButton extends StatelessWidget {
  const _BaseButton({
    required this.tone,
    required this.label,
    required this.onPressed,
    this.expanded = false,
    this.autofocus = false,
    this.focusNode,
  });

  final _ButtonTone tone;
  final String label;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool autofocus;
  final FocusNode? focusNode;

  _ButtonColors _colors(AppTokens t, PressState s) {
    if (!s.enabled) {
      return _ButtonColors(t.paper.sunken, t.ink.tertiary, t.line.strong);
    }
    if (s.hovered) {
      final emphasis = tone == _ButtonTone.shu ? t.shu : t.ink.primary;
      return _ButtonColors(t.paper.raised, emphasis, emphasis);
    }
    return switch (tone) {
      _ButtonTone.ink => _ButtonColors(t.ink.primary, t.paper.base, null),
      _ButtonTone.ghost => _ButtonColors(
        Colors.transparent,
        t.ink.primary,
        t.line.strong,
      ),
      _ButtonTone.shu => _ButtonColors(t.shu, t.onShu, null),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onPressed,
      autofocus: autofocus,
      focusNode: focusNode,
      builder: (context, state) {
        final colors = _colors(t, state);
        return PressNudge(
          pressed: state.pressed,
          child: Container(
            width: expanded ? double.infinity : null,
            alignment: expanded ? Alignment.center : null,
            constraints: const BoxConstraints(minHeight: PaperLayout.minTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s5,
              vertical: AppSpace.s3,
            ),
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: AppRadii.r1,
              border: colors.border == null
                  ? null
                  : Border.all(color: colors.border!, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: AppText(
                    label,
                    scale: TypeScale.label,
                    color: colors.foreground,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 主要動作：墨色實心。
class InkButton extends StatelessWidget {
  const InkButton({
    required this.label,
    required this.onPressed,
    this.expanded = false,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool expanded, autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => _BaseButton(
    tone: _ButtonTone.ink,
    label: label,
    onPressed: onPressed,
    expanded: expanded,
    autofocus: autofocus,
    focusNode: focusNode,
  );
}

/// 次要動作：細線框。
class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.label,
    required this.onPressed,
    this.expanded = false,
    this.autofocus = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool expanded, autofocus;

  @override
  Widget build(BuildContext context) => _BaseButton(
    tone: _ButtonTone.ghost,
    label: label,
    onPressed: onPressed,
    expanded: expanded,
    autofocus: autofocus,
  );
}

/// T2 的單項略過（載入失敗、沒有語音）：T2、L3、聽力共用同一個文案。
/// 略過不是完成，項目留在今日清單上（§3.2）。
class SkipItemButton extends StatelessWidget {
  const SkipItemButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      GhostButton(label: '略過這一項', onPressed: onPressed);
}

/// 警示動作：朱色實心（清除資料等）。一個畫面不超過一顆。
class ShuButton extends StatelessWidget {
  const ShuButton({
    required this.label,
    required this.onPressed,
    this.expanded = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) => _BaseButton(
    tone: _ButtonTone.shu,
    label: label,
    onPressed: onPressed,
    expanded: expanded,
  );
}

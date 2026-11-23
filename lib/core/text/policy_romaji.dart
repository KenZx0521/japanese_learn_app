import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/app_text.dart';
import '../backend/frb/dto.dart';
import 'romaji_scope.dart';

/// 單字卡與假名的 romaji，依 `RomajiMode` 顯示（§3.7）。句子用 `RubyLine`。
class PolicyRomaji extends StatefulWidget {
  const PolicyRomaji(this.romaji, {required this.mode, super.key});

  final String romaji;
  final RomajiMode mode;

  @override
  State<PolicyRomaji> createState() => _PolicyRomajiState();
}

class _PolicyRomajiState extends State<PolicyRomaji> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final collapsed = RomajiPageScope.collapsedOf(context);
    final text = AppText(
      widget.romaji,
      scale: TypeScale.caption,
      color: t.ink.secondary,
    );
    return switch (widget.mode) {
      RomajiMode.shown => text,
      RomajiMode.shownToggleable => collapsed ? const SizedBox.shrink() : text,
      RomajiMode.hidden => const SizedBox.shrink(),
      RomajiMode.tapToReveal => _tapToReveal(text),
      RomajiMode.longPressOnly => _longPress(text),
    };
  }

  Widget _tapToReveal(Widget text) => _revealed
      ? text
      : Pressable(
          onTap: () => setState(() => _revealed = true),
          semanticLabel: '顯示羅馬字',
          builder: (context, state) => const _RevealCaption(label: 'aA'),
        );

  Widget _longPress(Widget text) => _revealed
      ? text
      : Pressable(
          onLongPress: () => setState(() => _revealed = true),
          semanticLabel: '顯示羅馬字',
          builder: (context, state) => const _RevealCaption(label: '長按顯示羅馬字'),
        );
}

class _RevealCaption extends StatelessWidget {
  const _RevealCaption({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
    child: Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: AppText(
        label,
        scale: TypeScale.caption,
        color: AppTokens.of(context).ink.secondary,
      ),
    ),
  );
}

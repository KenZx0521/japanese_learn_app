import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/pressable.dart';
import 'romaji_scope.dart';

/// `ShownToggleable` 的頁面開關（§3.7）。放在 [RomajiPageScope] 內、頁面右上。
class RomajiToggle extends StatelessWidget {
  const RomajiToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final collapsed = RomajiPageScope.collapsedOf(context);
    return Pressable(
      onTap: () => RomajiPageScope.toggle(context),
      toggled: !collapsed,
      builder: (context, state) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
        child: Center(
          widthFactor: 1,
          child: AppText(
            collapsed ? '顯示羅馬字' : '收起羅馬字',
            scale: TypeScale.label,
            color: state.hovered ? t.ink.primary : t.ink.secondary,
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/pressable.dart';

/// 開關標籤：篩選與標記共用。開啟時為墨色實心，不只靠顏色（填滿與框線的形狀差異）。
class ToggleTag extends StatelessWidget {
  const ToggleTag({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;

  /// null 時停用（例如寫入中）。
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final change = onChanged;
    return Pressable(
      onTap: change == null ? null : () => change(!value),
      toggled: value,
      builder: (context, state) => PressNudge(
        pressed: state.pressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: PaperLayout.minTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s2,
          ),
          decoration: BoxDecoration(
            color: _fill(t, state),
            borderRadius: AppRadii.r1,
            border: Border.all(
              color: value ? t.ink.primary : t.line.strong,
              width: 1.5,
            ),
          ),
          // Container 的 alignment 會把標籤撐到整行，這裡只置中不佔寬
          child: Center(
            widthFactor: 1,
            child: AppText(
              label,
              scale: TypeScale.label,
              color: value ? t.paper.base : t.ink.primary,
            ),
          ),
        ),
      ),
    );
  }

  Color _fill(AppTokens t, PressState state) {
    if (value) return t.ink.primary;
    return state.hovered ? t.paper.raised : Colors.transparent;
  }
}

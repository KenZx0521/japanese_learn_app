import 'package:material_ui/material_ui.dart';

import '../motion.dart';
import '../tokens.dart';

/// 底部面板：`paper.raised` 加陰影（深色模式改 1px 邊框），內容可捲動。
Future<T?> showPaperSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isScrollControlled = true,
}) {
  final motion = AppMotion.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(
      duration: motion.base.duration,
      curve: motion.base.curve,
      reverseDuration: motion.base.duration,
    ),
    builder: (context) => PaperSheetFrame(child: child),
  );
}

class PaperSheetFrame extends StatelessWidget {
  const PaperSheetFrame({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return DecoratedBox(
      decoration: t.raised(strong: true),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: PaperLayout.maxContentWidth,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

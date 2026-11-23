import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'app_text.dart';
import 'pressable.dart';

/// 次層畫面的返回列：左上箭頭加一行小字，不佔標題列（§4.1）。
/// [onBack] 由呼叫端決定 pop 或 go。
class BackLine extends StatelessWidget {
  const BackLine({required this.onBack, this.label = '返回', super.key});

  final VoidCallback onBack;
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    widthFactor: 1,
    child: Pressable(onTap: onBack, semanticLabel: label, builder: _labelled),
  );

  Widget _labelled(BuildContext context, PressState state) {
    final t = AppTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(10, 16),
          painter: _ChevronPainter(
            color: state.pressed ? t.ink.primary : t.ink.secondary,
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        AppText(
          label,
          scale: TypeScale.label,
          color: state.hovered ? t.ink.primary : t.ink.secondary,
        ),
      ],
    );
  }
}

/// 有上一頁就回去，否則到 [fallback]（`AppRoutes` 的路徑，例如從深層連結直接進來）。
/// 不在路由內（元件測試）時什麼都不做。[PageBackLink] 與需要同一個離開動作的
/// Esc、完成按鈕共用。
void leavePage(BuildContext context, {required String fallback}) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return;
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(fallback);
  }
}

/// 次層畫面統一的返回（箭頭＋「返回」）：有上一頁就回去，否則到 [fallback]。
class PageBackLink extends StatelessWidget {
  const PageBackLink({required this.fallback, this.label = '返回', super.key});

  /// `AppRoutes` 的路徑。
  final String fallback;
  final String label;

  @override
  Widget build(BuildContext context) => BackLine(
    onBack: () => leavePage(context, fallback: fallback),
    label: label,
  );
}

/// 深層頁面的返回（Linux 與桌面沒有系統返回鍵）。沒有上一頁時不顯示。
class PopBackLine extends StatelessWidget {
  const PopBackLine({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return const SizedBox.shrink();
    return BackLine(onBack: () => unawaited(navigator.maybePop()));
  }
}

/// 字型子集不含箭頭符號，所以用畫的。
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}

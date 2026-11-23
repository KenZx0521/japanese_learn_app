import 'package:material_ui/material_ui.dart';

import '../motion.dart';
import '../tokens.dart';
import 'app_text.dart';

/// 底部回饋條（§4.4），由底部滑入。對錯同時有文字，`liveRegion` 讓螢幕報讀朗讀。
class FeedbackStrip extends StatelessWidget {
  const FeedbackStrip({
    required this.correct,
    required this.title,
    this.child,
    this.action,
    super.key,
  });

  final bool correct;
  final String title;
  final Widget? child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final motion = AppMotion.of(context).base;
    final color = correct ? t.moegi : t.shu;
    // 深色模式沒有陰影，改 1px 邊框才看得出是浮起的面（§4.2）
    final border = t.raisedBorder;
    final side = border == null ? BorderSide.none : BorderSide(color: border);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: motion.duration,
      curve: motion.curve,
      builder: (context, slide, content) =>
          FractionalTranslation(translation: Offset(0, slide), child: content),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.s4),
          decoration: BoxDecoration(
            color: t.paper.raised,
            border: Border(
              top: BorderSide(color: color, width: 3),
              left: side,
              right: side,
              bottom: side,
            ),
            boxShadow: t.shadow2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(title, scale: TypeScale.title, color: color),
              if (child != null) ...[
                const SizedBox(height: AppSpace.s2),
                child!,
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpace.s3),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

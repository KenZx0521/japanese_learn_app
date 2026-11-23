import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/text/ja_text.dart';
import '../tokens.dart';

/// 朱印（§4.1）：略為歪斜，內文 1–2 字（済、合格、学）。
class HankoBadge extends StatelessWidget {
  const HankoBadge(
    this.text, {
    this.size = 56,
    this.semanticLabel = '完成',
    this.muted = false,
    super.key,
  });

  final String text;
  final double size;
  final String semanticLabel;

  /// 列表上的小章用淡墨：朱色稀缺，一個畫面最多兩處（§4.1）。
  final bool muted;

  static const tiltRadians = -6 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final chars = text.characters.toList();
    final fontSize = size * (chars.length > 1 ? 0.36 : 0.5);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Transform.rotate(
          angle: tiltRadians,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: muted ? t.ink.tertiary : t.shu,
              borderRadius: AppRadii.stamp(size),
            ),
            child: Container(
              width: size * 0.84,
              height: size * 0.84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: t.onShu, width: size * 0.03),
                borderRadius: AppRadii.stamp(size * 0.84),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final ch in chars)
                    JaText(
                      ch,
                      fontSize: fontSize,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      color: t.onShu,
                      textScaler: TextScaler.noScaling,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

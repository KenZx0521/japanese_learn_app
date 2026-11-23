import 'package:material_ui/material_ui.dart';

import '../../core/text/ja_text.dart';
import '../tokens.dart';

/// 裝飾用直排短語（§7.3），逐字排，只用於不含「ー」的固定字串。
class VerticalTitle extends StatelessWidget {
  const VerticalTitle(this.text, {this.color, super.key});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final ch in text.characters)
          JaText(
            ch,
            scale: TypeScale.jaSentence,
            color: color ?? AppTokens.of(context).ink.secondary,
            textScaler: TextScaler.noScaling,
          ),
      ],
    ),
  );
}

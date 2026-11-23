import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// 伏字條（§3.7）：長度對應句長的墨線，文字不放進 widget tree。
class CensorBar extends StatelessWidget {
  const CensorBar({required this.characters, this.charWidth = 16, super.key});

  final int characters;
  final double charWidth;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '隱藏的日文',
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          width: (characters * charWidth).clamp(
            charWidth,
            constraints.maxWidth,
          ),
          height: 6,
          margin: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          color: AppTokens.of(context).ink.secondary,
        ),
      ),
    ),
  );
}

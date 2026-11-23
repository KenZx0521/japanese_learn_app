import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// 紙紋（§4.2）。圖檔是全透明底的纖維，以 token 墨色染色，疊上去不改變文字對比。
class PaperTexture extends StatelessWidget {
  const PaperTexture({super.key});

  static const assetPath = 'assets/textures/washi_256.png';

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (t.textureOpacity == 0) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: t.textureOpacity,
          child: Image.asset(
            assetPath,
            repeat: ImageRepeat.repeat,
            fit: BoxFit.none,
            alignment: Alignment.topLeft,
            color: t.ink.primary,
            colorBlendMode: BlendMode.srcIn,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

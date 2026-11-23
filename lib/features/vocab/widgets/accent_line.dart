import 'package:material_ui/material_ui.dart';

import '../../../core/text/ja_text.dart';
import '../../../design/tokens.dart';

const _smallKana = 'ゃゅょぁぃぅぇぉゎャュョァィゥェォヮ';

/// 依拍切開假名：小寫假名併入前一拍，っ與ー自成一拍。
List<String> moraeOf(String kana) {
  final morae = <String>[];
  for (final rune in kana.replaceAll(RegExp(r'\s'), '').runes) {
    final char = String.fromCharCode(rune);
    if (_smallKana.contains(char) && morae.isNotEmpty) {
      morae[morae.length - 1] = morae.last + char;
    } else {
      morae.add(char);
    }
  }
  return morae;
}

/// 每拍的高低。[accent] 是下降核位置：0 平板、1 頭高、n 第 n 拍後下降
/// （curriculum §4.4）。
List<bool> pitchOf(int moraCount, int accent) => [
  for (var i = 0; i < moraCount; i++)
    switch (accent) {
      0 => i > 0,
      1 => i == 0,
      _ => i > 0 && i < accent,
    },
];

/// 音調線（§3.4）：高拍畫上線、低拍畫下線，高低轉換處畫一豎。
class AccentLine extends StatelessWidget {
  const AccentLine({required this.kana, required this.accent, super.key});

  final String kana;
  final int accent;

  String get _semanticLabel => accent == 0 ? '音調：平板，不下降' : '音調：第 $accent 拍後下降';

  @override
  Widget build(BuildContext context) {
    final morae = moraeOf(kana);
    if (morae.isEmpty || accent > morae.length) return const SizedBox.shrink();
    final pitch = pitchOf(morae.length, accent);
    final color = AppTokens.of(context).ink.secondary;
    return Semantics(
      label: _semanticLabel,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, mora) in morae.indexed)
                _MoraCell(
                  mora: mora,
                  high: pitch[i],
                  // 高低轉換時在拍與拍之間畫豎線
                  drops: i + 1 < pitch.length && pitch[i] != pitch[i + 1],
                  color: color,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoraCell extends StatelessWidget {
  const _MoraCell({
    required this.mora,
    required this.high,
    required this.drops,
    required this.color,
  });

  static const _strokeWidth = 1.5;

  final String mora;
  final bool high, drops;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: color, width: _strokeWidth);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: high ? side : BorderSide.none,
          bottom: high ? BorderSide.none : side,
          right: drops ? side : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s1,
          vertical: AppSpace.s1,
        ),
        child: JaText(mora),
      ),
    );
  }
}

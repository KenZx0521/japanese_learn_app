import 'package:material_ui/material_ui.dart';

import '../../core/text/ja_text.dart';
import '../tokens.dart';

/// 單字列的一個詞（表記或假名）：只佔一行，放不下時整個縮小，
/// 不像一般文字在詞中斷行（§7.3 換行只發生在詞界）。
class JaWordLine extends StatelessWidget {
  const JaWordLine(
    this.data, {
    this.scale = TypeScale.jaBody,
    this.color,
    super.key,
  });

  final String data;
  final TypeScale scale;
  final Color? color;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: JaText(data, scale: scale, color: color, maxLines: 1),
  );
}

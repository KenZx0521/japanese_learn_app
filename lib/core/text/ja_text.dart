import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';

/// 所有日文的入口：Klee 字型＋ja locale，同時決定字形與螢幕報讀語言（§7.2）。
class JaText extends StatelessWidget {
  const JaText(
    this.data, {
    this.scale = TypeScale.jaBody,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.height,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textScaler,
    super.key,
  });

  final String data;
  final TypeScale scale;
  final Color? color;

  /// 字級來自版面（假名格）時使用；一般情況走 [scale]。
  final double? fontSize;
  final FontWeight? fontWeight;

  /// 行高倍率，用於緊湊版面（假名格、印章）。
  final double? height;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final base = jaStyle(scale, color ?? t.ink.primary);
    return Text(
      data,
      locale: jaLocale,
      style: fontSize == null && fontWeight == null && height == null
          ? base
          : base.copyWith(
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: height,
            ),
      textScaler: textScaler ?? scale.scaler(context),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

/// 日文 TextStyle：fallback 留空，缺字由系統依 ja locale 選字（§7.2 第 1 條）。
TextStyle jaStyle(TypeScale scale, Color color) => TextStyle(
  fontFamily: AppFonts.ja,
  fontFamilyFallback: const [],
  fontSize: scale.size,
  height: scale.lineHeight / scale.size,
  fontWeight: scale.weight,
  color: color,
  locale: jaLocale,
  leadingDistribution: TextLeadingDistribution.even,
);

/// 帶 ja 標註的語意字串，供合併語意的元件（`RubyLine`、`KanaCell`）使用。
AttributedString jaSemantics(String text, {String suffix = ''}) =>
    AttributedString(
      '$text$suffix',
      attributes: [
        LocaleStringAttribute(
          range: TextRange(start: 0, end: text.length),
          locale: jaLocale,
        ),
      ],
    );

import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// 中文介面文字，套用 token 字級與各級的縮放上限。日文請用 `JaText`。
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    this.scale = TypeScale.body,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.letterSpacing,
    this.semanticsLabel,
    super.key,
  });

  final String data;
  final TypeScale scale;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final double? letterSpacing;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Text(
      data,
      style: scale
          .style(color ?? t.ink.primary)
          .copyWith(letterSpacing: letterSpacing),
      textScaler: scale.scaler(context),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      semanticsLabel: semanticsLabel,
    );
  }
}

/// 小標（`letterSpacing: 2`，§4.2）。
class EyebrowText extends StatelessWidget {
  const EyebrowText(this.data, {this.color, super.key});
  final String data;
  final Color? color;

  @override
  Widget build(BuildContext context) => AppText(
    data,
    scale: TypeScale.label,
    letterSpacing: 2,
    color: color ?? AppTokens.of(context).ink.secondary,
  );
}

import 'package:material_ui/material_ui.dart';

@immutable
final class MotionSpec {
  const MotionSpec(this.duration, this.curve);
  final Duration duration;
  final Curve curve;
}

/// 動效 token（§4.2）。元件不得寫死 Duration，一律從這裡取（§4.6）。
@immutable
final class AppMotion {
  const AppMotion._(this.reduced);

  factory AppMotion.of(BuildContext context) =>
      AppMotion._(MediaQuery.disableAnimationsOf(context));

  final bool reduced;

  static const _instant = Duration.zero;
  static const _reducedFade = Duration(milliseconds: 120);

  MotionSpec get fast =>
      const MotionSpec(Duration(milliseconds: 120), Curves.easeOut);

  MotionSpec get base => MotionSpec(
    reduced ? _instant : const Duration(milliseconds: 220),
    Curves.easeOutCubic,
  );

  /// 頁面轉場；reduced motion 時無動畫。
  MotionSpec get page => MotionSpec(
    reduced ? _instant : const Duration(milliseconds: 280),
    Curves.easeOutCubic,
  );

  /// 翻卡；reduced motion 時改 120ms 交叉淡入。
  MotionSpec get flip => MotionSpec(
    reduced ? _reducedFade : const Duration(milliseconds: 280),
    Curves.easeOutCubic,
  );

  MotionSpec get stamp => MotionSpec(
    reduced ? _reducedFade : const Duration(milliseconds: 360),
    reduced ? Curves.linear : Curves.easeOutBack,
  );

  /// 骨架要等這麼久才出現，避免快速載入時閃爍（§2.3）。
  Duration get skeletonDelay => const Duration(milliseconds: 200);

  /// `SpeakButton` 準備中的細環延遲（§6.5）。
  Duration get preparingDelay => const Duration(milliseconds: 200);
}

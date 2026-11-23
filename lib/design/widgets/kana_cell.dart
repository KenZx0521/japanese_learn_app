import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/text/ja_text.dart';
import '../tokens.dart';
import 'pressable.dart';

/// 拗音格是兩個字，沿用單字的 0.5 會把格子撐滿；兩個字加起來也只佔七成左右。
const _singleKanaRatio = 0.5;
const _digraphKanaRatio = 0.36;

/// 假名格（§4.4）：假名＋romaji＋狀態點。字級 = 格寬×0.5，不隨字級縮放。
class KanaCell extends StatelessWidget {
  const KanaCell({
    required this.kana,
    required this.romaji,
    required this.status,
    this.fastBadge = false,
    this.selected = false,
    this.showRomaji = true,
    this.onTap,
    super.key,
  });

  final String kana, romaji;
  final KanaStatus status;
  final bool fastBadge, selected, showRomaji;
  final VoidCallback? onTap;

  static String statusLabel(KanaStatus status) => switch (status) {
    KanaStatus.notStarted => '尚未開始',
    KanaStatus.learning => '學習中',
    KanaStatus.mastered => '已熟練',
  };

  double get _kanaRatio =>
      kana.runes.length > 1 ? _digraphKanaRatio : _singleKanaRatio;

  Color _inkColor(AppTokens t) => switch (status) {
    KanaStatus.notStarted => t.ink.tertiary,
    KanaStatus.learning || KanaStatus.mastered => t.ink.primary,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final romajiLabel = showRomaji ? '，$romaji' : '';
    return Pressable(
      onTap: onTap,
      selected: selected,
      attributedLabel: jaSemantics(
        kana,
        suffix: '$romajiLabel，${statusLabel(status)}',
      ),
      builder: (context, state) => LayoutBuilder(
        builder: (context, constraints) =>
            _content(t, state, constraints.biggest.shortestSide),
      ),
    );
  }

  Widget _content(AppTokens t, PressState state, double side) {
    final fill = state.pressed
        ? t.paper.sunken
        : (state.hovered || selected ? t.paper.raised : Colors.transparent);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        border: selected ? Border.all(color: t.ink.primary, width: 1.5) : null,
      ),
      // 要撐滿整格：狀態點以格子四角定位，不能貼著字，會蓋住濁點
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 假名不縮放；romaji 放大到 1.5 倍時整組等比縮進格內，不破格
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JaText(
                    kana,
                    fontSize: side * _kanaRatio,
                    height: 1.15,
                    color: _inkColor(t),
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                  ),
                  if (showRomaji) _RomajiLabel(text: romaji),
                ],
              ),
            ),
          ),
          if (status == KanaStatus.mastered)
            Positioned(
              top: AppSpace.s1,
              right: AppSpace.s1,
              child: _Dot(color: t.shu),
            ),
          if (fastBadge)
            Positioned(
              top: AppSpace.s1,
              left: AppSpace.s1,
              child: _RingDot(color: t.ai),
            ),
        ],
      ),
    );
  }
}

class _RomajiLabel extends StatelessWidget {
  const _RomajiLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    textScaler: MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: RubyMetrics.romajiMaxScale),
    style: TypeScale.caption
        .style(AppTokens.of(context).ink.secondary)
        .copyWith(fontSize: RubyMetrics.minRomajiSize, height: 1.25),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 8,
    height: 8,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

class _RingDot extends StatelessWidget {
  const _RingDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 9,
    height: 9,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    ),
  );
}

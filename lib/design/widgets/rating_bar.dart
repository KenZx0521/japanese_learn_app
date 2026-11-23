import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'pressable.dart';

/// 下次間隔的中文顯示（僅 `show_rating_intervals` 開啟時，§3.4）。
String formatRatingInterval(int minutes) {
  const minutesPerHour = 60;
  const minutesPerDay = 1440;
  const daysPerMonth = 30;
  if (minutes < minutesPerHour) return '$minutes 分鐘';
  if (minutes < minutesPerDay) return '${minutes ~/ minutesPerHour} 小時';
  final days = minutes ~/ minutesPerDay;
  if (days < daysPerMonth) return '$days 天';
  return '${days ~/ daysPerMonth} 個月';
}

String ratingLabel(Rating rating) => switch (rating) {
  Rating.again => '再一次',
  Rating.hard => '困難',
  Rating.good => '記得',
  Rating.easy => '簡單',
};

/// FSRS 四鍵，只在 `SelfGrade` 出現（§3.4）。色彩只是輔助，文字永遠存在；
/// 桌面鍵盤 1–4。
class RatingBar extends StatelessWidget {
  const RatingBar({
    required this.onRate,
    this.previews = const [],
    this.showIntervals = false,
    this.showHelpLine = false,
    this.autofocus = true,
    super.key,
  });

  final ValueChanged<Rating> onRate;
  final List<RatingPreviewDto> previews;
  final bool showIntervals, showHelpLine, autofocus;

  static const _order = [Rating.again, Rating.hard, Rating.good, Rating.easy];
  static final _keys = {
    LogicalKeyboardKey.digit1: Rating.again,
    LogicalKeyboardKey.digit2: Rating.hard,
    LogicalKeyboardKey.digit3: Rating.good,
    LogicalKeyboardKey.digit4: Rating.easy,
  };

  String? _intervalFor(Rating rating) {
    if (!showIntervals) return null;
    final match = previews.where((p) => p.rating == rating).firstOrNull;
    return match == null
        ? null
        : formatRatingInterval(match.intervalMinutes.toInt());
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final rating = _keys[event.logicalKey];
    if (event is! KeyDownEvent || rating == null) {
      return KeyEventResult.ignored;
    }
    onRate(rating);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Focus(
      autofocus: autofocus,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHelpLine) ...[
            AppText(
              '依你記得的程度選，App 會決定下次何時複習。',
              scale: TypeScale.caption,
              color: t.ink.secondary,
            ),
            const SizedBox(height: AppSpace.s2),
          ],
          Row(
            children: [
              for (final (index, rating) in _order.indexed) ...[
                if (index > 0) const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: _RatingKey(
                    rating: rating,
                    interval: _intervalFor(rating),
                    onTap: () => onRate(rating),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingKey extends StatelessWidget {
  const _RatingKey({
    required this.rating,
    required this.interval,
    required this.onTap,
  });

  final Rating rating;
  final String? interval;
  final VoidCallback onTap;

  Color _accent(AppTokens t) => switch (rating) {
    Rating.again => t.shu,
    Rating.hard => t.kincha,
    Rating.good => t.ai,
    Rating.easy => t.moegi,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final accent = _accent(t);
    return Pressable(
      onTap: onTap,
      builder: (context, state) => PressNudge(
        pressed: state.pressed,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          decoration: BoxDecoration(
            color: state.hovered ? t.paper.raised : Colors.transparent,
            border: Border(
              top: BorderSide(color: accent, width: 3),
              bottom: BorderSide(color: t.line.grid),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                ratingLabel(rating),
                scale: TypeScale.label,
                color: accent,
              ),
              if (interval != null)
                AppText(
                  interval!,
                  scale: TypeScale.caption,
                  color: t.ink.secondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

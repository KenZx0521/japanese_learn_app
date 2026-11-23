import 'package:material_ui/material_ui.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/choice_tile.dart';
import '../../../design/widgets/pressable.dart';
import '../scope_copy.dart';
import 'plan_draft.dart';

const _weekdayNames = {
  1: '週一',
  2: '週二',
  3: '週三',
  4: '週四',
  5: '週五',
  6: '週六',
  7: '週日',
};

const _workdays = [1, 2, 3, 4, 5];
const _weekend = [6, 7];

class MinutesPicker extends StatelessWidget {
  const MinutesPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (index, minutes) in planMinuteOptions.indexed) ...[
        if (index > 0) const SizedBox(width: AppSpace.s2),
        Expanded(
          child: ChoiceTile(
            state: minutes == selected
                ? ChoiceTileState.selected
                : ChoiceTileState.idle,
            onTap: () => onChanged(minutes),
            semanticLabel: '每天 $minutes 分鐘',
            dense: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AppText('$minutes 分', maxLines: 1),
            ),
          ),
        ),
      ],
    ],
  );
}

class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  Widget _group(Iterable<int> days) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final day in days)
        Padding(
          padding: const EdgeInsets.only(right: AppSpace.s1),
          child: _DayToggle(
            name: _weekdayNames[day]!,
            selected: selected.contains(day),
            onTap: () => onToggle(day),
          ),
        ),
    ],
  );

  /// 一排放不下七個 48dp，依平日與週末分兩排，比自動換行好讀。
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _group(_workdays),
      const SizedBox(height: AppSpace.s1),
      _group(_weekend),
    ],
  );
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: name,
      builder: (context, state) => PressNudge(
        pressed: state.pressed,
        child: Container(
          width: PaperLayout.minTarget,
          height: PaperLayout.minTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? t.ink.primary : Colors.transparent,
            border: Border.all(color: selected ? t.ink.primary : t.line.strong),
          ),
          child: AppText(
            name.substring(1),
            scale: TypeScale.label,
            color: selected ? t.paper.base : t.ink.primary,
          ),
        ),
      ),
    );
  }
}

/// 目標日期（選填）。用三組加減鈕：月曆格在 320 寬會小於 48dp。
class TargetDateField extends StatelessWidget {
  const TargetDateField({
    required this.target,
    required this.today,
    required this.onChanged,
    super.key,
  });

  final String? target;
  final DateTime today;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceTile(
                state: value == null
                    ? ChoiceTileState.selected
                    : ChoiceTileState.idle,
                onTap: () => onChanged(null),
                child: const AppText('不設定', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: ChoiceTile(
                state: value == null
                    ? ChoiceTileState.idle
                    : ChoiceTileState.selected,
                onTap: value == null
                    ? () => onChanged(defaultTargetFrom(today))
                    : null,
                child: const AppText('設定日期', textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
        if (value != null) ...[
          const SizedBox(height: AppSpace.s3),
          DateSteppers(iso: value, today: today, onChanged: onChanged),
        ],
      ],
    );
  }
}

class DateSteppers extends StatelessWidget {
  const DateSteppers({
    required this.iso,
    required this.today,
    required this.onChanged,
    super.key,
  });

  final String iso;
  final DateTime today;
  final ValueChanged<String> onChanged;

  DateTime get _date => DateTime.parse(iso);
  DateTime get _earliest => DateTime(today.year, today.month, today.day + 1);

  /// 月底會溢位到下個月，先夾在該月最後一天；再夾在明天之後。
  void _shift({int years = 0, int months = 0, int days = 0}) {
    final d = _date;
    final monthIndex = d.year * 12 + d.month - 1 + years * 12 + months;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final moved = DateTime(year, month, d.day.clamp(1, lastDay) + days);
    final clamped = moved.isBefore(_earliest) ? _earliest : moved;
    onChanged(isoDateOf(clamped));
  }

  @override
  Widget build(BuildContext context) {
    final d = _date;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _Stepper(
            unit: '年',
            value: '${d.year}',
            onUp: () => _shift(years: 1),
            onDown: () => _shift(years: -1),
          ),
        ),
        Expanded(
          child: _Stepper(
            unit: '月',
            value: '${d.month}',
            onUp: () => _shift(months: 1),
            onDown: () => _shift(months: -1),
          ),
        ),
        Expanded(
          child: _Stepper(
            unit: '日',
            value: '${d.day}',
            onUp: () => _shift(days: 1),
            onDown: () => _shift(days: -1),
          ),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.unit,
    required this.value,
    required this.onUp,
    required this.onDown,
  });

  final String unit, value;
  final VoidCallback onUp, onDown;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _StepButton(glyph: '＋', label: '$unit，加一', onTap: onUp),
      Semantics(
        liveRegion: true,
        label: '$value $unit',
        child: ExcludeSemantics(
          child: AppText('$value $unit', textAlign: TextAlign.center),
        ),
      ),
      _StepButton(glyph: '－', label: '$unit，減一', onTap: onDown),
    ],
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final String glyph, label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, state) => Container(
        width: PaperLayout.minTarget,
        height: PaperLayout.minTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: state.hovered ? t.paper.sunken : Colors.transparent,
          border: Border.all(color: t.line.grid),
        ),
        child: AppText(glyph, color: t.ink.primary),
      ),
    );
  }
}

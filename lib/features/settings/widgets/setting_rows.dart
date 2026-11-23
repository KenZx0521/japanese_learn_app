import 'package:material_ui/material_ui.dart';

import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/pressable.dart';
import '../../../design/widgets/ruled_list.dart';
import '../../../design/widgets/sheet_frame.dart';
import '../settings_labels.dart';

/// 一列設定：左邊名稱、右邊目前的值，點開選擇面板。
class SettingValueRow extends StatelessWidget {
  const SettingValueRow({
    required this.title,
    required this.value,
    required this.onTap,
    this.detail,
    super.key,
  });

  final String title, value;
  final String? detail;
  final VoidCallback onTap;

  static const _maxValueRatio = 0.45;

  @override
  Widget build(BuildContext context) {
    final maxValue = MediaQuery.sizeOf(context).width * _maxValueRatio;
    return RuledTile(
      title: AppText(title),
      subtitle: detail == null ? null : _Detail(text: detail!),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxValue),
        child: AppText(
          value,
          scale: TypeScale.label,
          textAlign: TextAlign.right,
          color: AppTokens.of(context).ink.secondary,
        ),
      ),
      onTap: onTap,
      semanticLabel: '$title，目前是$value',
    );
  }
}

/// 開關列。整列都可點，語意帶 toggled，開關形狀與文字不只靠顏色（§4.6）。
class SettingToggleRow extends StatelessWidget {
  const SettingToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.detail,
    super.key,
  });

  final String title;
  final String? detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  String get _semantic => detail == null ? title : '$title，$detail';

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line.grid)),
      ),
      child: Pressable(
        onTap: () => onChanged(!value),
        toggled: value,
        semanticLabel: _semantic,
        builder: (context, state) => ColoredBox(
          color: state.hovered ? t.paper.raised : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpace.s3,
              horizontal: AppSpace.s1,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(title),
                      if (detail != null) _Detail(text: detail!),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                AppText(
                  value ? '開' : '關',
                  scale: TypeScale.caption,
                  color: t.ink.secondary,
                ),
                const SizedBox(width: AppSpace.s2),
                _PaperSwitch(value: value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => AppText(
    text,
    scale: TypeScale.caption,
    color: AppTokens.of(context).ink.secondary,
  );
}

/// 方形滑鈕，開著時整條上墨。只負責外觀，互動與語意在 [SettingToggleRow]。
class _PaperSwitch extends StatelessWidget {
  const _PaperSwitch({required this.value});
  final bool value;

  static const _width = 44.0;
  static const _height = 26.0;
  static const _thumb = 18.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final motion = AppMotion.of(context).base;
    return AnimatedContainer(
      duration: motion.duration,
      curve: motion.curve,
      width: _width,
      height: _height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? t.ink.primary : Colors.transparent,
        border: Border.all(color: value ? t.ink.primary : t.line.strong),
      ),
      child: AnimatedAlign(
        duration: motion.duration,
        curve: motion.curve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: SizedBox.square(
          dimension: _thumb,
          child: ColoredBox(color: value ? t.paper.base : t.line.strong),
        ),
      ),
    );
  }
}

/// 回傳被選的項目；關閉面板回傳 null（`T` 本身可為 null，用來表示「依課程」）。
Future<SettingOption<T>?> showSettingChoices<T>(
  BuildContext context, {
  required String title,
  required List<SettingOption<T>> options,
  required T selected,
}) => showPaperSheet<SettingOption<T>>(
  context,
  child: _ChoiceSheet<T>(title: title, options: options, selected: selected),
);

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<SettingOption<T>> options;
  final T selected;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(title, scale: TypeScale.title),
      const SizedBox(height: AppSpace.s3),
      for (final option in options)
        _ChoiceRow(
          label: option.label,
          detail: option.detail,
          selected: option.value == selected,
          onTap: () => Navigator.of(context).pop(option),
        ),
    ],
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line.grid)),
      ),
      child: Pressable(
        onTap: onTap,
        selected: selected,
        builder: (context, state) => ColoredBox(
          color: state.hovered ? t.paper.sunken : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpace.s3,
              horizontal: AppSpace.s1,
            ),
            child: Row(
              children: [
                _SelectedMark(selected: selected),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(label),
                      if (detail != null) _Detail(text: detail!),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedMark extends StatelessWidget {
  const _SelectedMark({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: 18,
      height: 18,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? t.ink.primary : t.line.strong,
          width: selected ? 2 : 1,
        ),
      ),
      child: selected ? ColoredBox(color: t.ink.primary) : null,
    );
  }
}

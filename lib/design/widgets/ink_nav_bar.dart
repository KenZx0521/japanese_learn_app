import 'package:material_ui/material_ui.dart';

import '../../core/text/ja_text.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'pressable.dart';

@immutable
final class InkNavDestination {
  const InkNavDestination(this.glyph, this.label);

  /// 圖示字是裝飾，螢幕報讀只唸 [label]（§2.1）。
  final String glyph, label;
}

/// 底部與側邊導覽（§4.4）：當前項以朱色方框圈住圖示字。
class InkNavBar extends StatelessWidget {
  const InkNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.vertical,
    super.key,
  });

  final List<InkNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final items = [
      for (final (index, destination) in destinations.indexed)
        _NavItem(
          destination: destination,
          selected: index == currentIndex,
          onTap: () => onSelect(index),
        ),
    ];
    return Semantics(
      container: true,
      label: '主要導覽',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.paper.base,
          border: vertical
              ? Border(right: BorderSide(color: t.line.grid))
              : Border(top: BorderSide(color: t.line.grid)),
        ),
        child: SafeArea(
          top: vertical,
          bottom: !vertical,
          right: false,
          child: vertical ? _rail(items) : _bar(items),
        ),
      ),
    );
  }

  Widget _rail(List<Widget> items) => SizedBox(
    width: PaperLayout.railWidth,
    child: Padding(
      padding: const EdgeInsets.only(top: AppSpace.s5),
      child: Column(children: items),
    ),
  );

  Widget _bar(List<Widget> items) =>
      Row(children: [for (final item in items) Expanded(child: item)]);
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final InkNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _frame = 34.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: destination.label,
      builder: (context, state) => PressNudge(
        pressed: state.pressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          color: state.hovered ? t.paper.raised : Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _frame,
                height: _frame,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: selected ? Border.all(color: t.shu, width: 2) : null,
                ),
                child: JaText(
                  destination.glyph,
                  scale: TypeScale.jaBody,
                  fontWeight: FontWeight.w600,
                  color: selected ? t.shu : t.ink.secondary,
                  textScaler: TextScaler.noScaling,
                ),
              ),
              const SizedBox(height: AppSpace.s1),
              AppText(
                destination.label,
                scale: TypeScale.caption,
                color: selected ? t.ink.primary : t.ink.secondary,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

/// `ShownToggleable`：頁面右上開關可收起羅馬字，只影響當前頁（§3.7）。
class RomajiPageScope extends StatefulWidget {
  const RomajiPageScope({required this.child, super.key});
  final Widget child;

  static bool collapsedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_RomajiScopeData>()
          ?.collapsed ??
      false;

  static void toggle(BuildContext context) =>
      context.findAncestorStateOfType<_RomajiPageScopeState>()?._toggle();

  @override
  State<RomajiPageScope> createState() => _RomajiPageScopeState();
}

class _RomajiPageScopeState extends State<RomajiPageScope> {
  bool _collapsed = false;

  void _toggle() => setState(() => _collapsed = !_collapsed);

  @override
  Widget build(BuildContext context) =>
      _RomajiScopeData(collapsed: _collapsed, child: widget.child);
}

class _RomajiScopeData extends InheritedWidget {
  const _RomajiScopeData({required this.collapsed, required super.child});
  final bool collapsed;

  @override
  bool updateShouldNotify(_RomajiScopeData oldWidget) =>
      oldWidget.collapsed != collapsed;
}

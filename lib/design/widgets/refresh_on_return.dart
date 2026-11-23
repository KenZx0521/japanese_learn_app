import 'package:material_ui/material_ui.dart';

/// 被別的路由蓋住或切到別的分頁再回來時呼叫 [onReturn]：學習進度可能變了，
/// 而分頁的第一層一直掛著，provider 不會自己重取。
class RefreshOnReturn extends StatefulWidget {
  const RefreshOnReturn({
    required this.onReturn,
    required this.child,
    super.key,
  });

  final VoidCallback onReturn;
  final Widget child;

  @override
  State<RefreshOnReturn> createState() => _RefreshOnReturnState();
}

class _RefreshOnReturnState extends State<RefreshOnReturn> {
  bool _hidden = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && _hidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReturn();
      });
    }
    _hidden = !visible;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

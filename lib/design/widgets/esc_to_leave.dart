import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 桌面與外接鍵盤的 Esc 離開（§4.6）。
///
/// 不用 `Focus(autofocus)`：它會先佔走 FocusScope，內層打字框與按鈕的自動焦點
/// 全部失效。面板或其他路由蓋在上面時本頁不是最上層，Esc 留給它們。
class EscToLeave extends StatefulWidget {
  const EscToLeave({required this.onEscape, required this.child, super.key});

  final VoidCallback onEscape;
  final Widget child;

  @override
  State<EscToLeave> createState() => _EscToLeaveState();
}

class _EscToLeaveState extends State<EscToLeave> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    final isEscape =
        event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape;
    if (!isEscape || !mounted) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    widget.onEscape();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

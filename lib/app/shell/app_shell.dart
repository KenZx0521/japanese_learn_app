import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/ink_nav_bar.dart';

const _destinations = [
  InkNavDestination('今', '今日'),
  InkNavDestination('学', '學習'),
  InkNavDestination('聴', '聽說'),
  InkNavDestination('暦', '計畫'),
  InkNavDestination('設', '設定'),
];

/// 底部導覽殼層，寬度 ≥1024 改為左側直欄（§2.1）。
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final vertical =
        MediaQuery.sizeOf(context).width >= PaperLayout.wideBreakpoint;
    final nav = InkNavBar(
      destinations: _destinations,
      currentIndex: shell.currentIndex,
      onSelect: _select,
      vertical: vertical,
    );
    return Material(
      type: MaterialType.transparency,
      child: vertical
          ? Row(
              children: [
                nav,
                Expanded(child: shell),
              ],
            )
          : Column(
              children: [
                Expanded(child: shell),
                nav,
              ],
            ),
    );
  }
}

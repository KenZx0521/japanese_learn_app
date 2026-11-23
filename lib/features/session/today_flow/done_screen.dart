import 'package:material_ui/material_ui.dart';

import '../../today/done_view.dart';

/// 路由入口（§2.2）。T3 的實作在 `features/today/`。
class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key});

  @override
  Widget build(BuildContext context) => const DoneView();
}

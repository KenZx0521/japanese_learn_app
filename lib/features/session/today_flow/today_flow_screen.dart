import 'package:material_ui/material_ui.dart';

import '../../today/flow/today_flow_view.dart';

/// 路由入口（§2.2）。T2 的實作在 `features/today/flow/`。
class TodayFlowScreen extends StatelessWidget {
  const TodayFlowScreen({this.start, super.key});

  final String? start;

  @override
  Widget build(BuildContext context) => TodayFlowView(start: start);
}

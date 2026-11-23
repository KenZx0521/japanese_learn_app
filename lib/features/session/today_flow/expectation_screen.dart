import 'package:material_ui/material_ui.dart';

import '../../today/expectation_view.dart';

/// 路由入口（§2.2）。O6 的實作在 `features/today/`。
class ExpectationScreen extends StatelessWidget {
  const ExpectationScreen({super.key});

  @override
  Widget build(BuildContext context) => const ExpectationView();
}

import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// 稿紙答題線（§3.6）：放 reorder 已選的詞塊，空的時候保留高度。
class AnswerLine extends StatelessWidget {
  const AnswerLine({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s2,
        vertical: AppSpace.s2,
      ),
      decoration: BoxDecoration(
        color: t.paper.sunken,
        border: Border(bottom: BorderSide(color: t.line.strong)),
      ),
      child: Wrap(
        spacing: AppSpace.s2,
        runSpacing: AppSpace.s2,
        children: children,
      ),
    );
  }
}

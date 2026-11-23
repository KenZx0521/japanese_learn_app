import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'app_text.dart';

enum SideRuleTone { ai, shu }

/// 左側直線提示：「和中文比一比」用 ai，「容易錯」用 shu（§3.5）。
class SideRuleNote extends StatelessWidget {
  const SideRuleNote({
    required this.title,
    required this.child,
    this.tone = SideRuleTone.ai,
    super.key,
  });

  final String title;
  final Widget child;
  final SideRuleTone tone;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final color = tone == SideRuleTone.ai ? t.ai : t.shu;
    return Container(
      padding: const EdgeInsets.only(left: AppSpace.s3),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title, scale: TypeScale.label, color: color),
          const SizedBox(height: AppSpace.s1),
          child,
        ],
      ),
    );
  }
}

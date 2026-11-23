import 'package:material_ui/material_ui.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ruled_list.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.label,
    required this.children,
    super.key,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: EyebrowText(label)),
        const SizedBox(height: AppSpace.s2),
        RuledList(children: children),
      ],
    ),
  );
}

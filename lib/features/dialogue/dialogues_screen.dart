import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/ruled_list.dart';
import 'dialogue_providers.dart';
import 'view/dialogue_summary_tile.dart';

/// S3 對話列表（§3.7）：還沒學到的對話標課次、仍可點。
class DialoguesScreen extends ConsumerWidget {
  const DialoguesScreen({super.key});

  static const _kindOrder = [
    DialogueKindDto.lesson,
    DialogueKindDto.extra,
    DialogueKindDto.casual,
  ];

  static String _kindLabel(DialogueKindDto kind) => switch (kind) {
    DialogueKindDto.lesson => '課文對話',
    DialogueKindDto.extra => '實戰對話',
    DialogueKindDto.casual => '常體對話',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => PaperScaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageBackLink(fallback: AppRoutes.listen),
        const SizedBox(height: AppSpace.s2),
        const AppText('對話', scale: TypeScale.displayM),
        const SizedBox(height: AppSpace.s5),
        AsyncBody<List<DialogueSummaryDto>>(
          value: ref.watch(dialogueListProvider),
          onRetry: () => ref.invalidate(dialogueListProvider),
          data: (items) => _list(context, items),
        ),
      ],
    ),
  );

  Widget _list(BuildContext context, List<DialogueSummaryDto> items) {
    if (items.isEmpty) {
      return const AppText('這一版還沒有對話。');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in _kindOrder)
          if (items.any((item) => item.kind == kind))
            _Group(
              label: _kindLabel(kind),
              items: [
                for (final item in items)
                  if (item.kind == kind) item,
              ],
            ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.items});

  final String label;
  final List<DialogueSummaryDto> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EyebrowText(label),
        const SizedBox(height: AppSpace.s2),
        RuledList(
          children: [
            for (final item in items) DialogueSummaryTile(dialogue: item),
          ],
        ),
      ],
    ),
  );
}

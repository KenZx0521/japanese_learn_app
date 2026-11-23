import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/course_groups.dart';
import '../../core/backend/frb/dto.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/esc_to_leave.dart';
import '../../design/widgets/paper_scaffold.dart';
import 'dialogue_providers.dart';
import 'view/dialogue_runner.dart';

/// S4 對話播放（`/session/dialogue/:id`），手動進入跑全部四階段。
class DialogueScreen extends ConsumerWidget {
  const DialogueScreen({required this.dialogueId, super.key});

  final String dialogueId;

  void _leave(BuildContext context) =>
      leavePage(context, fallback: AppRoutes.dialogues);

  @override
  Widget build(BuildContext context, WidgetRef ref) => EscToLeave(
    onEscape: () => _leave(context),
    child: PaperScaffold(
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageBackLink(fallback: AppRoutes.dialogues),
          const SizedBox(height: AppSpace.s2),
          _AheadNote(dialogueId: dialogueId),
          Expanded(
            child: AsyncBody<DialogueDto>(
              value: ref.watch(dialogueDetailProvider(dialogueId)),
              onRetry: () => ref.invalidate(dialogueDetailProvider(dialogueId)),
              data: (dialogue) => DialogueRunner(
                dialogue: dialogue,
                finishLabel: '回到列表',
                onFinished: () => _leave(context),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// S3、L2 可以點開還沒學到的對話（§3.7）。是否還沒學到看 `dialogues()` 的
/// `locked`，Dart 不自己推算進度；讀不到或不在列表時不顯示。
class _AheadNote extends ConsumerWidget {
  const _AheadNote({required this.dialogueId});

  final String dialogueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(dialogueListProvider).value ?? const [];
    final summary = summaries
        .where((item) => item.id == dialogueId && item.locked)
        .firstOrNull;
    if (summary == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: AppText(
        '還沒學到${lessonNumberLabel(summary.lessonId)}，可以先聽聽看。',
        scale: TypeScale.caption,
        color: AppTokens.of(context).ink.secondary,
      ),
    );
  }
}

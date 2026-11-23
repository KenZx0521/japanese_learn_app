import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/course_groups.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/text/mixed_text.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ruled_list.dart';

/// S3 與 L2 共用的對話列（§3.7）。還沒學到的對話淡色並標課次，但仍可點進 S4，
/// S4 再說明「還沒學到」，不鎖定內容。
class DialogueSummaryTile extends StatelessWidget {
  const DialogueSummaryTile({required this.dialogue, super.key});

  final DialogueSummaryDto dialogue;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final ahead = dialogue.locked;
    final lessonLabel = lessonNumberLabel(dialogue.lessonId);
    return RuledTile(
      title: MixedText(
        dialogue.sceneZh,
        color: ahead ? t.ink.tertiary : t.ink.primary,
      ),
      subtitle: MixedText(
        dialogue.goalZh,
        scale: TypeScale.caption,
        color: ahead ? t.ink.tertiary : t.ink.secondary,
      ),
      trailing: ahead
          ? AppText(
              lessonLabel,
              semanticsLabel: '還沒學到$lessonLabel',
              scale: TypeScale.caption,
              color: t.ink.secondary,
            )
          : null,
      onTap: () =>
          unawaited(context.push(AppRoutes.sessionDialogue(dialogue.id))),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/text/ja_text.dart';
import '../../core/text/mixed_text.dart';
import '../../core/tts/tts_engine.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'ink_buttons.dart';
import 'speak_button.dart';

/// 易混字組（§3.10）：`members` 並排大字、`literals`、`diff_zh`，各字可播。
class ConfusableView extends StatelessWidget {
  const ConfusableView({required this.group, this.onNext, super.key});

  final ConfusableDto group;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpace.s4,
          runSpacing: AppSpace.s3,
          children: [
            for (final member in group.members) _MemberColumn(member: member),
          ],
        ),
        if (group.literals.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s3),
          for (final (index, literal) in group.literals.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        JaText(literal.text),
                        AppText(
                          literal.zh,
                          scale: TypeScale.caption,
                          color: t.ink.secondary,
                        ),
                      ],
                    ),
                  ),
                  SpeakButton(
                    request: SpeechRequest.fromDto(
                      '${group.id}.lit$index',
                      literal.speech,
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppSpace.s3),
        MixedText(group.diffZh),
        const SizedBox(height: AppSpace.s5),
        InkButton(label: '下一步', onPressed: onNext, autofocus: true),
      ],
    );
  }
}

class _MemberColumn extends StatelessWidget {
  const _MemberColumn({required this.member});
  final KanaCellDto member;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      JaText(member.ch, scale: TypeScale.jaHero),
      if (!member.listenDisabled)
        SpeakButton(request: SpeechRequest.fromDto(member.id, member.speech)),
    ],
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/text/ruby_line.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/censor_bar.dart';
import '../dialogue_speech.dart';

/// 一句對白：角色、日文（可換成伏字條）、中文、補充說明。
/// 正在播這句時左側出現 `ai` 直線。
class TurnView extends ConsumerWidget {
  const TurnView({
    required this.dialogue,
    required this.index,
    required this.policy,
    this.showJapanese = true,
    this.showChinese = true,
    this.showNote = true,
    this.trailing,
    this.onWordTap,
    super.key,
  });

  final DialogueDto dialogue;
  final int index;
  final DisplayPolicyDto policy;
  final bool showJapanese, showChinese, showNote;
  final Widget? trailing;
  final ValueChanged<WordDto>? onWordTap;

  bool _isSpeaking(TtsPlayback playback) => switch (playback) {
    TtsPreparing(:final id) ||
    TtsSpeaking(:final id) => isTurnSpeech(id, dialogue, index),
    TtsIdle() || TtsError() => false,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final speaking = ref.watch(ttsControllerProvider.select(_isSpeaking));
    final turn = dialogue.turns[index];
    return AnimatedContainer(
      duration: AppMotion.of(context).fast.duration,
      curve: AppMotion.of(context).fast.curve,
      padding: const EdgeInsets.only(left: AppSpace.s3),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: speaking ? t.ai : t.line.grid,
            width: speaking ? 3 : 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _content(t, turn)),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.s2),
            trailing!,
          ],
        ],
      ),
    );
  }

  Widget _content(AppTokens t, DialogueTurnDto turn) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        roleNameOf(dialogue, turn.role),
        scale: TypeScale.label,
        color: t.ink.secondary,
      ),
      const SizedBox(height: AppSpace.s1),
      if (showJapanese)
        RubyLine.sentence(turn.sentence, policy: policy, onWordTap: onWordTap)
      else
        CensorBar(characters: turn.sentence.display.characters.length),
      if (showChinese) ...[
        const SizedBox(height: AppSpace.s1),
        MixedText(turn.sentence.zh, color: t.ink.secondary),
      ],
      if (showNote && turn.noteZh != null) ...[
        const SizedBox(height: AppSpace.s1),
        MixedText(
          turn.noteZh!,
          scale: TypeScale.caption,
          color: t.ink.secondary,
        ),
      ],
    ],
  );
}

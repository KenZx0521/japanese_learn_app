import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/text/ja_text.dart';
import '../../core/text/mixed_text.dart';
import '../../core/tts/tts_engine.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'beat_strip.dart';
import 'ink_buttons.dart';
import 'ruled_list.dart';
import 'sound_pair_view.dart';
import 'speak_button.dart';

/// 規則卡（§3.3 K3，L3 的 `Rule` 步驟共用）。
class RuleCardView extends StatelessWidget {
  const RuleCardView({required this.card, this.onTest, this.onNext, super.key});

  final RuleCardDto card;

  /// `drill_ids` 非空時才傳，L3 內不傳（由後續 `KanaQuiz` 出題）。
  final VoidCallback? onTest;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final test = onTest;
    final next = onNext;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MixedText(card.titleZh, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s3),
        MixedText(card.bodyZh),
        const SizedBox(height: AppSpace.s4),
        RuledList(
          children: [
            for (final (index, example) in card.examples.indexed)
              _RuleExampleRow(
                example: example,
                speechId: '${card.id}.ex$index',
              ),
          ],
        ),
        for (final group in card.soundGroups) ...[
          const SizedBox(height: AppSpace.s4),
          _SoundGroupBlock(group: group),
        ],
        if (test != null) ...[
          const SizedBox(height: AppSpace.s4),
          GhostButton(label: '測試一下', onPressed: test),
        ],
        if (next != null) ...[
          const SizedBox(height: AppSpace.s5),
          InkButton(label: '下一步', onPressed: next, autofocus: true),
        ],
      ],
    );
  }
}

class _RuleExampleRow extends StatelessWidget {
  const _RuleExampleRow({required this.example, required this.speechId});
  final RuleExampleDto example;
  final String speechId;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final request = SpeechRequest.fromDto(speechId, example.speech);
    return RuledTile(
      title: JaText(example.text, scale: TypeScale.jaSentence),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(example.zh, scale: TypeScale.caption, color: t.ink.secondary),
          if (example.beats.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s2),
            BeatStrip(beats: example.beats, request: request),
          ],
        ],
      ),
      trailing: SpeakButton(request: request),
    );
  }
}

class _SoundGroupBlock extends StatelessWidget {
  const _SoundGroupBlock({required this.group});
  final SoundGroupDto group;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MixedText(group.titleZh, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s1),
        MixedText(group.bodyZh, color: t.ink.secondary),
        if (group.kind == SoundGroupKindDto.accent) ...[
          const SizedBox(height: AppSpace.s1),
          AppText('由裝置合成，僅供參考', scale: TypeScale.caption, color: t.kincha),
        ],
        const SizedBox(height: AppSpace.s3),
        for (final (index, pair) in group.pairs.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s3),
            child: SoundPairView(pair: pair, pairId: '${group.id}.$index'),
          ),
      ],
    );
  }
}

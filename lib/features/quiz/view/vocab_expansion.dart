import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';
import '../../../core/text/ja_text.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/text/policy_romaji.dart';
import '../../../core/text/ruby_line.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/async_body.dart';
import '../../../design/widgets/note_body.dart';
import '../../../design/widgets/side_rule_note.dart';
import '../../../design/widgets/speak_button.dart';

final quizVocabDetailProvider = FutureProvider.autoDispose
    .family<VocabDetailDto, String>(
      (ref, id) => ref.watch(vocabRepositoryProvider).detail(id),
    );

/// V4 答後展開（§3.4 第 4 點）：Choice、Reorder 答完後，SelfGrade 翻面後。
class VocabExpansion extends ConsumerWidget {
  const VocabExpansion({
    required this.vocabId,
    required this.policy,
    this.showHead = true,
    super.key,
  });

  final String vocabId;
  final DisplayPolicyDto policy;

  /// SelfGrade 背面已顯示單字、羅馬字與意思時設 false，避免同一張卡寫兩次。
  final bool showHead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = quizVocabDetailProvider(vocabId);
    return AsyncBody<VocabDetailDto>(
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      data: (detail) =>
          _ExpandedWord(detail: detail, policy: policy, showHead: showHead),
    );
  }
}

class _ExpandedWord extends StatelessWidget {
  const _ExpandedWord({
    required this.detail,
    required this.policy,
    required this.showHead,
  });
  final VocabDetailDto detail;
  final DisplayPolicyDto policy;
  final bool showHead;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final word = detail.summary;
    final example = detail.examples.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badges(detail: detail),
        if (showHead) ...[
          JaText(word.surface, scale: TypeScale.jaSentence),
          if (word.kana != word.surface)
            JaText(word.kana, color: t.ink.secondary),
          PolicyRomaji(word.romaji, mode: policy.romaji),
          AppText(word.zh.join('、')),
        ],
        if (example != null) ...[
          const SizedBox(height: AppSpace.s3),
          RubyLine.sentence(example, policy: policy),
          AppText(example.zh, color: t.ink.secondary),
          SpeakButton(
            request: SpeechRequest.fromDto(example.id, example.speech),
          ),
        ],
        ..._notes(),
      ],
    );
  }

  List<Widget> _notes() => [
    if (detail.hookZh case final hook?) ...[
      const SizedBox(height: AppSpace.s3),
      SideRuleNote(title: '記法', child: MixedText(hook)),
    ],
    if (detail.trapZh case final trap?) ...[
      const SizedBox(height: AppSpace.s3),
      SideRuleNote(title: '容易錯', child: MixedText(trap)),
    ],
    for (final note in detail.notes) ...[
      const SizedBox(height: AppSpace.s3),
      NoteBody(note: note),
    ],
  ];
}

class _Badges extends StatelessWidget {
  const _Badges({required this.detail});
  final VocabDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final labels = <(String, Color)>[
      if (detail.notes.any((note) => note is NoteDto_FalseFriend))
        ('同形異義', t.shu),
      if (detail.notes.any((note) => note is NoteDto_Shinjitai))
        ('和正體不同', t.kincha),
      if (detail.useLevel == UseLevelDto.recognizeOnly) ('聽懂就好', t.ai),
    ];
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Wrap(
        spacing: AppSpace.s3,
        children: [
          for (final (label, color) in labels)
            AppText(label, scale: TypeScale.label, color: color),
        ],
      ),
    );
  }
}

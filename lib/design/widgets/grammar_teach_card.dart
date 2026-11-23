import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../core/text/ruby_line.dart';
import '../../core/tts/tts_engine.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'ink_buttons.dart';
import 'pattern_blocks.dart';
import 'side_rule_note.dart';
import 'speak_button.dart';

/// 新文法呈現（§3.10）：標題、公式、意思、說明、比較、陷阱、1–2 句例句。
class GrammarTeachCard extends StatelessWidget {
  const GrammarTeachCard({
    required this.detail,
    required this.policy,
    this.hasQuiz = false,
    this.onNext,
    super.key,
  });

  final GrammarDetailDto detail;
  final DisplayPolicyDto policy;
  final bool hasQuiz;
  final VoidCallback? onNext;

  static const _maxExamples = 2;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final summary = detail.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MixedText(summary.titleZh, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s3),
        PatternBlocks(summary.pattern),
        const SizedBox(height: AppSpace.s3),
        MixedText(summary.meaningZh, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s2),
        MixedText(detail.explainZh),
        const SizedBox(height: AppSpace.s4),
        SideRuleNote(title: '和中文比一比', child: MixedText(detail.compareZh)),
        if (detail.trapZh != null) ...[
          const SizedBox(height: AppSpace.s3),
          SideRuleNote(
            title: '容易錯',
            tone: SideRuleTone.shu,
            child: MixedText(detail.trapZh!),
          ),
        ],
        for (final example in detail.examples.take(_maxExamples)) ...[
          const SizedBox(height: AppSpace.s4),
          RubyLine.sentence(example, policy: policy),
          AppText(example.zh, color: t.ink.secondary),
          SpeakButton(
            request: SpeechRequest.fromDto(example.id, example.speech),
          ),
        ],
        const SizedBox(height: AppSpace.s5),
        InkButton(
          label: hasQuiz ? '考一題' : '下一步',
          onPressed: onNext,
          autofocus: true,
        ),
      ],
    );
  }
}

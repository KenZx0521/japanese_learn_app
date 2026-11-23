import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/text/ja_text.dart';
import '../../core/text/mixed_text.dart';
import '../../core/text/policy_romaji.dart';
import '../../core/text/ruby_line.dart';
import '../../core/tts/autoplay.dart';
import '../../core/tts/tts_engine.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'ink_buttons.dart';
import 'side_rule_note.dart';
import 'speak_button.dart';
import 'speed_toggle.dart';

/// 新單字呈現（§3.10）：`hasQuiz`（`first_card` 非 None）時主按鈕為「考一題」。
class VocabTeachCard extends StatelessWidget {
  const VocabTeachCard({
    required this.detail,
    required this.policy,
    this.hasQuiz = false,
    this.onNext,
    super.key,
  });

  final VocabDetailDto detail;
  final DisplayPolicyDto policy;
  final bool hasQuiz;
  final VoidCallback? onNext;

  VocabSummaryDto get _word => detail.summary;

  SpeechRequest get _request => SpeechRequest.fromDto(_word.id, _word.speech);

  bool get _showKana => _word.kana != _word.surface;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final example = detail.examples.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoplayOnce(request: _request),
        // 片語較長時縮小，換行會斷在詞中（§7.3 換行只發生在詞界）
        _SingleLine(JaText(_word.surface, scale: TypeScale.jaHero)),
        if (_showKana)
          _SingleLine(
            JaText(
              _word.kana,
              scale: TypeScale.jaSentence,
              color: t.ink.secondary,
            ),
          ),
        PolicyRomaji(_word.romaji, mode: policy.romaji),
        const SizedBox(height: AppSpace.s2),
        Row(
          children: [
            SpeakButton(request: _request),
            const SizedBox(width: AppSpace.s2),
            const SpeedToggle(),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        AppText(_word.zh.join('、'), scale: TypeScale.title),
        const SizedBox(height: AppSpace.s2),
        _Badges(notes: detail.notes),
        if (example != null) ...[
          const SizedBox(height: AppSpace.s4),
          _ExampleBlock(example: example, policy: policy),
        ],
        ..._notes(),
        const SizedBox(height: AppSpace.s5),
        InkButton(
          label: hasQuiz ? '考一題' : '下一步',
          onPressed: onNext,
          autofocus: true,
        ),
      ],
    );
  }

  List<Widget> _notes() => [
    if (detail.hookZh != null) ...[
      const SizedBox(height: AppSpace.s3),
      SideRuleNote(title: '記法', child: MixedText(detail.hookZh!)),
    ],
    if (detail.trapZh != null) ...[
      const SizedBox(height: AppSpace.s3),
      SideRuleNote(
        title: '容易錯',
        tone: SideRuleTone.shu,
        child: MixedText(detail.trapZh!),
      ),
    ],
  ];
}

class _SingleLine extends StatelessWidget {
  const _SingleLine(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: child,
  );
}

class _ExampleBlock extends StatelessWidget {
  const _ExampleBlock({required this.example, required this.policy});
  final SentenceDto example;
  final DisplayPolicyDto policy;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RubyLine.sentence(example, policy: policy),
      AppText(example.zh, color: AppTokens.of(context).ink.secondary),
      SpeakButton(request: SpeechRequest.fromDto(example.id, example.speech)),
    ],
  );
}

class _Badges extends StatelessWidget {
  const _Badges({required this.notes});
  final List<NoteDto> notes;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final hasFalseFriend = notes.any((note) => note is NoteDto_FalseFriend);
    final hasShinjitai = notes.any((note) => note is NoteDto_Shinjitai);
    if (!hasFalseFriend && !hasShinjitai) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpace.s2,
      children: [
        if (hasFalseFriend)
          AppText('同形異義', scale: TypeScale.label, color: t.shu),
        if (hasShinjitai)
          AppText('和正體不同', scale: TypeScale.label, color: t.kincha),
      ],
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/ja_text.dart';
import '../../core/text/policy_romaji.dart';
import '../../core/text/romaji_scope.dart';
import '../../core/tts/tts_engine.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/speak_button.dart';
import '../../design/widgets/speed_toggle.dart';
import 'vocab_labels.dart';
import 'vocab_providers.dart';
import 'widgets/accent_line.dart';
import 'widgets/vocab_detail_sections.dart';
import 'widgets/vocab_flag_bar.dart';

/// V3 單字詳情（§3.4）。
class VocabDetailScreen extends ConsumerWidget {
  const VocabDetailScreen({required this.wordId, super.key});

  final String wordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = vocabDetailViewProvider(wordId);
    final view = ref.watch(provider);
    final word = view.value?.detail.summary;
    return RomajiPageScope(
      child: PaperScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(word: word, policy: view.value?.policy),
            AsyncBody<VocabDetailView>(
              value: view,
              onRetry: () => ref.invalidate(provider),
              data: (data) =>
                  _DetailBody(detail: data.detail, policy: data.policy),
            ),
          ],
        ),
      ),
    );
  }
}

/// 窄螢幕放不下時標記鈕換到下一行，兩端對齊維持左返回、右標記。
class _TopBar extends StatelessWidget {
  const _TopBar({required this.word, required this.policy});

  final VocabSummaryDto? word;
  final DisplayPolicyDto? policy;

  @override
  Widget build(BuildContext context) {
    final current = word;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpace.s2,
      runSpacing: AppSpace.s2,
      children: [
        const PageBackLink(fallback: AppRoutes.vocab),
        if (current != null)
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              if (policy?.romaji == RomajiMode.shownToggleable)
                const _RomajiToggle(),
              VocabFlagButtons(word: current),
            ],
          ),
      ],
    );
  }
}

/// `ShownToggleable`：右上開關只影響當前頁（§3.7）。
class _RomajiToggle extends StatelessWidget {
  const _RomajiToggle();

  @override
  Widget build(BuildContext context) => GhostButton(
    label: RomajiPageScope.collapsedOf(context) ? '顯示羅馬字' : '收起羅馬字',
    onPressed: () => RomajiPageScope.toggle(context),
  );
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.policy});

  final VocabDetailDto detail;
  final DisplayPolicyDto policy;

  VocabSummaryDto get _word => detail.summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final request = SpeechRequest.fromDto(_word.id, _word.speech);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s3),
        JaText(_word.surface, scale: TypeScale.jaHero),
        if (_word.kana != _word.surface)
          JaText(
            _word.kana,
            scale: TypeScale.jaSentence,
            color: t.ink.secondary,
          ),
        PolicyRomaji(_word.romaji, mode: policy.romaji),
        if (detail.accent case final accent?) ...[
          const SizedBox(height: AppSpace.s2),
          Align(
            alignment: Alignment.centerLeft,
            child: AccentLine(kana: _word.kana, accent: accent),
          ),
        ],
        const SizedBox(height: AppSpace.s3),
        Row(
          children: [
            SpeakButton(request: request),
            const SizedBox(width: AppSpace.s2),
            const SpeedToggle(),
          ],
        ),
        const SizedBox(height: AppSpace.s4),
        AppText(_word.zh.join('、'), scale: TypeScale.title),
        _LevelTags(detail: detail),
        VocabFlagFeedback(word: _word),
        ...vocabDetailSections(context, detail: detail, policy: policy),
      ],
    );
  }
}

class _LevelTags extends ConsumerWidget {
  const _LevelTags({required this.detail});

  final VocabDetailDto detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final stage = ref.watch(vocabContentStageProvider).value;
    final jlpt = stage == null ? null : jlptLabelOf(detail.jlpt, stage);
    final useLevel = useLevelLabelOf(detail.useLevel);
    final trans = detail.trans;
    final tags = [
      ?jlpt,
      ?useLevel,
      if (trans != null) transitivityLabelOf(trans),
    ];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s2),
      child: Wrap(
        spacing: AppSpace.s3,
        runSpacing: AppSpace.s1,
        children: [
          for (final tag in tags)
            AppText(tag, scale: TypeScale.label, color: t.ink.secondary),
        ],
      ),
    );
  }
}

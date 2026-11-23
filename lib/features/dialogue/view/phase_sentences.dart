import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/text/romaji_scope.dart';
import '../../../core/text/word_peek.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../core/tts/voice_help.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/pressable.dart';
import '../../../design/widgets/speak_button.dart';
import '../dialogue_speech.dart';
import 'play_all_control.dart';
import 'turn_view.dart';

/// 第二階段：展開全文、逐句播放，可切逐詞與顯示內容（§3.7）。
/// 無聲模式只顯示文字。
class SentencesPhase extends ConsumerStatefulWidget {
  const SentencesPhase({
    required this.dialogue,
    required this.policy,
    required this.audio,
    required this.isLast,
    required this.onDone,
    super.key,
  });

  final DialogueDto dialogue;
  final DisplayPolicyDto policy;
  final bool audio;
  final bool isLast;
  final VoidCallback onDone;

  @override
  ConsumerState<SentencesPhase> createState() => _SentencesPhaseState();
}

class _SentencesPhaseState extends ConsumerState<SentencesPhase> {
  bool _wordMode = false;
  bool _showJapanese = true;
  bool _showChinese = true;

  void _openDetail(String refId) {
    if (refId.startsWith('vo.')) {
      unawaited(context.push(AppRoutes.vocabWord(refId)));
    } else if (refId.startsWith('gr.')) {
      unawaited(context.push(AppRoutes.grammarPoint(refId)));
    }
  }

  void _peek(WordDto word) =>
      unawaited(showWordPeek(context, word, onOpenDetail: _openDetail));

  Future<void> _playWords(int index) async {
    final tts = ref.read(ttsControllerProvider.notifier);
    final finished = await tts.playSequence([
      for (final request in wordRequests(widget.dialogue, index))
        tts.atUserSpeed(request),
    ], fixedGap(dialogueWordGap));
    final failed = !finished && ref.read(ttsControllerProvider) is TtsError;
    if (failed && mounted) unawaited(showVoiceHelpSheet(context));
  }

  Widget? _trailing(int index) {
    if (!widget.audio) return null;
    if (_wordMode) {
      return _WordPlayButton(onTap: () => unawaited(_playWords(index)));
    }
    return SpeakButton(request: turnRequest(widget.dialogue, index));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dialogue;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MixedText(
            d.goalZh,
            scale: TypeScale.caption,
            color: AppTokens.of(context).ink.secondary,
          ),
          const SizedBox(height: AppSpace.s3),
          if (widget.audio) ...[
            PlayAllControl(dialogue: d),
            const SizedBox(height: AppSpace.s2),
          ] else
            const _SilentNote(),
          _displayToggles(context),
          const SizedBox(height: AppSpace.s4),
          for (var i = 0; i < d.turns.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s4),
              child: TurnView(
                dialogue: d,
                index: i,
                policy: widget.policy,
                showJapanese: _showJapanese,
                showChinese: _showChinese,
                onWordTap: _peek,
                trailing: _trailing(i),
              ),
            ),
          InkButton(
            label: widget.isLast ? '完成這段' : '下一段',
            onPressed: widget.onDone,
          ),
        ],
      ),
    );
  }

  Widget _displayToggles(BuildContext context) {
    final toggleableRomaji = widget.policy.romaji == RomajiMode.shownToggleable;
    return Wrap(
      spacing: AppSpace.s2,
      children: [
        if (widget.audio) ...[
          _ToggleChip(
            label: '逐句',
            selected: !_wordMode,
            onTap: () => setState(() => _wordMode = false),
          ),
          _ToggleChip(
            label: '逐詞',
            selected: _wordMode,
            onTap: () => setState(() => _wordMode = true),
          ),
        ],
        _ToggleChip(
          label: '日文',
          selected: _showJapanese,
          onTap: () => setState(() => _showJapanese = !_showJapanese),
        ),
        _ToggleChip(
          label: '中文',
          selected: _showChinese,
          onTap: () => setState(() => _showChinese = !_showChinese),
        ),
        if (toggleableRomaji)
          _ToggleChip(
            label: '羅馬字',
            selected: !RomajiPageScope.collapsedOf(context),
            onTap: () => RomajiPageScope.toggle(context),
          ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      toggled: selected,
      builder: (context, state) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
        decoration: BoxDecoration(
          color: state.hovered ? t.paper.raised : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: selected ? t.ink.primary : t.line.grid,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: AppText(
          label,
          scale: TypeScale.label,
          color: selected ? t.ink.primary : t.ink.secondary,
        ),
      ),
    );
  }
}

class _WordPlayButton extends StatelessWidget {
  const _WordPlayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: '逐詞播放',
      builder: (context, state) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
        decoration: BoxDecoration(
          color: state.hovered ? t.paper.raised : Colors.transparent,
          border: Border.all(
            color: state.pressed ? t.ink.primary : t.line.strong,
          ),
          borderRadius: AppRadii.r1,
        ),
        child: AppText('逐詞', scale: TypeScale.caption, color: t.ai),
      ),
    );
  }
}

class _SilentNote extends StatelessWidget {
  const _SilentNote();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: AppText(
              '現在沒有語音，這一段只顯示文字。',
              scale: TypeScale.caption,
              color: t.ink.secondary,
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          GhostButton(
            label: '設定語音',
            onPressed: () => unawaited(showVoiceHelpSheet(context)),
          ),
        ],
      ),
    );
  }
}

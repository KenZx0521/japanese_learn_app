import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/local_log.dart';
import '../../../core/backend/providers.dart';
import '../../../core/text/display_context.dart';
import '../../../core/text/romaji_scope.dart';
import '../../../core/tts/audio_available.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/async_body.dart';
import '../../../design/widgets/hanko_badge.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/skeleton_lines.dart';
import '../dialogue_providers.dart';
import '../model/dialogue_run.dart';
import 'phase_blind.dart';
import 'phase_roleplay.dart';
import 'phase_sentences.dart';
import 'phase_shadow.dart';
import 'phase_strip.dart';

/// S4 對話流程（§3.7）。放在高度有限的版面（`PaperScaffold(scrollable: false)`）。
///
/// [phases] 從 T2 的 `Integration.phases` 傳入，從 S3 手動進入跑全部。
class DialogueRunner extends ConsumerStatefulWidget {
  const DialogueRunner({
    required this.dialogue,
    required this.onFinished,
    this.phases = allDialoguePhases,
    this.seed,
    this.finishLabel = '完成',
    this.autoFinish = false,
    super.key,
  });

  final DialogueDto dialogue;
  final VoidCallback onFinished;
  final List<int> phases;

  /// 盲聽題目的 `session_seed`；null 時以對話 id 算，離開重來題目相同。
  final int? seed;
  final String finishLabel;

  /// T2 內任務之間已有過場頁，跑完直接回報 [onFinished]，不顯示完成面板。
  /// 全部階段都因沒有語音略過時仍顯示面板，把原因講清楚（§6.4）。
  final bool autoFinish;

  @override
  ConsumerState<DialogueRunner> createState() => _DialogueRunnerState();
}

class _DialogueRunnerState extends ConsumerState<DialogueRunner> {
  late final TtsController _tts;
  bool _finished = false;

  DialogueRunArgs get _args =>
      DialogueRunArgs(dialogueId: widget.dialogue.id, phases: widget.phases);

  int get _seed => widget.seed ?? sessionSeed(widget.dialogue.id);

  DisplayContext get _displayContext =>
      DisplayContext(lessonId: widget.dialogue.lessonId);

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsControllerProvider.notifier);
  }

  @override
  void dispose() {
    // 卸載途中不能動 provider，等這一幀結束
    unawaited(Future.microtask(_stopOnLeave));
    super.dispose();
  }

  /// 只回報一次：T2 的回呼會 `complete_task`。
  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  /// `build` 中不能換任務，等這一幀結束。
  void _finishAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _finish();
    });
  }

  Future<void> _stopOnLeave() async {
    try {
      await _tts.stop();
    } on Exception catch (error, stack) {
      logLocal(error, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 探測前 audio 的 false 不算數，先別決定要略過哪些階段（§6.6）
    if (!ref.watch(audioResolvedProvider)) {
      return const DelayedReveal(child: SkeletonLines());
    }
    // 先停再換階段，下一段的自動播放才不會被上一段的尾音蓋掉
    ref.listen<int?>(dialogueRunProvider(_args).select((r) => r.phase), (
      previous,
      next,
    ) {
      if (previous != next) unawaited(_tts.stop());
    });
    final run = ref.watch(dialogueRunProvider(_args));
    final policy = ref.watch(displayPolicyProvider(_displayContext));
    return RomajiPageScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhaseStrip(run: run),
          const SizedBox(height: AppSpace.s5),
          Expanded(
            child: AsyncBody<DisplayPolicyDto>(
              value: policy,
              onRetry: () =>
                  ref.invalidate(displayPolicyProvider(_displayContext)),
              data: (data) => _phaseBody(run, data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseBody(DialogueRun run, DisplayPolicyDto policy) {
    final d = widget.dialogue;
    final complete = ref
        .read(dialogueRunProvider(_args).notifier)
        .completePhase;
    final phase = run.phase;
    if (phase == null) {
      if (widget.autoFinish && run.visible.isNotEmpty) {
        _finishAfterFrame();
        return const SizedBox.shrink();
      }
      return _FinishedPanel(
        skippedAll: run.visible.isEmpty,
        label: widget.finishLabel,
        onFinished: _finish,
      );
    }
    final key = ValueKey('phase-$phase');
    return switch (phase) {
      1 => BlindPhase(key: key, dialogue: d, seed: _seed, onDone: complete),
      3 => ShadowPhase(
        key: key,
        dialogue: d,
        policy: policy,
        isLast: run.isLastPhase,
        onDone: complete,
      ),
      4 => RoleplayPhase(
        key: key,
        dialogue: d,
        policy: policy,
        audio: run.audio,
        onDone: complete,
      ),
      _ => SentencesPhase(
        key: key,
        dialogue: d,
        policy: policy,
        audio: run.audio,
        isLast: run.isLastPhase,
        onDone: complete,
      ),
    };
  }
}

class _FinishedPanel extends StatelessWidget {
  const _FinishedPanel({
    required this.skippedAll,
    required this.label,
    required this.onFinished,
  });

  final bool skippedAll;
  final String label;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!skippedAll) ...[
        const HankoBadge('済', semanticLabel: '對話完成'),
        const SizedBox(height: AppSpace.s4),
      ],
      Semantics(
        liveRegion: true,
        child: AppText(
          skippedAll ? '現在沒有語音，這段要聽的部分先略過。' : '這段對話練完了。',
          scale: TypeScale.title,
        ),
      ),
      const SizedBox(height: AppSpace.s4),
      InkButton(label: label, onPressed: onFinished),
    ],
  );
}

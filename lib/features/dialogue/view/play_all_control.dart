import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/speed_toggle.dart';
import '../../../design/widgets/voice_failed_panel.dart';
import '../dialogue_speech.dart';
import 'silent_mode.dart';

/// 全篇連播＋語速切換。播放失敗時改顯示 `VoiceFailedPanel`，絕不靜默（§6.6）。
class PlayAllControl extends ConsumerStatefulWidget {
  const PlayAllControl({
    required this.dialogue,
    this.label = '全部播放',
    this.autoStart = false,
    this.onFinished,
    super.key,
  });

  final DialogueDto dialogue;
  final String label;

  /// 進入時自動連播一次（尊重自動播放設定，螢幕報讀時不播）。
  final bool autoStart;

  /// 完整播完才呼叫；被按停止不算。
  final VoidCallback? onFinished;

  @override
  ConsumerState<PlayAllControl> createState() => _PlayAllControlState();
}

class _PlayAllControlState extends ConsumerState<PlayAllControl> {
  bool _playing = false;
  bool _failed = false;
  bool _autoStartChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoStartChecked || !widget.autoStart) return;
    _autoStartChecked = true;
    final autoplay = ref.read(settingsProvider).value?.autoplay ?? false;
    if (!autoplay || MediaQuery.accessibleNavigationOf(context)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_play());
    });
  }

  Future<void> _play() async {
    final tts = ref.read(ttsControllerProvider.notifier);
    final requests = [
      for (final request in allTurnRequests(widget.dialogue))
        tts.atUserSpeed(request),
    ];
    setState(() {
      _playing = true;
      _failed = false;
    });
    final finished = await tts.playSequence(
      requests,
      fixedGap(dialogueTurnGap),
    );
    if (!mounted) return;
    final failed = !finished && ref.read(ttsControllerProvider) is TtsError;
    setState(() {
      _playing = false;
      _failed = failed;
    });
    if (finished) widget.onFinished?.call();
  }

  Future<void> _stop() => ref.read(ttsControllerProvider.notifier).stop();

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return VoiceFailedPanel(
        onRetry: () => unawaited(_play()),
        onSilent: () => unawaited(useSilentMode(ref)),
      );
    }
    return Wrap(
      spacing: AppSpace.s3,
      runSpacing: AppSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_playing)
          GhostButton(label: '停止', onPressed: () => unawaited(_stop()))
        else
          InkButton(label: widget.label, onPressed: () => unawaited(_play())),
        const SpeedToggle(),
      ],
    );
  }
}

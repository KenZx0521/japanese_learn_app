import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/tts/audio_available.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/speak_button.dart';
import '../../../design/widgets/speed_toggle.dart';

/// 播放鈕加語速切換（§6.5：`SpeedToggle` 在每個播放鈕旁）。
/// [replayOnR] 只給題幹那一列：畫面上可能有多個播放鈕，R 重播的是題目（§4.6）。
class SpeakRow extends StatelessWidget {
  const SpeakRow({
    required this.request,
    this.diameter = 48,
    this.replayOnR = false,
    super.key,
  });

  final SpeechRequest request;
  final double diameter;
  final bool replayOnR;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        SpeakButton(request: request, diameter: diameter),
        const SizedBox(width: AppSpace.s2),
        const SpeedToggle(),
      ],
    );
    return replayOnR ? _ReplayOnR(request: request, child: row) : row;
  }
}

class _ReplayOnR extends ConsumerStatefulWidget {
  const _ReplayOnR({required this.request, required this.child});

  final SpeechRequest request;
  final Widget child;

  @override
  ConsumerState<_ReplayOnR> createState() => _ReplayOnRState();
}

class _ReplayOnRState extends ConsumerState<_ReplayOnR> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// 打字題要輸入字母 r，輸入框有焦點時不攔。
  bool get _typing =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  bool _onKey(KeyEvent event) {
    final isR =
        event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyR;
    if (!isR || !mounted || _typing) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (!ref.read(audioAvailableProvider)) return false;
    final tts = ref.read(ttsControllerProvider.notifier);
    unawaited(tts.speak(tts.atUserSpeed(widget.request)));
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

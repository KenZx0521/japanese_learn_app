import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../backend/local_log.dart';
import 'tts_controller.dart';

/// 離開 session 時停止語音（§6.5）。包在整個流程外層，子畫面不用各自處理。
class StopSpeechOnLeave extends ConsumerStatefulWidget {
  const StopSpeechOnLeave({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StopSpeechOnLeave> createState() => _StopSpeechOnLeaveState();
}

class _StopSpeechOnLeaveState extends ConsumerState<StopSpeechOnLeave> {
  late final TtsController _tts;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsControllerProvider.notifier);
  }

  @override
  void dispose() {
    // 卸載途中不能動 provider，等這一幀結束
    if (_playing) unawaited(Future.microtask(_stop));
    super.dispose();
  }

  /// 整個 ProviderScope 一起卸載時 `TtsController` 已經不在，只留紀錄。
  Future<void> _stop() async {
    try {
      await _tts.stop();
    } on Exception catch (error, stack) {
      logLocal(error, stack);
    }
  }

  void _track(TtsPlayback? _, TtsPlayback next) {
    _playing = next is TtsPreparing || next is TtsSpeaking;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ttsControllerProvider, _track);
    return widget.child;
  }
}

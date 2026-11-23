import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../settings/settings_controller.dart';
import 'audio_available.dart';
import 'tts_controller.dart';
import 'tts_engine.dart';

/// 只自動播一次（§3.4、§4.6）。條件：`enabled`、設定開啟自動播放、語音可用，
/// 且沒有開螢幕報讀（`accessibleNavigation`），避免與 TTS 打架。
class AutoplayOnce extends ConsumerStatefulWidget {
  const AutoplayOnce({
    required this.request,
    this.enabled = true,
    this.child,
    super.key,
  });

  final SpeechRequest request;
  final bool enabled;
  final Widget? child;

  @override
  ConsumerState<AutoplayOnce> createState() => _AutoplayOnceState();
}

class _AutoplayOnceState extends ConsumerState<AutoplayOnce> {
  bool _fired = false;

  void _maybeFire(bool shouldPlay) {
    if (_fired || !shouldPlay) return;
    _fired = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final tts = ref.read(ttsControllerProvider.notifier);
        tts.speak(tts.atUserSpeed(widget.request));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ref.watch(audioResolvedProvider);
    final available = ref.watch(audioAvailableProvider);
    final autoplay = ref.watch(
      settingsProvider.select((s) => s.value?.autoplay ?? false),
    );
    final screenReader = MediaQuery.accessibleNavigationOf(context);
    _maybeFire(
      widget.enabled && resolved && available && autoplay && !screenReader,
    );
    return widget.child ?? const SizedBox.shrink();
  }
}

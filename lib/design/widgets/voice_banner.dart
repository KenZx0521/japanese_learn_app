import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/tts/audio_available.dart';
import '../../core/tts/tts_engine.dart';
import '../../core/tts/voice_help.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'pressable.dart';

/// T1、S1 頂部的語音狀態（§4.4、§6.6）：語音不可用可關閉，無聲模式常駐。
/// 探測完成前不顯示。
class VoiceBanner extends ConsumerStatefulWidget {
  const VoiceBanner({super.key});

  @override
  ConsumerState<VoiceBanner> createState() => _VoiceBannerState();
}

class _VoiceBannerState extends ConsumerState<VoiceBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final tts = ref.watch(ttsAvailabilityProvider);
    final silent = ref.watch(
      settingsProvider.select((s) => s.value?.silentMode ?? false),
    );
    if (!ref.watch(audioResolvedProvider)) return const SizedBox.shrink();
    if (silent) {
      return const _BannerBody(message: '無聲模式：聽力題暫時不出現，語音恢復後會自動回來');
    }
    if (tts.kind == TtsAvailabilityKind.ready || _dismissed) {
      return const SizedBox.shrink();
    }
    return _BannerBody(
      message: '語音無法使用，聽力題暫時不出現',
      onDismiss: () => setState(() => _dismissed = true),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.message, this.onDismiss});
  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s3,
        AppSpace.s2,
        0,
        AppSpace.s2,
      ),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: t.kincha, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: AppText(
                message,
                scale: TypeScale.caption,
                color: t.ink.secondary,
              ),
            ),
          ),
          _BannerAction(
            label: '設定語音',
            onTap: () => unawaited(showVoiceHelpSheet(context)),
          ),
          if (onDismiss != null) _BannerAction(label: '關閉', onTap: onDismiss!),
        ],
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      builder: (context, state) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
        color: state.hovered ? t.paper.raised : Colors.transparent,
        child: AppText(
          label,
          scale: TypeScale.label,
          color: state.pressed ? t.ink.primary : t.ai,
        ),
      ),
    );
  }
}

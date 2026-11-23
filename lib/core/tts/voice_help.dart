import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/sheet_frame.dart';
import '../backend/failures.dart';
import '../backend/local_log.dart';
import '../settings/settings_controller.dart';
import 'audio_available.dart';
import 'tts_engine.dart';

enum VoiceHelpPlatform { android, ios, linux, other }

VoiceHelpPlatform currentVoiceHelpPlatform() => switch (defaultTargetPlatform) {
  TargetPlatform.android => VoiceHelpPlatform.android,
  TargetPlatform.iOS => VoiceHelpPlatform.ios,
  TargetPlatform.linux => VoiceHelpPlatform.linux,
  _ => VoiceHelpPlatform.other,
};

@immutable
final class VoiceHelpCopy {
  const VoiceHelpCopy(this.title, this.steps, {this.note});
  final String title;
  final List<String> steps;
  final String? note;
}

/// §6.4 的對照表。路徑待實機確認，改文案只改這裡。
VoiceHelpCopy voiceHelpCopy(
  TtsAvailabilityKind kind,
  VoiceHelpPlatform platform,
) {
  if (platform == VoiceHelpPlatform.linux) {
    return const VoiceHelpCopy('開發用平台，需要 speech-dispatcher 與日語模組', [
      '在終端機執行：sudo apt install speech-dispatcher-espeak-ng',
    ], note: '音質僅供驗證。');
  }
  return switch (kind) {
    TtsAvailabilityKind.voiceNotDownloaded => const VoiceHelpCopy(
      '手機還沒下載日語語音',
      ['打開手機的「設定」', '依序進入：系統 › 語言 › 文字轉語音 › Google 語音服務', '點「安裝語音資料」，選「日本語」'],
      note: '下載由系統進行，本 App 不連網。各廠牌的路徑可能略有不同。',
    ),
    TtsAvailabilityKind.noJapaneseVoice => const VoiceHelpCopy('找不到日語語音', [
      '打開「設定」',
      '依序進入：輔助使用 › 語音內容 › 聲音 › 日文',
    ]),
    TtsAvailabilityKind.engineMissing => const VoiceHelpCopy('手機沒有語音引擎', [
      '打開 Play 商店',
      '安裝「Google 語音服務」',
    ]),
    TtsAvailabilityKind.ready || TtsAvailabilityKind.unknown =>
      const VoiceHelpCopy('語音沒有順利播放', ['確認音量沒有關小', '再按一次播放鈕試試看']),
  };
}

/// 語音不可用時絕不靜默（§6.4）。`onReady` 在探測轉為可用時呼叫。
Future<void> showVoiceHelpSheet(
  BuildContext context, {
  VoidCallback? onReady,
}) => showPaperSheet<void>(context, child: VoiceHelpSheet(onReady: onReady));

class VoiceHelpSheet extends ConsumerStatefulWidget {
  const VoiceHelpSheet({this.onReady, super.key});
  final VoidCallback? onReady;

  @override
  ConsumerState<VoiceHelpSheet> createState() => _VoiceHelpSheetState();
}

class _VoiceHelpSheetState extends ConsumerState<VoiceHelpSheet> {
  bool _waitingForSetup = false;
  String? _writeError;

  void _startSetup() {
    setState(() => _waitingForSetup = true);
  }

  Future<void> _setSilent(bool silent) async {
    try {
      await ref
          .read(settingsProvider.notifier)
          .patch(settingsPatch(silentMode: silent));
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) setState(() => _writeError = failure.userMessage);
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(ttsAvailabilityProvider);
    ref.listen(ttsAvailabilityProvider, (previous, next) {
      if (next.isReady && previous?.isReady != true && mounted) {
        widget.onReady?.call();
        Navigator.of(context).maybePop();
      }
    });
    final silent = ref.watch(
      settingsProvider.select((s) => s.value?.silentMode ?? false),
    );
    if (silent && availability.isReady) return _silentContent();
    return _helpContent(availability.kind);
  }

  Widget _silentContent() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppText('無聲模式開著', scale: TypeScale.title),
      const SizedBox(height: AppSpace.s3),
      const AppText('聽力題暫時不出現，語音恢復後會自動回來。'),
      const SizedBox(height: AppSpace.s5),
      InkButton(label: '開回語音', onPressed: () => _setSilent(false)),
      if (_writeError != null) _ErrorLine(text: _writeError!),
    ],
  );

  Widget _helpContent(TtsAvailabilityKind kind) {
    final copy = voiceHelpCopy(kind, currentVoiceHelpPlatform());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(copy.title, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s3),
        for (final (index, step) in copy.steps.indexed)
          _StepLine(number: index + 1, text: step),
        if (copy.note != null) ...[
          const SizedBox(height: AppSpace.s2),
          AppText(
            copy.note!,
            scale: TypeScale.caption,
            color: AppTokens.of(context).ink.secondary,
          ),
        ],
        const SizedBox(height: AppSpace.s5),
        if (_waitingForSetup) ...[
          const AppText('照上面的步驟設定好，回到 App 時會自動重新檢查。'),
          const SizedBox(height: AppSpace.s3),
          GhostButton(
            label: '重新檢查',
            onPressed: () =>
                ref.read(ttsAvailabilityProvider.notifier).reprobe(),
          ),
          const SizedBox(height: AppSpace.s2),
        ] else ...[
          InkButton(label: '現在設定', onPressed: _startSetup, autofocus: true),
          const SizedBox(height: AppSpace.s2),
        ],
        GhostButton(label: '先用無聲模式', onPressed: () => _setSilent(true)),
        if (_writeError != null) _ErrorLine(text: _writeError!),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s3),
    child: Semantics(
      liveRegion: true,
      child: AppText(
        text,
        scale: TypeScale.caption,
        color: AppTokens.of(context).shu,
      ),
    ),
  );
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('$number.', color: AppTokens.of(context).ink.secondary),
        const SizedBox(width: AppSpace.s2),
        Expanded(child: AppText(text)),
      ],
    ),
  );
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/text/ja_text.dart';
import '../../core/tts/audio_available.dart';
import '../../core/tts/tts_controller.dart';
import '../../core/tts/tts_engine.dart';
import '../../core/tts/voice_help.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/ruled_list.dart';
import '../../design/widgets/speak_button.dart';
import 'settings_labels.dart';
import 'settings_write.dart';
import 'widgets/setting_rows.dart';
import 'widgets/settings_section.dart';

const _testRequest = SpeechRequest(
  id: 'settings.voice_test',
  text: 'こんにちは',
  kana: 'こんにちは',
);
const _slowRate = 0.7;
const _normalRate = 1.0;

/// X2 語音與說明（§3.9）。語音不可用時一定給出下一步（§6.4）。
class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(settingsWriteErrorProvider);
    return PaperScaffold(
      bottom: error == null ? null : SettingsWriteErrorLine(message: error),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PopBackLine(),
          Semantics(
            header: true,
            child: const AppText('語音與說明', scale: TypeScale.displayM),
          ),
          const SizedBox(height: AppSpace.s5),
          AsyncBody(
            value: ref.watch(settingsProvider),
            onRetry: () => ref.invalidate(settingsProvider),
            data: (settings) => _VoiceBody(settings: settings),
          ),
        ],
      ),
    );
  }
}

class _VoiceBody extends ConsumerWidget {
  const _VoiceBody({required this.settings});

  final SettingsDto settings;

  bool get _isSlow => settings.ttsRate <= 0.85;

  Future<void> _pickVoice(
    BuildContext context,
    WidgetRef ref,
    List<String> voiceIds,
  ) async {
    final choice = await showSettingChoices<String?>(
      context,
      title: '語音選擇',
      options: [
        const SettingOption<String?>(null, '裝置預設'),
        for (final id in voiceIds) SettingOption<String?>(id, id),
      ],
      selected: settings.voiceId,
    );
    if (choice == null || !context.mounted) return;
    final id = choice.value;
    await saveSetting(
      ref,
      id == null
          ? settingsPatch(clearVoiceId: true)
          : settingsPatch(voiceId: id),
    );
  }

  List<Widget> _playbackRows(
    BuildContext context,
    WidgetRef ref,
    TtsAvailability tts,
  ) => [
    SettingToggleRow(
      title: '無聲模式',
      detail: '聽力題暫時不出現，之後隨時可以在這裡開回來',
      value: settings.silentMode,
      onChanged: (v) =>
          unawaited(saveSetting(ref, settingsPatch(silentMode: v))),
    ),
    SettingToggleRow(
      title: '慢速預設',
      detail: '語音一律先用 0.7 倍播放',
      value: _isSlow,
      onChanged: (v) => unawaited(
        saveSetting(ref, settingsPatch(ttsRate: v ? _slowRate : _normalRate)),
      ),
    ),
    SettingToggleRow(
      title: '自動播放',
      detail: '新內容出現時自動念一次',
      value: settings.autoplay,
      onChanged: (v) => unawaited(saveSetting(ref, settingsPatch(autoplay: v))),
    ),
    if (tts.voiceIds.length >= 2)
      SettingValueRow(
        title: '語音選擇',
        value: settings.voiceId ?? '裝置預設',
        onTap: () => unawaited(_pickVoice(context, ref, tts.voiceIds)),
      ),
    RuledTile.text(
      '裝置語音設定教學',
      subtitle: '下載語音、調整手機的文字轉語音',
      onTap: () => unawaited(showVoiceHelpSheet(context)),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsAvailabilityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusBlock(availability: tts, silent: settings.silentMode),
        const SizedBox(height: AppSpace.s6),
        const _TestPlay(),
        const SizedBox(height: AppSpace.s6),
        SettingsSection(
          label: '播放方式',
          children: _playbackRows(context, ref, tts),
        ),
      ],
    );
  }
}

class _StatusBlock extends ConsumerWidget {
  const _StatusBlock({required this.availability, required this.silent});

  final TtsAvailability availability;
  final bool silent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final name = availability.voiceName;
    final needsSetup =
        !availability.isReady &&
        availability.kind != TtsAvailabilityKind.unknown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EyebrowText('語音狀態'),
        const SizedBox(height: AppSpace.s2),
        Semantics(
          liveRegion: true,
          child: AppText(
            voiceStatusTitle(availability, silent: silent),
            scale: TypeScale.title,
          ),
        ),
        if (name != null)
          AppText(
            '目前語音：$name',
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
        const SizedBox(height: AppSpace.s3),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            if (needsSetup)
              InkButton(
                label: '看設定步驟',
                onPressed: () => unawaited(showVoiceHelpSheet(context)),
              ),
            GhostButton(
              label: '重新檢查',
              onPressed: () => unawaited(
                ref.read(ttsAvailabilityProvider.notifier).reprobe(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TestPlay extends ConsumerWidget {
  const _TestPlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(
      ttsControllerProvider.select(
        (p) => p is TtsError && p.id == _testRequest.id,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EyebrowText('測試播放'),
        const SizedBox(height: AppSpace.s2),
        Row(
          children: [
            const SpeakButton(request: _testRequest),
            const SizedBox(width: AppSpace.s3),
            const Expanded(child: JaText('こんにちは', scale: TypeScale.jaSentence)),
          ],
        ),
        if (failed) ...[
          const SizedBox(height: AppSpace.s3),
          Semantics(
            liveRegion: true,
            child: const AppText('剛剛沒有播出來。確認音量後再試，或看看說明。'),
          ),
          const SizedBox(height: AppSpace.s2),
          GhostButton(
            label: '查看說明',
            onPressed: () => unawaited(showVoiceHelpSheet(context)),
          ),
        ],
      ],
    );
  }
}

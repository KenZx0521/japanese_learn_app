import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/audio_available.dart';
import '../../core/tts/tts_engine.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/ruled_list.dart';
import '../../design/widgets/sheet_frame.dart';
import '../plan/scope_copy.dart';
import 'reset_data_sheet.dart';
import 'settings_labels.dart';
import 'settings_write.dart';
import 'widgets/display_section.dart';
import 'widgets/setting_rows.dart';
import 'widgets/settings_section.dart';

/// 範圍文案要看內容版本；讀不到時保守地不顯示，其他設定照常可用。
final _contentStageProvider = FutureProvider.autoDispose<ContentStage>(
  (ref) async =>
      (await ref.watch(courseRepositoryProvider).overview()).contentStage,
);

/// X1 設定（§3.9）。全部經 `update_settings` 寫入。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(settingsWriteErrorProvider);
    return PaperScaffold(
      bottom: error == null ? null : SettingsWriteErrorLine(message: error),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const AppText('設定', scale: TypeScale.displayM),
          ),
          const SizedBox(height: AppSpace.s5),
          AsyncBody(
            value: ref.watch(settingsProvider),
            onRetry: () => ref.invalidate(settingsProvider),
            data: (settings) => _SettingsBody(settings: settings),
          ),
        ],
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.settings});

  final SettingsDto settings;

  Future<void> _openReset(BuildContext context, WidgetRef ref) async {
    // 先取出來：清除成功後路由會換掉這頁，之後不能再用 ref
    final onboarded = ref.read(onboardingDoneProvider);
    final done = await showPaperSheet<bool>(
      context,
      child: const ResetDataSheet(),
    );
    if (done == true) onboarded.value = false;
  }

  Widget _voiceSection(BuildContext context, TtsAvailability tts) =>
      SettingsSection(
        label: '語音',
        children: [
          RuledTile.text(
            '語音與播放',
            subtitle: voiceStatusTitle(tts, silent: settings.silentMode),
            onTap: () => unawaited(context.push(AppRoutes.settingsVoice)),
          ),
        ],
      );

  Widget _studySection(BuildContext context, WidgetRef ref) => SettingsSection(
    label: '學習',
    children: [
      SettingValueRow(
        title: '換日時間',
        detail: '過了這個時間才算新的一天',
        value: rolloverLabel(settings.dayRolloverHour),
        onTap: () => unawaited(
          pickSetting<int>(
            context,
            ref,
            title: '換日時間',
            options: rolloverOptions(),
            selected: settings.dayRolloverHour,
            patch: (hour) => settingsPatch(dayRolloverHour: hour),
          ),
        ),
      ),
    ],
  );

  Widget _accessibilitySection(WidgetRef ref) => SettingsSection(
    label: '無障礙',
    children: [
      SettingToggleRow(
        title: '假名時限',
        detail: '關閉後假名練習不看作答時間',
        value: settings.kanaTimeLimit,
        onChanged: (v) =>
            unawaited(saveSetting(ref, settingsPatch(kanaTimeLimit: v))),
      ),
    ],
  );

  Widget _dataSection(BuildContext context, WidgetRef ref) => SettingsSection(
    label: '資料',
    children: [
      RuledTile.text(
        '清除全部進度',
        subtitle: '資料只存在這台裝置，清除後無法復原',
        onTap: () => unawaited(_openReset(context, ref)),
      ),
    ],
  );

  Widget _aboutSection(BuildContext context, ContentStage? stage) =>
      SettingsSection(
        label: '關於',
        children: [
          RuledTile.text(
            '程度說明',
            subtitle: stage == null ? null : scopeCopyOf(stage).opening,
            onTap: () => unawaited(context.push(AppRoutes.planAbout)),
          ),
          const _InfoRow(title: '語音限制', text: voiceLimitCopy),
          RuledTile.text(
            '授權',
            subtitle: '字型與開放原始碼授權',
            onTap: () => unawaited(context.push(AppRoutes.settingsLicenses)),
          ),
        ],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(_contentStageProvider).value;
    final tts = ref.watch(ttsAvailabilityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _voiceSection(context, tts),
        DisplaySection(settings: settings, stage: stage),
        _studySection(context, ref),
        _accessibilitySection(ref),
        _dataSection(context, ref),
        _aboutSection(context, stage),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.text});
  final String title, text;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line.grid)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpace.s3,
          horizontal: AppSpace.s1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(title),
            AppText(text, scale: TypeScale.caption, color: t.ink.secondary),
          ],
        ),
      ),
    );
  }
}

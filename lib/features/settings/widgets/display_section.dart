import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/text/ja_text.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../settings_labels.dart';
import '../settings_write.dart';
import 'setting_rows.dart';
import 'settings_section.dart';

/// X1 的「顯示」區（§3.9）。覆寫值為 null 時回到「依課程」。
class DisplaySection extends ConsumerWidget {
  const DisplaySection({
    required this.settings,
    required this.stage,
    super.key,
  });

  final SettingsDto settings;
  final ContentStage? stage;

  Widget _romajiRow(BuildContext context, WidgetRef ref) => SettingValueRow(
    title: '羅馬字',
    value: optionLabel(romajiOptions, settings.romajiOverride),
    onTap: () => unawaited(
      pickSetting<RomajiMode?>(
        context,
        ref,
        title: '羅馬字',
        options: romajiOptions,
        selected: settings.romajiOverride,
        patch: (v) => v == null
            ? settingsPatch(clearRomajiOverride: true)
            : settingsPatch(romajiOverride: v),
      ),
    ),
  );

  Widget _furiganaRow(BuildContext context, WidgetRef ref) => SettingValueRow(
    title: '振假名',
    value: optionLabel(furiganaOptions, settings.furiganaOverride),
    onTap: () => unawaited(
      pickSetting<FuriganaMode?>(
        context,
        ref,
        title: '振假名',
        options: furiganaOptions,
        selected: settings.furiganaOverride,
        patch: (v) => v == null
            ? settingsPatch(clearFuriganaOverride: true)
            : settingsPatch(furiganaOverride: v),
      ),
    ),
  );

  Widget _themeRow(BuildContext context, WidgetRef ref) => SettingValueRow(
    title: '主題',
    value: optionLabel(themeOptions, settings.themeMode),
    onTap: () => unawaited(
      pickSetting<AppThemeMode>(
        context,
        ref,
        title: '主題',
        options: themeOptions,
        selected: settings.themeMode,
        patch: (v) => settingsPatch(themeMode: v),
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsSection(
    label: '顯示',
    children: [
      _romajiRow(context, ref),
      _furiganaRow(context, ref),
      // p0a 的內容到不了 L09，這個開關沒有作用，也不宣稱有這些課（O7）
      if (stage != null && stage != ContentStage.p0A)
        SettingToggleRow(
          title: 'L09 起收起羅馬字',
          value: settings.romajiOffConfirmed,
          onChanged: (v) =>
              unawaited(saveSetting(ref, settingsPatch(romajiOffConfirmed: v))),
        ),
      _themeRow(context, ref),
      SettingToggleRow(
        title: '評分鈕顯示間隔',
        detail: '在複習的評分鈕上顯示下次出現的時間',
        value: settings.showRatingIntervals,
        onChanged: (v) =>
            unawaited(saveSetting(ref, settingsPatch(showRatingIntervals: v))),
      ),
      const _FontPreview(),
    ],
  );
}

class _FontPreview extends StatelessWidget {
  const _FontPreview();

  String _scaleLabel(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return scale.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpace.s3,
        horizontal: AppSpace.s1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('字級預覽'),
          const SizedBox(height: AppSpace.s1),
          const JaText('こんにちは', scale: TypeScale.jaSentence),
          AppText('中文說明會是這個大小。', color: t.ink.secondary),
          const SizedBox(height: AppSpace.s1),
          AppText(
            '目前系統字級 ${_scaleLabel(context)} 倍，可在手機的顯示設定調整',
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
        ],
      ),
    );
  }
}

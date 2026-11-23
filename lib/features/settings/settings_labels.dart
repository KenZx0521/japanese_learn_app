import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/frb/dto.dart';
import '../../core/tts/tts_engine.dart';
import '../../core/tts/voice_help.dart';

@immutable
final class SettingOption<T> {
  const SettingOption(this.value, this.label, {this.detail});
  final T value;
  final String label;
  final String? detail;
}

const romajiOptions = <SettingOption<RomajiMode?>>[
  SettingOption(null, '依課程', detail: '隨課程進度逐步收起'),
  SettingOption(RomajiMode.shown, '永遠顯示'),
  SettingOption(RomajiMode.shownToggleable, '預設顯示，可收起'),
  SettingOption(RomajiMode.tapToReveal, '點一下才顯示'),
  SettingOption(RomajiMode.longPressOnly, '長按單字才顯示'),
  SettingOption(RomajiMode.hidden, '不顯示'),
];

const furiganaOptions = <SettingOption<FuriganaMode?>>[
  SettingOption(null, '依課程'),
  SettingOption(FuriganaMode.all, '全部標示'),
  SettingOption(FuriganaMode.unknownOnly, '只標還不熟的字'),
];

const themeOptions = <SettingOption<AppThemeMode>>[
  SettingOption(AppThemeMode.system, '跟隨系統'),
  SettingOption(AppThemeMode.light, '淺色（和紙）'),
  SettingOption(AppThemeMode.dark, '深色（墨夜）'),
];

/// `day_rollover_hour` 的範圍是 0–12（rust-core §2）。
const maxRolloverHour = 12;

String rolloverLabel(int hour) => switch (hour) {
  0 => '午夜 12 點',
  < 5 => '凌晨 $hour 點',
  < 12 => '早上 $hour 點',
  _ => '中午 12 點',
};

List<SettingOption<int>> rolloverOptions() => [
  for (var hour = 0; hour <= maxRolloverHour; hour++)
    SettingOption(hour, rolloverLabel(hour)),
];

String optionLabel<T>(List<SettingOption<T>> options, T value) =>
    options.firstWhere((o) => o.value == value).label;

/// X1 與 X2 共用的語音狀態文字。
String voiceStatusTitle(TtsAvailability availability, {required bool silent}) {
  if (availability.kind == TtsAvailabilityKind.unknown) return '正在確認語音';
  if (silent) return '無聲模式開著';
  if (availability.isReady) return '語音可以使用';
  return voiceHelpCopy(availability.kind, currentVoiceHelpPlatform()).title;
}

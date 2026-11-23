import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/frb/dto.dart';
import '../backend/providers.dart';

/// 啟動時已讀過的設定，第一次 build 直接用，避免主題閃爍。
final class SettingsSeed {
  SettingsSeed(this._value);
  SettingsDto? _value;

  SettingsDto? take() {
    final value = _value;
    _value = null;
    return value;
  }
}

final settingsSeedProvider = Provider<SettingsSeed?>((ref) => null);

final settingsProvider = AsyncNotifierProvider<SettingsController, SettingsDto>(
  SettingsController.new,
);

class SettingsController extends AsyncNotifier<SettingsDto> {
  @override
  Future<SettingsDto> build() async {
    final seeded = ref.read(settingsSeedProvider)?.take();
    if (seeded != null) return seeded;
    return ref.watch(settingsRepositoryProvider).load();
  }

  /// 寫入成功才更新狀態；失敗時保留舊值並往外拋，由呼叫端提示。
  Future<void> patch(SettingsPatchDto patch) async {
    final updated = await ref.read(settingsRepositoryProvider).patch(patch);
    if (ref.mounted) state = AsyncData(updated);
  }
}

/// `SettingsPatchDto` 的三個 clear 旗標是必填，這裡補預設值。
SettingsPatchDto settingsPatch({
  int? dayRolloverHour,
  RomajiMode? romajiOverride,
  bool clearRomajiOverride = false,
  FuriganaMode? furiganaOverride,
  bool clearFuriganaOverride = false,
  double? ttsRate,
  bool? autoplay,
  String? voiceId,
  bool clearVoiceId = false,
  AppThemeMode? themeMode,
  bool? silentMode,
  bool? kanaTimeLimit,
  bool? showRatingIntervals,
  bool? romajiOffConfirmed,
  List<QuestionType>? seenQuestionHints,
}) => SettingsPatchDto(
  dayRolloverHour: dayRolloverHour,
  romajiOverride: romajiOverride,
  clearRomajiOverride: clearRomajiOverride,
  furiganaOverride: furiganaOverride,
  clearFuriganaOverride: clearFuriganaOverride,
  ttsRate: ttsRate,
  autoplay: autoplay,
  voiceId: voiceId,
  clearVoiceId: clearVoiceId,
  themeMode: themeMode,
  silentMode: silentMode,
  kanaTimeLimit: kanaTimeLimit,
  showRatingIntervals: showRatingIntervals,
  romajiOffConfirmed: romajiOffConfirmed,
  seenQuestionHints: seenQuestionHints,
);

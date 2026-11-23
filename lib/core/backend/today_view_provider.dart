import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import '../tts/audio_available.dart';
import 'frb/dto.dart';
import 'providers.dart';

/// T1、T2 共用的今日資料。語音探測完成且設定載入前停在載入階段，
/// 不呼叫 Rust，否則快照會以 `audio_available = false` 凍結一整天（§6.6）。
final todayViewProvider = FutureProvider.autoDispose<TodayViewDto>((ref) {
  ref
    ..watch(resumeTickProvider)
    // 換日時間改了，「今天」可能變成另一天
    ..watch(settingsProvider.select((s) => s.value?.dayRolloverHour));
  if (!ref.watch(audioResolvedProvider)) {
    return Completer<TodayViewDto>().future;
  }
  final audio = ref.watch(audioAvailableProvider);
  return ref.watch(todayRepositoryProvider).today(audio);
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/local_log.dart';
import '../settings/settings_controller.dart';
import 'tts_controller.dart';
import 'tts_engine.dart';

final ttsAvailabilityProvider =
    NotifierProvider<TtsAvailabilityController, TtsAvailability>(
      TtsAvailabilityController.new,
    );

/// `build` 回 unknown 並啟動第一次探測；`reprobe` 期間保留上一次結果，
/// 不回到 unknown，畫面不閃骨架（architecture §5.2）。
class TtsAvailabilityController extends Notifier<TtsAvailability> {
  Future<void>? _inFlight;

  @override
  TtsAvailability build() {
    _inFlight = null;
    unawaited(Future.microtask(reprobe));
    return TtsAvailability.unknown;
  }

  /// 探測進行中再呼叫會共用同一次，不重複探測。
  Future<void> reprobe() => _inFlight ??= _runProbe();

  Future<void> _runProbe() async {
    final engine = ref.read(ttsEngineProvider);
    try {
      final result = await engine.probe();
      if (ref.mounted) state = result;
    } on Exception catch (error, stack) {
      logLocal(error, stack);
      if (ref.mounted) {
        state = const TtsAvailability(TtsAvailabilityKind.engineMissing);
      }
    } finally {
      _inFlight = null;
    }
  }
}

/// 所有帶 `audio_available` 參數的 Rust 函式都傳這個值（§6.6）。
final audioAvailableProvider = Provider<bool>((ref) {
  final tts = ref.watch(ttsAvailabilityProvider);
  final silent = ref.watch(
    settingsProvider.select((s) => s.value?.silentMode ?? false),
  );
  return tts.kind == TtsAvailabilityKind.ready && !silent;
});

/// 第一次探測完成且設定已載入時為 true，此時 [audioAvailableProvider] 的值才算數。
/// 為 false 時不得呼叫任何帶 `audio_available` 的 Rust 函式，否則快照會以 false
/// 凍結一整天（§6.6）。
final audioResolvedProvider = Provider<bool>((ref) {
  final probed = ref.watch(
    ttsAvailabilityProvider.select(
      (a) => a.kind != TtsAvailabilityKind.unknown,
    ),
  );
  final settingsLoaded = ref.watch(settingsProvider.select((s) => s.hasValue));
  return probed && settingsLoaded;
});

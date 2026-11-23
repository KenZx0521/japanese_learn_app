import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show immutable;

import '../backend/local_log.dart';
import '../settings/settings_controller.dart';
import 'tts_engine.dart';

@immutable
sealed class TtsPlayback {
  const TtsPlayback();
}

final class TtsIdle extends TtsPlayback {
  const TtsIdle();
}

final class TtsPreparing extends TtsPlayback {
  const TtsPreparing(this.id);
  final String id;
}

final class TtsSpeaking extends TtsPlayback {
  const TtsSpeaking(this.id);
  final String id;
}

final class TtsError extends TtsPlayback {
  const TtsError(this.id, this.reason);
  final String id, reason;
}

/// 連播的間隔；`spoken` 是這句實際念的時間（跟讀用句長×1.5）。
typedef SequenceGap = Duration Function(SpeechRequest request, Duration spoken);

SequenceGap fixedGap(Duration gap) =>
    (_, _) => gap;

final ttsEngineProvider = Provider<TtsEngine>(
  (ref) => throw UnimplementedError('TtsEngine 尚未注入'),
);

final ttsControllerProvider = NotifierProvider<TtsController, TtsPlayback>(
  TtsController.new,
);

const _maxRememberedDurations = 64;

/// 全 App 同時只播一句（§6.5）。`_currentId` 是唯一標記，事件 id 不符就丟棄。
class TtsController extends Notifier<TtsPlayback> {
  static const callTimeout = Duration(seconds: 3);
  static const startTimeout = Duration(seconds: 5);

  Timer? _watchdog;
  Timer? _gapTimer;
  Completer<void>? _gapDone;
  String? _currentId;
  Completer<bool>? _utterance;
  DateTime? _startedAt;
  int _sequenceToken = 0;
  final Map<String, Duration> _durations = {};

  @override
  TtsPlayback build() {
    final subscription = ref.watch(ttsEngineProvider).events.listen(_onEvent);
    ref.onDispose(() {
      _watchdog?.cancel();
      _gapTimer?.cancel();
      unawaited(subscription.cancel());
    });
    return const TtsIdle();
  }

  /// 同 id 代表停止，不同 id 代表切換。
  Future<void> toggle(SpeechRequest request) {
    final current = state;
    final isCurrent = switch (current) {
      TtsPreparing(:final id) => id == request.id,
      TtsSpeaking(:final id) => id == request.id,
      TtsIdle() || TtsError() => false,
    };
    if (isCurrent) return stop();
    _sequenceToken++;
    return _start(request);
  }

  /// 套用使用者的語速偏好（`SpeakButton`、自動播放都走這裡）。
  SpeechRequest atUserSpeed(SpeechRequest request) {
    final rate = ref.read(settingsProvider).value?.ttsRate ?? 1.0;
    return request.withSpeed(speedFromRate(rate));
  }

  /// 單句播放，播放中再次呼叫會切換到這句。
  Future<void> speak(SpeechRequest request) {
    _sequenceToken++;
    return _start(request);
  }

  Future<void> stop() async {
    _sequenceToken++;
    _finishUtterance(false);
    _clearGap();
    _clear();
    state = const TtsIdle();
    try {
      await ref.read(ttsEngineProvider).stop().timeout(callTimeout);
    } on TimeoutException catch (error, stack) {
      logLocal(error, stack);
    } on Exception catch (error, stack) {
      logLocal(error, stack);
    }
  }

  /// 對話連播、逐詞、跟讀。回傳 true 表示完整播完，被打斷或失敗回 false。
  Future<bool> playSequence(
    List<SpeechRequest> requests,
    SequenceGap gap,
  ) async {
    final token = ++_sequenceToken;
    for (final (index, request) in requests.indexed) {
      final startedAt = DateTime.now();
      final finished = await _playAndWait(request);
      if (!finished || token != _sequenceToken) return false;
      if (index == requests.length - 1) break;
      final pause = gap(request, DateTime.now().difference(startedAt));
      await _waitGap(pause);
      if (token != _sequenceToken) return false;
    }
    return true;
  }

  /// 這句上一次 Started→Completed 的實測時長，`BeatStrip` 用來分拍。
  Duration? durationOf(String id) => _durations[id];

  SpeechRequest _withPreferredVoice(SpeechRequest request) {
    final voiceId = ref.read(settingsProvider).value?.voiceId;
    return voiceId == null ? request : request.withVoiceId(voiceId);
  }

  Future<void> _start(SpeechRequest request, {Completer<bool>? waiter}) async {
    final engine = ref.read(ttsEngineProvider);
    _finishUtterance(false);
    _clear();
    _currentId = request.id;
    _utterance = waiter;
    state = TtsPreparing(request.id);
    try {
      await engine.stop().timeout(callTimeout);
      if (_currentId != request.id) return;
      await engine.speak(_withPreferredVoice(request)).timeout(callTimeout);
      if (_currentId != request.id) return;
      if (state is TtsPreparing) {
        _watchdog = Timer(
          startTimeout,
          () => _fail(request.id, 'no-start-event'),
        );
      }
    } on TimeoutException {
      _fail(request.id, 'engine-timeout');
    } on Exception catch (error, stack) {
      logLocal(error, stack);
      _fail(request.id, error.runtimeType.toString());
    }
  }

  Future<bool> _playAndWait(SpeechRequest request) {
    final waiter = Completer<bool>();
    unawaited(_start(request, waiter: waiter));
    return waiter.future;
  }

  Future<void> _waitGap(Duration pause) {
    _clearGap();
    final done = Completer<void>();
    _gapDone = done;
    _gapTimer = Timer(pause, () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  void _clearGap() {
    _gapTimer?.cancel();
    _gapTimer = null;
    final done = _gapDone;
    _gapDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  void _onEvent(TtsEvent event) {
    if (event.id != _currentId) return;
    switch (event) {
      case TtsStarted():
        _watchdog?.cancel();
        _startedAt = DateTime.now();
        state = TtsSpeaking(event.id);
      case TtsCompleted():
        _rememberDuration(event.id);
        _clear();
        state = const TtsIdle();
        _finishUtterance(true);
      case TtsFailed(:final reason):
        _fail(event.id, reason);
    }
  }

  void _rememberDuration(String id) {
    final startedAt = _startedAt;
    if (startedAt == null) return;
    if (_durations.length >= _maxRememberedDurations) {
      _durations.remove(_durations.keys.first);
    }
    _durations[id] = DateTime.now().difference(startedAt);
  }

  void _fail(String id, String reason) {
    if (id != _currentId) return;
    _clear();
    state = TtsError(id, reason);
    _finishUtterance(false);
    unawaited(_stopQuietly());
  }

  Future<void> _stopQuietly() async {
    try {
      await ref.read(ttsEngineProvider).stop().timeout(callTimeout);
    } on TimeoutException catch (error, stack) {
      logLocal(error, stack);
    } on Exception catch (error, stack) {
      logLocal(error, stack);
    }
  }

  void _finishUtterance(bool finished) {
    final waiter = _utterance;
    _utterance = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete(finished);
  }

  void _clear() {
    _watchdog?.cancel();
    _watchdog = null;
    _currentId = null;
    _startedAt = null;
  }
}

import 'dart:async';

import 'tts_engine.dart';

/// 測試與 `--dart-define=JLA_TTS=fake` 用的假引擎（flutter-app-tts.md §6.2）。
/// `probe` 可用 [probeGate] 控制完成時機；`autoComplete` 為真時播放馬上結束。
class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({
    this.availability = const TtsAvailability(TtsAvailabilityKind.ready),
    this.autoStart = true,
    this.autoComplete = true,
    this.probeGate,
  });

  TtsAvailability availability;
  bool autoStart;
  bool autoComplete;
  Future<void>? probeGate;

  /// 設定後 `speak` 會拋出此例外。
  Exception? speakError;

  final _events = StreamController<TtsEvent>.broadcast(sync: true);
  final spoken = <SpeechRequest>[];
  int stopCount = 0;
  int probeCount = 0;

  @override
  Stream<TtsEvent> get events => _events.stream;

  @override
  Future<TtsAvailability> probe() async {
    probeCount++;
    final gate = probeGate;
    if (gate != null) await gate;
    return availability;
  }

  @override
  Future<void> speak(SpeechRequest request) async {
    final error = speakError;
    if (error != null) throw error;
    spoken.add(request);
    if (autoStart) emit(TtsStarted(request.id));
    if (autoStart && autoComplete) emit(TtsCompleted(request.id));
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  void emit(TtsEvent event) => _events.add(event);

  Future<void> close() => _events.close();
}

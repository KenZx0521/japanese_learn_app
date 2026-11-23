import 'dart:async';

import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// iOS 的 rate 與實際語速不是線性，實機校準只改這裡（§6.3）。
final class TtsRateProfile {
  const TtsRateProfile({required this.normal, required this.slow});

  final double normal, slow;

  static const android = TtsRateProfile(normal: 0.5, slow: 0.35);
  static const ios = TtsRateProfile(normal: 0.5, slow: 0.42);

  double rateOf(TtsSpeed speed) => switch (speed) {
    TtsSpeed.normal => normal,
    TtsSpeed.slow => slow,
  };
}

const _ja = 'ja-JP';
const _probeStepTimeout = Duration(seconds: 5);
const _slotBPitch = 1.15;
const _defaultPitch = 1.0;

/// 探測結束就回傳結果，不再往下一步（§6.3 的順序）。
final class _ProbeStop implements Exception {
  const _ProbeStop(this.result);
  final TtsAvailability result;
}

/// flutter_tts 的回呼不帶 utterance id，事件歸屬由這裡管理（§6.3）。
/// 不設 cancelHandler：Android 的 onStop 非同步，遲到的 cancel 會打斷新一句。
final class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine(this._tts, {required this.isAndroid}) {
    _tts
      ..setStartHandler(_onStart)
      ..setCompletionHandler(_onComplete)
      ..setErrorHandler((Object? message) => _onError('$message'));
  }

  final FlutterTts _tts;
  final bool isAndroid;
  final _events = StreamController<TtsEvent>.broadcast();
  String? _id;
  bool _started = false;
  List<Map<String, String>> _voices = const [];
  Object? _appliedVoice;

  TtsRateProfile get _profile =>
      isAndroid ? TtsRateProfile.android : TtsRateProfile.ios;

  @override
  Stream<TtsEvent> get events => _events.stream;

  void _onStart() {
    final id = _id;
    if (id == null) return;
    _started = true;
    _events.add(TtsStarted(id));
  }

  void _onComplete() {
    final id = _id;
    // 上一句遲到的完成事件
    if (id == null || !_started) return;
    _id = null;
    _events.add(TtsCompleted(id));
  }

  void _onError(String reason) {
    final id = _id;
    if (id == null) return;
    _id = null;
    _events.add(TtsFailed(id, reason));
  }

  Future<T> _step<T>(Future<T> call) => call.timeout(_probeStepTimeout);

  @override
  Future<TtsAvailability> probe() async {
    try {
      await _checkEngine();
      await _checkLanguage();
      await _prepareAudioSession();
      await _step(_tts.setLanguage(_ja));
      return await _selectVoice();
    } on _ProbeStop catch (stop) {
      return stop.result;
    } on TimeoutException {
      return const TtsAvailability(TtsAvailabilityKind.engineMissing);
    } on MissingPluginException {
      return const TtsAvailability(TtsAvailabilityKind.engineMissing);
    } on PlatformException {
      return const TtsAvailability(TtsAvailabilityKind.engineMissing);
    }
  }

  Future<void> _checkEngine() async {
    if (!isAndroid) return;
    final engines = await _step(_tts.getEngines);
    if (engines is! List || engines.isEmpty) {
      throw const _ProbeStop(
        TtsAvailability(TtsAvailabilityKind.engineMissing),
      );
    }
  }

  Future<void> _checkLanguage() async {
    final available = await _step(_tts.isLanguageAvailable(_ja));
    if (available != true) {
      throw const _ProbeStop(
        TtsAvailability(TtsAvailabilityKind.noJapaneseVoice),
      );
    }
    if (!isAndroid) return;
    final installed = await _step(_tts.isLanguageInstalled(_ja));
    if (installed != true) {
      throw const _ProbeStop(
        TtsAvailability(TtsAvailabilityKind.voiceNotDownloaded),
      );
    }
  }

  /// 靜音開關打開時也要有聲音，否則初學者會以為壞了。
  Future<void> _prepareAudioSession() async {
    if (isAndroid) return;
    await _step(_tts.setSharedInstance(true));
    await _step(
      _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ], IosTextToSpeechAudioMode.spokenAudio),
    );
  }

  Future<TtsAvailability> _selectVoice() async {
    final raw = await _step(_tts.getVoices);
    _voices = _japaneseVoices(raw);
    if (_voices.isEmpty) {
      return const TtsAvailability(TtsAvailabilityKind.ready);
    }
    await _step(_tts.setVoice(_voices.first));
    _appliedVoice = _voices.first['name'];
    return TtsAvailability(
      TtsAvailabilityKind.ready,
      voiceName: _voices.first['name'],
      voiceIds: [for (final voice in _voices) voice['name'] ?? ''],
    );
  }

  List<Map<String, String>> _japaneseVoices(Object? raw) {
    if (raw is! List) return const [];
    final voices = <Map<String, String>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final voice = {for (final e in entry.entries) '${e.key}': '${e.value}'};
      if (!(voice['locale'] ?? '').startsWith('ja')) continue;
      // 維持離線（O8）
      if (isAndroid && voice['network_required'] == '1') continue;
      voices.add(voice);
    }
    voices.sort((a, b) => _qualityRank(b).compareTo(_qualityRank(a)));
    return voices;
  }

  static int _qualityRank(Map<String, String> voice) {
    final quality = voice['quality'] ?? '';
    return switch (quality) {
      'premium' => 3000,
      'enhanced' => 2000,
      'default' => 1000,
      _ => int.tryParse(quality) ?? 0,
    };
  }

  Future<void> _applyVoiceAndPitch(SpeechRequest request) async {
    final hasSecondVoice = _voices.length >= 2;
    final useSecondVoice = request.voice == VoiceSlot.b && hasSecondVoice;
    final preferred = useSecondVoice
        ? _voices[1]
        : _voices
              .where((voice) => voice['name'] == request.voiceId)
              .firstOrNull;
    final fallback = _voices.isEmpty ? null : _voices.first;
    final voice = preferred ?? fallback;
    if (voice != null && voice['name'] != _appliedVoice) {
      await _tts.setVoice(voice);
      _appliedVoice = voice['name'];
    }
    final needsPitch = request.voice == VoiceSlot.b && !hasSecondVoice;
    await _tts.setPitch(needsPitch ? _slotBPitch : _defaultPitch);
  }

  @override
  Future<void> speak(SpeechRequest request) async {
    _id = request.id;
    _started = false;
    await _tts.setSpeechRate(_profile.rateOf(request.speed));
    await _applyVoiceAndPitch(request);
    await _tts.speak(request.text);
  }

  @override
  Future<void> stop() async {
    _id = null;
    await _tts.stop();
  }
}

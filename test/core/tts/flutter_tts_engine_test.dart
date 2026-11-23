import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:japanese_learn_app/core/tts/flutter_tts_engine.dart';
import 'package:japanese_learn_app/core/tts/tts_engine.dart';

const _request = SpeechRequest(id: 's1', text: '猫', kana: 'ねこ');

final class _StubTts extends Fake implements FlutterTts {
  VoidCallback? start;
  VoidCallback? complete;
  ErrorHandler? error;

  dynamic engines = ['com.google.android.tts'];
  dynamic languageAvailable = true;
  dynamic languageInstalled = true;
  dynamic voices = <Map<String, String>>[
    {
      'name': 'ja-b',
      'locale': 'ja-JP',
      'quality': '300',
      'network_required': '0',
    },
    {
      'name': 'ja-a',
      'locale': 'ja-JP',
      'quality': '400',
      'network_required': '0',
    },
    {
      'name': 'ja-net',
      'locale': 'ja-JP',
      'quality': '500',
      'network_required': '1',
    },
    {
      'name': 'en',
      'locale': 'en-US',
      'quality': '500',
      'network_required': '0',
    },
  ];
  final log = <String>[];
  final rates = <double>[];
  final pitches = <double>[];
  final setVoices = <Map<String, String>>[];
  bool hangLanguageCheck = false;

  @override
  void setStartHandler(VoidCallback callback) => start = callback;
  @override
  void setCompletionHandler(VoidCallback callback) => complete = callback;
  @override
  void setErrorHandler(ErrorHandler handler) => error = handler;

  @override
  Future<dynamic> get getEngines async => engines;
  @override
  Future<dynamic> get getVoices async => voices;
  @override
  Future<dynamic> isLanguageAvailable(String language) {
    if (hangLanguageCheck) return Completer<dynamic>().future;
    return Future.value(languageAvailable);
  }

  @override
  Future<dynamic> isLanguageInstalled(String language) async =>
      languageInstalled;
  @override
  Future<dynamic> setLanguage(String language) async {
    log.add('setLanguage');
    return 1;
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    setVoices.add(voice);
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    rates.add(rate);
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    pitches.add(pitch);
    return 1;
  }

  @override
  Future<dynamic> setSharedInstance(bool sharedSession) async {
    log.add('sharedInstance');
    return 1;
  }

  @override
  Future<dynamic> setIosAudioCategory(
    IosTextToSpeechAudioCategory category,
    List<IosTextToSpeechAudioCategoryOptions> options, [
    IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode,
  ]) async {
    log.add('category');
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    log.add('speak:$text');
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    log.add('stop');
    return 1;
  }
}

void main() {
  late _StubTts stub;

  setUp(() => stub = _StubTts());

  FlutterTtsEngine engine({bool android = true}) =>
      FlutterTtsEngine(stub, isAndroid: android);

  group('事件歸屬', () {
    test('遲到的完成事件在 Started 之前會被丟棄', () async {
      final tts = engine();
      final events = <TtsEvent>[];
      tts.events.listen(events.add);

      await tts.speak(_request);
      stub.complete?.call(); // 上一句的完成
      await pumpEventQueue();
      expect(events, isEmpty);

      stub.start?.call();
      stub.complete?.call();
      await pumpEventQueue();

      expect(events.map((e) => e.runtimeType), [TtsStarted, TtsCompleted]);
      expect(events.every((e) => e.id == 's1'), isTrue);
    });

    test('stop 之後的事件沒有歸屬，全部丟棄', () async {
      final tts = engine();
      final events = <TtsEvent>[];
      tts.events.listen(events.add);

      await tts.speak(_request);
      await tts.stop();
      stub.start?.call();
      stub.complete?.call();
      await pumpEventQueue();

      expect(events, isEmpty);
    });

    test('錯誤回呼轉成 TtsFailed', () async {
      final tts = engine();
      final events = <TtsEvent>[];
      tts.events.listen(events.add);

      await tts.speak(_request);
      stub.error?.call('synthesis failed');
      await pumpEventQueue();

      expect(events.single, isA<TtsFailed>());
    });
  });

  group('探測', () {
    test('Android 正常：回 ready，選最高品質的離線語音', () async {
      final result = await engine().probe();

      expect(result.kind, TtsAvailabilityKind.ready);
      expect(result.voiceName, 'ja-a');
      expect(result.voiceIds, ['ja-a', 'ja-b']);
      expect(stub.setVoices.single['name'], 'ja-a');
    });

    test('Android 沒有引擎：engineMissing', () async {
      stub.engines = <String>[];
      expect((await engine().probe()).kind, TtsAvailabilityKind.engineMissing);
    });

    test('語言不支援：noJapaneseVoice', () async {
      stub.languageAvailable = false;
      expect(
        (await engine().probe()).kind,
        TtsAvailabilityKind.noJapaneseVoice,
      );
    });

    test('Android 語音未下載：voiceNotDownloaded', () async {
      stub.languageInstalled = false;
      expect(
        (await engine().probe()).kind,
        TtsAvailabilityKind.voiceNotDownloaded,
      );
    });

    test('iOS 設定音訊類別，避免靜音開關時沒聲音', () async {
      final result = await engine(android: false).probe();

      expect(result.kind, TtsAvailabilityKind.ready);
      expect(stub.log, containsAll(['sharedInstance', 'category']));
    });

    testWidgets('單一步驟逾時視為 engineMissing', (tester) async {
      stub.hangLanguageCheck = true;
      TtsAvailability? result;

      unawaited(engine().probe().then((r) => result = r));
      await tester.pump(const Duration(seconds: 6));

      expect(result?.kind, TtsAvailabilityKind.engineMissing);
    });

    test('MissingPluginException 視為 engineMissing', () async {
      final tts = FlutterTtsEngine(_MissingPlugin(), isAndroid: false);
      expect((await tts.probe()).kind, TtsAvailabilityKind.engineMissing);
    });
  });

  group('語速表', () {
    test('Android', () async {
      final tts = engine();
      await tts.speak(_request);
      await tts.speak(_request.withSpeed(TtsSpeed.slow));

      expect(stub.rates, [0.5, 0.35]);
    });

    test('iOS', () async {
      final tts = engine(android: false);
      await tts.speak(_request);
      await tts.speak(_request.withSpeed(TtsSpeed.slow));

      expect(stub.rates, [0.5, 0.42]);
    });
  });

  group('角色語音', () {
    test('有兩個語音時 slot b 用第二個語音', () async {
      final tts = engine();
      await tts.probe();
      stub.setVoices.clear();

      await tts.speak(
        const SpeechRequest(id: 'x', text: 'a', kana: 'a', voice: VoiceSlot.b),
      );

      expect(stub.setVoices.single['name'], 'ja-b');
      expect(stub.pitches.single, 1.0);
    });

    test('只有一個語音時 slot b 以 pitch 區分', () async {
      stub.voices = <Map<String, String>>[
        {
          'name': 'ja-a',
          'locale': 'ja-JP',
          'quality': '400',
          'network_required': '0',
        },
      ];
      final tts = engine();
      await tts.probe();

      await tts.speak(
        const SpeechRequest(id: 'x', text: 'a', kana: 'a', voice: VoiceSlot.b),
      );

      expect(stub.pitches.single, 1.15);
    });

    test('使用者選的語音優先於預設', () async {
      final tts = engine();
      await tts.probe();
      stub.setVoices.clear();

      await tts.speak(_request.withVoiceId('ja-b'));

      expect(stub.setVoices.single['name'], 'ja-b');
    });
  });
}

final class _MissingPlugin extends _StubTts {
  @override
  Future<dynamic> isLanguageAvailable(String language) async =>
      throw MissingPluginException('no impl');
}

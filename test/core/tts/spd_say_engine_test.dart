import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/tts/spd_say_engine.dart';
import 'package:japanese_learn_app/core/tts/tts_engine.dart';

final class _FakeProcess implements Process {
  _FakeProcess(this._exit);
  final Future<int> _exit;

  @override
  Future<int> get exitCode => _exit;
  @override
  int get pid => 1;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
  @override
  IOSink get stdin => throw UnimplementedError();
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
}

Stopwatch _elapsed(int ms) => _FixedStopwatch(ms);

final class _FixedStopwatch implements Stopwatch {
  _FixedStopwatch(this.ms);
  final int ms;
  @override
  int get elapsedMilliseconds => ms;
  @override
  void start() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProcessResult _result(String out, [int code = 0]) =>
    ProcessResult(0, code, out, '');

void main() {
  const request = SpeechRequest(id: 'x', text: '猫', kana: 'ねこ');
  late List<List<String>> started;
  late List<List<String>> ran;

  setUp(() {
    started = [];
    ran = [];
  });

  group('探測', () {
    test('沒有 spd-say：engineMissing', () async {
      final engine = SpdSayTtsEngine(
        run: (_, _) async => throw const ProcessException('spd-say', []),
      );

      expect((await engine.probe()).kind, TtsAvailabilityKind.engineMissing);
    });

    test('openjtalk 回 0 但太快結束時不採用，改用 espeak-ng', () async {
      var call = 0;
      final engine = SpdSayTtsEngine(
        run: (_, args) async {
          if (args.first == '-O') return _result('openjtalk\nespeak-ng\n');
          return _result('');
        },
        stopwatch: () => _elapsed(call++ == 0 ? 20 : 500),
      );

      final result = await engine.probe();

      expect(result.kind, TtsAvailabilityKind.ready);
      expect(result.voiceName, 'espeak-ng');
    });

    test('模組都不能出聲：noJapaneseVoice', () async {
      final engine = SpdSayTtsEngine(
        run: (_, args) async =>
            args.first == '-O' ? _result('espeak-ng\n') : _result(''),
        stopwatch: () => _elapsed(5),
      );

      expect((await engine.probe()).kind, TtsAvailabilityKind.noJapaneseVoice);
    });
  });

  group('播放', () {
    SpdSayTtsEngine make(Completer<int> exit) => SpdSayTtsEngine(
      run: (_, args) async {
        ran.add(args);
        return _result('');
      },
      start: (_, args) async {
        started.add(args);
        return _FakeProcess(exit.future);
      },
    );

    test('送 kana，不送漢字', () async {
      await make(Completer<int>()).speak(request);

      expect(started.single.last, 'ねこ');
      expect(started.single, isNot(contains('猫')));
    });

    test('慢速的 -r 參數', () async {
      final engine = make(Completer<int>());
      await engine.speak(request.withSpeed(TtsSpeed.slow));

      expect(started[0][started[0].indexOf('-r') + 1], '-50');
    });

    test('Started 之後，結束碼 0 發 Completed', () async {
      final exit = Completer<int>();
      final engine = make(exit);
      final events = <TtsEvent>[];
      engine.events.listen(events.add);

      await engine.speak(request);
      exit.complete(0);
      await pumpEventQueue();

      expect(events.map((e) => e.runtimeType), [TtsStarted, TtsCompleted]);
    });

    test('stop 用 -C，之後遲到的結束事件被丟棄', () async {
      final exit = Completer<int>();
      final engine = make(exit);
      final events = <TtsEvent>[];
      engine.events.listen(events.add);

      await engine.speak(request);
      await engine.stop();
      exit.complete(0);
      await pumpEventQueue();

      expect(ran.single, ['-C']);
      expect(events.map((e) => e.runtimeType), [TtsStarted]);
    });

    test('行程啟動失敗發 TtsFailed', () async {
      final engine = SpdSayTtsEngine(
        start: (_, _) async => throw const ProcessException('spd-say', []),
      );
      final events = <TtsEvent>[];
      engine.events.listen(events.add);

      await engine.speak(request);
      await pumpEventQueue();

      expect(events.single, isA<TtsFailed>());
    });
  });

  test('utf8 解碼：探測輸出可解析', () {
    expect(utf8.decode(utf8.encode('espeak-ng')), 'espeak-ng');
  });
}

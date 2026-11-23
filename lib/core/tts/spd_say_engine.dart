import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'tts_engine.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> args,
);
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> args,
);

Future<ProcessResult> _runProcess(String executable, List<String> args) =>
    Process.run(executable, args, stdoutEncoding: utf8, stderrEncoding: utf8);

Future<Process> _startProcess(String executable, List<String> args) =>
    Process.start(executable, args);

const _exe = 'spd-say';
const _minRealSpeechMs = 150;
const _probeTimeout = Duration(seconds: 5);
const _candidateModules = ['openjtalk', 'espeak-ng'];
const _rateArgs = {TtsSpeed.normal: '0', TtsSpeed.slow: '-50'};

/// Linux 僅作驗證平台。結束碼不代表成功（實證 #8），要靠耗時判斷；
/// 播放一律送 kana（實證 #9）；停止用 `-C`，`kill` 只殺 client。
final class SpdSayTtsEngine implements TtsEngine {
  SpdSayTtsEngine({
    ProcessRunner? run,
    ProcessStarter? start,
    Stopwatch Function()? stopwatch,
  }) : _run = run ?? _runProcess,
       _start = start ?? _startProcess,
       _stopwatch = stopwatch ?? Stopwatch.new;

  final ProcessRunner _run;
  final ProcessStarter _start;
  final Stopwatch Function() _stopwatch;
  final _events = StreamController<TtsEvent>.broadcast();
  String _module = 'espeak-ng';

  /// 遲到的結束事件靠世代號丟棄：同 id 連續重播時 id 分不出來。
  int _generation = 0;

  @override
  Stream<TtsEvent> get events => _events.stream;

  Future<bool> _reallySpeaks(String module) async {
    final watch = _stopwatch()..start();
    final result = await _run(_exe, [
      '-o',
      module,
      '-l',
      'ja',
      '-i',
      '-100',
      '-w',
      'あ',
    ]).timeout(_probeTimeout);
    return result.exitCode == 0 &&
        watch.elapsedMilliseconds >= _minRealSpeechMs;
  }

  @override
  Future<TtsAvailability> probe() async {
    final ProcessResult modules;
    try {
      modules = await _run(_exe, ['-O']).timeout(_probeTimeout);
    } on ProcessException {
      return const TtsAvailability(TtsAvailabilityKind.engineMissing);
    } on TimeoutException {
      return const TtsAvailability(TtsAvailabilityKind.engineMissing);
    }
    final names = '${modules.stdout}'.split('\n').map((s) => s.trim()).toSet();
    for (final module in _candidateModules) {
      if (names.contains(module) && await _speaksSafely(module)) {
        _module = module;
        return TtsAvailability(
          TtsAvailabilityKind.ready,
          voiceName: module,
          voiceIds: [module],
        );
      }
    }
    return const TtsAvailability(TtsAvailabilityKind.noJapaneseVoice);
  }

  Future<bool> _speaksSafely(String module) async {
    try {
      return await _reallySpeaks(module);
    } on ProcessException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Future<void> speak(SpeechRequest request) async {
    final generation = ++_generation;
    final Process process;
    try {
      process = await _start(_exe, [
        '-o',
        _module,
        '-l',
        'ja',
        '-r',
        _rateArgs[request.speed] ?? '0',
        if (request.voice == VoiceSlot.b) ...['-p', '15'],
        '-w',
        request.kana,
      ]);
    } on ProcessException catch (error) {
      _events.add(TtsFailed(request.id, error.message));
      return;
    }
    if (generation != _generation) return;
    _events.add(TtsStarted(request.id));
    unawaited(_awaitExit(process, request.id, generation));
  }

  Future<void> _awaitExit(Process process, String id, int generation) async {
    final code = await process.exitCode;
    if (generation != _generation) return;
    _events.add(
      code == 0 ? TtsCompleted(id) : TtsFailed(id, 'spd-say rc=$code'),
    );
  }

  @override
  Future<void> stop() async {
    _generation++;
    try {
      await _run(_exe, ['-C']);
    } on ProcessException {
      // 沒有 spd-say 時就沒有東西在播
    }
  }
}

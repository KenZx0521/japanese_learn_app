/// 作答耗時。`KanaListen` 從播放結束起算，播放中作答記 0（§3.3）。
final class AnswerClock {
  final Stopwatch _stopwatch = Stopwatch()..start();
  bool _playing = false;

  void playbackStarted() => _playing = true;

  void playbackEnded() {
    _playing = false;
    _stopwatch
      ..reset()
      ..start();
  }

  int get elapsedMs => _playing ? 0 : _stopwatch.elapsedMilliseconds;
}

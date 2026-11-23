import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/text/ja_text.dart';
import '../../core/tts/audio_available.dart';
import '../../core/tts/tts_controller.dart';
import '../../core/tts/tts_engine.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'ink_buttons.dart';
import 'pressable.dart';

const _sokuonBeats = {'っ', 'ッ'};
const _longBeats = {'ー', 'う長', 'あ長', 'い長'};
const _firstBeatGuess = Duration(milliseconds: 320);
const _silentBeat = Duration(milliseconds: 500);

/// 每拍一格的拍感示範（§3.3）。收到 `TtsStarted` 後依總時長等距亮格，
/// 單拍不分開送 TTS。無聲模式以固定節拍示範。
class BeatStrip extends ConsumerStatefulWidget {
  const BeatStrip({required this.beats, required this.request, super.key});

  final List<String> beats;
  final SpeechRequest request;

  static bool isSokuon(String beat) => _sokuonBeats.contains(beat);
  static bool isLong(String beat) =>
      _longBeats.contains(beat) || beat.contains('ー');

  @override
  ConsumerState<BeatStrip> createState() => _BeatStripState();
}

class _BeatStripState extends ConsumerState<BeatStrip> {
  Timer? _timer;
  int _active = -1;

  void _run(Duration beat) {
    _timer?.cancel();
    setState(() => _active = 0);
    _timer = Timer.periodic(beat, (timer) {
      final next = _active + 1;
      if (next >= widget.beats.length) {
        timer.cancel();
        setState(() => _active = -1);
        return;
      }
      setState(() => _active = next);
    });
  }

  void _runForSpeech() {
    final total = ref
        .read(ttsControllerProvider.notifier)
        .durationOf(widget.request.id);
    final count = widget.beats.length;
    _run(total == null ? _firstBeatGuess : total ~/ count);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _semantic(int index) {
    final beat = widget.beats[index];
    final suffix = BeatStrip.isSokuon(beat)
        ? '，停一拍'
        : (BeatStrip.isLong(beat) ? '，拉長一拍' : '');
    return '第 ${index + 1} 拍$suffix';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ttsControllerProvider, (previous, next) {
      if (next is TtsSpeaking && next.id == widget.request.id) _runForSpeech();
    });
    final audio = ref.watch(audioAvailableProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: PaperLayout.genkoRowGap,
          runSpacing: PaperLayout.genkoRowGap,
          children: [
            for (final (index, beat) in widget.beats.indexed)
              _BeatCell(
                beat: beat,
                active: index == _active,
                semantic: _semantic(index),
              ),
          ],
        ),
        if (!audio) ...[
          const SizedBox(height: AppSpace.s2),
          Row(
            children: [
              AppText(
                '無聲示範',
                scale: TypeScale.caption,
                color: AppTokens.of(context).ink.secondary,
              ),
              const SizedBox(width: AppSpace.s3),
              GhostButton(label: '看節拍', onPressed: () => _run(_silentBeat)),
            ],
          ),
        ],
      ],
    );
  }
}

class _BeatCell extends StatelessWidget {
  const _BeatCell({
    required this.beat,
    required this.active,
    required this.semantic,
  });

  final String beat, semantic;
  final bool active;

  static const _side = 48.0;

  bool get _isPause => BeatStrip.isSokuon(beat) || BeatStrip.isLong(beat);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      semanticLabel: semantic,
      builder: (context, state) => Container(
        width: _side,
        height: _side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // 只換底色，不做過渡：reduced motion 也適用
          color: active ? t.ai.withValues(alpha: 0.22) : Colors.transparent,
          border: Border.all(color: active ? t.ai : t.line.grid),
        ),
        child: _isPause
            ? CustomPaint(
                size: const Size.square(_side),
                painter: _DiagonalPainter(t.line.strong),
              )
            : JaText(
                beat,
                scale: TypeScale.jaBody,
                textScaler: TextScaler.noScaling,
              ),
      ),
    );
  }
}

class _DiagonalPainter extends CustomPainter {
  const _DiagonalPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DiagonalPainter oldDelegate) =>
      oldDelegate.color != color;
}

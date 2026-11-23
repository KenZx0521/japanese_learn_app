import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/tts/audio_available.dart';
import '../../core/tts/tts_controller.dart';
import '../../core/tts/tts_engine.dart';
import '../../core/tts/voice_help.dart';
import '../motion.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'pressable.dart';
import 'speaker_icon.dart';

enum _SpeakVisual { idle, preparing, speaking, error, unavailable }

/// 播放鈕（§6.5）。語音不可用時維持可見，改為斜線喇叭，點擊開說明。
class SpeakButton extends ConsumerWidget {
  const SpeakButton({required this.request, this.diameter = 48, super.key});

  final SpeechRequest request;
  final double diameter;

  _SpeakVisual _visualOf(TtsPlayback playback) => switch (playback) {
    TtsPreparing(:final id) when id == request.id => _SpeakVisual.preparing,
    TtsSpeaking(:final id) when id == request.id => _SpeakVisual.speaking,
    TtsError(:final id) when id == request.id => _SpeakVisual.error,
    _ => _SpeakVisual.idle,
  };

  static String _semanticOf(_SpeakVisual visual) => switch (visual) {
    _SpeakVisual.idle => '播放',
    _SpeakVisual.preparing => '準備中',
    _SpeakVisual.speaking => '停止播放',
    _SpeakVisual.error => '播放失敗，查看說明',
    _SpeakVisual.unavailable => '語音無法使用，查看說明',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsAvailabilityProvider);
    final audio = ref.watch(audioAvailableProvider);
    final resolved = ref.watch(audioResolvedProvider);
    final playing = ref.watch(ttsControllerProvider.select(_visualOf));
    final pending = tts.kind == TtsAvailabilityKind.unknown || !resolved;
    final visual = pending
        ? _SpeakVisual.preparing
        : (audio ? playing : _SpeakVisual.unavailable);
    return Pressable(
      onTap: pending ? null : () => _onTap(context, ref, visual),
      semanticLabel: _semanticOf(visual),
      minSize: diameter,
      builder: (context, state) =>
          _SpeakFace(visual: visual, press: state, diameter: diameter),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref, _SpeakVisual visual) {
    final tts = ref.read(ttsControllerProvider.notifier);
    switch (visual) {
      case _SpeakVisual.unavailable:
      case _SpeakVisual.error:
        unawaited(showVoiceHelpSheet(context));
      case _SpeakVisual.idle:
      case _SpeakVisual.preparing:
      case _SpeakVisual.speaking:
        unawaited(tts.toggle(tts.atUserSpeed(request)));
    }
  }
}

class _SpeakFace extends StatelessWidget {
  const _SpeakFace({
    required this.visual,
    required this.press,
    required this.diameter,
  });

  final _SpeakVisual visual;
  final PressState press;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final borderColor = switch (visual) {
      _SpeakVisual.error => t.shu,
      _SpeakVisual.speaking => t.ai,
      _ => press.hovered ? t.ink.primary : t.line.strong,
    };
    return PressNudge(
      pressed: press.pressed,
      child: Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: press.hovered ? t.paper.raised : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: visual == _SpeakVisual.error ? 2 : 1.5,
          ),
        ),
        child: _glyph(t),
      ),
    );
  }

  Widget _glyph(AppTokens t) => switch (visual) {
    _SpeakVisual.idle => SpeakerIcon(color: t.ink.primary),
    _SpeakVisual.preparing => const _PreparingRing(),
    _SpeakVisual.speaking => _SoundBars(color: t.ai),
    _SpeakVisual.error => SpeakerIcon(color: t.shu),
    _SpeakVisual.unavailable => SpeakerIcon(
      color: t.ink.tertiary,
      slashed: true,
    ),
  };
}

/// 準備中：200ms 後才顯示細環，快速起播時不閃。
class _PreparingRing extends StatefulWidget {
  const _PreparingRing();

  @override
  State<_PreparingRing> createState() => _PreparingRingState();
}

class _PreparingRingState extends State<_PreparingRing> {
  Timer? _timer;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(AppMotion.of(context).preparingDelay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (!_visible) return SpeakerIcon(color: t.ink.tertiary);
    return SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        color: t.ink.secondary,
        value: AppMotion.of(context).reduced ? 0.7 : null,
      ),
    );
  }
}

/// 三條音波；reduced motion 時改靜止圖形加文字（§4.2）。
class _SoundBars extends StatefulWidget {
  const _SoundBars({required this.color});
  final Color color;

  @override
  State<_SoundBars> createState() => _SoundBarsState();
}

class _SoundBarsState extends State<_SoundBars>
    with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 900);
  static const _heights = [0.5, 0.9, 0.65];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.of(context).reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.of(context).reduced) {
      return AppText('播放中', scale: TypeScale.caption, color: widget.color);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, base) in _heights.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.scale(
                scaleY: _scaleFor(i, base),
                child: SizedBox(
                  width: 3,
                  height: 18,
                  child: ColoredBox(color: widget.color),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _scaleFor(int index, double base) {
    final phase = (_controller.value + index / _heights.length) % 1;
    final swing = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return base * (0.55 + 0.45 * swing);
  }
}

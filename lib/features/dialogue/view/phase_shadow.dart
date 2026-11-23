import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/tts/autoplay.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/speak_button.dart';
import '../../../design/widgets/speed_toggle.dart';
import '../../../design/widgets/voice_failed_panel.dart';
import '../dialogue_speech.dart';
import 'silent_mode.dart';
import 'turn_view.dart';

enum _ShadowStage { listening, echoing, rating, finished }

/// 第三階段：逐句播放＋空檔（句長×1.5），再三級自評（課綱 §10.1）。
///
/// 自評只在這一輪顯示小計：對白不是內容表裡的句子，`grade_drill` 查不到，
/// 寫不進 `daily_activity`（會回 NotFound）。
class ShadowPhase extends ConsumerStatefulWidget {
  const ShadowPhase({
    required this.dialogue,
    required this.policy,
    required this.isLast,
    required this.onDone,
    super.key,
  });

  final DialogueDto dialogue;
  final DisplayPolicyDto policy;
  final bool isLast;
  final VoidCallback onDone;

  @override
  ConsumerState<ShadowPhase> createState() => _ShadowPhaseState();
}

class _ShadowPhaseState extends ConsumerState<ShadowPhase>
    with SingleTickerProviderStateMixin {
  static const _minEchoMs = 1500;
  static const _echoRatio = 1.5;

  // `preserve`：空檔長度是內容的一部分，系統關閉動畫時也不能被壓縮
  late final AnimationController _echo = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onEchoStatus);

  int _index = 0;
  _ShadowStage _stage = _ShadowStage.listening;
  bool _failed = false;
  Map<ShadowLevel, int> _counts = const {};

  String get _speechId => turnSpeechId(widget.dialogue, _index);

  @override
  void dispose() {
    _echo.dispose();
    super.dispose();
  }

  void _onEchoStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _stage = _ShadowStage.rating);
    }
  }

  void _onPlayback(TtsPlayback? previous, TtsPlayback next) {
    final wasSpeaking = previous is TtsSpeaking && previous.id == _speechId;
    if (next is TtsError && next.id == _speechId) {
      _echo.stop();
      setState(() => _failed = true);
    } else if (next is TtsSpeaking && next.id == _speechId) {
      _echo.stop();
      setState(() {
        _failed = false;
        _stage = _ShadowStage.listening;
      });
    } else if (next is TtsIdle && wasSpeaking) {
      _startEcho();
    }
  }

  void _retry() {
    setState(() => _failed = false);
    final tts = ref.read(ttsControllerProvider.notifier);
    final request = turnRequest(widget.dialogue, _index);
    unawaited(tts.speak(tts.atUserSpeed(request)));
  }

  void _startEcho() {
    final spoken = ref
        .read(ttsControllerProvider.notifier)
        .durationOf(_speechId);
    final echoMs = math.max(
      _minEchoMs,
      ((spoken?.inMilliseconds ?? 0) * _echoRatio).round(),
    );
    _echo.duration = Duration(milliseconds: echoMs);
    setState(() => _stage = _ShadowStage.echoing);
    _echo.forward(from: 0);
  }

  void _rate(ShadowLevel level) {
    final counts = {..._counts, level: (_counts[level] ?? 0) + 1};
    setState(() {
      _counts = counts;
      if (_index + 1 < widget.dialogue.turns.length) {
        _index++;
        _stage = _ShadowStage.listening;
      } else {
        _stage = _ShadowStage.finished;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TtsPlayback>(ttsControllerProvider, _onPlayback);
    if (_stage == _ShadowStage.finished) return _finished();
    final d = widget.dialogue;
    final request = turnRequest(d, _index);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  '第 ${_index + 1}／${d.turns.length} 句',
                  scale: TypeScale.caption,
                  color: AppTokens.of(context).ink.secondary,
                ),
              ),
              const SpeedToggle(),
            ],
          ),
          const SizedBox(height: AppSpace.s3),
          AutoplayOnce(key: ValueKey(_index), request: request),
          TurnView(
            dialogue: d,
            index: _index,
            policy: widget.policy,
            showNote: false,
            trailing: SpeakButton(request: request),
          ),
          const SizedBox(height: AppSpace.s4),
          _stageBody(),
        ],
      ),
    );
  }

  Widget _stageBody() => switch (_stage) {
    // 這句沒播出來就無法跟讀，不留死路（§6.6）
    _ShadowStage.listening when _failed => VoiceFailedPanel(
      onRetry: _retry,
      onSilent: () => unawaited(useSilentMode(ref)),
    ),
    _ShadowStage.listening => const _Caption('聽完後，跟著念一次。'),
    _ShadowStage.echoing => _EchoCountdown(animation: _echo),
    _ShadowStage.rating => _ratingRow(),
    _ShadowStage.finished => const SizedBox.shrink(),
  };

  Widget _ratingRow() {
    Widget key(String label, ShadowLevel level) => Expanded(
      child: GhostButton(
        label: label,
        expanded: true,
        onPressed: () => _rate(level),
      ),
    );
    return Row(
      children: [
        key('跟上了', ShadowLevel.kept),
        const SizedBox(width: AppSpace.s2),
        key('差一點', ShadowLevel.almost),
        const SizedBox(width: AppSpace.s2),
        key('跟不上', ShadowLevel.lost),
      ],
    );
  }

  Widget _finished() {
    int count(ShadowLevel level) => _counts[level] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText('跟讀完成。不評分發音，這裡只是給自己看。'),
        const SizedBox(height: AppSpace.s2),
        AppText(
          '跟上了 ${count(ShadowLevel.kept)} 句，'
          '差一點 ${count(ShadowLevel.almost)} 句，'
          '跟不上 ${count(ShadowLevel.lost)} 句',
          color: AppTokens.of(context).ink.secondary,
        ),
        const SizedBox(height: AppSpace.s4),
        InkButton(
          label: widget.isLast ? '完成這段' : '下一段',
          onPressed: widget.onDone,
        ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      AppText(text, color: AppTokens.of(context).ink.secondary);
}

class _EchoCountdown extends StatelessWidget {
  const _EchoCountdown({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Caption('現在跟著念。'),
        if (!AppMotion.of(context).reduced) ...[
          const SizedBox(height: AppSpace.s2),
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Transform.scale(
              scaleX: 1 - animation.value,
              alignment: Alignment.centerLeft,
              child: child,
            ),
            child: Container(height: 2, color: t.ai),
          ),
        ],
      ],
    );
  }
}

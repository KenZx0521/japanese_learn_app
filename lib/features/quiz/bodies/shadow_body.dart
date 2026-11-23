import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../model/quiz_run_state.dart';

enum _ShadowStage { listening, echoing, rating }

/// 跟讀（§3.6）：播放 → 空檔（句長×1.5，線條倒數）→ 三級自評。可重播，不評分發音。
class ShadowBody extends ConsumerStatefulWidget {
  const ShadowBody({
    required this.promptId,
    required this.phase,
    required this.onAnswer,
    super.key,
  });

  /// 題幹那句的語音 id，監聽它播完。
  final String promptId;
  final QuizPhase phase;
  final ValueChanged<AnswerPayload> onAnswer;

  @override
  ConsumerState<ShadowBody> createState() => _ShadowBodyState();
}

class _ShadowBodyState extends ConsumerState<ShadowBody>
    with SingleTickerProviderStateMixin {
  static const _minEchoMs = 1500;
  static const _echoRatio = 1.5;

  // `preserve`：空檔長度是內容的一部分，系統關閉動畫時也不能被壓縮
  late final AnimationController _echo = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onEchoStatus);

  _ShadowStage _stage = _ShadowStage.listening;

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
    final wasSpeaking =
        previous is TtsSpeaking && previous.id == widget.promptId;
    if (next is TtsSpeaking && next.id == widget.promptId) {
      _echo.stop();
      setState(() => _stage = _ShadowStage.listening);
    } else if (next is TtsIdle && wasSpeaking) {
      _startEcho();
    }
  }

  void _startEcho() {
    final spoken = ref
        .read(ttsControllerProvider.notifier)
        .durationOf(widget.promptId);
    final echoMs = math.max(
      _minEchoMs,
      ((spoken?.inMilliseconds ?? 0) * _echoRatio).round(),
    );
    _echo.duration = Duration(milliseconds: echoMs);
    setState(() => _stage = _ShadowStage.echoing);
    _echo.forward(from: 0);
  }

  void _rate(ShadowLevel level) =>
      widget.onAnswer(AnswerPayload.shadow(level: level));

  @override
  Widget build(BuildContext context) {
    ref.listen<TtsPlayback>(ttsControllerProvider, _onPlayback);
    return switch (_stage) {
      _ShadowStage.listening => _Caption('聽完後，跟著念一次。'),
      _ShadowStage.echoing => _EchoCountdown(animation: _echo),
      _ShadowStage.rating => _ratingRow(),
    };
  }

  Widget _ratingRow() {
    final onTap = widget.phase is QuizAnswering ? _rate : null;
    Widget key(String label, ShadowLevel level) => Expanded(
      child: GhostButton(
        label: label,
        expanded: true,
        onPressed: onTap == null ? null : () => onTap(level),
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

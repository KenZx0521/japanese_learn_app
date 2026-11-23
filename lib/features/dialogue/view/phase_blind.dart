import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/censor_bar.dart';
import '../../../design/widgets/error_slip.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/skeleton_lines.dart';
import '../../quiz/quiz.dart';
import '../dialogue_providers.dart';
import 'play_all_control.dart';

enum _BlindStage { listening, quiz }

/// 第一階段：只顯示情境，對白是伏字條，全篇連播後接題目（§3.7）。
class BlindPhase extends ConsumerStatefulWidget {
  const BlindPhase({
    required this.dialogue,
    required this.seed,
    required this.onDone,
    super.key,
  });

  final DialogueDto dialogue;
  final int seed;
  final VoidCallback onDone;

  @override
  ConsumerState<BlindPhase> createState() => _BlindPhaseState();
}

class _BlindPhaseState extends ConsumerState<BlindPhase> {
  _BlindStage _stage = _BlindStage.listening;
  bool _played = false;

  void _next() {
    unawaited(ref.read(ttsControllerProvider.notifier).stop());
    if (widget.dialogue.quizDrillIds.isEmpty) {
      widget.onDone();
    } else {
      setState(() => _stage = _BlindStage.quiz);
    }
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _BlindStage.listening => _listening(context),
    _BlindStage.quiz => _BlindQuiz(
      dialogue: widget.dialogue,
      seed: widget.seed,
      onDone: widget.onDone,
    ),
  };

  Widget _listening(BuildContext context) {
    final t = AppTokens.of(context);
    final d = widget.dialogue;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EyebrowText('情境'),
          const SizedBox(height: AppSpace.s1),
          MixedText(d.sceneZh),
          const SizedBox(height: AppSpace.s5),
          for (final turn in d.turns)
            CensorBar(characters: turn.sentence.display.characters.length),
          const SizedBox(height: AppSpace.s5),
          AppText('先不看字，聽聽看這段在說什麼。', color: t.ink.secondary),
          const SizedBox(height: AppSpace.s3),
          PlayAllControl(
            dialogue: d,
            label: _played ? '再聽一次' : '播放全篇',
            autoStart: true,
            onFinished: () => setState(() => _played = true),
          ),
          if (_played) ...[
            const SizedBox(height: AppSpace.s4),
            InkButton(
              label: d.quizDrillIds.isEmpty ? '下一段' : '做題目',
              onPressed: _next,
            ),
          ],
        ],
      ),
    );
  }
}

class _BlindQuiz extends ConsumerStatefulWidget {
  const _BlindQuiz({
    required this.dialogue,
    required this.seed,
    required this.onDone,
  });

  final DialogueDto dialogue;
  final int seed;
  final VoidCallback onDone;

  @override
  ConsumerState<_BlindQuiz> createState() => _BlindQuizState();
}

class _BlindQuizState extends ConsumerState<_BlindQuiz> {
  bool _skipScheduled = false;

  DialogueQuizArgs get _args =>
      (seed: widget.seed, drillIdsKey: widget.dialogue.quizDrillIds.join(','));

  /// `build` 中不能換階段，等這一幀結束。
  void _skipAfterFrame() {
    if (_skipScheduled) return;
    _skipScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(dialogueQuizProvider(_args))
      .when(
        loading: () => const DelayedReveal(child: SkeletonLines()),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ErrorSlip.fromObject(
              error,
              onRetry: () => ref.invalidate(dialogueQuizProvider(_args)),
            ),
            const SizedBox(height: AppSpace.s3),
            GhostButton(label: '略過題目', onPressed: widget.onDone),
          ],
        ),
        data: (questions) {
          if (questions.isEmpty) {
            _skipAfterFrame();
            return const SizedBox.shrink();
          }
          return QuizSessionView(
            questions: questions,
            grader: const DrillGrader(),
            fallbackLessonId: widget.dialogue.lessonId,
            onFinished: (_) => widget.onDone(),
          );
        },
      );
}

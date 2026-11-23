import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/tts/audio_available.dart';
import '../../core/tts/stop_speech_on_leave.dart';
import '../../core/tts/voice_help.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/confusable_view.dart';
import '../../design/widgets/error_slip.dart';
import '../../design/widgets/esc_to_leave.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/kana_teach_card.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/rule_card_view.dart';
import '../../design/widgets/skeleton_lines.dart';
import '../quiz/quiz.dart';
import 'session/kana_session_controller.dart';
import 'session/kana_session_done.dart';
import 'session/kana_teach_plan.dart';

/// K2 假名自由練習（§3.3）：先呈現未學字，再用 `kana_session` 測驗，不影響計畫。
class KanaSessionScreen extends ConsumerWidget {
  const KanaSessionScreen({required this.lessonId, super.key});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = kanaSessionProvider(lessonId);
    final value = ref.watch(provider);
    return EscToLeave(
      onEscape: () => leavePage(context, fallback: AppRoutes.kana),
      child: StopSpeechOnLeave(
        child: PaperScaffold(
          scrollable: false,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageBackLink(label: '離開', fallback: AppRoutes.kana),
              const SizedBox(height: AppSpace.s2),
              Expanded(
                child: value.when(
                  data: (run) => _RunBody(
                    run: run,
                    controller: ref.read(provider.notifier),
                    lessonId: lessonId,
                  ),
                  loading: () => const DelayedReveal(child: SkeletonLines()),
                  error: (error, _) => _LoadError(
                    error: error,
                    onRetry: () => ref.invalidate(provider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunBody extends StatelessWidget {
  const _RunBody({
    required this.run,
    required this.controller,
    required this.lessonId,
  });

  final KanaSessionRun run;
  final KanaSessionController controller;
  final String lessonId;

  @override
  Widget build(BuildContext context) => switch (run.phase) {
    KanaSessionPhase.teaching => _TeachBody(
      run: run,
      onNext: controller.nextStep,
    ),
    KanaSessionPhase.quiz when run.questions.isEmpty => const _NoQuestions(),
    KanaSessionPhase.quiz => QuizSessionView(
      key: ValueKey(run.attempt),
      questions: run.questions,
      grader: const KanaGrader(),
      requeueWrong: true,
      fallbackLessonId: lessonId,
      onFinished: controller.finishQuiz,
    ),
    KanaSessionPhase.finished => KanaSessionDone(
      outcome: run.outcome!,
      onClose: () => leavePage(context, fallback: AppRoutes.kana),
      onRetry: controller.restart,
    ),
  };
}

class _TeachBody extends StatelessWidget {
  const _TeachBody({required this.run, required this.onNext});

  final KanaSessionRun run;
  final VoidCallback onNext;

  Widget _stepView() => switch (run.currentStep) {
    KanaCharStep(:final detail) => KanaTeachCard(
      key: ValueKey(detail.cell.id),
      detail: detail,
      onNext: onNext,
    ),
    KanaRuleStep(:final card) => RuleCardView(
      key: ValueKey(card.id),
      card: card,
      onNext: onNext,
    ),
    KanaConfusableStep(:final group) => ConfusableView(
      key: ValueKey(group.id),
      group: group,
      onNext: onNext,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          '先認字 ${run.stepIndex + 1}／${run.steps.length}',
          scale: TypeScale.caption,
          color: t.ink.secondary,
        ),
        const SizedBox(height: AppSpace.s3),
        Expanded(child: SingleChildScrollView(child: _stepView())),
      ],
    );
  }
}

class _NoQuestions extends ConsumerWidget {
  const _NoQuestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioAvailableProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(audio ? '這批都熟了' : '這一課的題目都要聽聲音，打開語音就能練。'),
        const SizedBox(height: AppSpace.s5),
        Wrap(
          spacing: AppSpace.s3,
          runSpacing: AppSpace.s3,
          children: [
            if (!audio)
              InkButton(
                label: '設定語音',
                onPressed: () => unawaited(showVoiceHelpSheet(context)),
              ),
            GhostButton(
              label: '回上一頁',
              onPressed: () => leavePage(context, fallback: AppRoutes.kana),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ErrorSlip.fromObject(error, onRetry: onRetry),
      const SizedBox(height: AppSpace.s3),
      GhostButton(
        label: '回上一頁',
        onPressed: () => leavePage(context, fallback: AppRoutes.kana),
      ),
    ],
  );
}

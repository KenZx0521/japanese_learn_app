import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../core/text/display_context.dart';
import '../../core/tts/audio_available.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/confusable_view.dart';
import '../../design/widgets/error_slip.dart';
import '../../design/widgets/grammar_teach_card.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/kana_teach_card.dart';
import '../../design/widgets/rule_card_view.dart';
import '../../design/widgets/skeleton_lines.dart';
import '../../design/widgets/vocab_teach_card.dart';
import '../quiz/quiz.dart';
import 'new_content_reducer.dart';

final newContentSessionProvider = FutureProvider.autoDispose
    .family<NewContentSessionDto, (String, int)>((ref, args) {
      // 探測完成前不可呼叫帶 audio_available 的函式（§6.6）。
      // 語音值在 provider 內讀，不放 family 參數，否則探測完成的那一刻舊參數會多呼叫一次。
      if (!ref.watch(audioResolvedProvider)) {
        return Completer<NewContentSessionDto>().future;
      }
      final audio = ref.watch(audioAvailableProvider);
      final (key, seed) = args;
      return ref.watch(todayRepositoryProvider).newContent(key, seed, audio);
    });

/// L3 新內容學習（§3.10）：呈現、播音、立即一題。只由 T2 進入。
class NewContentView extends ConsumerWidget {
  const NewContentView({
    required this.taskKey,
    required this.lessonId,
    required this.seed,
    required this.onComplete,
    this.onSkip,
    super.key,
  });

  final String taskKey, lessonId;
  final int seed;
  final VoidCallback onComplete;

  /// 整項載入失敗時可略過（§2.3 T2），其餘任務繼續。
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (taskKey, seed);
    void retry() => ref.invalidate(newContentSessionProvider(args));
    return ref
        .watch(newContentSessionProvider(args))
        .when(
          data: (session) => _NewContentRunView(
            key: ObjectKey(session),
            session: session,
            lessonId: lessonId,
            onComplete: onComplete,
          ),
          loading: () => const DelayedReveal(child: SkeletonLines(lines: 5)),
          error: (error, _) =>
              _LoadFailed(error: error, onRetry: retry, onSkip: onSkip),
        );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.error, required this.onRetry, this.onSkip});

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final skip = onSkip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErrorSlip.fromObject(error, onRetry: onRetry),
        if (skip != null) ...[
          const SizedBox(height: AppSpace.s3),
          SkipItemButton(onPressed: skip),
        ],
      ],
    );
  }
}

class _NewContentRunView extends StatefulWidget {
  const _NewContentRunView({
    required this.session,
    required this.lessonId,
    required this.onComplete,
    super.key,
  });

  final NewContentSessionDto session;
  final String lessonId;
  final VoidCallback onComplete;

  @override
  State<_NewContentRunView> createState() => _NewContentRunViewState();
}

class _NewContentRunViewState extends State<_NewContentRunView> {
  late NewContentRun _run = NewContentRun.start(widget.session.steps);
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    if (_run.finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
    }
  }

  void _complete() {
    if (_completed || !mounted) return;
    _completed = true;
    widget.onComplete();
  }

  void _apply(NewContentEvent event) {
    final next = reduceNewContent(_run, event);
    setState(() => _run = next);
    if (next.finished) _complete();
  }

  void _teachDone() => _apply(const NewContentTeachDone());

  void _quizDone(QuizOutcome _) => _apply(const NewContentQuizDone());

  @override
  Widget build(BuildContext context) {
    final step = _run.current;
    if (step == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepProgress(value: _run.progress),
        const SizedBox(height: AppSpace.s4),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey('${_run.index}/${_run.part.name}'),
            child: _stepBody(step),
          ),
        ),
      ],
    );
  }

  Widget _stepBody(NewContentStepDto step) => switch (step) {
    NewContentStepDto_Kana(:final detail) => _scroll(
      KanaTeachCard(detail: detail, onNext: _teachDone),
    ),
    NewContentStepDto_Rule(:final card) => _scroll(
      RuleCardView(card: card, onNext: _teachDone),
    ),
    NewContentStepDto_Confusable(:final group) => _scroll(
      ConfusableView(group: group, onNext: _teachDone),
    ),
    NewContentStepDto_KanaQuiz(:final questions) => QuizSessionView(
      questions: questions,
      grader: const KanaGrader(),
      requeueWrong: true,
      // L3 頂部已有步驟進度線，題目進度不再疊第二條（§3.10）
      showProgress: false,
      fallbackLessonId: widget.lessonId,
      onFinished: _quizDone,
    ),
    NewContentStepDto_Vocab(:final detail) => _withCard(
      teach: (policy) => VocabTeachCard(
        detail: detail,
        policy: policy,
        hasQuiz: _run.currentCard != null,
        onNext: _teachDone,
      ),
      contentLessonId: detail.summary.lessonId,
    ),
    NewContentStepDto_Grammar(:final detail) => _withCard(
      teach: (policy) => GrammarTeachCard(
        detail: detail,
        policy: policy,
        hasQuiz: _run.currentCard != null,
        onNext: _teachDone,
      ),
      contentLessonId: detail.summary.lessonId,
    ),
  };

  Widget _scroll(Widget child) => SingleChildScrollView(child: child);

  Widget _withCard({
    required Widget Function(DisplayPolicyDto policy) teach,
    required String contentLessonId,
  }) {
    final card = _run.currentCard;
    if (_run.part == NewContentPart.firstCard && card != null) {
      return QuizSessionView(
        questions: [card.question],
        grader: ReviewGrader(expectedReps: card.expectedReps),
        ratingPreviews: card.ratingPreviews,
        expandVocab: true,
        showProgress: false,
        fallbackLessonId: widget.lessonId,
        onFinished: _quizDone,
      );
    }
    return _PolicyScope(
      lessonId: contentLessonId,
      builder: (policy) => _scroll(teach(policy)),
    );
  }
}

/// 單字、文法步驟的顯示規則依內容所屬的課（§3.7）。
class _PolicyScope extends ConsumerWidget {
  const _PolicyScope({required this.lessonId, required this.builder});

  final String lessonId;
  final Widget Function(DisplayPolicyDto policy) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = DisplayContext(lessonId: lessonId);
    return AsyncBody(
      value: ref.watch(displayPolicyProvider(args)),
      onRetry: () => ref.invalidate(displayPolicyProvider(args)),
      data: builder,
    );
  }
}

/// 頂部細線進度條（已完成步驟／總步驟），只動 transform。
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final motion = AppMotion.of(context).base;
    return Semantics(
      label: '學習進度 ${(value * 100).round()}%',
      child: ExcludeSemantics(
        child: Container(
          height: 2,
          color: t.line.grid,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: motion.duration,
            curve: motion.curve,
            builder: (context, width, child) => Transform.scale(
              scaleX: width,
              alignment: Alignment.centerLeft,
              child: child,
            ),
            child: Container(color: t.ink.primary),
          ),
        ),
      ),
    );
  }
}

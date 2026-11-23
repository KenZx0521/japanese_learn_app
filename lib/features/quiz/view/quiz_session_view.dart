import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/local_log.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../design/motion.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/error_slip.dart';
import '../../../design/widgets/skeleton_lines.dart';
import '../model/quiz_run_state.dart';
import '../model/quiz_verdict.dart';
import '../question_policy.dart';
import '../quiz_grader.dart';
import '../quiz_session_controller.dart';
import 'question_view.dart';
import 'quiz_feedback.dart';

/// 跑一輪題目（§3.6）。取題由呼叫端負責，傳入新的 [questions] 會重置回合。
///
/// 放在高度有限的版面（`PaperScaffold(scrollable: false)`）時題目區捲動、回饋條固定
/// 在底部；放在捲動頁內（G2 小測驗）時內容依序往下排。
class QuizSessionView extends ConsumerStatefulWidget {
  const QuizSessionView({
    required this.questions,
    required this.grader,
    required this.onFinished,
    this.fallbackLessonId,
    this.requeueWrong = false,
    this.ratingPreviews = const [],
    this.expandVocab = false,
    this.showProgress = true,
    this.emptyMessage = '這裡目前沒有題目',
    super.key,
  });

  final List<QuestionDto> questions;
  final QuizGrader grader;
  final ValueChanged<QuizOutcome> onFinished;

  /// §3.7 的 `fallbackLessonId`；null 時用計畫目前的課。
  final String? fallbackLessonId;

  /// 答錯者本回合末重出一次（D2、K2）。
  final bool requeueWrong;

  /// `SessionCardDto.rating_previews`，只有 V4 需要。
  final List<RatingPreviewDto> ratingPreviews;

  /// `vo.*` 的答後展開（V4，§3.4 第 4 點）。
  final bool expandVocab;
  final bool showProgress;
  final String emptyMessage;

  @override
  ConsumerState<QuizSessionView> createState() => _QuizSessionViewState();
}

class _QuizSessionViewState extends ConsumerState<QuizSessionView> {
  /// 回饋條的細節最多占可用高度的比例，其餘留給題目與按鈕。
  static const _feedbackHeightRatio = 0.42;

  late QuizSessionArgs _args = _newArgs();
  late final TtsController _tts;
  late final String _scope = 'quiz/${identityHashCode(this)}';
  final GlobalKey _feedbackKey = GlobalKey();
  final ScrollController _questionScroll = ScrollController();
  bool _ownsPlayback = false;

  QuizSessionArgs _newArgs() => QuizSessionArgs(
    questions: widget.questions,
    grader: widget.grader,
    requeueWrong: widget.requeueWrong,
  );

  QuizSessionController get _controller =>
      ref.read(quizSessionProvider(_args).notifier);

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsControllerProvider.notifier);
  }

  @override
  void didUpdateWidget(QuizSessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 比內容：呼叫端常寫 `questions: [card.question]`，每次 build 都是新 List
    if (!listEquals(oldWidget.questions, widget.questions)) _args = _newArgs();
  }

  @override
  void dispose() {
    _questionScroll.dispose();
    // 卸載途中不能動 provider，等這一幀結束；只停自己的，下一頁可能已開始播
    if (_ownsPlayback) unawaited(Future.microtask(_stopOnLeave));
    super.dispose();
  }

  /// 整個 ProviderScope 一起卸載時 `TtsController` 已經不在，只留紀錄。
  Future<void> _stopOnLeave() async {
    try {
      await _tts.stop();
    } on Exception catch (error, stack) {
      logLocal(error, stack);
    }
  }

  void _trackPlayback(TtsPlayback? _, TtsPlayback next) {
    _ownsPlayback = switch (next) {
      TtsPreparing(:final id) ||
      TtsSpeaking(:final id) => id.startsWith(_scope),
      TtsIdle() || TtsError() => false,
    };
  }

  void _onRunChanged(QuizRunState? previous, QuizRunState next) {
    final finished = next.phase is QuizFinished;
    if (finished && previous?.phase is! QuizFinished) {
      widget.onFinished(next.outcome);
    }
    if (previous != null && previous.index != next.index) {
      _resetQuestionScroll();
      if (_ownsPlayback) unawaited(_tts.stop());
    }
    final showsResult =
        next.phase is QuizShowingFeedback || next.phase is QuizSaveFailed;
    if (showsResult && !identical(previous?.phase, next.phase)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealFeedback();
        _showAnsweredOptions();
      });
    }
  }

  void _resetQuestionScroll() {
    if (_questionScroll.hasClients) _questionScroll.jumpTo(0);
  }

  /// 固定版面下回饋條壓縮題目區，捲到底才看得到剛選的選項（窄螢幕）。
  void _showAnsweredOptions() {
    if (!mounted || !_questionScroll.hasClients) return;
    final motion = AppMotion.of(context).base;
    final position = _questionScroll.position;
    if (position.maxScrollExtent <= 0) return;
    unawaited(
      _questionScroll.animateTo(
        position.maxScrollExtent,
        duration: motion.duration,
        curve: motion.curve,
      ),
    );
  }

  /// 捲動頁內的回饋條可能在畫面外。固定版面找不到 Scrollable，沒有作用。
  void _revealFeedback() {
    final target = _feedbackKey.currentContext;
    if (target == null || !target.mounted) return;
    final motion = AppMotion.of(target).base;
    unawaited(
      Scrollable.ensureVisible(
        target,
        duration: motion.duration,
        curve: motion.curve,
      ),
    );
  }

  void _submit(AnswerPayload payload, int durationMs) =>
      unawaited(_controller.submit(payload, durationMs: durationMs));

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) return AppText(widget.emptyMessage);
    final provider = quizSessionProvider(_args);
    ref.listen(provider, _onRunChanged);
    ref.listen(ttsControllerProvider, _trackPlayback);
    final run = ref.watch(provider);
    final entry = run.current;
    if (entry == null) return const SizedBox.shrink();
    // 設定載入前不建題目：操作提示要在建立當下讀 `seen_question_hints`
    final settingsPending = ref.watch(
      settingsProvider.select((s) => s.isLoading && !s.hasValue),
    );
    final policy = settingsPending ? null : _policyOf(entry);
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? _fixed(run, entry, policy, constraints.maxHeight)
          : _inline(run, entry, policy),
    );
  }

  DisplayPolicyDto? _policyOf(QuizEntry entry) => ref
      .watch(
        questionPolicyProvider((
          entry.question.reference,
          widget.fallbackLessonId,
        )),
      )
      .when<DisplayPolicyDto?>(
        skipLoadingOnReload: true,
        data: (value) => value,
        loading: () => null,
        error: (_, _) => fallbackQuestionPolicy,
      );

  Widget _fixed(
    QuizRunState run,
    QuizEntry entry,
    DisplayPolicyDto? policy,
    double height,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ..._progress(run),
      Expanded(
        child: SingleChildScrollView(
          controller: _questionScroll,
          child: _question(run, entry, policy),
        ),
      ),
      ?_resultArea(run, entry, policy, height * _feedbackHeightRatio),
    ],
  );

  Widget _inline(QuizRunState run, QuizEntry entry, DisplayPolicyDto? policy) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._progress(run),
          _question(run, entry, policy),
          const SizedBox(height: AppSpace.s4),
          ?_resultArea(run, entry, policy, null),
        ],
      );

  List<Widget> _progress(QuizRunState run) => [
    if (widget.showProgress && run.total > 1) ...[
      _ProgressRule(
        current: run.index + 1,
        completed: run.completedCount,
        total: run.total,
      ),
      const SizedBox(height: AppSpace.s4),
    ],
  ];

  Widget _question(
    QuizRunState run,
    QuizEntry entry,
    DisplayPolicyDto? policy,
  ) {
    if (policy == null) return const DelayedReveal(child: SkeletonLines());
    return _QuestionEntrance(
      key: ValueKey('${identityHashCode(_args)}/${run.index}'),
      child: QuestionView(
        question: entry.question,
        phase: run.phase,
        policy: policy,
        speechScope: '$_scope/${run.index}',
        ratingPreviews: widget.ratingPreviews,
        expandVocab: widget.expandVocab,
        onAnswer: _submit,
      ),
    );
  }

  Widget? _resultArea(
    QuizRunState run,
    QuizEntry entry,
    DisplayPolicyDto? policy,
    double? maxDetailHeight,
  ) {
    final phase = run.phase;
    return switch (phase) {
      QuizShowingFeedback() when policy != null => QuizFeedback(
        key: _feedbackKey,
        question: entry.question,
        payload: phase.payload,
        verdict: phase.verdict,
        durationMs: phase.durationMs,
        policy: policy,
        speechScope: '$_scope/${run.index}',
        expandVocab: widget.expandVocab,
        maxDetailHeight: maxDetailHeight,
        onContinue: _controller.advance,
      ),
      QuizShowingFeedback() => null,
      QuizSaveFailed() => Padding(
        key: _feedbackKey,
        padding: const EdgeInsets.only(top: AppSpace.s3),
        child: ErrorSlip(
          failure: phase.failure,
          onRetry: () => unawaited(_controller.retry()),
        ),
      ),
      QuizGrading() => const Padding(
        padding: EdgeInsets.only(top: AppSpace.s3),
        child: DelayedReveal(child: SkeletonLines(lines: 1)),
      ),
      QuizAnswering() || QuizFinished() => null,
    };
  }
}

/// 頂部細線進度條（§3.3）。只動 transform。
class _ProgressRule extends StatelessWidget {
  const _ProgressRule({
    required this.current,
    required this.completed,
    required this.total,
  });

  final int current, completed, total;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final motion = AppMotion.of(context).base;
    return Semantics(
      label: '第 $current 題，共 $total 題',
      child: ExcludeSemantics(
        child: Container(
          height: 2,
          color: t.line.grid,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: completed / total),
            duration: motion.duration,
            curve: motion.curve,
            builder: (context, value, child) => Transform.scale(
              scaleX: value,
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

/// 換題時淡入，只動 opacity；reduced motion 時立即顯示。
class _QuestionEntrance extends StatelessWidget {
  const _QuestionEntrance({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context).base;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.duration,
      curve: motion.curve,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}

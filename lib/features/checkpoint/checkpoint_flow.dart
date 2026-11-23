import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/failures.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/local_log.dart';
import '../../core/backend/providers.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/error_slip.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/skeleton_lines.dart';
import '../quiz/model/feedback_plan.dart';
import '../quiz/quiz.dart';
import 'checkpoint_result_view.dart';

final checkpointQuestionsProvider = FutureProvider.autoDispose
    .family<List<QuestionDto>, (String, int, bool)>((ref, args) {
      final (id, seed, audio) = args;
      return ref
          .watch(drillRepositoryProvider)
          .checkpointStart(id, seed, audio);
    });

/// 檢定中途不顯示對錯，全部由 Rust 判定（§3.6 D3）。
/// T2、P1、O3 的畢業考共用，差異由參數決定。
class CheckpointFlow extends ConsumerStatefulWidget {
  const CheckpointFlow({
    required this.milestoneId,
    required this.title,
    required this.seed,
    required this.audio,
    required this.onFinished,
    this.onEmpty,
    this.onDismiss,
    this.passedNote = '通過了，這個里程碑蓋上章了。',
    this.failedNote = '可以先往下學，有空再回來',
    this.showWeak = true,
    this.continueLabel = '繼續',
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  });

  final String milestoneId, title;
  final int seed;
  final bool audio;
  final ValueChanged<CheckpointResultDto> onFinished;

  /// 沒有題目時呼叫（T2 略過這一項）；null 時顯示空狀態文字。
  final VoidCallback? onEmpty;

  /// 「先略過」。null 時不顯示。失敗時留在本頁。
  final Future<void> Function()? onDismiss;

  final String passedNote, failedNote, continueLabel;
  final bool showWeak;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  ConsumerState<CheckpointFlow> createState() => _CheckpointFlowState();
}

enum _Stage { intro, quiz, submitting, result }

class _CheckpointFlowState extends ConsumerState<CheckpointFlow> {
  _Stage _stage = _Stage.intro;
  CheckpointResultDto? _result;
  List<AnswerDto> _answers = const [];
  AppFailure? _failure;
  bool _dismissing = false;
  bool _emptyHandled = false;

  /// 開始作答時定住題目：語音或回前景的變動都不能換題、丟掉已作答的內容。
  List<QuestionDto>? _questions;
  String? _restartNote;

  (String, int, bool) get _args =>
      (widget.milestoneId, widget.seed, widget.audio);

  void _begin(List<QuestionDto> questions) => setState(() {
    _questions = questions;
    _restartNote = null;
    _stage = _Stage.quiz;
  });

  @override
  void didUpdateWidget(CheckpointFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audio && !widget.audio) _restartIfNeedsAudio();
  }

  /// 要聽的題目在沒有語音時無法作答，只有這時才重來，而且要講清楚（§6.6）。
  void _restartIfNeedsAudio() {
    if (_stage != _Stage.quiz) return;
    if (!(_questions?.any(needsPlaybackOf) ?? false)) return;
    _questions = null;
    _stage = _Stage.intro;
    _restartNote = '語音改變了，檢定要重新開始。';
  }

  Future<void> _submit(List<AnswerDto> answers) async {
    setState(() {
      _answers = answers;
      _stage = _Stage.submitting;
      _failure = null;
    });
    try {
      final result = await ref
          .read(drillRepositoryProvider)
          .checkpointFinish(widget.milestoneId, answers);
      if (!mounted) return;
      setState(() {
        _result = result;
        _stage = _Stage.result;
      });
    } on Exception catch (error, stack) {
      logLocal(error, stack);
      if (!mounted) return;
      setState(
        () =>
            _failure = error is AppFailure ? error : const UnexpectedFailure(),
      );
    }
  }

  Future<void> _dismiss(Future<void> Function() action) async {
    setState(() {
      _dismissing = true;
      _failure = null;
    });
    try {
      await action();
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _dismissing = false);
    }
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _Stage.intro => _intro(),
    _Stage.quiz => _quiz(),
    _Stage.submitting => _submitting(),
    _Stage.result => CheckpointResultView(
      result: _result!,
      passedNote: widget.passedNote,
      failedNote: widget.failedNote,
      showWeak: widget.showWeak,
      continueLabel: widget.continueLabel,
      secondaryLabel: widget.secondaryLabel,
      onSecondary: widget.onSecondary,
      onContinue: () => widget.onFinished(_result!),
    ),
  };

  Widget _intro() => ref
      .watch(checkpointQuestionsProvider(_args))
      .when(
        loading: () => const DelayedReveal(child: SkeletonLines()),
        error: (error, _) => ErrorSlip.fromObject(
          error,
          onRetry: () => ref.invalidate(checkpointQuestionsProvider(_args)),
        ),
        data: (questions) => questions.isEmpty
            ? _empty()
            : SingleChildScrollView(child: _introBody(questions)),
      );

  Widget _empty() {
    final onEmpty = widget.onEmpty;
    if (onEmpty == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MixedText(widget.title, scale: TypeScale.title),
          const SizedBox(height: AppSpace.s2),
          const AppText('這課目前沒有題目'),
        ],
      );
    }
    if (!_emptyHandled) {
      _emptyHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => onEmpty());
    }
    return const SizedBox.shrink();
  }

  Widget _introBody(List<QuestionDto> questions) {
    final t = AppTokens.of(context);
    final dismiss = widget.onDismiss;
    final failure = _failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MixedText(widget.title, scale: TypeScale.title),
        if (_restartNote case final note?) ...[
          const SizedBox(height: AppSpace.s2),
          AppText(note, color: t.ink.secondary),
        ],
        const SizedBox(height: AppSpace.s2),
        AppText('${questions.length} 題', color: t.ink.secondary),
        AppText('中途不顯示對錯', color: t.ink.secondary),
        const SizedBox(height: AppSpace.s5),
        InkButton(
          label: '開始',
          autofocus: true,
          onPressed: () => _begin(questions),
        ),
        if (dismiss != null) ...[
          const SizedBox(height: AppSpace.s2),
          GhostButton(
            label: '先略過',
            onPressed: _dismissing ? null : () => unawaited(_dismiss(dismiss)),
          ),
        ],
        if (failure != null) ...[
          const SizedBox(height: AppSpace.s3),
          ErrorSlip(failure: failure),
        ],
      ],
    );
  }

  Widget _quiz() {
    final questions = _questions;
    if (questions == null) return const SizedBox.shrink();
    return QuizSessionView(
      questions: questions,
      grader: const CheckpointCollector(),
      onFinished: (outcome) => unawaited(_submit(outcome.answers)),
    );
  }

  Widget _submitting() {
    final failure = _failure;
    if (failure == null) return const DelayedReveal(child: SkeletonLines());
    return ErrorSlip(
      failure: failure,
      onRetry: () => unawaited(_submit(_answers)),
    );
  }
}

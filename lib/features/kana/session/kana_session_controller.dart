import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show immutable;

import '../../../core/backend/failures.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/local_log.dart';
import '../../../core/backend/providers.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/tts/audio_available.dart';
import '../../quiz/quiz.dart';
import 'kana_teach_plan.dart';

enum KanaSessionPhase { teaching, quiz, finished }

/// K2 一回合的進度。語音可用性改變時只換題目，不重置教學進度。
@immutable
final class KanaSessionRun {
  const KanaSessionRun({
    required this.steps,
    required this.questions,
    required this.phase,
    this.stepIndex = 0,
    this.attempt = 0,
    this.outcome,
  });

  factory KanaSessionRun.start(
    List<KanaTeachStep> steps,
    List<QuestionDto> questions,
  ) => KanaSessionRun(
    steps: steps,
    questions: questions,
    phase: steps.isEmpty ? KanaSessionPhase.quiz : KanaSessionPhase.teaching,
  );

  final List<KanaTeachStep> steps;
  final List<QuestionDto> questions;
  final KanaSessionPhase phase;
  final int stepIndex;

  /// 「再練一次」遞增，讓 `QuizSessionView` 以新 key 重來。
  final int attempt;
  final QuizOutcome? outcome;

  KanaTeachStep get currentStep => steps[stepIndex];

  KanaSessionRun _copy({
    List<QuestionDto>? questions,
    KanaSessionPhase? phase,
    int? stepIndex,
    int? attempt,
    QuizOutcome? outcome,
  }) => KanaSessionRun(
    steps: steps,
    questions: questions ?? this.questions,
    phase: phase ?? this.phase,
    stepIndex: stepIndex ?? this.stepIndex,
    attempt: attempt ?? this.attempt,
    outcome: outcome ?? this.outcome,
  );

  KanaSessionRun advanced() => stepIndex + 1 < steps.length
      ? _copy(stepIndex: stepIndex + 1)
      : _copy(phase: KanaSessionPhase.quiz);

  KanaSessionRun finished(QuizOutcome result) =>
      _copy(phase: KanaSessionPhase.finished, outcome: result);

  KanaSessionRun restarted() =>
      _copy(phase: KanaSessionPhase.quiz, attempt: attempt + 1);

  KanaSessionRun withQuestions(List<QuestionDto> next) =>
      _copy(questions: next);
}

final kanaSessionProvider = AsyncNotifierProvider.autoDispose
    .family<KanaSessionController, KanaSessionRun, String>(
      KanaSessionController.new,
    );

/// 同一天重開題目相同（§5.2）；K2 可能還沒有計畫，不能向 Rust 要 logical_date。
String _logicalDate(DateTime now, int rolloverHour) {
  final date = now.subtract(Duration(hours: rolloverHour));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

class KanaSessionController extends AsyncNotifier<KanaSessionRun> {
  KanaSessionController(this.lessonId);

  final String lessonId;

  late final int _seed = sessionSeed(
    _logicalDate(
      DateTime.now(),
      ref.read(settingsProvider).value?.dayRolloverHour ?? 0,
    ),
  );

  @override
  Future<KanaSessionRun> build() {
    if (!ref.watch(audioResolvedProvider)) {
      return Completer<KanaSessionRun>().future;
    }
    ref.listen(
      audioAvailableProvider,
      (_, audio) => unawaited(_refetchQuestions(audio)),
    );
    return _load(ref.read(audioAvailableProvider));
  }

  Future<KanaSessionRun> _load(bool audio) async {
    final kana = ref.read(kanaRepositoryProvider);
    final lesson = await ref.read(courseRepositoryProvider).lesson(lessonId);
    final questions = await kana.session(lessonId, _seed, audio);
    final lessonIds = {for (final cell in lesson.kana) cell.id};
    final newIds = [
      for (final cell in lesson.kana)
        if (cell.status == KanaStatus.notStarted) cell.id,
    ];
    final outsideIds = kanaTargetsOf(questions).difference(lessonIds);
    final details = await Future.wait(
      [...newIds, ...outsideIds].map(kana.detail),
    );
    return KanaSessionRun.start(
      buildTeachSteps(details, questions, rules: rulesToTeach(lesson)),
      questions,
    );
  }

  /// §6.6：同 seed 重取，尚未作答的題目直接丟棄。
  Future<void> _refetchQuestions(bool audio) async {
    if (state.value == null) return;
    try {
      final questions = await ref
          .read(kanaRepositoryProvider)
          .session(lessonId, _seed, audio);
      if (ref.mounted) _update((run) => run.withQuestions(questions));
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (ref.mounted) state = AsyncError(failure, stack);
    }
  }

  void _update(KanaSessionRun Function(KanaSessionRun run) next) {
    final run = state.value;
    if (run != null) state = AsyncData(next(run));
  }

  void nextStep() => _update((run) => run.advanced());

  void finishQuiz(QuizOutcome outcome) =>
      _update((run) => run.finished(outcome));

  void restart() => _update((run) => run.restarted());
}

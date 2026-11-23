import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/backend/frb/dto.dart';
import '../../../../core/backend/providers.dart';
import '../../../../core/tts/audio_available.dart';
import '../../../../design/widgets/skeleton_lines.dart';
import '../../../quiz/quiz.dart';
import 'task_load_failed.dart';

const _lessonDrillCount = 10;

final _drillQuestionsProvider = FutureProvider.autoDispose
    .family<List<QuestionDto>, (String?, String?, int, int)>((ref, args) {
      if (!ref.watch(audioResolvedProvider)) {
        return Completer<List<QuestionDto>>().future;
      }
      final audio = ref.watch(audioAvailableProvider);
      final (taskKey, lessonId, count, seed) = args;
      return ref
          .watch(drillRepositoryProvider)
          .session(
            DrillFilterDto(
              taskKey: taskKey,
              lessonId: lessonId,
              drillIds: const [],
              count: count,
            ),
            seed,
            audio,
          );
    });

/// `Drill` 任務（§3.2）。
class DrillTaskRunner extends ConsumerWidget {
  const DrillTaskRunner({
    required this.taskKey,
    required this.count,
    required this.seed,
    required this.onFinished,
    required this.onSkip,
    super.key,
  });

  final String taskKey;
  final int count, seed;
  final VoidCallback onFinished, onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (taskKey, null, count, seed);
    return QuestionTaskBody(
      value: ref.watch(_drillQuestionsProvider(args)),
      onRetry: () => ref.invalidate(_drillQuestionsProvider(args)),
      onFinished: onFinished,
      onSkip: onSkip,
    );
  }
}

/// `Integration` 沒有對話時改跑 D2（§3.2）。
class LessonDrillRunner extends ConsumerWidget {
  const LessonDrillRunner({
    required this.lessonId,
    required this.seed,
    required this.onFinished,
    required this.onSkip,
    super.key,
  });

  final String lessonId;
  final int seed;
  final VoidCallback onFinished, onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (null, lessonId, _lessonDrillCount, seed);
    return QuestionTaskBody(
      value: ref.watch(_drillQuestionsProvider(args)),
      onRetry: () => ref.invalidate(_drillQuestionsProvider(args)),
      fallbackLessonId: lessonId,
      onFinished: onFinished,
      onSkip: onSkip,
    );
  }
}

/// 載入、空（略過）、錯誤、作答。取題為空時略過，不呼叫 `complete_task`（§3.2）。
class QuestionTaskBody extends StatefulWidget {
  const QuestionTaskBody({
    required this.value,
    required this.onRetry,
    required this.onFinished,
    required this.onSkip,
    this.fallbackLessonId,
    super.key,
  });

  final AsyncValue<List<QuestionDto>> value;
  final VoidCallback onRetry, onFinished, onSkip;
  final String? fallbackLessonId;

  @override
  State<QuestionTaskBody> createState() => _QuestionTaskBodyState();
}

class _QuestionTaskBodyState extends State<QuestionTaskBody> {
  bool _skipScheduled = false;

  void _skipOnce() {
    if (_skipScheduled) return;
    _skipScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSkip();
    });
  }

  @override
  Widget build(BuildContext context) => widget.value.when(
    loading: () => const DelayedReveal(child: SkeletonLines()),
    error: (error, _) => TaskLoadFailed(
      error: error,
      onRetry: widget.onRetry,
      onSkip: widget.onSkip,
    ),
    data: (questions) {
      if (questions.isEmpty) {
        _skipOnce();
        return const SizedBox.shrink();
      }
      return QuizSessionView(
        questions: questions,
        grader: const DrillGrader(),
        requeueWrong: true,
        fallbackLessonId: widget.fallbackLessonId,
        onFinished: (_) => widget.onFinished(),
      );
    },
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/backend/frb/dto.dart';
import '../../../../core/tts/audio_available.dart';
import '../../../../design/widgets/skeleton_lines.dart';
import '../../../checkpoint/checkpoint_flow.dart';
import '../../../dialogue/dialogue.dart';
import '../../../listen/listen.dart';
import '../../../new_content/new_content_view.dart';
import '../../../session/cards/card_runner.dart';
import '../../today_providers.dart';
import 'question_task_runner.dart';
import 'task_load_failed.dart';

/// 依 `TaskDto` 選執行元件（§3.2 的表）。
class TaskRunner extends ConsumerWidget {
  const TaskRunner({
    required this.task,
    required this.seed,
    required this.onFinished,
    required this.onSkip,
    required this.onDismissCheckpoint,
    super.key,
  });

  final TaskDto task;
  final int seed;

  /// 任務完成，要 `complete_task`。
  final VoidCallback onFinished;

  /// 取題為空或載入失敗時略過，不 `complete_task`。
  final VoidCallback onSkip;

  final Future<void> Function(String milestoneId) onDismissCheckpoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (task) {
    TaskDto_Review() => CardRunner(seed: seed, onDone: (_) => onFinished()),
    TaskDto_NewContent(:final key, :final lessonId) => NewContentView(
      taskKey: key,
      lessonId: lessonId,
      seed: seed,
      onComplete: onFinished,
      onSkip: onSkip,
    ),
    TaskDto_Integration() => _integration(task as TaskDto_Integration),
    TaskDto_Drill(:final key, :final questions) => DrillTaskRunner(
      taskKey: key,
      count: questions,
      seed: seed,
      onFinished: onFinished,
      onSkip: onSkip,
    ),
    TaskDto_Listen(:final key) => ListenSessionView(
      taskKey: key,
      seed: seed,
      onFinished: (_) => onFinished(),
      onEmpty: onSkip,
      onSkipFailed: onSkip,
    ),
    TaskDto_Checkpoint(:final milestoneId) => _checkpoint(ref, milestoneId),
  };

  Widget _integration(TaskDto_Integration task) {
    final dialogueId = task.dialogueId;
    if (dialogueId == null) {
      return LessonDrillRunner(
        lessonId: task.lessonId,
        seed: seed,
        onFinished: onFinished,
        onSkip: onSkip,
      );
    }
    return _DialogueTask(
      dialogueId: dialogueId,
      phases: task.phases.toList(growable: false),
      seed: seed,
      onFinished: onFinished,
      onSkip: onSkip,
    );
  }

  Widget _checkpoint(WidgetRef ref, String milestoneId) => CheckpointFlow(
    milestoneId: milestoneId,
    title: ref.watch(milestoneTitleProvider(milestoneId)).value ?? '里程碑檢定',
    seed: seed,
    audio: ref.watch(audioAvailableProvider),
    onFinished: (_) => onFinished(),
    onEmpty: onSkip,
    onDismiss: () => onDismissCheckpoint(milestoneId),
  );
}

/// `Integration`：載入對話後交給 S4，只跑排定的段落。載入失敗可略過（§2.3）。
class _DialogueTask extends ConsumerWidget {
  const _DialogueTask({
    required this.dialogueId,
    required this.phases,
    required this.seed,
    required this.onFinished,
    required this.onSkip,
  });

  final String dialogueId;
  final List<int> phases;
  final int seed;
  final VoidCallback onFinished, onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = dialogueDetailProvider(dialogueId);
    return ref
        .watch(provider)
        .when(
          loading: () => const DelayedReveal(child: SkeletonLines()),
          error: (error, _) => TaskLoadFailed(
            error: error,
            onRetry: () => ref.invalidate(provider),
            onSkip: onSkip,
          ),
          data: (dialogue) => DialogueRunner(
            dialogue: dialogue,
            phases: phases,
            seed: seed,
            autoFinish: true,
            onFinished: onFinished,
          ),
        );
  }
}

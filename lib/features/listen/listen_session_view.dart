import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/tts/audio_available.dart';
import '../../core/tts/voice_help.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/error_slip.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/skeleton_lines.dart';
import '../quiz/quiz.dart';
import 'listen_providers.dart';

/// 今日 `Listen` 任務（D2 版面，§3.5）。每 3 題的第 3 題是跟讀：
/// 三級自評由 `grade_drill` 累計進 `daily_activity`，不進 FSRS（§6.1）。
///
/// 放在 `PaperScaffold(scrollable: false)` 內。[onFinished] 後由 T2 呼叫 `complete_task`；
/// 取題為空時走 [onEmpty]，不呼叫 `complete_task`（§3.2）。
class ListenSessionView extends ConsumerWidget {
  const ListenSessionView({
    required this.taskKey,
    required this.seed,
    required this.onFinished,
    required this.onEmpty,
    this.fallbackLessonId,
    this.onSkipFailed,
    super.key,
  });

  final String taskKey;

  /// T2 當日的 `session_seed`（§5.2）。語音改變時同 seed 重取（§6.6）。
  final int seed;
  final ValueChanged<QuizOutcome> onFinished;
  final VoidCallback onEmpty;
  final String? fallbackLessonId;

  /// 載入失敗時的略過動作（§2.3 T2：單項失敗可略過）；null 則只能重試。
  final VoidCallback? onSkipFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (taskKey: taskKey, seed: seed);
    return ref
        .watch(listenQuestionsProvider(args))
        .when(
          loading: () => const DelayedReveal(child: SkeletonLines()),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorSlip.fromObject(
                error,
                onRetry: () => ref.invalidate(listenQuestionsProvider(args)),
              ),
              if (onSkipFailed != null) ...[
                const SizedBox(height: AppSpace.s3),
                SkipItemButton(onPressed: onSkipFailed),
              ],
            ],
          ),
          data: (questions) => questions.isEmpty
              ? _ListenEmpty(onEmpty: onEmpty)
              : QuizSessionView(
                  questions: questions,
                  grader: const DrillGrader(),
                  requeueWrong: true,
                  onFinished: onFinished,
                  fallbackLessonId: fallbackLessonId,
                ),
        );
  }
}

/// 有語音卻沒題目才自動略過；沒語音時要講清楚並給設定入口，絕不靜默（§6.4）。
class _ListenEmpty extends ConsumerStatefulWidget {
  const _ListenEmpty({required this.onEmpty});
  final VoidCallback onEmpty;

  @override
  ConsumerState<_ListenEmpty> createState() => _ListenEmptyState();
}

class _ListenEmptyState extends ConsumerState<_ListenEmpty> {
  bool _skipScheduled = false;

  void _skipAfterFrame() {
    if (_skipScheduled) return;
    _skipScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onEmpty();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(audioAvailableProvider)) {
      _skipAfterFrame();
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(liveRegion: true, child: const AppText('現在沒有語音，聽力先略過。')),
        const SizedBox(height: AppSpace.s3),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            InkButton(
              label: '設定語音',
              onPressed: () => unawaited(showVoiceHelpSheet(context)),
            ),
            SkipItemButton(onPressed: widget.onEmpty),
          ],
        ),
      ],
    );
  }
}

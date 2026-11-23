import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/drill_questions_provider.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/romaji_scope.dart';
import '../../core/text/romaji_toggle.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/esc_to_leave.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/voice_banner.dart';
import '../quiz/question_policy.dart';
import '../quiz/quiz.dart';
import 'drill_finished_view.dart';

/// D2 演練（§3.6）。題目不記歷史，離開後以同 seed 重做，所以不需要離開確認（§2.3）。
class DrillScreen extends StatelessWidget {
  const DrillScreen({this.lesson, this.target, this.drills, super.key});

  final String? lesson;
  final String? target;
  final List<String>? drills;

  /// 依課與依目標的題數（§3.6）。指定題組時 0 表示全部都出。
  static const _scopedCount = 10;

  DrillQuery get _query => (
    lessonId: lesson,
    target: target,
    drillIds: drills?.join(',') ?? '',
    count: drills == null ? _scopedCount : 0,
  );

  @override
  Widget build(BuildContext context) {
    final query = _query;
    // 換條件就是新的一輪，回合狀態跟著重置
    return _DrillRun(key: ValueKey(query), query: query);
  }
}

class _DrillRun extends ConsumerStatefulWidget {
  const _DrillRun({required this.query, super.key});
  final DrillQuery query;

  @override
  ConsumerState<_DrillRun> createState() => _DrillRunState();
}

class _DrillRunState extends ConsumerState<_DrillRun> {
  int _attempt = 0;
  QuizOutcome? _outcome;

  void _leave() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.drills);

  void _redo() => setState(() {
    _attempt++;
    _outcome = null;
  });

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    final value = ref.watch(drillQuestionsProvider(query));
    final first = _outcome == null ? value.value?.firstOrNull : null;
    return EscToLeave(
      onEscape: _leave,
      child: RomajiPageScope(
        child: PaperScaffold(
          scrollable: false,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: BackLine(onBack: _leave, label: '離開'),
                  ),
                  if (first != null)
                    _QuestionRomajiToggle(
                      reference: first.reference,
                      lessonId: query.lessonId,
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s2),
              Expanded(
                child: AsyncBody<List<QuestionDto>>(
                  value: value,
                  onRetry: () => retryDrillQuestions(ref, query),
                  data: _content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<QuestionDto> questions) {
    if (questions.isEmpty) {
      return _EmptyDrill(
        isLesson: widget.query.lessonId != null,
        onBack: _leave,
      );
    }
    final outcome = _outcome;
    if (outcome != null) {
      return DrillFinishedView(outcome: outcome, onRedo: _redo, onDone: _leave);
    }
    return QuizSessionView(
      key: ValueKey(_attempt),
      questions: questions,
      grader: const DrillGrader(),
      requeueWrong: true,
      fallbackLessonId: widget.query.lessonId,
      onFinished: (result) => setState(() => _outcome = result),
    );
  }
}

/// 同一輪的題目通常來自同一課，開關跟著第一題的規則（§3.7）。
class _QuestionRomajiToggle extends ConsumerWidget {
  const _QuestionRomajiToggle({required this.reference, this.lessonId});

  final QuestionRefDto reference;
  final String? lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref
        .watch(questionPolicyProvider((reference, lessonId)))
        .value;
    return policy?.romaji == RomajiMode.shownToggleable
        ? const RomajiToggle()
        : const SizedBox.shrink();
  }
}

/// 無聲模式或語音不可用時，聽力題被 Rust 排除，可能因此沒題，要說明原因（§6.6）。
class _EmptyDrill extends StatelessWidget {
  const _EmptyDrill({required this.isLesson, required this.onBack});

  final bool isLesson;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VoiceBanner(),
        const SizedBox(height: AppSpace.s4),
        Semantics(
          liveRegion: true,
          child: AppText(isLesson ? '這課目前沒有題目' : '這裡目前沒有題目'),
        ),
        const SizedBox(height: AppSpace.s4),
        GhostButton(label: '回去', onPressed: onBack),
      ],
    ),
  );
}

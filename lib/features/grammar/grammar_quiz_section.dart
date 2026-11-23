import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/drill_questions_provider.dart';
import '../../core/backend/frb/dto.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/ink_buttons.dart';
import '../quiz/quiz.dart';
import 'grammar_providers.dart';

/// 小測驗（§3.5）：內嵌在頁尾，完成不蓋章。沒有題目時整區不出現。
///
/// 要按「開始」才建立題目：這區在第一屏之外，題目一建立就會自動播音，
/// 也會把該題型的操作提示記成已看過（§3.12）。
class GrammarQuizSection extends ConsumerStatefulWidget {
  const GrammarQuizSection({
    required this.grammarId,
    required this.lessonId,
    super.key,
  });

  final String grammarId;
  final String lessonId;

  @override
  ConsumerState<GrammarQuizSection> createState() => _GrammarQuizSectionState();
}

class _GrammarQuizSectionState extends ConsumerState<GrammarQuizSection> {
  bool _started = false;
  int _attempt = 0;
  QuizOutcome? _outcome;

  DrillQuery get _query => grammarQuizQuery(widget.grammarId);

  void _start() => setState(() => _started = true);

  void _redo() => setState(() {
    _attempt++;
    _outcome = null;
  });

  @override
  Widget build(BuildContext context) => AsyncBody<List<QuestionDto>>(
    value: ref.watch(drillQuestionsProvider(_query)),
    onRetry: () => retryDrillQuestions(ref, _query),
    data: (questions) =>
        questions.isEmpty ? const SizedBox.shrink() : _section(questions),
  );

  Widget _section(List<QuestionDto> questions) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.line.strong)),
          ),
          child: const AppText('小測驗', scale: TypeScale.title),
        ),
        const SizedBox(height: AppSpace.s3),
        _body(questions),
      ],
    );
  }

  Widget _body(List<QuestionDto> questions) {
    final outcome = _outcome;
    if (outcome != null) return _Result(outcome: outcome, onRedo: _redo);
    if (!_started) return _Intro(count: questions.length, onStart: _start);
    return QuizSessionView(
      key: ValueKey(_attempt),
      questions: questions,
      grader: const DrillGrader(),
      fallbackLessonId: widget.lessonId,
      onFinished: (outcome) => setState(() => _outcome = outcome),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.count, required this.onStart});

  final int count;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        '讀完了，用 $count 題確認一下。',
        color: AppTokens.of(context).ink.secondary,
      ),
      const SizedBox(height: AppSpace.s3),
      InkButton(label: '開始小測驗', onPressed: onStart),
    ],
  );
}

class _Result extends StatelessWidget {
  const _Result({required this.outcome, required this.onRedo});

  final QuizOutcome outcome;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        liveRegion: true,
        child: AppText(
          '答對 ${outcome.firstTryCorrect} 題，共 ${outcome.firstTryCount} 題',
        ),
      ),
      const SizedBox(height: AppSpace.s3),
      GhostButton(label: '再做一次', onPressed: onRedo),
    ],
  );
}

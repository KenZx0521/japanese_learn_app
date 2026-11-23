import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/text/ja_text.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/text/option_language.dart';
import '../../../core/text/ruby_line.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/choice_tile.dart';
import '../model/quiz_run_state.dart';

enum _ChoiceLayout { list, grid, keys }

_ChoiceLayout _layoutOf(QuestionType type) => switch (type) {
  QuestionType.kanaRead ||
  QuestionType.kanaListen ||
  QuestionType.kanaConfuse => _ChoiceLayout.grid,
  QuestionType.particleFill => _ChoiceLayout.keys,
  QuestionType.recog ||
  QuestionType.vocabListen ||
  QuestionType.produce ||
  QuestionType.kanaMatch ||
  QuestionType.minimalPair ||
  QuestionType.kanaWord ||
  QuestionType.substitution ||
  QuestionType.reorder ||
  QuestionType.zhToJaChoice ||
  QuestionType.listenMeaning ||
  QuestionType.situationResponse ||
  QuestionType.conjugate ||
  QuestionType.registerConvert ||
  QuestionType.shadowing ||
  QuestionType.falseFriend => _ChoiceLayout.list,
};

/// 作答前全部 idle；送出後先依 `correct_option_id` 標記，回傳後以 Rust 為準（§3.6）。
ChoiceTileState choiceTileStateOf(
  OptionDto option,
  QuestionBodyDto_Choice body,
  QuizPhase phase,
) {
  final (chosen, verdict) = switch (phase) {
    QuizGrading(:final payload) ||
    QuizSaveFailed(:final payload) => (_chosenId(payload), null),
    QuizShowingFeedback(:final payload, :final verdict) => (
      _chosenId(payload),
      verdict.isCorrect,
    ),
    QuizAnswering() || QuizFinished() => (null, null),
  };
  if (chosen == null) return ChoiceTileState.idle;
  final isAnswer = option.id == body.correctOptionId;
  final correct = verdict ?? chosen == body.correctOptionId;
  if (option.id == chosen) {
    return correct ? ChoiceTileState.correct : ChoiceTileState.wrong;
  }
  return isAnswer && !correct && chosen != body.correctOptionId
      ? ChoiceTileState.correct
      : ChoiceTileState.dimmed;
}

String? _chosenId(AnswerPayload payload) =>
    payload is AnswerPayload_Choice ? payload.optionId : null;

class ChoiceBody extends StatelessWidget {
  const ChoiceBody({
    required this.body,
    required this.questionType,
    required this.policy,
    required this.phase,
    required this.onAnswer,
    super.key,
  });

  final QuestionBodyDto_Choice body;
  final QuestionType questionType;
  final DisplayPolicyDto policy;
  final QuizPhase phase;
  final ValueChanged<AnswerPayload> onAnswer;

  @override
  Widget build(BuildContext context) => switch (_layoutOf(questionType)) {
    _ChoiceLayout.list => _list(),
    _ChoiceLayout.grid => _grid(),
    _ChoiceLayout.keys => _keys(),
  };

  Widget _list() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, option) in body.options.indexed) ...[
        if (index > 0) const SizedBox(height: AppSpace.s2),
        _tile(option, _optionChild(option, centered: false)),
      ],
    ],
  );

  /// 假名大字用兩欄，選項一眼看完。
  Widget _grid() => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - AppSpace.s2) / 2;
      return Wrap(
        spacing: AppSpace.s2,
        runSpacing: AppSpace.s2,
        children: [
          for (final option in body.options)
            SizedBox(
              width: width,
              child: _tile(option, _optionChild(option, centered: true)),
            ),
        ],
      );
    },
  );

  /// 助詞鍵：一排短鍵，空格在題幹的句子內。
  Widget _keys() => Wrap(
    spacing: AppSpace.s2,
    runSpacing: AppSpace.s2,
    children: [
      for (final option in body.options)
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72),
          child: IntrinsicWidth(
            child: _tile(option, _optionChild(option, centered: true)),
          ),
        ),
    ],
  );

  Widget _tile(OptionDto option, Widget child) => ChoiceTile(
    state: choiceTileStateOf(option, body, phase),
    onTap: phase is QuizAnswering
        ? () => onAnswer(AnswerPayload.choice(optionId: option.id))
        : null,
    child: child,
  );

  Widget _optionChild(OptionDto option, {required bool centered}) {
    final sentence = option.sentence;
    if (sentence != null) return RubyLine.sentence(sentence, policy: policy);
    final align = centered ? TextAlign.center : TextAlign.start;
    final large = _layoutOf(questionType) == _ChoiceLayout.grid;
    return switch (optionLanguageOf(questionType)) {
      OptionLanguage.ja => JaText(
        option.text,
        scale: large ? TypeScale.jaHero : TypeScale.jaBody,
        textAlign: align,
      ),
      OptionLanguage.zh => MixedText(option.text, textAlign: align),
      OptionLanguage.romaji => AppText(
        option.text,
        scale: TypeScale.title,
        textAlign: align,
      ),
      OptionLanguage.none => AppText(option.text, textAlign: align),
    };
  }
}

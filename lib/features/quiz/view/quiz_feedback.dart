import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/text/ruby_line.dart';
import '../../../core/tts/autoplay.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/feedback_strip.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/scroll_fade_box.dart';
import '../../../design/widgets/side_rule_note.dart';
import '../model/feedback_plan.dart';
import '../model/quiz_verdict.dart';
import 'answer_compare.dart';
import 'focus_points.dart';
import 'speak_row.dart';
import 'vocab_expansion.dart';

/// 答後回饋條（§3.6）：全文、中文、原因、語法重點一次展開。
class QuizFeedback extends ConsumerWidget {
  const QuizFeedback({
    required this.question,
    required this.payload,
    required this.verdict,
    required this.durationMs,
    required this.policy,
    required this.speechScope,
    required this.expandVocab,
    required this.onContinue,
    this.maxDetailHeight,
    super.key,
  });

  final QuestionDto question;
  final AnswerPayload payload;
  final QuizVerdict verdict;
  final int durationMs;
  final DisplayPolicyDto policy;
  final String speechScope;
  final bool expandVocab;
  final VoidCallback onContinue;

  /// 全螢幕作答時限制高度，內容過長在條內捲動，「繼續」永遠看得到。
  final double? maxDetailHeight;

  String? get _vocabId {
    final id = question.reference.contentId;
    return expandVocab && id.startsWith('vo.') ? id : null;
  }

  String get _title => switch (question.body) {
    QuestionBodyDto_Match() => verdict.isCorrect ? '全部配對正確' : '配對完成',
    QuestionBodyDto_Choice() ||
    QuestionBodyDto_Reorder() ||
    QuestionBodyDto_Typing() ||
    QuestionBodyDto_SelfGrade() ||
    QuestionBodyDto_Shadow() => verdict.isCorrect ? '答對了' : '不對喔',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = ref.watch(textToolsProvider);
    final plan = feedbackPlanFor(
      question,
      payload,
      verdict,
      plainOf: (mixed) => tools.parseMixedText(mixed).map(_spanText).join(),
      vocabExpanded: _vocabId != null,
    );
    final romaji = _typedRomaji(tools.romanizeReading);
    final details = _details(plan, romaji, context);
    final limit = maxDetailHeight;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: _spaced(details),
    );
    return FeedbackStrip(
      correct: verdict.isCorrect,
      title: _title,
      action: InkButton(
        label: '繼續',
        expanded: true,
        autofocus: true,
        onPressed: onContinue,
      ),
      child: limit == null
          ? body
          : ScrollFadeBox(maxHeight: limit, child: body),
    );
  }

  static String _spanText(MixedSpanDto span) => switch (span) {
    MixedSpanDto_Zh(:final text) || MixedSpanDto_Ja(:final text) => text,
  };

  String? _typedRomaji(String? Function(String, ReadingMode) romanize) {
    final body = question.body;
    return body is QuestionBodyDto_Typing
        ? romanize(body.expectedReading, ReadingMode.word)
        : null;
  }

  List<Widget> _spaced(List<Widget> children) => [
    for (final (index, child) in children.indexed) ...[
      if (index > 0) const SizedBox(height: AppSpace.s3),
      child,
    ],
  ];

  List<Widget> _details(
    FeedbackPlan plan,
    String? romaji,
    BuildContext context,
  ) {
    final secondary = AppTokens.of(context).ink.secondary;
    final sides = compareSidesOf(question);
    return [
      ..._autoplay(),
      if (_masteryLine() case final line?) AppText(line, color: secondary),
      if (question.body is QuestionBodyDto_Match)
        AppText('用了 ${(durationMs / 1000).round()} 秒', color: secondary),
      if (plan.correctDisplay case final display?)
        _CorrectAnswer(display: display, romaji: romaji),
      ..._sentence(plan, secondary),
      if (question.questionType == QuestionType.substitution)
        AppText('跟著念一次。', color: secondary),
      if (plan.whyZh case final why?)
        SideRuleNote(title: '為什麼不對', child: MixedText(why)),
      if (plan.explainZh case final explain?)
        SideRuleNote(title: '說明', child: MixedText(explain)),
      if (sides.isNotEmpty)
        AnswerCompare(sides: sides, speechScope: speechScope),
      if (plan.focusIds.isNotEmpty) FocusPoints(ids: plan.focusIds),
      if (_vocabId case final id?) VocabExpansion(vocabId: id, policy: policy),
    ];
  }

  String? _masteryLine() {
    final mastery = verdict.mastery;
    if (mastery == null) return null;
    return mastery.mastered
        ? '這個字熟練了'
        : '連續答對 ${mastery.run}／${mastery.required_}';
  }

  SpeechRequest _request(String name, SpeechDto speech) =>
      SpeechRequest.fromDto('$speechScope/$name', speech);

  List<Widget> _autoplay() {
    final speech = afterAnswerSpeechOf(question, verdict);
    if (speech == null) return const [];
    return [AutoplayOnce(request: _request('after', speech))];
  }

  List<Widget> _sentence(FeedbackPlan plan, Color secondary) {
    final sentence = plan.sentence;
    final showLine = sentence != null && !plan.sentenceInPrompt;
    final speech = _stripSpeech(plan);
    return [
      if (showLine) RubyLine.sentence(sentence, policy: policy),
      if (plan.sentenceZh case final zh?) AppText(zh, color: secondary),
      if (speech != null) SpeakRow(request: _request('after', speech)),
    ];
  }

  /// 題幹已有播放鈕時不重複；否則補一顆讓使用者能再聽。
  SpeechDto? _stripSpeech(FeedbackPlan plan) {
    final sentence = plan.sentence;
    if (sentence != null && !plan.sentenceInPrompt) return sentence.speech;
    if (question.prompt.speech != null) return null;
    return sentence?.speech ?? afterAnswerSpeechOf(question, verdict);
  }
}

class _CorrectAnswer extends StatelessWidget {
  const _CorrectAnswer({required this.display, required this.romaji});
  final String display;
  final String? romaji;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = romaji;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('正確答案', scale: TypeScale.label, color: t.ink.secondary),
        MixedText(display),
        if (text != null)
          AppText(text, scale: TypeScale.caption, color: t.ink.secondary),
      ],
    );
  }
}

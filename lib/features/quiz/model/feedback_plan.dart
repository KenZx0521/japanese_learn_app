import 'package:material_ui/material_ui.dart' show immutable;

import '../../../core/backend/frb/dto.dart';
import 'quiz_verdict.dart';

/// 回饋條要顯示什麼。把去重與退回規則集中成純函式，畫面只負責排版。
@immutable
final class FeedbackPlan {
  const FeedbackPlan({
    required this.correctDisplay,
    required this.sentence,
    required this.sentenceInPrompt,
    required this.sentenceZh,
    required this.whyZh,
    required this.explainZh,
    required this.focusIds,
  });

  /// null 表示不用另外列出正解。
  final String? correctDisplay;

  /// 答後要展開的句子；`verdict.reveal` 優先，其次是被隱藏的題幹。
  final SentenceDto? sentence;

  /// 題幹已經畫出 [sentence]，回饋條只補中文。
  final bool sentenceInPrompt;

  /// [sentence] 的中文；和正解或選項重複時為 null。
  final String? sentenceZh;
  final String? whyZh, explainZh;
  final List<String> focusIds;
}

FeedbackPlan feedbackPlanFor(
  QuestionDto question,
  AnswerPayload payload,
  QuizVerdict verdict, {
  required String Function(String mixed) plainOf,
  bool vocabExpanded = false,
}) {
  final prompt = question.prompt;
  final sentence =
      verdict.reveal ?? (prompt.hideTextUntilAnswered ? prompt.text : null);
  final chosen = _chosenOption(question, payload);
  return FeedbackPlan(
    correctDisplay: _correctDisplay(verdict, sentence, chosen, plainOf),
    sentence: sentence,
    sentenceInPrompt: sentence != null && _inPrompt(question, sentence),
    sentenceZh: _sentenceZh(sentence, verdict, chosen, plainOf),
    whyZh: verdict.isCorrect ? null : verdict.whyZh ?? chosen?.whyZh,
    explainZh: verdict.explainZh ?? question.explainZh,
    focusIds: _focusIds(question, vocabExpanded),
  );
}

OptionDto? _chosenOption(QuestionDto question, AnswerPayload payload) {
  final body = question.body;
  if (body is! QuestionBodyDto_Choice || payload is! AnswerPayload_Choice) {
    return null;
  }
  return body.options
      .where((option) => option.id == payload.optionId)
      .firstOrNull;
}

String? _correctDisplay(
  QuizVerdict verdict,
  SentenceDto? sentence,
  OptionDto? chosen,
  String Function(String) plainOf,
) {
  final display = verdict.correctDisplay;
  if (display.isEmpty) return null;
  final plain = plainOf(display);
  // `revealed()` 的 correct_display 就是 reveal 那句，不重複
  if (sentence != null && plain == sentence.display) return null;
  // 答對且正解就是剛選的那項，選項上已有 ○
  if (verdict.isCorrect && plain == chosen?.text) return null;
  return display;
}

bool _inPrompt(QuestionDto question, SentenceDto sentence) {
  final prompt = question.prompt;
  if (prompt.text?.id == sentence.id) return true;
  // 單字題的 reveal 由單字合成（rust-core §8.3），題幹的 plain_text 就是該字
  return prompt.plainText != null &&
      sentence.id == question.reference.contentId;
}

String? _sentenceZh(
  SentenceDto? sentence,
  QuizVerdict verdict,
  OptionDto? chosen,
  String Function(String) plainOf,
) {
  final zh = sentence?.zh;
  if (zh == null || zh.isEmpty) return null;
  if (zh == chosen?.text || zh == plainOf(verdict.correctDisplay)) return null;
  return zh;
}

/// `ka.*` 的 `focus_ids` 是題目本身的字，沒有語法重點可展開。
List<String> _focusIds(QuestionDto question, bool vocabExpanded) => [
  for (final id in question.focusIds)
    if (!id.startsWith('ka.') &&
        !(vocabExpanded && id == question.reference.contentId))
      id,
];

/// 本題要聽才能作答（tts §6.6）：播放失敗時題幹改顯示 `VoiceFailedPanel`。
bool needsPlaybackOf(QuestionDto question) {
  final prompt = question.prompt;
  if (prompt.speech == null) return false;
  return prompt.hideTextUntilAnswered ||
      question.body is QuestionBodyDto_Shadow ||
      (prompt.text == null && prompt.plainText == null);
}

/// 作答前不能先聽的題型：聽了就等於看到答案（§3.3「實字，先讀」）。
bool speechAllowedBeforeAnswer(QuestionType type) => switch (type) {
  QuestionType.kanaRead || QuestionType.kanaWord => false,
  QuestionType.recog ||
  QuestionType.vocabListen ||
  QuestionType.produce ||
  QuestionType.kanaListen ||
  QuestionType.kanaMatch ||
  QuestionType.kanaConfuse ||
  QuestionType.minimalPair ||
  QuestionType.substitution ||
  QuestionType.reorder ||
  QuestionType.particleFill ||
  QuestionType.zhToJaChoice ||
  QuestionType.listenMeaning ||
  QuestionType.situationResponse ||
  QuestionType.conjugate ||
  QuestionType.registerConvert ||
  QuestionType.shadowing ||
  QuestionType.falseFriend => true,
};

/// 答後自動朗讀的內容（§3.3、§3.6）；null 表示只留播放鈕。
SpeechDto? afterAnswerSpeechOf(QuestionDto question, QuizVerdict verdict) =>
    switch (question.questionType) {
      QuestionType.kanaRead || QuestionType.kanaWord => question.prompt.speech,
      QuestionType.substitution =>
        (verdict.reveal ?? question.prompt.text)?.speech,
      QuestionType.conjugate => _readingSpeech(question.body),
      QuestionType.recog ||
      QuestionType.vocabListen ||
      QuestionType.produce ||
      QuestionType.kanaListen ||
      QuestionType.kanaMatch ||
      QuestionType.kanaConfuse ||
      QuestionType.minimalPair ||
      QuestionType.reorder ||
      QuestionType.particleFill ||
      QuestionType.zhToJaChoice ||
      QuestionType.listenMeaning ||
      QuestionType.situationResponse ||
      QuestionType.registerConvert ||
      QuestionType.shadowing ||
      QuestionType.falseFriend => null,
    };

/// `conjugate` 的題目沒有 speech，用動態產生的讀音念。
SpeechDto? _readingSpeech(QuestionBodyDto body) => switch (body) {
  QuestionBodyDto_Typing(:final expectedReading) => SpeechDto(
    text: expectedReading,
    kana: expectedReading,
  ),
  QuestionBodyDto_Choice() ||
  QuestionBodyDto_Reorder() ||
  QuestionBodyDto_Match() ||
  QuestionBodyDto_SelfGrade() ||
  QuestionBodyDto_Shadow() => null,
};

/// 答後並排比較的兩段語音（§3.3 `MinimalPair`）。
@immutable
final class CompareSide {
  const CompareSide({required this.label, required this.speech});
  final String label;
  final SpeechDto speech;
}

List<CompareSide> compareSidesOf(QuestionDto question) {
  final body = question.body;
  if (body is! QuestionBodyDto_Choice) return const [];
  return switch (question.questionType) {
    QuestionType.minimalPair => [
      for (final option in body.options)
        if (option.speech case final speech?)
          CompareSide(label: option.text, speech: speech),
    ],
    _ => const [],
  };
}

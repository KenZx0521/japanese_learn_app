import 'dart:typed_data';

import 'package:japanese_learn_app/core/backend/frb/dto.dart';

import '../../support/fixtures.dart';

QuestionRefDto refFixture(
  QuestionType type, {
  String contentId = 'vo.neko',
  String? drillId,
  String? cardId,
  int? variant,
}) => QuestionRefDto(
  questionType: type,
  contentId: contentId,
  drillId: drillId,
  cardId: cardId,
  variant: variant,
);

PromptDto promptFixture({
  String instruction = '選出正確的答案',
  SentenceDto? text,
  String? plainText,
  SpeechDto? speech,
  bool autoplay = false,
  bool hide = false,
}) => PromptDto(
  instructionZh: instruction,
  text: text,
  plainText: plainText,
  speech: speech,
  autoplay: autoplay,
  hideTextUntilAnswered: hide,
);

QuestionDto questionFixture(
  QuestionType type,
  QuestionBodyDto body, {
  PromptDto? prompt,
  QuestionRefDto? reference,
  String? explainZh,
  List<String> focusIds = const [],
}) => QuestionDto(
  questionType: type,
  reference: reference ?? refFixture(type),
  prompt: prompt ?? promptFixture(),
  body: body,
  explainZh: explainZh,
  focusIds: focusIds,
);

OptionDto optionFixture(
  String id,
  String text, {
  SentenceDto? sentence,
  SpeechDto? speech,
  String? whyZh,
}) => OptionDto(
  id: id,
  text: text,
  sentence: sentence,
  speech: speech,
  whyZh: whyZh,
);

QuestionBodyDto choiceBodyFixture({
  List<OptionDto>? options,
  String correct = 'a',
  int? blank,
}) => QuestionBodyDto.choice(
  options: options ?? [optionFixture('a', '貓'), optionFixture('b', '狗')],
  correctOptionId: correct,
  blankWordIndex: blank,
);

QuestionBodyDto reorderBodyFixture() => QuestionBodyDto.reorder(
  chunks: const [
    ChunkDto(index: 2, text: '学生'),
    ChunkDto(index: 0, text: '私'),
    ChunkDto(index: 1, text: 'は'),
  ],
  acceptOrders: [
    Uint32List.fromList([0, 1, 2]),
  ],
);

QuestionBodyDto typingBodyFixture({String expected = 'たべて'}) =>
    QuestionBodyDto.typing(expectedReading: expected, placeholderZh: '打羅馬字');

QuestionBodyDto matchBodyFixture() => const QuestionBodyDto.match(
  pairs: [
    MatchPairDto(leftId: 'ka.a', left: 'あ', rightId: 'ka.a', right: 'a'),
    MatchPairDto(leftId: 'ka.i', left: 'い', rightId: 'ka.i', right: 'i'),
    MatchPairDto(leftId: 'ka.u', left: 'う', rightId: 'ka.u', right: 'u'),
  ],
);

QuestionDto choiceQuestion({
  QuestionType type = QuestionType.recog,
  PromptDto? prompt,
  QuestionBodyDto? body,
  QuestionRefDto? reference,
  String? explainZh,
  List<String> focusIds = const [],
}) => questionFixture(
  type,
  body ?? choiceBodyFixture(),
  prompt: prompt,
  reference: reference,
  explainZh: explainZh,
  focusIds: focusIds,
);

QuestionDto reorderQuestion({PromptDto? prompt}) => questionFixture(
  QuestionType.reorder,
  reorderBodyFixture(),
  prompt: prompt ?? promptFixture(plainText: '我是學生。'),
  reference: refFixture(
    QuestionType.reorder,
    contentId: 'gr.wa',
    drillId: 'dr.1',
  ),
);

QuestionDto typingQuestion() => questionFixture(
  QuestionType.conjugate,
  typingBodyFixture(),
  prompt: promptFixture(plainText: '{ja:食べる|たべる} → {ja:て}形'),
  reference: refFixture(
    QuestionType.conjugate,
    contentId: 'gr.te',
    drillId: 'dr.2',
    variant: 3,
  ),
);

QuestionDto matchQuestion() => questionFixture(
  QuestionType.kanaMatch,
  matchBodyFixture(),
  prompt: promptFixture(instruction: '把假名和讀音配成一對'),
  reference: refFixture(QuestionType.kanaMatch, contentId: 'ka.a'),
);

QuestionDto selfGradeQuestion({
  QuestionType type = QuestionType.produce,
  PromptDto? prompt,
  String contentId = 'vo.neko',
}) => questionFixture(
  type,
  QuestionBodyDto.selfGrade(reveal: sentenceFixture(id: contentId)),
  prompt: prompt ?? promptFixture(plainText: '貓'),
  reference: refFixture(type, contentId: contentId, cardId: '$contentId:p'),
);

QuestionDto shadowQuestion() => questionFixture(
  QuestionType.shadowing,
  QuestionBodyDto.shadow(reveal: sentenceFixture()),
  prompt: promptFixture(
    instruction: '跟著念一次',
    text: sentenceFixture(),
    speech: sentenceFixture().speech,
    autoplay: true,
  ),
  reference: refFixture(QuestionType.shadowing, contentId: 'se.l01.001'),
);

const drillOk = DrillResultDto(isCorrect: true, correctDisplay: '貓');

DrillResultDto drillWrong({
  String correctDisplay = '貓',
  String? whyZh,
  String? explainZh,
  SentenceDto? reveal,
}) => DrillResultDto(
  isCorrect: false,
  correctDisplay: correctDisplay,
  whyZh: whyZh,
  explainZh: explainZh,
  reveal: reveal,
);

AnswerResultDto reviewOk() => const AnswerResultDto(
  isCorrect: true,
  rating: Rating.good,
  nextDueInMinutes: 600,
  correctDisplay: '貓',
  unlockedCards: 0,
);

const peekGrammar = PeekDto(
  refId: 'gr.wa',
  title: '主題助詞 {ja:は}',
  summaryZh: '{ja:は} 標示話題',
);

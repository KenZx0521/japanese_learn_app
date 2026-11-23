import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../quiz/quiz_fixtures.dart';

/// 全部題型的提示都看過，避免提示列干擾作答流程。
SettingsDto seenHints() => applyPatch(
  settingsFixture(),
  settingsPatch(seenQuestionHints: QuestionType.values),
);

KanaRowDto rowOf(List<KanaCellDto?> cells) => KanaRowDto(cells: cells);

const firstRow = [
  ('ka.hira.a', 'あ', 'a'),
  ('ka.hira.i', 'い', 'i'),
  ('ka.hira.u', 'う', 'u'),
];

List<KanaGroupDto> hiraganaChart({
  KanaStatus status = KanaStatus.notStarted,
  bool listenDisabled = false,
}) => [
  KanaGroupDto(
    titleZh: '清音',
    columns: 3,
    rows: [
      rowOf([
        for (final (id, ch, romaji) in firstRow)
          kanaCellFixture(
            id: id,
            ch: ch,
            romaji: romaji,
            status: status,
            listenDisabled: listenDisabled,
          ),
      ]),
      rowOf([
        kanaCellFixture(
          id: 'ka.hira.ya',
          ch: 'や',
          romaji: 'ya',
          status: status,
        ),
        null,
        kanaCellFixture(
          id: 'ka.hira.yu',
          ch: 'ゆ',
          romaji: 'yu',
          status: status,
        ),
      ]),
    ],
  ),
  KanaGroupDto(
    titleZh: '拗音',
    columns: 3,
    rows: [
      rowOf([
        kanaCellFixture(
          id: 'ka.hira.kya',
          ch: 'きゃ',
          romaji: 'kya',
          status: status,
        ),
        null,
        null,
      ]),
    ],
  ),
];

List<KanaGroupDto> katakanaChart() => [
  KanaGroupDto(
    titleZh: '清音',
    columns: 3,
    rows: [
      rowOf([
        kanaCellFixture(id: 'ka.kata.a', ch: 'ア', romaji: 'a'),
        null,
        null,
      ]),
    ],
  ),
];

void stubCharts(FakeBackend backend, {List<KanaGroupDto>? hira}) =>
    backend.kana.chartStub.answers(
      (args) => args.single == KanaScript.hiragana
          ? hira ?? hiraganaChart()
          : katakanaChart(),
    );

KanaDetailDto detailOf(
  KanaCellDto cell, {
  String lessonId = 'le.k01',
  String? origin = '安',
  String hint = '{ja:あ}：嘴巴自然張開',
  List<ConfusableDto> confusables = const [],
  String? ruleId,
}) => KanaDetailDto(
  cell: cell,
  lessonId: lessonId,
  originKanji: origin,
  hintZh: hint,
  exampleWords: [
    KanaExampleDto(
      surface: '${cell.ch}い',
      zh: '例字中文',
      speech: SpeechDto(text: '${cell.ch}い', kana: '${cell.ch}い'),
    ),
  ],
  confusables: confusables,
  ruleId: ruleId,
);

void stubDetails(FakeBackend backend, List<KanaDetailDto> details) {
  final byId = {for (final d in details) d.cell.id: d};
  backend.kana.detailStub.answers((args) {
    final id = args.single! as String;
    return byId[id] ?? (throw StateError('沒有 $id 的假資料'));
  });
}

LessonDetailDto lessonOf(
  List<KanaCellDto> kana, {
  String id = 'le.k01',
  List<RuleCardDto> rules = const [],
}) => LessonDetailDto(
  summary: LessonSummaryDto(
    id: id,
    stageId: 'st.s0',
    titleZh: '{ja:あ}行',
    canDoZh: '讀出母音',
    status: LessonStatus.current,
  ),
  kana: kana,
  rules: rules,
  words: const [],
  grammar: const [],
  integrationDaysDone: 0,
  integrationDaysNeeded: 0,
);

QuestionDto kanaRead(
  String id,
  String ch, {
  required String correct,
  List<String> others = const ['x', 'y'],
}) => questionFixture(
  QuestionType.kanaRead,
  QuestionBodyDto.choice(
    options: [
      OptionDto(id: id, text: correct),
      for (final other in others) OptionDto(id: 'ka.other.$other', text: other),
    ],
    correctOptionId: id,
  ),
  prompt: promptFixture(instruction: '選出這個字的讀音', plainText: '{ja:$ch}'),
  reference: refFixture(QuestionType.kanaRead, contentId: id),
  focusIds: [id],
);

QuestionDto kanaConfuse(String id, String romaji, {required String explain}) =>
    questionFixture(
      QuestionType.kanaConfuse,
      QuestionBodyDto.choice(
        options: [
          OptionDto(id: id, text: 'ぬ'),
          const OptionDto(id: 'ka.hira.me', text: 'め'),
        ],
        correctOptionId: id,
      ),
      prompt: promptFixture(instruction: '看讀音，選出正確的字', plainText: romaji),
      reference: refFixture(QuestionType.kanaConfuse, contentId: id),
      explainZh: explain,
      focusIds: [id],
    );

const kanaRight = KanaSubmitResultDto(isCorrect: true, correctDisplay: 'a');

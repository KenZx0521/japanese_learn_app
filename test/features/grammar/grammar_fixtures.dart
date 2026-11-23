import 'package:japanese_learn_app/core/backend/frb/dto.dart';

import '../../support/fixtures.dart';

const stagesFixture = [
  StageDto(id: 'st.s0', titleZh: '假名與發音'),
  StageDto(id: 'st.s1', titleZh: '敬體基礎'),
  StageDto(id: 'st.s3', titleZh: '參考 N4 口語核心'),
];

LessonSummaryDto lessonFixture(
  String id, {
  String stageId = 'st.s1',
  String titleZh = '初次見面',
  String canDoZh = '能用 {ja:です} 介紹自己',
  LessonStatus status = LessonStatus.notStarted,
}) => LessonSummaryDto(
  id: id,
  stageId: stageId,
  titleZh: titleZh,
  canDoZh: canDoZh,
  status: status,
);

CourseOverviewDto overviewFixture({
  List<LessonSummaryDto> lessons = const [],
  String? currentLessonId,
  bool notesAvailable = false,
}) => CourseOverviewDto(
  contentStage: ContentStage.p0A,
  stages: stagesFixture,
  lessons: lessons,
  currentLessonId: currentLessonId,
  notesAvailable: notesAvailable,
);

GrammarSummaryDto grammarSummaryFixture({
  String id = 'gr.wa',
  String titleZh = '{ja:は}：提出主題',
  String pattern = 'N {ja:は} …',
  String meaningZh = '把 N 提出來當話題',
  String lessonId = 'le.l01',
  String stageId = 'st.s1',
  GrammarStatus status = GrammarStatus.notStarted,
}) => GrammarSummaryDto(
  id: id,
  titleZh: titleZh,
  pattern: pattern,
  meaningZh: meaningZh,
  lessonId: lessonId,
  stageId: stageId,
  jlpt: JlptLevel.n5,
  status: status,
);

const termFixture = NoteDto.term(
  id: 'no.term.te_form',
  term: '{ja:て}形',
  akaZh: '連接形',
  bodyZh: '動詞接 {ja:て} 的形態',
  grammarIds: ['gr.wa'],
);

List<SentenceDto> examplesFixture(int count) => [
  for (var i = 0; i < count; i++) sentenceFixture(id: 'se.l01.00$i'),
];

GrammarDetailDto grammarDetailOf({
  GrammarSummaryDto? summary,
  String? trapZh = '{ja:は} 當助詞時念 wa',
  List<FormationRowDto> formation = const [
    FormationRowDto(from: 'N', to: 'N {ja:は}'),
  ],
  int exampleCount = 3,
  List<GrammarRefDto> contrast = const [],
  List<NoteDto> terms = const [],
}) => GrammarDetailDto(
  summary: summary ?? grammarSummaryFixture(),
  explainZh: '先說出話題，後面接 {ja:は}。',
  compareZh: '中文靠語序就知道主題。',
  trapZh: trapZh,
  formation: formation,
  register: 'neutral',
  requires: const [],
  examples: examplesFixture(exampleCount),
  contrast: contrast,
  terms: terms,
);

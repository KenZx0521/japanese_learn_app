import 'package:japanese_learn_app/core/backend/frb/dto.dart';

import '../grammar/grammar_fixtures.dart';

/// 依學習順序：假名課與主線課交錯，目前在 `le.kk01`。
List<LessonSummaryDto> mixedLessons({
  LessonStatus kk01 = LessonStatus.current,
}) => [
  lessonFixture(
    'le.k01',
    stageId: 'st.s0',
    titleZh: '{ja:あ}行',
    canDoZh: '能讀出 {ja:あいうえお}',
    status: LessonStatus.done,
  ),
  lessonFixture(
    'le.k02',
    stageId: 'st.s0',
    titleZh: '{ja:か}行',
    canDoZh: '能讀出 {ja:かきくけこ}',
    status: LessonStatus.skipped,
  ),
  lessonFixture(
    'le.l01',
    titleZh: '初次見面',
    canDoZh: '能說出姓名與身分',
    status: LessonStatus.done,
  ),
  lessonFixture(
    'le.kk01',
    stageId: 'st.s0',
    titleZh: '{ja:ア}行、{ja:カ}行',
    canDoZh: '能讀出 {ja:アイウエオ}',
    status: kk01,
  ),
  lessonFixture('le.l02', titleZh: '這是什麼', canDoZh: '能問這是什麼'),
  lessonFixture(
    'le.kk02',
    stageId: 'st.s0',
    titleZh: '{ja:サ}行、{ja:タ}行',
    canDoZh: '能讀出 {ja:サ} 行',
  ),
  lessonFixture('le.l03', titleZh: '多少錢', canDoZh: '能問價錢'),
];

CourseOverviewDto mixedOverview({
  String? currentLessonId = 'le.kk01',
  bool notesAvailable = false,
  List<LessonSummaryDto>? lessons,
}) => overviewFixture(
  lessons: lessons ?? mixedLessons(),
  currentLessonId: currentLessonId,
  notesAvailable: notesAvailable,
);

LessonSummaryDto kanaSummary({
  String id = 'le.k01',
  LessonStatus status = LessonStatus.current,
}) => lessonFixture(
  id,
  stageId: 'st.s0',
  titleZh: '{ja:あ}行',
  canDoZh: '能讀出 {ja:あいうえお}',
  status: status,
);

LessonSummaryDto mainSummary({
  String id = 'le.l03',
  LessonStatus status = LessonStatus.current,
}) => lessonFixture(id, titleZh: '多少錢', canDoZh: '能問價錢', status: status);

RuleCardDto ruleOf({
  String id = 'ka.rule.sokuon',
  String titleZh = '促音 {ja:っ}：停一拍',
  List<String> drillIds = const [],
}) => RuleCardDto(
  id: id,
  lessonId: 'le.k16',
  titleZh: titleZh,
  bodyZh: '停一拍',
  examples: const [],
  soundGroups: const [],
  drillIds: drillIds,
);

DialogueSummaryDto dialogueOf({bool locked = false}) => DialogueSummaryDto(
  id: 'di.konbini',
  kind: DialogueKindDto.lesson,
  lessonId: 'le.l03',
  sceneZh: '在便利商店結帳',
  goalZh: '問價錢、說請給我這個',
  locked: locked,
);

LessonDetailDto lessonDetail({
  LessonSummaryDto? summary,
  List<KanaCellDto> kana = const [],
  List<RuleCardDto> rules = const [],
  List<VocabSummaryDto> words = const [],
  List<GrammarSummaryDto> grammar = const [],
  DialogueSummaryDto? dialogue,
}) => LessonDetailDto(
  summary: summary ?? mainSummary(),
  kana: kana,
  rules: rules,
  words: words,
  grammar: grammar,
  dialogue: dialogue,
  integrationDaysDone: 0,
  integrationDaysNeeded: 0,
);

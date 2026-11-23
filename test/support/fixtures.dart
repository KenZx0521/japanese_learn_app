import 'dart:typed_data';

import 'package:japanese_learn_app/core/backend/frb/dto.dart';

SettingsDto settingsFixture({
  bool silentMode = false,
  bool autoplay = true,
  double ttsRate = 1.0,
  AppThemeMode themeMode = AppThemeMode.system,
  String? voiceId,
}) => SettingsDto(
  dayRolloverHour: 4,
  desiredRetention: 0.9,
  ttsRate: ttsRate,
  autoplay: autoplay,
  voiceId: voiceId,
  themeMode: themeMode,
  silentMode: silentMode,
  kanaTimeLimit: true,
  showRatingIntervals: false,
  romajiOffConfirmed: false,
  seenQuestionHints: const [],
);

SettingsDto applyPatch(SettingsDto s, SettingsPatchDto p) => SettingsDto(
  dayRolloverHour: p.dayRolloverHour ?? s.dayRolloverHour,
  desiredRetention: p.desiredRetention ?? s.desiredRetention,
  romajiOverride: p.clearRomajiOverride
      ? null
      : p.romajiOverride ?? s.romajiOverride,
  furiganaOverride: p.clearFuriganaOverride
      ? null
      : p.furiganaOverride ?? s.furiganaOverride,
  ttsRate: p.ttsRate ?? s.ttsRate,
  autoplay: p.autoplay ?? s.autoplay,
  voiceId: p.clearVoiceId ? null : p.voiceId ?? s.voiceId,
  themeMode: p.themeMode ?? s.themeMode,
  silentMode: p.silentMode ?? s.silentMode,
  kanaTimeLimit: p.kanaTimeLimit ?? s.kanaTimeLimit,
  showRatingIntervals: p.showRatingIntervals ?? s.showRatingIntervals,
  romajiOffConfirmed: p.romajiOffConfirmed ?? s.romajiOffConfirmed,
  seenQuestionHints: p.seenQuestionHints ?? s.seenQuestionHints,
);

DisplayPolicyDto displayPolicyFixture({
  RomajiMode romaji = RomajiMode.shown,
  FuriganaMode furigana = FuriganaMode.all,
  bool wordSpacing = true,
}) => DisplayPolicyDto(
  romaji: romaji,
  furigana: furigana,
  wordSpacing: wordSpacing,
);

BudgetDto budgetFixture({int reviewCap = 100}) => BudgetDto(
  newMinutes: 6,
  reviewMinutes: 14,
  drillMinutes: 0,
  listenMinutes: 0,
  reviewCap: reviewCap,
  capacity: reviewCap,
  newWordsLimit: 5,
  kanaCharsLimit: 5,
);

TodayViewDto todayFixture({
  List<TaskDto> tasks = const [],
  String logicalDate = '2026-03-02',
  bool isStudyDay = true,
  int learningTail = 0,
  bool canLearnMore = false,
  double estimatedMinutes = 17,
  int reviewCap = 100,
}) => TodayViewDto(
  logicalDate: logicalDate,
  isStudyDay: isStudyDay,
  tasks: tasks,
  budget: budgetFixture(reviewCap: reviewCap),
  streak: 3,
  minimalNew: false,
  learningTail: learningTail,
  estimatedMinutes: estimatedMinutes,
  canLearnMore: canLearnMore,
);

PlanInputDto planInputFixture() => PlanInputDto(
  dailyMinutes: 20,
  weekdays: Uint32List.fromList(const [1, 2, 3, 4, 5, 6, 7]),
  startLevel: StartLevel.zero,
  knownKanaLessons: const [],
);

MilestoneDto milestoneFixture({
  String id = 'ms.hira',
  String titleZh = '平假名',
  bool passed = false,
  bool dismissed = false,
}) => MilestoneDto(
  id: id,
  titleZh: titleZh,
  lessonId: 'le.k10',
  passRatio: 0.8,
  questions: 20,
  delayDays: 0,
  passed: passed,
  dismissed: dismissed,
);

PlanViewDto planViewFixture({
  List<MilestoneDto> milestones = const [],
  String? currentLessonId = 'le.k01',
}) => PlanViewDto(
  input: planInputFixture(),
  currentLessonId: currentLessonId,
  milestones: milestones,
  status: PlanStatus.onTrack,
);

StatsDto statsFixture() => const StatsDto(
  streakCurrent: 3,
  streakBest: 5,
  totalReviews: 42,
  cardsNew: 1,
  cardsLearning: 2,
  cardsReview: 3,
  cardsMastered: 4,
  kanaMastered: 10,
  vocabIntroduced: 5,
  grammarIntroduced: 2,
);

CourseOverviewDto courseOverviewFixture({
  ContentStage contentStage = ContentStage.p0A,
}) => CourseOverviewDto(
  contentStage: contentStage,
  stages: const [],
  lessons: const [],
  currentLessonId: 'le.k01',
  notesAvailable: false,
);

WordDto wordFixture({
  required String surface,
  required String kana,
  required String romaji,
  List<RubyPartDto>? ruby,
  String? refId,
  String? glossZh,
  bool isPunct = false,
  bool isKnown = false,
}) => WordDto(
  surface: surface,
  kana: kana,
  romaji: romaji,
  speechKana: kana,
  ruby: ruby ?? [RubyPartDto(base: surface)],
  refs: refId == null ? const [] : [refId],
  refId: refId,
  glossZh: glossZh,
  isPunct: isPunct,
  isKnown: isKnown,
);

/// 私は学生です。
List<WordDto> sentenceWordsFixture() => [
  wordFixture(
    surface: '私',
    kana: 'わたし',
    romaji: 'watashi',
    ruby: const [RubyPartDto(base: '私', ruby: 'わたし')],
    refId: 'vo.watashi',
    isKnown: true,
  ),
  wordFixture(surface: 'は', kana: 'わ', romaji: 'wa'),
  wordFixture(
    surface: '学生',
    kana: 'がくせい',
    romaji: 'gakusei',
    ruby: const [RubyPartDto(base: '学生', ruby: 'がくせい')],
    refId: 'vo.gakusei',
  ),
  wordFixture(surface: 'です', kana: 'です', romaji: 'desu'),
  wordFixture(surface: '。', kana: '。', romaji: '', isPunct: true),
];

SentenceDto sentenceFixture({String id = 'se.l01.001'}) => SentenceDto(
  id: id,
  display: '私は学生です。',
  romaji: 'watashi wa gakusei desu.',
  zh: '我是學生。',
  style: 'teineigo',
  words: sentenceWordsFixture(),
  speech: const SpeechDto(text: '私は学生です。', kana: 'わたしはがくせいです。'),
);

KanaCellDto kanaCellFixture({
  String id = 'ka.hira.a',
  String ch = 'あ',
  String romaji = 'a',
  KanaStatus status = KanaStatus.notStarted,
  bool listenDisabled = false,
}) => KanaCellDto(
  id: id,
  ch: ch,
  romaji: romaji,
  kind: KanaKindDto.basic,
  status: status,
  fastBadge: false,
  speech: SpeechDto(text: ch, kana: ch),
  listenDisabled: listenDisabled,
);

KanaDetailDto kanaDetailFixture({bool listenDisabled = false}) => KanaDetailDto(
  cell: kanaCellFixture(listenDisabled: listenDisabled),
  lessonId: 'le.k01',
  originKanji: '安',
  hintZh: '{ja:あ}：嘴巴自然張開',
  exampleWords: const [
    KanaExampleDto(
      surface: 'あい',
      zh: '愛',
      speech: SpeechDto(text: 'あい', kana: 'あい'),
    ),
  ],
  confusables: const [],
);

VocabSummaryDto vocabSummaryFixture({
  String id = 'vo.neko',
  String surface = '猫',
  String kana = 'ねこ',
  String romaji = 'neko',
}) => VocabSummaryDto(
  id: id,
  surface: surface,
  kana: kana,
  romaji: romaji,
  zh: const ['貓'],
  pos: 'n',
  lessonId: 'le.l01',
  srsState: SrsStateLabel.notStarted,
  speech: SpeechDto(text: surface, kana: kana),
  known: false,
  starred: false,
);

VocabDetailDto vocabDetailFixture({
  List<NoteDto> notes = const [],
  String? trapZh,
  JlptLevel jlpt = JlptLevel.n5,
}) => VocabDetailDto(
  summary: vocabSummaryFixture(),
  jlpt: jlpt,
  useLevel: UseLevelDto.safe,
  sameFormZh: true,
  hookZh: '聯想：{ja:ねこ}',
  trapZh: trapZh,
  readingFamily: const [],
  examples: [sentenceFixture()],
  notes: notes,
  conjugations: const [],
);

GrammarDetailDto grammarDetailFixture() => GrammarDetailDto(
  summary: const GrammarSummaryDto(
    id: 'gr.wa',
    titleZh: '主題助詞 {ja:は}',
    pattern: 'N {ja:は} N {ja:です}',
    meaningZh: 'N 是 N',
    lessonId: 'le.l01',
    stageId: 'st.s1',
    jlpt: JlptLevel.n5,
    status: GrammarStatus.notStarted,
  ),
  explainZh: '{ja:は} 標示話題。',
  compareZh: '中文的「是」不需要主題助詞。',
  trapZh: '{ja:は} 當助詞時念 wa。',
  formation: const [],
  register: 'polite',
  requires: const [],
  examples: [sentenceFixture()],
  contrast: const [],
  terms: const [],
);

RuleCardDto ruleCardFixture({List<String> beats = const ['か', 'っ', 'こ']}) =>
    RuleCardDto(
      id: 'ka.rule.sokuon',
      lessonId: 'le.k16',
      titleZh: '促音 {ja:っ}',
      bodyZh: '{ja:っ} 不發聲，停一拍。',
      examples: [
        RuleExampleDto(
          text: 'かっこ',
          zh: '括號',
          beats: beats,
          speech: const SpeechDto(text: 'かっこ', kana: 'かっこ'),
        ),
      ],
      soundGroups: const [],
      drillIds: const [],
    );

ConfusableDto confusableFixture() => ConfusableDto(
  id: 'ka.cf.nu_me',
  kind: ConfusableKindDto.shape,
  members: [
    kanaCellFixture(id: 'ka.hira.nu', ch: 'ぬ', romaji: 'nu'),
    kanaCellFixture(id: 'ka.hira.me', ch: 'め', romaji: 'me'),
  ],
  literals: const [],
  diffZh: '{ja:ぬ} 收筆有圈。',
);

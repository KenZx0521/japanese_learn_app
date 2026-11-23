import 'package:japanese_learn_app/core/backend/frb/dto.dart';

import '../../support/fixtures.dart';

VocabSummaryDto wordAt(
  int index, {
  String lessonId = 'le.l01',
  SrsStateLabel srs = SrsStateLabel.notStarted,
  bool known = false,
  bool starred = false,
}) => VocabSummaryDto(
  id: 'vo.w$index',
  surface: '語$index',
  kana: 'かな$index',
  romaji: 'kana$index',
  zh: ['意思$index'],
  pos: 'n',
  lessonId: lessonId,
  srsState: srs,
  speech: SpeechDto(text: '語$index', kana: 'かな$index'),
  known: known,
  starred: starred,
);

/// 依 `[filter, offset, limit]` 從 [all] 切一頁。
VocabPageDto pageOf(List<VocabSummaryDto> all, List<Object?> args) {
  final offset = args[1]! as int;
  final limit = args[2]! as int;
  return VocabPageDto(
    items: all.skip(offset).take(limit).toList(),
    total: all.length,
  );
}

VocabFilterDto filterOf(List<Object?> args) => args.first! as VocabFilterDto;

VocabDetailDto detailFixture({
  VocabSummaryDto? summary,
  int? accent,
  JlptLevel jlpt = JlptLevel.n5,
  UseLevelDto useLevel = UseLevelDto.safe,
  TransitivityDto? trans,
  String? hookZh = '聯想：{ja:ねこ}',
  String? trapZh,
  VocabRefDto? pair,
  List<VocabRefDto> readingFamily = const [],
  List<SentenceDto>? examples,
  List<NoteDto> notes = const [],
  List<ConjugationDto> conjugations = const [],
}) => VocabDetailDto(
  summary: summary ?? vocabSummaryFixture(),
  accent: accent,
  jlpt: jlpt,
  useLevel: useLevel,
  trans: trans,
  sameFormZh: false,
  hookZh: hookZh,
  trapZh: trapZh,
  pair: pair,
  readingFamily: readingFamily,
  examples: examples ?? [sentenceFixture()],
  notes: notes,
  conjugations: conjugations,
);

const falseFriendNote = NoteDto.falseFriend(
  id: 'no.ff.tegami',
  surface: '手紙',
  jaZh: '信件',
  misreadZh: '衛生紙',
  vocabId: 'vo.tegami',
);

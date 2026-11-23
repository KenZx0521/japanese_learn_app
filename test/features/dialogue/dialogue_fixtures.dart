import 'package:japanese_learn_app/core/backend/frb/dto.dart';

import '../../support/fixtures.dart';

SentenceDto turnSentence(
  String id, {
  required String display,
  required String kana,
  required String zh,
  required List<String> words,
}) => SentenceDto(
  id: id,
  display: display,
  romaji: kana,
  zh: zh,
  style: 'polite',
  words: [
    for (final word in words)
      wordFixture(surface: word, kana: word, romaji: 'ro'),
    wordFixture(surface: '。', kana: '', romaji: '', isPunct: true),
  ],
  speech: SpeechDto(text: display, kana: kana),
);

// RubyLine 逐詞排版，畫面上每個詞是獨立的 Text，測試以詞比對。
const firstWord = 'はじめまして';
const secondWord = 'よろしく';
const thirdWord = '学生';

DialogueDto dialogueFixture({
  String id = 'di.l01',
  String lessonId = 'le.l01',
  List<String> quizDrillIds = const ['dr.l01.001', 'dr.l01.002'],
}) => DialogueDto(
  id: id,
  kind: DialogueKindDto.lesson,
  lessonId: lessonId,
  style: 'polite',
  sceneZh: '語言交換活動上第一次見面',
  goalZh: '用日語打招呼並問對方的身分',
  roles: const [
    DialogueRoleDto(id: 'a', nameZh: '小王', voice: 'a'),
    DialogueRoleDto(id: 'b', nameZh: '鈴木', voice: 'b'),
  ],
  turns: [
    DialogueTurnDto(
      role: 'a',
      sentence: turnSentence(
        '$id#0',
        display: 'はじめまして。',
        kana: 'はじめまして。',
        zh: '初次見面。',
        words: const [firstWord],
      ),
      noteZh: '第一次見面的招呼',
    ),
    DialogueTurnDto(
      role: 'b',
      sentence: turnSentence(
        '$id#1',
        display: 'よろしくお願いします。',
        kana: 'よろしくおねがいします。',
        zh: '請多指教。',
        words: const [secondWord, 'お願い', 'します'],
      ),
    ),
    DialogueTurnDto(
      role: 'a',
      sentence: turnSentence(
        '$id#2',
        display: '学生ですか。',
        kana: 'がくせいですか。',
        zh: '是學生嗎？',
        words: const [thirdWord, 'です', 'か'],
      ),
    ),
  ],
  focusIds: const [],
  quizDrillIds: quizDrillIds,
);

DialogueSummaryDto dialogueSummaryFixture({
  String id = 'di.l01',
  DialogueKindDto kind = DialogueKindDto.lesson,
  String lessonId = 'le.l01',
  String sceneZh = '第一次見面',
  bool locked = false,
}) => DialogueSummaryDto(
  id: id,
  kind: kind,
  lessonId: lessonId,
  sceneZh: sceneZh,
  goalZh: '打招呼',
  locked: locked,
);

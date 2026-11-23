import 'dart:typed_data';

import 'package:japanese_learn_app/core/backend/frb/dto.dart';

TaskDto reviewTask({
  bool done = false,
  int due = 4,
  int learning = 2,
  int newCards = 0,
  double minutes = 2.5,
}) => TaskDto.review(
  key: 'review',
  due: due,
  learning: learning,
  newCards: newCards,
  minutes: minutes,
  done: done,
);

TaskDto newContentTask({
  String key = 'new:le.k01:0',
  String titleZh = 'あ行',
  int kana = 3,
  int words = 0,
  int grammar = 0,
  int rules = 0,
  double minutes = 6,
  bool done = false,
}) => TaskDto.newContent(
  key: key,
  lessonId: 'le.k01',
  titleZh: titleZh,
  words: words,
  grammar: grammar,
  kana: kana,
  rules: rules,
  minutes: minutes,
  done: done,
);

TaskDto integrationTask({
  String? dialogueId = 'di.l01',
  List<int> phases = const [1, 2],
  bool done = false,
}) => TaskDto.integration(
  key: 'integration',
  lessonId: 'le.l01',
  titleZh: '自我介紹',
  dialogueId: dialogueId,
  phases: Uint32List.fromList(phases),
  minutes: 4,
  done: done,
);

TaskDto drillTask({int questions = 5, double minutes = 3, bool done = false}) =>
    TaskDto.drill(
      key: 'drill',
      questions: questions,
      minutes: minutes,
      done: done,
    );

TaskDto listenTask({int sentences = 4, bool done = false}) =>
    TaskDto.listen(key: 'listen', sentences: sentences, minutes: 2, done: done);

TaskDto checkpointTask({bool done = false}) => TaskDto.checkpoint(
  key: 'checkpoint:ms.hira',
  milestoneId: 'ms.hira',
  done: done,
);

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';

import '../../support/fixtures.dart';
import '../quiz/quiz_fixtures.dart';

NewContentSessionDto kanaSession() => NewContentSessionDto(
  taskKey: 'new:le.k01:0',
  lessonId: 'le.k01',
  titleZh: 'あ行',
  steps: [NewContentStepDto.kana(detail: kanaDetailFixture())],
);

SessionNextDto cardNext({String id = 'vo.neko:recog', int reps = 0}) =>
    SessionNextDto.card(
      card: SessionCardDto(
        cardId: id,
        expectedReps: reps,
        facet: 'recog',
        question: choiceQuestion(),
        ratingPreviews: const [],
        remainingEstimate: 1,
      ),
    );

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

DialogueDto flowDialogue({List<String> quiz = const []}) => DialogueDto(
  id: 'di.l01',
  kind: DialogueKindDto.lesson,
  lessonId: 'le.l01',
  style: 'teineigo',
  sceneZh: '在教室',
  goalZh: '打招呼',
  roles: const [
    DialogueRoleDto(id: 'a', nameZh: '小明', voice: 'a'),
    DialogueRoleDto(id: 'b', nameZh: '老師', voice: 'b'),
  ],
  turns: [
    DialogueTurnDto(
      role: 'a',
      sentence: sentenceFixture(id: 'se.1'),
    ),
    DialogueTurnDto(
      role: 'b',
      sentence: sentenceFixture(id: 'se.2'),
    ),
  ],
  focusIds: const [],
  quizDrillIds: quiz,
);

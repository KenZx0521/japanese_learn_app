// 視覺 QA：L3 的假名測驗只留頂部一條進度線。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/new_content/new_content_view.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../quiz/quiz_fixtures.dart';

void main() {
  testWidgets('KanaQuiz 步驟不再疊一條題目進度', (tester) async {
    final backend = FakeBackend();
    backend.today.newContentStub.returns(
      NewContentSessionDto(
        taskKey: 'new:le.k01:0',
        lessonId: 'le.k01',
        titleZh: 'あ行',
        steps: [
          NewContentStepDto.kanaQuiz(
            questions: [
              choiceQuestion(type: QuestionType.kanaRead),
              choiceQuestion(type: QuestionType.kanaRead),
            ],
          ),
        ],
      ),
    );

    await pumpApp(
      tester,
      backend: backend,
      settings: settingsFixture(),
      child: NewContentView(
        taskKey: 'new:le.k01:0',
        lessonId: 'le.k01',
        seed: 7,
        onComplete: () {},
      ),
    );

    expect(
      tester.widget<QuizSessionView>(find.byType(QuizSessionView)).showProgress,
      isFalse,
    );
  });
}

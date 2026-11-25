import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:japanese_learn_app/design/widgets/grammar_teach_card.dart';
import 'package:japanese_learn_app/features/new_content/new_content_view.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../quiz/quiz_fixtures.dart';

GrammarDetailDto _teForm() {
  final data = jsonDecode(
    File('rust/content/grammar/s2.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final point = (data['items'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .singleWhere((item) => item['id'] == 'gr.te_form');
  return GrammarDetailDto(
    summary: GrammarSummaryDto(
      id: point['id'] as String,
      titleZh: point['title_zh'] as String,
      pattern: point['pattern'] as String,
      meaningZh: point['meaning_zh'] as String,
      lessonId: point['lesson'] as String,
      stageId: 'st.s2',
      jlpt: JlptLevel.n5,
      status: GrammarStatus.notStarted,
    ),
    explainZh: point['explain_zh'] as String,
    compareZh: point['compare_zh'] as String,
    trapZh: point['trap_zh'] as String?,
    formation: [
      for (final row
          in (point['formation'] as List<dynamic>).cast<Map<String, dynamic>>())
        FormationRowDto(from: row['from'] as String, to: row['to'] as String),
    ],
    register: point['register'] as String,
    requires: const [],
    examples: const [],
    contrast: const [],
    terms: const [],
  );
}

void main() {
  for (final hasQuiz in [false, true]) {
    testWidgets('首次學て形可讀完完整接續表，再${hasQuiz ? '考一題' : '下一步'}', (tester) async {
      final detail = _teForm();
      final backend = FakeBackend();
      final card = SessionCardDto(
        cardId: 'gr.te_form:use',
        expectedReps: 0,
        facet: 'use',
        question: choiceQuestion(
          type: QuestionType.zhToJaChoice,
          reference: refFixture(
            QuestionType.zhToJaChoice,
            contentId: 'gr.te_form',
          ),
        ),
        ratingPreviews: const [],
        remainingEstimate: 0,
      );
      backend.today.newContentStub.returns(
        NewContentSessionDto(
          taskKey: 'new:le.l15:0',
          lessonId: 'le.l15',
          titleZh: '請做',
          steps: [
            // 開頭沒有 firstCard 會被視為斷點續做而略過；放在規則步驟後
            // 驗證同批次中無測驗的文法卡仍可讀完接續表並前進。
            if (!hasQuiz) NewContentStepDto.rule(card: ruleCardFixture()),
            NewContentStepDto.grammar(
              detail: detail,
              firstCard: hasQuiz ? card : null,
            ),
          ],
        ),
      );
      var completed = 0;
      await pumpApp(
        tester,
        backend: backend,
        width: 320,
        textScale: 1.5,
        child: NewContentView(
          taskKey: 'new:le.l15:0',
          lessonId: 'le.l15',
          seed: 7,
          onComplete: () => completed++,
        ),
      );
      if (!hasQuiz) {
        await tester.tap(find.text('下一步'));
        await tester.pumpAndSettle();
      }

      expect(find.text('接續'), findsOneWidget);
      expect(find.byType(QuizSessionView), findsNothing);
      for (final row in detail.formation) {
        final value = find.byWidgetPredicate(
          (widget) => widget is MixedText && widget.source == row.to,
        );
        expect(value, findsOneWidget);
        await tester.ensureVisible(value);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      // 真實教材最後一列包含首次學習不能遺漏的兩個第三類變化。
      expect(find.textContaining('する→して', findRichText: true), findsOneWidget);
      expect(find.textContaining('来', findRichText: true), findsWidgets);
      final next = find.text(hasQuiz ? '考一題' : '下一步');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(completed, hasQuiz ? 0 : 1);
      if (hasQuiz) {
        expect(find.byType(GrammarTeachCard), findsNothing);
        expect(find.byType(QuizSessionView), findsOneWidget);
      }
    });
  }
}

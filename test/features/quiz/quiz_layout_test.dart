// 視覺 QA 抓到的題目版面與文案回歸。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/tts/tts_engine.dart';
import 'package:japanese_learn_app/design/widgets/choice_tile.dart';
import 'package:japanese_learn_app/design/widgets/question_hint_strip.dart';
import 'package:japanese_learn_app/design/widgets/speak_button.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';
import 'package:japanese_learn_app/features/quiz/view/quiz_feedback.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import 'quiz_fixtures.dart';
import 'quiz_harness.dart';

QuestionDto _kanaRead() => questionFixture(
  QuestionType.kanaRead,
  choiceBodyFixture(
    options: [optionFixture('a', 'ka'), optionFixture('b', 'ki')],
  ),
  prompt: promptFixture(
    instruction: '選出這個字的讀音',
    plainText: '{ja:か}',
    speech: const SpeechDto(text: 'か', kana: 'か'),
  ),
  reference: refFixture(QuestionType.kanaRead, contentId: 'ka.ka'),
);

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.drills.gradeStub.returns(drillOk);
  });

  testWidgets('大字題幹答完多出播放鈕時，選項不跳動', (tester) async {
    await pumpQuiz(tester, [_kanaRead()], backend: backend);

    final tile = find.byType(ChoiceTile).first;
    final before = tester.getTopLeft(tile).dy;
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byType(SpeakButton), findsOneWidget);
    expect(tester.getTopLeft(tile).dy, before);
  });

  group('干擾項不足退回 SelfGrade 的 Recog／VocabListen（§3.4）', () {
    QuestionDto fallback(QuestionType type) => selfGradeQuestion(
      type: type,
      prompt: promptFixture(instruction: '選出這個字的意思', text: sentenceFixture()),
    );

    SettingsDto fresh() => settingsFixture();

    testWidgets('操作提示與題幹不寫「選出」，要翻面', (tester) async {
      await pumpQuiz(
        tester,
        [fallback(QuestionType.recog)],
        backend: backend,
        settings: fresh(),
      );

      expect(find.byType(QuestionHintStrip), findsOneWidget);
      expect(find.textContaining('選出'), findsNothing);
      expect(find.textContaining('翻面'), findsWidgets);
    });

    testWidgets('聽力型的 SelfGrade 也一樣', (tester) async {
      await pumpQuiz(
        tester,
        [fallback(QuestionType.vocabListen)],
        backend: backend,
        settings: fresh(),
      );

      expect(find.textContaining('選出'), findsNothing);
      expect(find.textContaining('翻面'), findsWidgets);
    });

    testWidgets('一般 Produce 的提示不受影響', (tester) async {
      await pumpQuiz(
        tester,
        [selfGradeQuestion()],
        backend: backend,
        settings: fresh(),
      );

      expect(find.text('看中文，先在心裡說出日文，再翻面自評。'), findsOneWidget);
    });
  });

  testWidgets('SelfGrade 翻面的單字展開不重複單字本身', (tester) async {
    backend.vocab.detailStub.returns(vocabDetailFixture());

    await pumpQuiz(
      tester,
      [selfGradeQuestion(contentId: 'vo.neko')],
      backend: backend,
      expandVocab: true,
      grader: const ReviewGrader(expectedReps: 1),
    );
    await tester.tap(find.text('翻面看答案'));
    await tester.pumpAndSettle();

    expect(find.text('ねこ'), findsNothing, reason: '展開區不再列一次假名');
    expect(find.text('記法'), findsOneWidget, reason: '記法等補充仍要顯示');
  });

  testWidgets('回饋細節超出時顯示「還有內容」提示，捲到底就消失', (tester) async {
    backend.drills.gradeStub.returns(
      drillWrong(explainZh: List.filled(40, '很長的說明文字。').join()),
    );
    await pumpQuiz(tester, [choiceQuestion()], backend: backend, height: 520);

    await tester.tap(find.byType(ChoiceTile).at(1));
    await tester.pumpAndSettle();

    const cue = ValueKey('feedback-more-below');
    expect(find.byKey(cue), findsOneWidget);

    final scrollable = find.descendant(
      of: find.byType(QuizFeedback),
      matching: find.byType(Scrollable),
    );
    final state = tester.state<ScrollableState>(scrollable.first);
    state.position.jumpTo(state.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(find.byKey(cue), findsNothing);
  });

  group('窄螢幕的回饋條壓縮題目區時', () {
    Finder questionScroll() => find.descendant(
      of: find.byType(QuizSessionView),
      matching: find.byType(Scrollable),
    );

    testWidgets('自動捲到選項，下一題回到頂端', (tester) async {
      backend.drills.gradeStub.returns(
        drillWrong(explainZh: List.filled(20, '說明。').join()),
      );
      final longPrompt = promptFixture(
        plainText: List.filled(12, '很長的中文提示。').join(),
      );
      await pumpQuiz(
        tester,
        [
          choiceQuestion(prompt: longPrompt),
          choiceQuestion(prompt: longPrompt),
        ],
        backend: backend,
        height: 520,
      );

      await tester.tap(find.byType(ChoiceTile).first);
      await tester.pumpAndSettle();
      final state = tester.state<ScrollableState>(questionScroll().first);
      expect(state.position.pixels, greaterThan(0));

      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      final next = tester.state<ScrollableState>(questionScroll().first);
      expect(next.position.pixels, 0);
    });
  });

  test('SpeechDto 構造（fixture 防呆）', () {
    expect(
      SpeechRequest.fromDto('x', const SpeechDto(text: 'か', kana: 'か')).text,
      'か',
    );
  });
}

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/tts/tts_controller.dart';
import 'package:japanese_learn_app/design/widgets/answer_line.dart';
import 'package:japanese_learn_app/design/widgets/rating_bar.dart';
import 'package:japanese_learn_app/design/widgets/word_tile.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'quiz_fixtures.dart';
import 'quiz_harness.dart';

Finder _inAnswerLine(String text) =>
    find.descendant(of: find.byType(AnswerLine), matching: find.text(text));

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.drills.gradeStub.returns(drillOk);
  });

  group('Reorder', () {
    testWidgets('點一下移到答題線，再點移回', (tester) async {
      await pumpQuiz(tester, [reorderQuestion()], backend: backend);

      await tester.tap(find.text('私'));
      await tester.pump();
      expect(_inAnswerLine('私'), findsOneWidget);

      await tester.tap(_inAnswerLine('私'));
      await tester.pump();
      expect(_inAnswerLine('私'), findsNothing);
    });

    testWidgets('全部放完才能確認；送出 ChunkDto.index 的順序', (tester) async {
      await pumpQuiz(tester, [reorderQuestion()], backend: backend);

      await tester.tap(find.text('確認'));
      await tester.pump();
      expect(backend.drills.gradeStub.calls, isEmpty);

      for (final text in ['私', 'は', '学生']) {
        await tester.tap(find.text(text));
        await tester.pump();
      }
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();

      final payload =
          backend.drills.gradeStub.calls.single[1] as AnswerPayload_Reorder;
      expect(payload.order, Uint32List.fromList([0, 1, 2]));
      expect(find.text('答對了'), findsOneWidget);
    });

    QuestionDto audioFirst() => reorderQuestionWith(
      promptFixture(
        text: sentenceFixture(),
        speech: sentenceFixture().speech,
        autoplay: true,
        hide: true,
      ),
    );

    testWidgets('audio_first：播完前沒有詞塊，也沒有句子', (tester) async {
      final tts = FakeTtsEngine(autoComplete: false);
      await pumpQuiz(
        tester,
        [audioFirst()],
        backend: backend,
        tts: tts,
        settle: false,
      );
      await settleFrames(tester);

      expect(find.byType(WordTile), findsNothing);
      expect(find.text('私'), findsNothing);
      expect(find.text('開始拼句'), findsOneWidget);

      await tester.tap(find.text('開始拼句'));
      await tester.pump();
      expect(find.byType(WordTile), findsNothing);
    });

    testWidgets('audio_first：播過一次才能開始拼句，答後才出現完整句', (tester) async {
      final tts = FakeTtsEngine();
      backend.drills.gradeStub.returns(
        DrillResultDto(
          isCorrect: true,
          correctDisplay: '{ja:私は学生です。|わたしはがくせいです。}',
          reveal: sentenceFixture(),
        ),
      );
      await pumpQuiz(tester, [audioFirst()], backend: backend, tts: tts);
      expect(tts.spoken, hasLength(1));

      await tester.tap(find.text('開始拼句'));
      await tester.pumpAndSettle();
      expect(find.byType(WordTile), findsNWidgets(3));
      // 詞塊可見，但完整句（含「です」）要答題後才出現
      expect(find.text('です'), findsNothing);

      for (final text in ['私', 'は', '学生']) {
        await tester.tap(find.text(text));
        await tester.pump();
      }
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(find.text('です'), findsOneWidget);
    });
  });

  group('Typing', () {
    testWidgets('TextField 設定給 Latin 鍵盤並關閉校正', (tester) async {
      await pumpQuiz(tester, [typingQuestion()], backend: backend);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.visiblePassword);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.textCapitalization, TextCapitalization.none);
      expect(field.obscureText, isFalse);
    });

    testWidgets('正解的讀音在作答前不進 widget tree', (tester) async {
      await pumpQuiz(tester, [typingQuestion()], backend: backend);
      expect(find.text('たべて'), findsNothing);
    });

    testWidgets('即時顯示假名預覽；空白不能送出；送出原文', (tester) async {
      await pumpQuiz(tester, [typingQuestion()], backend: backend);

      await tester.tap(find.text('確認'));
      await tester.pump();
      expect(backend.drills.gradeStub.calls, isEmpty);

      await tester.enterText(find.byType(TextField), 'tabete');
      await tester.pump();
      // FakeTextTools 的預覽回傳原字串
      expect(find.text('tabete'), findsNWidgets(2));

      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(
        backend.drills.gradeStub.calls.single[1],
        const AnswerPayload.typing(input: 'tabete'),
      );
      expect(
        backend.drills.gradeStub.calls.single[0],
        typingQuestion().reference,
      );
    });
  });

  group('Match', () {
    Future<void> tapPair(WidgetTester tester, String left, String right) async {
      await tester.tap(find.text(left));
      await tester.pump();
      await tester.tap(find.text(right));
      await tester.pump();
    }

    setUp(() {
      backend.kana.submitStub.returns(
        const KanaSubmitResultDto(isCorrect: true, correctDisplay: ''),
      );
    });

    testWidgets('全對回報 allCorrect=true，顯示總秒數', (tester) async {
      await pumpQuiz(
        tester,
        [matchQuestion()],
        backend: backend,
        grader: const KanaGrader(),
      );
      await tapPair(tester, 'あ', 'a');
      await tapPair(tester, 'い', 'i');
      expect(backend.kana.submitStub.calls, isEmpty);
      await tapPair(tester, 'う', 'u');
      await tester.pumpAndSettle();

      expect(
        backend.kana.submitStub.calls.single[1],
        const AnswerPayload.match(allCorrect: true),
      );
      expect(find.textContaining('秒'), findsOneWidget);
    });

    testWidgets('配錯過一次就回報 allCorrect=false', (tester) async {
      backend.kana.submitStub.returns(
        const KanaSubmitResultDto(isCorrect: false, correctDisplay: ''),
      );
      await pumpQuiz(
        tester,
        [matchQuestion()],
        backend: backend,
        grader: const KanaGrader(),
      );
      await tapPair(tester, 'あ', 'i');
      await tapPair(tester, 'あ', 'a');
      await tapPair(tester, 'い', 'i');
      await tapPair(tester, 'う', 'u');
      await tester.pumpAndSettle();

      expect(
        backend.kana.submitStub.calls.single[1],
        const AnswerPayload.match(allCorrect: false),
      );
    });
  });

  group('SelfGrade', () {
    AnswerResultDto ok() => reviewOk();
    const grader = ReviewGrader(expectedReps: 4);

    setUp(() => backend.review.submitStub.returns(ok()));

    testWidgets('翻面前答案不在 widget tree，也沒有評分列', (tester) async {
      await pumpQuiz(
        tester,
        [selfGradeQuestion()],
        backend: backend,
        grader: grader,
      );

      expect(find.text('学生'), findsNothing);
      expect(find.byType(RatingBar), findsNothing);
      expect(find.text('貓'), findsOneWidget);
    });

    testWidgets('reduced motion 時翻面前答案也不在 tree', (tester) async {
      await pumpQuiz(
        tester,
        [selfGradeQuestion()],
        backend: backend,
        grader: grader,
        disableAnimations: true,
      );
      expect(find.text('学生'), findsNothing);
    });

    testWidgets('翻面後評分；送出 expected_reps 與 SelfGrade', (tester) async {
      final question = selfGradeQuestion();
      var finished = false;
      await pumpQuiz(
        tester,
        [question],
        backend: backend,
        grader: grader,
        onFinished: (_) => finished = true,
      );

      await tester.tap(find.text('翻面看答案'));
      await tester.pumpAndSettle();
      expect(find.text('学生'), findsOneWidget);
      expect(find.byType(RatingBar), findsOneWidget);

      await tester.tap(find.text('記得'));
      await tester.pumpAndSettle();

      final answer = backend.review.submitStub.calls.single[0] as AnswerDto;
      expect(answer.expectedReps, 4);
      expect(answer.reference, question.reference);
      expect(
        answer.response,
        const AnswerPayload.selfGrade(rating: Rating.good),
      );
      expect(answer.hintUsed, isFalse);
      expect(answer.attempts, 1);
      expect(finished, isTrue);
    });

    testWidgets('空白鍵翻面', (tester) async {
      await pumpQuiz(
        tester,
        [selfGradeQuestion()],
        backend: backend,
        grader: grader,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(RatingBar), findsOneWidget);
    });

    const previews = [
      RatingPreviewDto(rating: Rating.good, intervalMinutes: 1440),
    ];

    testWidgets('間隔數字預設隱藏', (tester) async {
      await pumpQuiz(
        tester,
        [selfGradeQuestion()],
        backend: backend,
        grader: grader,
        previews: previews,
      );
      await tester.tap(find.text('翻面看答案'));
      await tester.pumpAndSettle();
      expect(find.text('1 天'), findsNothing);
    });

    testWidgets('設定開啟後顯示間隔數字', (tester) async {
      await pumpQuiz(
        tester,
        [selfGradeQuestion()],
        backend: backend,
        grader: grader,
        previews: previews,
        settings: allHintsSeen(showIntervals: true),
      );
      await tester.tap(find.text('翻面看答案'));
      await tester.pumpAndSettle();
      expect(find.text('1 天'), findsOneWidget);
    });

    testWidgets('第一次看到評分鍵時有說明行', (tester) async {
      await pumpQuiz(
        tester,
        [selfGradeQuestion()],
        backend: backend,
        grader: grader,
        settings: settingsFixture(),
      );
      await tester.tap(find.text('翻面看答案'));
      await tester.pumpAndSettle();
      expect(find.text('依你記得的程度選，App 會決定下次何時複習。'), findsOneWidget);
    });
  });

  testWidgets('看過這個題型就沒有評分鍵說明行', (tester) async {
    backend.review.submitStub.returns(reviewOk());
    await pumpQuiz(
      tester,
      [selfGradeQuestion()],
      backend: backend,
      grader: const ReviewGrader(expectedReps: 1),
    );
    await tester.tap(find.text('翻面看答案'));
    await tester.pumpAndSettle();
    expect(find.text('依你記得的程度選，App 會決定下次何時複習。'), findsNothing);
  });

  group('Shadow', () {
    testWidgets('播放後經過空檔才出現三級自評，回傳 ShadowLevel', (tester) async {
      await pumpQuiz(
        tester,
        [shadowQuestion()],
        backend: backend,
        settle: false,
      );
      await settleFrames(tester);

      expect(find.text('跟上了'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('跟上了'), findsOneWidget);
      expect(find.text('差一點'), findsOneWidget);
      expect(find.text('跟不上'), findsOneWidget);

      await tester.tap(find.text('差一點'));
      await tester.pumpAndSettle();
      expect(
        backend.drills.gradeStub.calls.single[1],
        const AnswerPayload.shadow(level: ShadowLevel.almost),
      );
    });

    testWidgets('沒有播過不能自評', (tester) async {
      await pumpQuiz(
        tester,
        [shadowQuestion()],
        backend: backend,
        settings: allHintsSeen(autoplay: false),
      );
      expect(find.text('跟上了'), findsNothing);
    });
  });

  testWidgets('離開時停止本回合的播放', (tester) async {
    final tts = FakeTtsEngine(autoComplete: false);
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    final settings = allHintsSeen();
    backend.settings.current = settings;
    final container = await pumpApp(
      tester,
      backend: backend,
      tts: tts,
      settings: settings,
      settle: false,
      child: ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (context, visible, _) => visible
            ? QuizSessionView(
                questions: [shadowQuestion()],
                grader: const DrillGrader(),
                onFinished: (_) {},
                fallbackLessonId: 'le.l01',
              )
            : const SizedBox.shrink(),
      ),
    );
    await settleFrames(tester);
    expect(container.read(ttsControllerProvider), isA<TtsSpeaking>());
    final stopsBefore = tts.stopCount;

    shown.value = false;
    await tester.pump();
    await tester.pump();

    expect(tts.stopCount, greaterThan(stopsBefore));
    expect(container.read(ttsControllerProvider), isA<TtsIdle>());
  });
}

QuestionDto reorderQuestionWith(PromptDto prompt) =>
    reorderQuestion(prompt: prompt);

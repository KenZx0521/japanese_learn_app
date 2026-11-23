import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/core/text/ruby_line.dart';
import 'package:japanese_learn_app/design/widgets/choice_tile.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/question_hint_strip.dart';
import 'package:japanese_learn_app/design/widgets/speak_button.dart';
import 'package:japanese_learn_app/design/widgets/voice_failed_panel.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import 'quiz_fixtures.dart';
import 'quiz_harness.dart';

const _speech = SpeechDto(text: '猫', kana: 'ねこ');

QuestionDto _hiddenListen() => choiceQuestion(
  type: QuestionType.listenMeaning,
  prompt: promptFixture(
    text: sentenceFixture(),
    speech: _speech,
    autoplay: true,
    hide: true,
  ),
);

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.drills.gradeStub.returns(drillOk);
  });

  group('回合流程', () {
    testWidgets('繼續到下一題；最後一題回報 outcome', (tester) async {
      QuizOutcome? outcome;
      await pumpQuiz(
        tester,
        [
          choiceQuestion(),
          choiceQuestion(
            body: choiceBodyFixture(
              options: [optionFixture('a', '書'), optionFixture('b', '筆')],
            ),
          ),
        ],
        backend: backend,
        onFinished: (o) => outcome = o,
      );

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      expect(find.text('書'), findsOneWidget);
      expect(find.text('答對了'), findsNothing);

      await tester.tap(find.text('書'));
      await tester.pumpAndSettle();
      expect(outcome, isNull);
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      expect(outcome?.firstTryCorrect, 2);
      expect(outcome?.firstTryCount, 2);
    });

    testWidgets('答錯者本回合末重出一次', (tester) async {
      backend.drills.gradeStub.returns(drillWrong());
      QuizOutcome? outcome;
      await pumpQuiz(
        tester,
        [choiceQuestion()],
        backend: backend,
        requeueWrong: true,
        onFinished: (o) => outcome = o,
      );

      await tester.tap(find.text('狗'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      expect(outcome, isNull);
      expect(find.text('繼續'), findsNothing);

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      expect(outcome?.records, hasLength(2));
    });

    testWidgets('空題目顯示空狀態', (tester) async {
      await pumpQuiz(tester, const [], backend: backend);
      expect(find.text('這裡目前沒有題目'), findsOneWidget);
    });

    testWidgets('父層重建傳入內容相同的新 List 不會重置回合', (tester) async {
      final key = GlobalKey<SwapHostState>();
      await pumpQuizSwap(tester, backend, key);
      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();

      key.currentState!.rebuildWithSameQuestion();
      await tester.pumpAndSettle();
      expect(find.text('答對了'), findsOneWidget);
    });

    testWidgets('新一批題目會重置回合', (tester) async {
      final key = GlobalKey<SwapHostState>();
      await pumpQuizSwap(tester, backend, key);
      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      expect(find.text('答對了'), findsOneWidget);

      key.currentState!.swap();
      await tester.pumpAndSettle();
      expect(find.text('答對了'), findsNothing);
      expect(find.text('書'), findsOneWidget);
    });
  });

  group('回饋內容', () {
    testWidgets('假名熟練進度', (tester) async {
      backend.kana.submitStub.returns(
        const KanaSubmitResultDto(
          isCorrect: true,
          correctDisplay: 'ka',
          mastery: KanaMasteryDto(
            kanaId: 'ka.ka',
            run: 1,
            required_: 2,
            mastered: false,
            fastBadge: false,
          ),
        ),
      );
      await pumpQuiz(
        tester,
        [choiceQuestion(type: QuestionType.kanaRead)],
        backend: backend,
        grader: const KanaGrader(),
      );
      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      expect(find.text('連續答對 1／2'), findsOneWidget);
    });

    testWidgets('reveal 不是題幹那句時，回饋條畫出句子與播放鈕', (tester) async {
      backend.drills.gradeStub.returns(
        DrillResultDto(
          isCorrect: true,
          correctDisplay: '{ja:私は学生です。|わたしはがくせいです。}',
          reveal: sentenceFixture(),
        ),
      );
      await pumpQuiz(tester, [
        choiceQuestion(
          type: QuestionType.zhToJaChoice,
          prompt: promptFixture(plainText: '我是學生'),
          body: choiceBodyFixture(
            options: [optionFixture('a', 'はい'), optionFixture('b', 'いいえ')],
          ),
        ),
      ], backend: backend);
      await tester.tap(find.text('はい'));
      await tester.pumpAndSettle();
      expect(find.byType(RubyLine), findsOneWidget);
      expect(find.byType(SpeakButton), findsOneWidget);
    });

    testWidgets('語體轉換：先原句再目標語體', (tester) async {
      await pumpQuiz(tester, [
        questionFixture(
          QuestionType.registerConvert,
          reorderBodyFixture(),
          prompt: promptFixture(text: sentenceFixture(), plainText: '改成常體'),
          reference: refFixture(
            QuestionType.registerConvert,
            contentId: 'gr.x',
            drillId: 'dr.4',
          ),
        ),
      ], backend: backend);
      final ruby = tester.getTopLeft(find.byType(RubyLine));
      final target = tester.getTopLeft(find.text('改成常體'));
      expect(ruby.dy, lessThan(target.dy));
    });

    testWidgets('語法重點讀取失敗可重試', (tester) async {
      var calls = 0;
      backend.peek.peekStub.answers((args) {
        if (args.single == 'vo.neko') return peekGrammar;
        calls++;
        if (calls == 1) throw const NotFoundFailure();
        return peekGrammar;
      });
      await pumpQuiz(tester, [
        choiceQuestion(focusIds: const ['gr.wa']),
      ], backend: backend);
      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      expect(find.text('這個重點暫時讀不出來。'), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.text('這個重點暫時讀不出來。'), findsNothing);
    });
  });

  group('作答耗時', () {
    QuestionDto kanaListen() => choiceQuestion(
      type: QuestionType.kanaListen,
      reference: refFixture(QuestionType.kanaListen, contentId: 'ka.a'),
      prompt: promptFixture(speech: _speech, autoplay: true, hide: true),
      body: choiceBodyFixture(
        options: [optionFixture('a', 'あ'), optionFixture('b', 'い')],
      ),
    );

    testWidgets('KanaListen 播放中作答記 0', (tester) async {
      final tts = FakeTtsEngine(autoComplete: false);
      backend.kana.submitStub.returns(
        const KanaSubmitResultDto(isCorrect: true, correctDisplay: '{ja:あ}'),
      );
      await pumpQuiz(
        tester,
        [kanaListen()],
        backend: backend,
        tts: tts,
        grader: const KanaGrader(),
        settle: false,
      );
      await settleFrames(tester);

      await tester.tap(find.byType(ChoiceTile).first);
      await settleFrames(tester);

      expect(backend.kana.submitStub.calls.single[2], 0);
    });

    testWidgets('換題時停止上一題的播放', (tester) async {
      final tts = FakeTtsEngine(autoComplete: false);
      await pumpQuiz(
        tester,
        [_hiddenListen(), choiceQuestion()],
        backend: backend,
        tts: tts,
        settle: false,
      );
      await settleFrames(tester);
      await tester.tap(find.text('貓'));
      await settleFrames(tester);
      await tester.pump(const Duration(milliseconds: 400));
      final before = tts.stopCount;

      await tester.tap(find.text('繼續'));
      await settleFrames(tester);

      expect(tts.stopCount, greaterThan(before));
    });
  });

  group('檢定', () {
    testWidgets('不顯示對錯，累積 AnswerDto，不呼叫判定 API', (tester) async {
      QuizOutcome? outcome;
      final question = choiceQuestion(
        reference: refFixture(QuestionType.recog, drillId: 'dr.1', variant: 1),
      );
      await pumpQuiz(
        tester,
        [question],
        backend: backend,
        grader: const CheckpointCollector(),
        onFinished: (o) => outcome = o,
      );

      await tester.tap(find.text('狗'));
      await tester.pumpAndSettle();

      expect(find.text('不對喔'), findsNothing);
      expect(find.text('答對了'), findsNothing);
      expect(backend.drills.gradeStub.calls, isEmpty);
      final answer = outcome!.answers.single;
      expect(answer.expectedReps, 0);
      expect(answer.reference, question.reference);
    });
  });

  group('錯誤與重試', () {
    testWidgets('寫入失敗顯示友善訊息，重試用同一份作答', (tester) async {
      var attempts = 0;
      backend.drills.gradeStub.answers((_) {
        attempts++;
        if (attempts == 1) throw const StorageFailure();
        return drillOk;
      });
      await pumpQuiz(tester, [choiceQuestion()], backend: backend);

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorSlip), findsOneWidget);
      expect(find.text(const StorageFailure().userMessage), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.text('答對了'), findsOneWidget);
      expect(backend.drills.gradeStub.calls, hasLength(2));
      expect(
        backend.drills.gradeStub.calls.last[1],
        const AnswerPayload.choice(optionId: 'a'),
      );
    });

    testWidgets('StaleCard 靜默跳過', (tester) async {
      backend.review.submitStub.throws(const StaleCardFailure());
      QuizOutcome? outcome;
      await pumpQuiz(
        tester,
        [choiceQuestion()],
        backend: backend,
        grader: const ReviewGrader(expectedReps: 1),
        onFinished: (o) => outcome = o,
      );

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorSlip), findsNothing);
      expect(outcome, isNotNull);
    });
  });

  group('操作提示', () {
    testWidgets('第一次顯示並寫入，同題型第二題不再顯示', (tester) async {
      final settings = settingsFixture();
      await pumpQuiz(
        tester,
        [choiceQuestion(), choiceQuestion()],
        backend: backend,
        settings: settings,
      );

      expect(find.byType(QuestionHintStrip), findsOneWidget);
      expect(find.text('看日文，選出意思。'), findsOneWidget);
      expect(backend.settings.current.seenQuestionHints, [QuestionType.recog]);

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      expect(find.byType(QuestionHintStrip), findsNothing);
    });

    testWidgets('按「知道了」收起', (tester) async {
      await pumpQuiz(
        tester,
        [choiceQuestion()],
        backend: backend,
        settings: settingsFixture(),
      );
      await tester.tap(find.text('知道了'));
      await tester.pump();
      expect(find.byType(QuestionHintStrip), findsNothing);
    });

    testWidgets('寫入失敗仍可作答，本次不重複提示', (tester) async {
      backend.settings.patchStub.throws(const StorageFailure());
      await pumpQuiz(
        tester,
        [choiceQuestion(), choiceQuestion()],
        backend: backend,
        settings: settingsFixture(),
      );
      expect(find.byType(QuestionHintStrip), findsOneWidget);

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      expect(find.byType(QuestionHintStrip), findsNothing);
    });
  });

  group('語音', () {
    testWidgets('播放失敗：題幹改顯示 VoiceFailedPanel，不提供略過', (tester) async {
      final tts = FakeTtsEngine(autoStart: false);
      await pumpQuiz(
        tester,
        [_hiddenListen()],
        backend: backend,
        tts: tts,
        settle: false,
      );
      await settleFrames(tester);
      tts.emit(const TtsFailed('x', 'noop'));
      await tester.pump();
      expect(find.byType(VoiceFailedPanel), findsNothing);

      tts.emit(TtsFailed(tts.spoken.single.id, 'engine'));
      await tester.pump();
      expect(find.byType(VoiceFailedPanel), findsOneWidget);
      expect(find.text('略過'), findsNothing);
      expect(backend.drills.gradeStub.calls, isEmpty);
    });

    testWidgets('重試會再念一次', (tester) async {
      final tts = FakeTtsEngine(autoStart: false);
      await pumpQuiz(
        tester,
        [_hiddenListen()],
        backend: backend,
        tts: tts,
        settle: false,
      );
      await settleFrames(tester);
      tts.emit(TtsFailed(tts.spoken.single.id, 'engine'));
      await tester.pump();

      await tester.tap(find.text('重試'));
      await settleFrames(tester);
      expect(tts.spoken, hasLength(2));
      expect(find.byType(VoiceFailedPanel), findsNothing);
    });

    testWidgets('改用無聲模式寫入 silent_mode', (tester) async {
      final tts = FakeTtsEngine(autoStart: false);
      final container = await pumpQuiz(
        tester,
        [_hiddenListen()],
        backend: backend,
        tts: tts,
        settle: false,
      );
      await settleFrames(tester);
      tts.emit(TtsFailed(tts.spoken.single.id, 'engine'));
      await tester.pump();

      await tester.tap(find.text('改用無聲模式'));
      await settleFrames(tester);
      expect(container.read(settingsProvider).value?.silentMode, isTrue);
    });

    testWidgets('語音不可用時不靜默：有說明入口', (tester) async {
      final tts = FakeTtsEngine(
        availability: const TtsAvailability(TtsAvailabilityKind.engineMissing),
      );
      await pumpQuiz(tester, [_hiddenListen()], backend: backend, tts: tts);

      expect(find.text('這題要聽聲音，現在無法播放。'), findsOneWidget);
      await tester.tap(find.text('查看語音說明'));
      await tester.pumpAndSettle();
      expect(find.text('手機沒有語音引擎'), findsOneWidget);
    });

    testWidgets('螢幕報讀時不自動播放', (tester) async {
      final tts = FakeTtsEngine();
      await pumpQuiz(
        tester,
        [_hiddenListen()],
        backend: backend,
        tts: tts,
        accessibleNavigation: true,
      );
      expect(tts.spoken, isEmpty);
    });
  });

  group('顯示規則', () {
    testWidgets('依 peek 的課次取 display_policy', (tester) async {
      backend.peek.peekStub.returns(
        const PeekDto(
          refId: 'vo.neko',
          title: '猫',
          summaryZh: '貓',
          lessonId: 'le.l05',
        ),
      );
      await pumpQuiz(tester, [choiceQuestion()], backend: backend);
      final context =
          backend.settings.displayPolicyStub.calls.single[0] as DisplayContext;
      expect(context.lessonId, 'le.l05');
    });

    testWidgets('se.* 不呼叫 peek，用 fallback 的課', (tester) async {
      await pumpQuiz(tester, [
        choiceQuestion(
          reference: refFixture(QuestionType.recog, contentId: 'se.l02.001'),
        ),
      ], backend: backend);
      expect(backend.peek.peekStub.calls, isEmpty);
      final context =
          backend.settings.displayPolicyStub.calls.single[0] as DisplayContext;
      expect(context.lessonId, 'le.l01');
    });

    testWidgets('ka.* 不套用規則', (tester) async {
      await pumpQuiz(tester, [
        choiceQuestion(
          reference: refFixture(QuestionType.kanaRead, contentId: 'ka.a'),
          type: QuestionType.kanaRead,
        ),
      ], backend: backend);
      expect(backend.settings.displayPolicyStub.calls, isEmpty);
    });

    testWidgets('display_policy 失敗不擋作答', (tester) async {
      backend.settings.displayPolicyStub.throws(const StorageFailure());
      await pumpQuiz(tester, [choiceQuestion()], backend: backend);
      expect(find.text('貓'), findsOneWidget);
    });
  });

  group('單字答後展開', () {
    testWidgets('vo.* 且 expandVocab 時顯示勾連與徽章', (tester) async {
      backend.review.submitStub.returns(reviewOk());
      backend.vocab.detailStub.returns(
        vocabDetailFixture(
          trapZh: '別和 {ja:犬} 搞混',
          notes: const [
            NoteDto.falseFriend(
              id: 'no.ff.1',
              surface: '手紙',
              vocabId: 'vo.tegami',
              jaZh: '信',
              misreadZh: '衛生紙',
            ),
          ],
        ),
      );
      await pumpQuiz(
        tester,
        [choiceQuestion()],
        backend: backend,
        grader: const ReviewGrader(expectedReps: 1),
        expandVocab: true,
      );

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();

      expect(find.text('同形異義'), findsOneWidget);
      expect(backend.vocab.detailStub.calls.single, ['vo.neko']);
    });

    testWidgets('沒開 expandVocab 時不查單字', (tester) async {
      await pumpQuiz(tester, [choiceQuestion()], backend: backend);
      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      expect(backend.vocab.detailStub.calls, isEmpty);
    });
  });

  group('版面與無障礙', () {
    final cases = <String, QuestionDto Function()>{
      'choice': choiceQuestion,
      'reorder': reorderQuestion,
      'typing': typingQuestion,
      'match': matchQuestion,
      'selfGrade': selfGradeQuestion,
    };

    for (final MapEntry(key: name, value: build) in cases.entries) {
      testWidgets('$name 在 320 寬、字級 1.5 倍不破版', (tester) async {
        await pumpQuiz(
          tester,
          [build()],
          backend: backend,
          width: 320,
          height: 568,
          textScale: 1.5,
          settings: settingsFixture(),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('回饋很長時 320 寬也不破版，繼續鈕可點', (tester) async {
      backend.peek.peekStub.returns(peekGrammar);
      backend.drills.gradeStub.returns(
        DrillResultDto(
          isCorrect: false,
          correctDisplay: '貓',
          explainZh: '很長的說明。' * 40,
          whyZh: '很長的原因。' * 20,
          reveal: sentenceFixture(),
        ),
      );
      await pumpQuiz(
        tester,
        [
          choiceQuestion(focusIds: const ['gr.wa']),
        ],
        backend: backend,
        width: 320,
        height: 568,
        textScale: 1.5,
      );
      await tester.tap(find.text('狗'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('放在捲動頁內（無限高）也能排版', (tester) async {
      await pumpQuiz(
        tester,
        [choiceQuestion()],
        backend: backend,
        inline: true,
      );
      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('繼續'), findsOneWidget);
    });

    testWidgets('互動目標符合 48dp 與標籤準則', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpQuiz(tester, [choiceQuestion()], backend: backend);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('reduced motion 下完整走一題', (tester) async {
      await pumpQuiz(
        tester,
        [choiceQuestion()],
        backend: backend,
        disableAnimations: true,
      );
      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      expect(find.text('答對了'), findsOneWidget);
    });

    testWidgets('進度條有語意', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpQuiz(tester, [
        choiceQuestion(),
        choiceQuestion(),
      ], backend: backend);
      expect(find.bySemanticsLabel('第 1 題，共 2 題'), findsOneWidget);
      handle.dispose();
    });
  });
}

class SwapHost extends StatefulWidget {
  const SwapHost({super.key});

  @override
  State<SwapHost> createState() => SwapHostState();
}

class SwapHostState extends State<SwapHost> {
  List<QuestionDto> _questions = [choiceQuestion()];

  void rebuildWithSameQuestion() => setState(() {
    _questions = [_questions.single];
  });

  void swap() => setState(() {
    _questions = [
      choiceQuestion(
        body: choiceBodyFixture(
          options: [optionFixture('a', '書'), optionFixture('b', '筆')],
        ),
      ),
    ];
  });

  @override
  Widget build(BuildContext context) => QuizSessionView(
    questions: _questions,
    grader: const DrillGrader(),
    onFinished: (_) {},
    fallbackLessonId: 'le.l01',
  );
}

Future<void> pumpQuizSwap(
  WidgetTester tester,
  FakeBackend backend,
  GlobalKey<SwapHostState> key,
) async {
  await pumpQuizChild(tester, backend, SwapHost(key: key));
}

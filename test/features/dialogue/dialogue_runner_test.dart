import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/paper_scaffold.dart';
import 'package:japanese_learn_app/design/widgets/voice_failed_panel.dart';
import 'package:japanese_learn_app/features/dialogue/dialogue.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'dialogue_fixtures.dart';

Finder _rich(String text) => find.textContaining(text, findRichText: true);

const _afterSequence = Duration(seconds: 2);

Widget _runner(
  DialogueDto dialogue, {
  List<int> phases = allDialoguePhases,
  VoidCallback? onFinished,
}) => PaperScaffold(
  scrollable: false,
  body: DialogueRunner(
    dialogue: dialogue,
    phases: phases,
    onFinished: onFinished ?? () {},
  ),
);

/// 第 2 階段的語音 id 比對用：`di.l01#0` 這類。
List<String> _spokenIds(FakeTtsEngine tts) => [
  for (final request in tts.spoken) request.id,
];

void main() {
  group('盲聽', () {
    testWidgets('只顯示情境與伏字條，不出現日文', (tester) async {
      await pumpApp(
        tester,
        tts: FakeTtsEngine(autoComplete: false),
        child: _runner(dialogueFixture()),
      );

      expect(_rich('語言交換活動上第一次見面'), findsOneWidget);
      expect(find.text(firstWord), findsNothing);
      expect(_rich('初次見面。'), findsNothing);
    });

    testWidgets('自動連播全部對白，角色用各自的語音', (tester) async {
      final tts = FakeTtsEngine();
      await pumpApp(
        tester,
        tts: tts,
        child: _runner(dialogueFixture()),
        settle: false,
      );
      await tester.pumpAndSettle();
      await tester.pump(_afterSequence);
      await tester.pumpAndSettle();

      expect(_spokenIds(tts), ['di.l01#0', 'di.l01#1', 'di.l01#2']);
      expect(tts.spoken[0].voice, VoiceSlot.a);
      expect(tts.spoken[1].voice, VoiceSlot.b);
      expect(find.text('做題目'), findsOneWidget);
    });

    testWidgets('關閉自動播放時不連播', (tester) async {
      final tts = FakeTtsEngine();
      await pumpApp(
        tester,
        tts: tts,
        settings: settingsFixture(autoplay: false),
        child: _runner(dialogueFixture()),
      );

      expect(tts.spoken, isEmpty);
      expect(find.text('播放全篇'), findsOneWidget);
    });

    testWidgets('播完接題目，用 quiz_drill_ids 取題', (tester) async {
      final backend = FakeBackend();
      backend.drills.sessionStub.returns([_choiceQuestion()]);
      await pumpApp(
        tester,
        backend: backend,
        child: _runner(dialogueFixture()),
        settle: false,
      );
      await tester.pumpAndSettle();
      await tester.pump(_afterSequence);
      await tester.pumpAndSettle();

      await tester.tap(find.text('做題目'));
      await tester.pumpAndSettle();

      final filter =
          backend.drills.sessionStub.calls.single.first! as DrillFilterDto;
      expect(filter.drillIds, ['dr.l01.001', 'dr.l01.002']);
      expect(filter.count, 2);
      expect(find.byType(QuizSessionView), findsOneWidget);
    });

    testWidgets('沒有 quiz_drill_ids 時直接進第二階段', (tester) async {
      await pumpApp(
        tester,
        child: _runner(
          dialogueFixture(quizDrillIds: const []),
          phases: const [1, 2],
        ),
        settle: false,
      );
      await tester.pumpAndSettle();
      await tester.pump(_afterSequence);
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一段'));
      await tester.pumpAndSettle();

      expect(find.text(firstWord), findsOneWidget);
    });

    testWidgets('取題為空時略過題目', (tester) async {
      final backend = FakeBackend();
      await pumpApp(
        tester,
        backend: backend,
        child: _runner(dialogueFixture(), phases: const [1, 2]),
        settle: false,
      );
      await tester.pumpAndSettle();
      await tester.pump(_afterSequence);
      await tester.pumpAndSettle();

      await tester.tap(find.text('做題目'));
      await tester.pumpAndSettle();

      expect(find.byType(QuizSessionView), findsNothing);
      expect(find.text(firstWord), findsOneWidget);
    });

    testWidgets('取題失敗可略過', (tester) async {
      final backend = FakeBackend();
      backend.drills.sessionStub.throws(const StorageFailure());
      await pumpApp(
        tester,
        backend: backend,
        child: _runner(dialogueFixture(), phases: const [1, 2]),
        settle: false,
      );
      await tester.pumpAndSettle();
      await tester.pump(_afterSequence);
      await tester.pumpAndSettle();
      await tester.tap(find.text('做題目'));
      await tester.pumpAndSettle();

      expect(find.text(const StorageFailure().userMessage), findsOneWidget);
      await tester.tap(find.text('略過題目'));
      await tester.pumpAndSettle();

      expect(find.text(firstWord), findsOneWidget);
    });

    testWidgets('播放失敗顯示 VoiceFailedPanel，不靜默', (tester) async {
      final tts = FakeTtsEngine()..speakError = Exception('boom');
      await pumpApp(
        tester,
        tts: tts,
        child: _runner(dialogueFixture()),
        settle: false,
      );
      await tester.pumpAndSettle();

      expect(find.byType(VoiceFailedPanel), findsOneWidget);
    });

    testWidgets('改用無聲模式後略過盲聽', (tester) async {
      final backend = FakeBackend();
      final tts = FakeTtsEngine()..speakError = Exception('boom');
      await pumpApp(
        tester,
        backend: backend,
        tts: tts,
        settings: settingsFixture(),
        child: _runner(dialogueFixture()),
        settle: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('改用無聲模式'));
      await tester.pumpAndSettle();

      expect(backend.settings.current.silentMode, isTrue);
      expect(find.text(firstWord), findsOneWidget);
      expect(find.textContaining('現在沒有語音'), findsOneWidget);
    });
  });

  group('逐句', () {
    Future<FakeTtsEngine> pumpSentences(
      WidgetTester tester, {
      DialogueDto? dialogue,
      SettingsDto? settings,
    }) async {
      final tts = FakeTtsEngine();
      await pumpApp(
        tester,
        tts: tts,
        settings: settings ?? settingsFixture(),
        child: _runner(dialogue ?? dialogueFixture(), phases: const [2]),
      );
      return tts;
    }

    testWidgets('展開全文、中文與補充說明', (tester) async {
      await pumpSentences(tester);

      expect(find.text(firstWord), findsOneWidget);
      expect(_rich('初次見面。'), findsOneWidget);
      expect(_rich('第一次見面的招呼'), findsOneWidget);
      expect(find.text('小王'), findsNWidgets(2));
      expect(find.text('鈴木'), findsOneWidget);
    });

    testWidgets('顯示切換可收起日文與中文', (tester) async {
      await pumpSentences(tester);

      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(_rich('初次見面。'), findsNothing);

      await tester.tap(find.text('日文'));
      await tester.pumpAndSettle();
      expect(find.text(firstWord), findsNothing);
    });

    testWidgets('全部播放依序連播', (tester) async {
      final tts = await pumpSentences(tester);

      await tester.tap(find.text('全部播放'));
      await tester.pump();
      await tester.pump(_afterSequence);
      await tester.pumpAndSettle();

      expect(_spokenIds(tts), ['di.l01#0', 'di.l01#1', 'di.l01#2']);
    });

    testWidgets('逐詞模式送 speech_kana 且略過標點', (tester) async {
      final tts = await pumpSentences(tester);

      await tester.tap(find.text('逐詞'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('逐詞播放').first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tts.spoken, hasLength(1));
      expect(tts.spoken.single.text, 'はじめまして');
      expect(tts.spoken.single.kana, 'はじめまして');
    });

    testWidgets('已存的 1.2 倍設定當正常速度', (tester) async {
      final tts = await pumpSentences(
        tester,
        settings: settingsFixture(ttsRate: 1.2),
      );

      await tester.tap(find.text('全部播放'));
      await tester.pump();
      await tester.pump(_afterSequence);
      await tester.pumpAndSettle();

      expect(tts.spoken.first.speed, TtsSpeed.normal);
    });

    testWidgets('慢速設定套用到連播', (tester) async {
      final tts = await pumpSentences(
        tester,
        settings: settingsFixture(ttsRate: 0.7),
      );

      await tester.tap(find.text('全部播放'));
      await tester.pump();
      await tester.pump(_afterSequence);
      await tester.pumpAndSettle();

      expect(tts.spoken.first.speed, TtsSpeed.slow);
    });

    testWidgets('換階段時停掉還在播的句子', (tester) async {
      final tts = FakeTtsEngine(autoComplete: false);
      await pumpApp(
        tester,
        tts: tts,
        disableAnimations: true,
        child: _runner(dialogueFixture(), phases: const [2, 4]),
      );
      await tester.tap(find.text('全部播放'));
      await tester.pump();
      await tester.pump();
      final before = tts.stopCount;

      await tester.ensureVisible(find.text('下一段'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一段'));
      await tester.pumpAndSettle();

      expect(tts.stopCount, greaterThan(before));
      expect(find.textContaining('選一個角色'), findsOneWidget);
    });

    testWidgets('ShownToggleable 才有羅馬字開關，可收起', (tester) async {
      final backend = FakeBackend();
      backend.settings.displayPolicyStub.returns(
        displayPolicyFixture(romaji: RomajiMode.shownToggleable),
      );
      await pumpApp(
        tester,
        backend: backend,
        child: _runner(dialogueFixture(), phases: const [2]),
      );
      expect(find.text('ro'), findsWidgets);

      await tester.tap(find.text('羅馬字'));
      await tester.pumpAndSettle();

      expect(find.text('ro'), findsNothing);
    });

    testWidgets('其他 RomajiMode 沒有羅馬字開關', (tester) async {
      await pumpApp(
        tester,
        child: _runner(dialogueFixture(), phases: const [2]),
      );

      expect(find.text('羅馬字'), findsNothing);
    });

    testWidgets('按下一段後完成，顯示完成章與回呼', (tester) async {
      var finished = 0;
      await pumpApp(
        tester,
        tts: FakeTtsEngine(),
        child: _runner(
          dialogueFixture(),
          phases: const [2],
          onFinished: () => finished++,
        ),
      );

      await tester.ensureVisible(find.text('完成這段'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成這段'));
      await tester.pumpAndSettle();
      expect(find.byType(HankoBadge), findsOneWidget);

      await tester.tap(find.text('完成'));
      await tester.pump();
      expect(finished, 1);
    });
  });

  group('無聲模式', () {
    testWidgets('略過第一、三階段，第二階段只有文字', (tester) async {
      final tts = FakeTtsEngine();
      await pumpApp(
        tester,
        tts: tts,
        settings: settingsFixture(silentMode: true),
        child: _runner(dialogueFixture()),
      );

      expect(find.text(firstWord), findsOneWidget);
      expect(find.text('全部播放'), findsNothing);
      expect(find.text('逐詞'), findsNothing);
      expect(find.textContaining('現在沒有語音'), findsOneWidget);
      expect(find.text('設定語音'), findsOneWidget);
      expect(tts.spoken, isEmpty);
      expect(find.bySemanticsLabel(RegExp('盲聽，已略過')), findsOneWidget);
    });

    testWidgets('按設定語音開說明面板', (tester) async {
      await pumpApp(
        tester,
        settings: settingsFixture(silentMode: true),
        child: _runner(dialogueFixture()),
      );

      await tester.tap(find.text('設定語音'));
      await tester.pumpAndSettle();

      expect(find.text('無聲模式開著'), findsOneWidget);
    });

    testWidgets('全部階段都需要語音時說明略過', (tester) async {
      await pumpApp(
        tester,
        settings: settingsFixture(silentMode: true),
        child: _runner(dialogueFixture(), phases: const [1, 3]),
      );

      expect(find.textContaining('要聽的部分先略過'), findsOneWidget);
      expect(find.byType(HankoBadge), findsNothing);
    });

    testWidgets('語音探測完成前停在載入，不開始播放', (tester) async {
      final probe = Completer<void>();
      final tts = FakeTtsEngine(probeGate: probe.future);
      await pumpApp(
        tester,
        tts: tts,
        child: _runner(dialogueFixture()),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tts.spoken, isEmpty);
      expect(find.text('盲聽'), findsNothing);

      probe.complete();
      await tester.pumpAndSettle();
      expect(find.text('盲聽'), findsOneWidget);
    });
  });

  group('跟讀', () {
    testWidgets('播完留空檔再三級自評，走完顯示小計', (tester) async {
      await pumpApp(
        tester,
        tts: FakeTtsEngine(),
        child: _runner(dialogueFixture(), phases: const [3, 4]),
        settle: false,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      for (final label in ['跟上了', '差一點', '跟不上']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('跟上了'));
      await tester.pumpAndSettle();
      expect(find.text('第 2／3 句'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('差一點'));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跟上了'));
      await tester.pumpAndSettle();

      expect(find.textContaining('跟上了 2 句'), findsOneWidget);
      expect(find.textContaining('差一點 1 句'), findsOneWidget);
    });

    testWidgets('跟讀不寫入 grade_drill', (tester) async {
      final backend = FakeBackend();
      await pumpApp(
        tester,
        backend: backend,
        tts: FakeTtsEngine(),
        child: _runner(dialogueFixture(), phases: const [3]),
        settle: false,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跟不上'));
      await tester.pumpAndSettle();

      expect(backend.drills.gradeStub.calls, isEmpty);
    });

    testWidgets('這句播不出來時給重試，不留死路', (tester) async {
      final tts = FakeTtsEngine()..speakError = Exception('boom');
      await pumpApp(
        tester,
        tts: tts,
        child: _runner(dialogueFixture(), phases: const [3]),
        settle: false,
      );
      await tester.pumpAndSettle();

      expect(find.byType(VoiceFailedPanel), findsOneWidget);
    });
  });

  group('角色扮演', () {
    testWidgets('選角色後對方發聲，輪到自己顯示台詞', (tester) async {
      final tts = FakeTtsEngine();
      await pumpApp(
        tester,
        tts: tts,
        child: _runner(dialogueFixture(), phases: const [4]),
      );

      expect(find.textContaining('選一個角色'), findsOneWidget);
      await tester.tap(find.text('鈴木'));
      await tester.pump();
      await tester.pumpAndSettle();

      // 小王先說，由 TTS 發聲；播完輪到鈴木（使用者）
      expect(_spokenIds(tts), ['di.l01#0']);
      expect(find.text(secondWord), findsOneWidget);
      expect(find.text('換你說。'), findsOneWidget);
    });

    testWidgets('隱藏我的台詞改為伏字條', (tester) async {
      await pumpApp(
        tester,
        tts: FakeTtsEngine(),
        child: _runner(dialogueFixture(), phases: const [4]),
      );
      await tester.tap(find.text('小王'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text(firstWord), findsOneWidget);
      await tester.tap(find.text('隱藏我的台詞'));
      await tester.pumpAndSettle();

      expect(find.text(firstWord), findsNothing);
      expect(find.text('顯示我的台詞'), findsOneWidget);
    });

    testWidgets('自己的空檔結束後自動換句', (tester) async {
      await pumpApp(
        tester,
        tts: FakeTtsEngine(autoComplete: false),
        disableAnimations: true,
        child: _runner(dialogueFixture(), phases: const [4]),
      );
      await tester.tap(find.text('小王'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('第 1／3 句'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('第 2／3 句'), findsOneWidget);
    });

    testWidgets('對方說話時按下一句，只前進一句並停止播放', (tester) async {
      final tts = FakeTtsEngine(autoComplete: false);
      await pumpApp(
        tester,
        tts: tts,
        disableAnimations: true,
        child: _runner(dialogueFixture(), phases: const [4]),
      );
      await tester.tap(find.text('鈴木'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final before = tts.stopCount;

      await tester.tap(find.text('下一句'));
      await tester.pump();
      await tester.pump();

      expect(find.text('第 2／3 句'), findsOneWidget);
      expect(tts.stopCount, greaterThan(before));
    });

    testWidgets('無聲時對方台詞以文字呈現，手動下一句', (tester) async {
      final tts = FakeTtsEngine();
      await pumpApp(
        tester,
        tts: tts,
        settings: settingsFixture(silentMode: true),
        child: _runner(dialogueFixture(), phases: const [4]),
      );
      await tester.tap(find.text('鈴木'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text(firstWord), findsOneWidget);
      expect(tts.spoken, isEmpty);

      await tester.tap(find.text('下一句'));
      await tester.pumpAndSettle();
      expect(find.text(secondWord), findsOneWidget);
    });

    testWidgets('無聲時仍可隱藏自己的台詞', (tester) async {
      await pumpApp(
        tester,
        settings: settingsFixture(silentMode: true),
        child: _runner(dialogueFixture(), phases: const [4]),
      );
      await tester.tap(find.text('小王'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text(firstWord), findsOneWidget);

      await tester.tap(find.text('隱藏我的台詞'));
      await tester.pumpAndSettle();

      expect(find.text(firstWord), findsNothing);
    });

    testWidgets('走完全部台詞後可完成', (tester) async {
      var finished = 0;
      await pumpApp(
        tester,
        tts: FakeTtsEngine(autoComplete: false),
        disableAnimations: true,
        child: _runner(
          dialogueFixture(),
          phases: const [4],
          onFinished: () => finished++,
        ),
      );
      await tester.tap(find.text('小王'));
      await tester.pump();
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('下一句'));
        await tester.pump();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('完成這段'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pump();

      expect(finished, 1);
    });
  });

  group('版面與路由', () {
    testWidgets('互動目標符合無障礙準則', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        settings: settingsFixture(),
        child: _runner(dialogueFixture(), phases: const [2]),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('字級放大 1.5 倍不破版', (tester) async {
      await pumpApp(
        tester,
        width: 320,
        textScale: 1.5,
        settings: settingsFixture(silentMode: true),
        child: _runner(dialogueFixture()),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('有語音時三個階段在 320 寬放大 1.5 倍都不破版', (tester) async {
      await pumpApp(
        tester,
        width: 320,
        textScale: 1.5,
        child: _runner(dialogueFixture(), phases: const [2]),
      );
      expect(tester.takeException(), isNull);

      await pumpApp(
        tester,
        width: 320,
        textScale: 1.5,
        child: _runner(dialogueFixture(id: 'di.b'), phases: const [3]),
        settle: false,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('跟上了'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpApp(
        tester,
        width: 320,
        textScale: 1.5,
        tts: FakeTtsEngine(),
        child: _runner(dialogueFixture(id: 'di.c'), phases: const [4]),
      );
      await tester.tap(find.text('鈴木'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('隱藏我的台詞'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('S4 路由載入失敗可重試', (tester) async {
      final backend = FakeBackend();
      backend.listening.dialogueStub.throws(const NotFoundFailure());

      await pumpApp(
        tester,
        backend: backend,
        tts: FakeTtsEngine(autoComplete: false),
        location: '/session/dialogue/di.l01',
      );
      expect(find.text(const NotFoundFailure().userMessage), findsOneWidget);

      backend.listening.dialogueStub.returns(dialogueFixture());
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(find.text('盲聽'), findsOneWidget);
    });

    testWidgets('對話 id 含 # 以外的字元時路由能解碼', (tester) async {
      final backend = FakeBackend();
      backend.listening.dialogueStub.returns(dialogueFixture());

      await pumpApp(
        tester,
        backend: backend,
        tts: FakeTtsEngine(autoComplete: false),
        location: '/session/dialogue/di.self%5Fintro.casual',
      );

      expect(backend.listening.dialogueStub.calls.single, [
        'di.self_intro.casual',
      ]);
    });
  });
}

QuestionDto _choiceQuestion() => QuestionDto(
  questionType: QuestionType.listenMeaning,
  reference: const QuestionRefDto(
    questionType: QuestionType.listenMeaning,
    contentId: 'se.l01.001',
    drillId: 'dr.l01.001',
  ),
  prompt: const PromptDto(
    instructionZh: '聽完選出意思',
    autoplay: false,
    hideTextUntilAnswered: true,
  ),
  body: const QuestionBodyDto.choice(
    options: [
      OptionDto(id: 'a', text: '打招呼'),
      OptionDto(id: 'b', text: '道別'),
    ],
    correctOptionId: 'a',
  ),
  focusIds: const [],
);

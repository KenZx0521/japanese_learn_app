import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/core/text/ruby_line.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/pattern_blocks.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/design/widgets/speak_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../quiz/quiz_fixtures.dart';
import '../quiz/quiz_harness.dart';
import 'grammar_fixtures.dart';

Finder _rich(String text) => find.textContaining(text, findRichText: true);

String _path(ProviderContainer c) =>
    c.read(appRouterProvider).state.uri.toString();

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  FakeTtsEngine? tts,
  SettingsDto? settings,
  double width = 375,
  double height = 2400,
  double textScale = 1,
  bool settle = true,
}) => pumpApp(
  tester,
  backend: backend,
  tts: tts,
  location: AppRoutes.grammarPoint('gr.wa'),
  settings: settings ?? allHintsSeen(),
  width: width,
  height: height,
  textScale: textScale,
  settle: settle,
);

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.grammar.detailStub.returns(grammarDetailOf());
    backend.settings.displayPolicyStub.returns(displayPolicyFixture());
  });

  group('文章內容', () {
    testWidgets('依固定順序呈現公式、意思、說明、比較、陷阱', (tester) async {
      await _pump(tester, backend);

      expect(find.byType(PatternBlocks), findsOneWidget);
      final order = [
        _rich('提出主題'),
        find.byType(PatternBlocks),
        _rich('把 N 提出來當話題'),
        _rich('先說出話題'),
        find.text('和中文比一比'),
        find.text('容易錯'),
      ];
      for (var i = 1; i < order.length; i++) {
        expect(
          tester.getTopLeft(order[i - 1]).dy,
          lessThan(tester.getTopLeft(order[i]).dy),
        );
      }
    });

    testWidgets('沒有陷阱與 formation 時不顯示該區', (tester) async {
      backend.grammar.detailStub.returns(
        grammarDetailOf(trapZh: null, formation: const []),
      );
      await _pump(tester, backend);

      expect(find.text('容易錯'), findsNothing);
      expect(find.text('接續'), findsNothing);
    });

    testWidgets('formation 的日文走混排', (tester) async {
      await _pump(tester, backend);

      expect(find.text('接續'), findsOneWidget);
      expect(_rich('N は'), findsOneWidget);
    });

    testWidgets('顯示規則依內容所屬的課', (tester) async {
      await _pump(tester, backend);

      final context =
          backend.settings.displayPolicyStub.calls.single.single!
              as DisplayContext;
      expect(context.lessonId, 'le.l01');
    });

    testWidgets('ShownToggleable 時右上可收起羅馬字', (tester) async {
      backend.settings.displayPolicyStub.returns(
        displayPolicyFixture(romaji: RomajiMode.shownToggleable),
      );
      await _pump(tester, backend);

      expect(find.text('watashi'), findsWidgets);
      await tester.tap(find.text('收起羅馬字'));
      await tester.pumpAndSettle();

      expect(find.text('watashi'), findsNothing);
      expect(find.text('顯示羅馬字'), findsOneWidget);
    });

    testWidgets('其他羅馬字模式不顯示開關', (tester) async {
      await _pump(tester, backend);
      expect(find.text('收起羅馬字'), findsNothing);
    });
  });

  group('例句', () {
    testWidgets('先顯示 3 句，其餘按下才展開', (tester) async {
      backend.grammar.detailStub.returns(grammarDetailOf(exampleCount: 5));
      await _pump(tester, backend);

      expect(find.byType(RubyLine), findsNWidgets(3));
      await tester.tap(find.text('再看 2 句'));
      await tester.pumpAndSettle();

      expect(find.byType(RubyLine), findsNWidgets(5));
      expect(find.textContaining('再看'), findsNothing);
    });

    testWidgets('3 句以內沒有展開鈕', (tester) async {
      await _pump(tester, backend);
      expect(find.textContaining('再看'), findsNothing);
    });

    testWidgets('按播放送出語音', (tester) async {
      final tts = FakeTtsEngine();
      await _pump(tester, backend, tts: tts);

      await tester.tap(find.byType(SpeakButton).first);
      await settleFrames(tester);

      expect(tts.spoken.single.kana, 'わたしはがくせいです。');
    });

    testWidgets('語音不可用時按播放開說明，不靜默', (tester) async {
      final tts = FakeTtsEngine(
        availability: const TtsAvailability(TtsAvailabilityKind.engineMissing),
      );
      await _pump(tester, backend, tts: tts);

      await tester.tap(find.byType(SpeakButton).first);
      await tester.pumpAndSettle();

      expect(tts.spoken, isEmpty);
      expect(find.textContaining('語音'), findsWidgets);
    });

    testWidgets('點字開查詢面板，可前往完整內容', (tester) async {
      backend.peek.peekStub.returns(
        const PeekDto(
          refId: 'vo.gakusei',
          title: '学生',
          kana: 'がくせい',
          romaji: 'gakusei',
          summaryZh: '學生',
          lessonId: 'le.l01',
        ),
      );
      final container = await _pump(tester, backend);

      await tester.tap(find.text('学生').first);
      await tester.pumpAndSettle();
      expect(find.text('看完整內容'), findsOneWidget);

      await tester.tap(find.text('看完整內容'));
      await tester.pumpAndSettle();
      expect(_path(container), '/learn/vocab/word/vo.gakusei');
      expect(find.text('看完整內容'), findsNothing);
    });
  });

  group('連結', () {
    testWidgets('相近文法連到另一個文法點', (tester) async {
      backend.grammar.detailStub.answers(
        (args) => args.single == 'gr.wa'
            ? grammarDetailOf(
                contrast: const [
                  GrammarRefDto(id: 'gr.ga', titleZh: '{ja:が}：主語'),
                ],
              )
            : grammarDetailOf(
                summary: grammarSummaryFixture(
                  id: 'gr.ga',
                  titleZh: '{ja:が}：標主語',
                ),
              ),
      );
      final container = await _pump(tester, backend);

      await tester.tap(_rich('：主語'));
      await tester.pumpAndSettle();

      expect(_path(container), '/learn/grammar/gr.ga');
      expect(_rich('：標主語'), findsOneWidget);
    });

    testWidgets('術語開面板，可到筆記頁', (tester) async {
      backend.grammar.detailStub.returns(
        grammarDetailOf(terms: const [termFixture]),
      );
      final container = await _pump(tester, backend);
      expect(find.text('相關術語'), findsOneWidget);

      await tester.tap(_rich('形').first);
      await tester.pumpAndSettle();
      expect(_rich('動詞接'), findsOneWidget);

      await tester.tap(find.text('看全部術語'));
      await tester.pumpAndSettle();
      expect(_path(container), '/learn/notes?kind=term');
    });

    testWidgets('沒有術語時不顯示該區', (tester) async {
      await _pump(tester, backend);
      expect(find.text('相關術語'), findsNothing);
    });
  });

  group('小測驗', () {
    setUp(() {
      backend.drills.sessionStub.returns([
        choiceQuestion(reference: refFixture(QuestionType.recog, drillId: 'a')),
        choiceQuestion(
          body: choiceBodyFixture(
            options: [optionFixture('a', '書'), optionFixture('b', '筆')],
          ),
          reference: refFixture(QuestionType.recog, drillId: 'b'),
        ),
      ]);
      backend.drills.gradeStub.returns(drillOk);
    });

    testWidgets('以文法點為目標取 3 題，同日同 seed', (tester) async {
      await _pump(tester, backend);

      final [filter, seed, audio] = backend.drills.sessionStub.calls.single;
      final dto = filter! as DrillFilterDto;
      expect(dto.target, 'gr.wa');
      expect(dto.count, 3);
      expect(dto.lessonId, isNull);
      expect(seed, sessionSeed('2026-03-02'));
      expect(audio, isTrue);
    });

    testWidgets('按下開始前不出題，避免畫面外自動播音', (tester) async {
      final tts = FakeTtsEngine();
      backend.drills.sessionStub.returns([
        choiceQuestion(
          prompt: promptFixture(
            text: sentenceFixture(),
            speech: const SpeechDto(text: '猫', kana: 'ねこ'),
            autoplay: true,
          ),
        ),
      ]);
      await _pump(tester, backend, tts: tts);

      expect(find.text('小測驗'), findsOneWidget);
      expect(tts.spoken, isEmpty);
      expect(find.text('貓'), findsNothing);
    });

    testWidgets('作完顯示結果，不蓋章，可再做一次', (tester) async {
      await _pump(tester, backend);
      await tester.tap(find.text('開始小測驗'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('書'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();

      expect(find.textContaining('答對 2 題'), findsOneWidget);
      expect(find.byType(HankoBadge), findsNothing);
      expect(backend.drills.gradeStub.calls, hasLength(2));

      await tester.tap(find.text('再做一次'));
      await tester.pumpAndSettle();
      expect(find.text('貓'), findsOneWidget);
      expect(backend.drills.sessionStub.calls, hasLength(1));
    });

    testWidgets('語音探測完成前不取題', (tester) async {
      final probe = Completer<void>();
      await _pump(tester, backend, tts: FakeTtsEngine(probeGate: probe.future));

      expect(backend.drills.sessionStub.calls, isEmpty);
      probe.complete();
      await tester.pumpAndSettle();
      expect(backend.drills.sessionStub.calls, hasLength(1));
    });

    testWidgets('無聲模式傳 audio=false', (tester) async {
      await _pump(
        tester,
        backend,
        settings: applyPatch(allHintsSeen(), settingsPatch(silentMode: true)),
      );
      expect(backend.drills.sessionStub.calls.single[2], isFalse);
    });

    testWidgets('沒有題目時不顯示小測驗', (tester) async {
      backend.drills.sessionStub.returns(const []);
      await _pump(tester, backend);
      expect(find.text('小測驗'), findsNothing);
    });

    testWidgets('取題失敗可重試，文章仍在', (tester) async {
      backend.drills.sessionStub.throws(const StorageFailure());
      await _pump(tester, backend);

      expect(find.byType(ErrorSlip), findsOneWidget);
      expect(_rich('先說出話題'), findsOneWidget);

      backend.drills.sessionStub.returns([choiceQuestion()]);
      await _scrollTo(tester, find.text('重試'));
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.text('開始小測驗'), findsOneWidget);
    });
  });

  group('狀態', () {
    testWidgets('載入時顯示骨架', (tester) async {
      final gate = Completer<void>();
      backend.grammar.detailStub.gate = gate.future;
      await _pump(tester, backend, settle: false);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SkeletonLines), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('錯誤時有重試，也能返回', (tester) async {
      backend.grammar.detailStub.throws(const NotFoundFailure());
      await _pump(tester, backend);

      expect(find.byType(ErrorSlip), findsOneWidget);
      expect(find.text('返回'), findsOneWidget);

      backend.grammar.detailStub.returns(grammarDetailOf());
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(_rich('先說出話題'), findsOneWidget);
    });

    testWidgets('320 寬、1.5 倍字級不溢位', (tester) async {
      backend.grammar.detailStub.returns(
        grammarDetailOf(
          exampleCount: 5,
          contrast: const [GrammarRefDto(id: 'gr.ga', titleZh: '{ja:が}')],
          terms: const [termFixture],
        ),
      );
      backend.drills.sessionStub.returns([choiceQuestion()]);
      await _pump(tester, backend, width: 320, textScale: 1.5, height: 800);

      expect(tester.takeException(), isNull);
    });
  });
}

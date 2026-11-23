import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/ja_text.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:japanese_learn_app/core/text/ruby_line.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:japanese_learn_app/design/widgets/censor_bar.dart';
import 'package:japanese_learn_app/design/widgets/choice_tile.dart';
import 'package:japanese_learn_app/design/widgets/speak_button.dart';
import 'package:japanese_learn_app/features/quiz/quiz.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import 'quiz_fixtures.dart';
import 'quiz_harness.dart';

ChoiceTileState _stateOf(WidgetTester tester, String text) => tester
    .widget<ChoiceTile>(
      find.ancestor(of: find.text(text), matching: find.byType(ChoiceTile)),
    )
    .state;

Finder _heroMixed(String source) => find.byWidgetPredicate(
  (w) => w is MixedText && w.source == source && w.scale == TypeScale.jaHero,
);

Finder _jaOption(String text) =>
    find.byWidgetPredicate((w) => w is JaText && w.data == text);

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.drills.gradeStub.returns(drillOk);
  });

  group('Choice', () {
    testWidgets('答對：立即標記、顯示回饋、reference 原樣帶回', (tester) async {
      final reference = refFixture(
        QuestionType.substitution,
        drillId: 'dr.7',
        variant: 2,
      );
      final question = choiceQuestion(
        type: QuestionType.substitution,
        reference: reference,
      );
      await pumpQuiz(tester, [question], backend: backend);

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();

      expect(_stateOf(tester, '貓'), ChoiceTileState.correct);
      expect(_stateOf(tester, '狗'), ChoiceTileState.dimmed);
      expect(find.text('答對了'), findsOneWidget);
      final call = backend.drills.gradeStub.calls.single;
      expect(identical(call[0], reference), isTrue);
      expect(call[1], const AnswerPayload.choice(optionId: 'a'));
    });

    testWidgets('判定回來前已依 correct_option_id 標記', (tester) async {
      final gate = Completer<void>();
      backend.drills.gradeStub.gate = gate.future;
      await pumpQuiz(tester, [choiceQuestion()], backend: backend);

      await tester.tap(find.text('狗'));
      await tester.pump();

      expect(_stateOf(tester, '狗'), ChoiceTileState.wrong);
      expect(_stateOf(tester, '貓'), ChoiceTileState.correct);
      expect(find.text('不對喔'), findsNothing);

      gate.complete();
      backend.drills.gradeStub.returns(drillWrong());
      await tester.pumpAndSettle();
      expect(find.text('不對喔'), findsOneWidget);
    });

    testWidgets('最終以 Rust 為準：本地答對但 Rust 判錯', (tester) async {
      backend.drills.gradeStub.returns(drillWrong());
      await pumpQuiz(tester, [choiceQuestion()], backend: backend);

      await tester.tap(find.text('貓'));
      await tester.pumpAndSettle();

      expect(_stateOf(tester, '貓'), ChoiceTileState.wrong);
      expect(find.text('不對喔'), findsOneWidget);
    });

    testWidgets('答錯顯示該項 why_zh 與正解', (tester) async {
      backend.drills.gradeStub.returns(drillWrong(whyZh: '這是敬語的場合'));
      await pumpQuiz(tester, [
        choiceQuestion(type: QuestionType.zhToJaChoice),
      ], backend: backend);

      await tester.tap(find.text('狗'));
      await tester.pumpAndSettle();

      expect(find.text('這是敬語的場合'), findsOneWidget);
      expect(find.text('正確答案'), findsOneWidget);
    });

    testWidgets('選項語言：ja 用 JaText、zh 用 MixedText、romaji 用一般文字', (tester) async {
      await pumpQuiz(tester, [
        choiceQuestion(
          type: QuestionType.zhToJaChoice,
          body: choiceBodyFixture(
            options: [optionFixture('a', 'はい'), optionFixture('b', 'いいえ')],
          ),
        ),
      ], backend: backend);
      expect(_jaOption('はい'), findsOneWidget);

      await pumpQuiz(tester, [choiceQuestion()], backend: FakeBackend());
      expect(
        find.byWidgetPredicate((w) => w is MixedText && w.source == '貓'),
        findsOneWidget,
      );

      await pumpQuiz(tester, [
        choiceQuestion(
          type: QuestionType.kanaRead,
          body: choiceBodyFixture(
            options: [optionFixture('a', 'ka'), optionFixture('b', 'ki')],
          ),
          prompt: promptFixture(plainText: '{ja:か}'),
        ),
      ], backend: FakeBackend());
      expect(_jaOption('ka'), findsNothing);
      expect(find.text('ka'), findsOneWidget);
    });

    testWidgets('有 sentence 的選項用 RubyLine', (tester) async {
      await pumpQuiz(tester, [
        choiceQuestion(
          type: QuestionType.zhToJaChoice,
          body: choiceBodyFixture(
            options: [
              optionFixture('a', '私は学生です。', sentence: sentenceFixture()),
              optionFixture('b', '別の', sentence: sentenceFixture(id: 'se.2')),
            ],
          ),
        ),
      ], backend: backend);
      expect(find.byType(RubyLine), findsNWidgets(2));
    });

    testWidgets('blank_word_index：題幹畫空格，答後補上', (tester) async {
      await pumpQuiz(tester, [
        choiceQuestion(
          type: QuestionType.particleFill,
          prompt: promptFixture(text: sentenceFixture()),
          body: choiceBodyFixture(
            options: [optionFixture('a', 'は'), optionFixture('b', 'が')],
            blank: 1,
          ),
        ),
      ], backend: backend);

      expect(tester.widget<RubyLine>(find.byType(RubyLine)).blankWordIndex, 1);

      await tester.tap(_jaOption('が'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<RubyLine>(find.byType(RubyLine).first).blankWordIndex,
        isNull,
      );
    });
  });

  group('hide_text_until_answered', () {
    QuestionDto listenMeaning() => choiceQuestion(
      type: QuestionType.listenMeaning,
      reference: refFixture(
        QuestionType.listenMeaning,
        contentId: 'se.l01.001',
        drillId: 'dr.3',
      ),
      prompt: promptFixture(
        instruction: '聽句子，選出意思',
        text: sentenceFixture(),
        speech: sentenceFixture().speech,
        autoplay: true,
        hide: true,
      ),
      body: choiceBodyFixture(
        options: [optionFixture('a', '我是學生'), optionFixture('b', '我是老師')],
      ),
      focusIds: const ['gr.wa'],
    );

    void expectNoJapanese() {
      expect(find.byType(RubyLine), findsNothing);
      for (final text in ['私', '学生', 'わたし', 'がくせい', 'watashi', 'gakusei']) {
        expect(find.text(text), findsNothing, reason: text);
      }
    }

    testWidgets('作答前日文、假名、羅馬字都不在 widget tree', (tester) async {
      await pumpQuiz(tester, [listenMeaning()], backend: backend);

      expectNoJapanese();
      expect(find.byType(CensorBar), findsOneWidget);
      expect(find.byType(SpeakButton), findsOneWidget);
    });

    testWidgets('答後一次展開全文、中文、語法重點', (tester) async {
      backend.peek.peekStub.returns(peekGrammar);
      backend.drills.gradeStub.returns(
        DrillResultDto(
          isCorrect: true,
          correctDisplay: '我是學生',
          reveal: sentenceFixture(),
        ),
      );
      await pumpQuiz(tester, [listenMeaning()], backend: backend);

      await tester.tap(find.text('我是學生'));
      await tester.pumpAndSettle();

      expect(find.byType(CensorBar), findsNothing);
      expect(find.byType(RubyLine), findsOneWidget);
      expect(find.text('学生'), findsOneWidget);
      expect(find.text('我是學生。'), findsOneWidget);
      expect(find.text('語法重點'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is MixedText && w.source == '主題助詞 {ja:は}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('KanaListen 只有播放鈕，不顯示任何文字，自動播一次', (tester) async {
      final tts = FakeTtsEngine();
      const speech = SpeechDto(text: 'あ', kana: 'あ');
      await pumpQuiz(
        tester,
        [
          choiceQuestion(
            type: QuestionType.kanaListen,
            reference: refFixture(QuestionType.kanaListen, contentId: 'ka.a'),
            prompt: promptFixture(speech: speech, autoplay: true, hide: true),
            body: choiceBodyFixture(
              options: [optionFixture('a', 'あ'), optionFixture('b', 'い')],
            ),
          ),
        ],
        backend: backend,
        tts: tts,
        grader: const KanaGrader(),
      );
      backend.kana.submitStub.returns(
        const KanaSubmitResultDto(isCorrect: true, correctDisplay: '{ja:あ} a'),
      );

      expect(find.byType(CensorBar), findsNothing);
      expect(tts.spoken, hasLength(1));
      expect(_jaOption('あ'), findsOneWidget);
    });

    testWidgets('Rust 帶 plain_text 也要藏（VocabListen）', (tester) async {
      await pumpQuiz(tester, [
        choiceQuestion(
          type: QuestionType.vocabListen,
          prompt: promptFixture(
            plainText: '{ja:猫|ねこ}',
            speech: const SpeechDto(text: '猫', kana: 'ねこ'),
            autoplay: true,
            hide: true,
          ),
        ),
      ], backend: backend);

      expect(find.text('猫'), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is MixedText && w.source.contains('猫')),
        findsNothing,
      );
    });
  });

  group('KanaConfuse', () {
    testWidgets('shape：題幹是讀音（大字），選項是同組的字', (tester) async {
      backend.kana.submitStub.returns(
        const KanaSubmitResultDto(isCorrect: true, correctDisplay: '{ja:ぬ}'),
      );
      await pumpQuiz(
        tester,
        [
          choiceQuestion(
            type: QuestionType.kanaConfuse,
            reference: refFixture(QuestionType.kanaConfuse, contentId: 'ka.nu'),
            prompt: promptFixture(
              instruction: '看讀音，選出正確的字',
              plainText: 'nu',
              speech: const SpeechDto(text: 'ぬ', kana: 'ぬ'),
            ),
            body: choiceBodyFixture(
              options: [
                optionFixture('ka.nu', 'ぬ'),
                optionFixture('ka.me', 'め'),
              ],
              correct: 'ka.nu',
            ),
            explainZh: '{ja:ぬ} 收筆有圈',
          ),
        ],
        backend: backend,
        grader: const KanaGrader(),
      );

      expect(_heroMixed('nu'), findsOneWidget);
      expect(_jaOption('ぬ'), findsOneWidget);
      expect(_jaOption('め'), findsOneWidget);
      // 讀音題幹可以先聽
      expect(find.byType(SpeakButton), findsOneWidget);

      await tester.tap(_jaOption('ぬ'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is MixedText && w.source == '{ja:ぬ} 收筆有圈',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cross_script：題幹是另一種文字的字，選項是目標文字', (tester) async {
      await pumpQuiz(
        tester,
        [
          choiceQuestion(
            type: QuestionType.kanaConfuse,
            reference: refFixture(QuestionType.kanaConfuse, contentId: 'ka.ka'),
            prompt: promptFixture(instruction: '選出對應的片假名', plainText: '{ja:か}'),
            body: choiceBodyFixture(
              options: [
                optionFixture('ka.ka', 'カ'),
                optionFixture('ka.ki', 'キ'),
              ],
              correct: 'ka.ka',
            ),
          ),
        ],
        backend: backend,
        grader: const KanaGrader(),
      );

      expect(_heroMixed('{ja:か}'), findsOneWidget);
      expect(_jaOption('カ'), findsOneWidget);
      expect(_jaOption('キ'), findsOneWidget);
      expect(find.byType(SpeakButton), findsNothing);
    });
  });

  group('答後朗讀', () {
    const speech = SpeechDto(text: 'か', kana: 'か');

    testWidgets('KanaRead：作答前沒有播放鈕，答後自動念', (tester) async {
      final tts = FakeTtsEngine();
      backend.kana.submitStub.returns(
        const KanaSubmitResultDto(isCorrect: true, correctDisplay: 'ka'),
      );
      await pumpQuiz(
        tester,
        [
          choiceQuestion(
            type: QuestionType.kanaRead,
            reference: refFixture(QuestionType.kanaRead, contentId: 'ka.ka'),
            prompt: promptFixture(plainText: '{ja:か}', speech: speech),
            body: choiceBodyFixture(
              options: [optionFixture('a', 'ka'), optionFixture('b', 'ki')],
            ),
          ),
        ],
        backend: backend,
        tts: tts,
        grader: const KanaGrader(),
      );

      expect(_heroMixed('{ja:か}'), findsOneWidget);
      expect(find.byType(SpeakButton), findsNothing);
      expect(tts.spoken, isEmpty);

      await tester.tap(find.text('ka'));
      await tester.pumpAndSettle();
      expect(tts.spoken, hasLength(1));
      expect(tts.spoken.single.text, 'か');
    });

    testWidgets('自動播放關閉時答後不自動念，但有播放鈕', (tester) async {
      final tts = FakeTtsEngine();
      backend.kana.submitStub.returns(
        const KanaSubmitResultDto(isCorrect: true, correctDisplay: 'ka'),
      );
      await pumpQuiz(
        tester,
        [
          choiceQuestion(
            type: QuestionType.kanaRead,
            reference: refFixture(QuestionType.kanaRead, contentId: 'ka.ka'),
            prompt: promptFixture(plainText: '{ja:か}', speech: speech),
            body: choiceBodyFixture(
              options: [optionFixture('a', 'ka'), optionFixture('b', 'ki')],
            ),
          ),
        ],
        backend: backend,
        tts: tts,
        grader: const KanaGrader(),
        settings: allHintsSeen(autoplay: false),
      );

      await tester.tap(find.text('ka'));
      await tester.pumpAndSettle();
      expect(tts.spoken, isEmpty);
      expect(find.byType(SpeakButton), findsOneWidget);
    });

    testWidgets('MinimalPair：答後依序播兩個選項比較', (tester) async {
      final tts = FakeTtsEngine();
      backend.drills.gradeStub.returns(
        const DrillResultDto(isCorrect: true, correctDisplay: '{ja:おばさん} 阿姨'),
      );
      await pumpQuiz(
        tester,
        [
          choiceQuestion(
            type: QuestionType.minimalPair,
            reference: refFixture(
              QuestionType.minimalPair,
              contentId: 'ka.rule.long',
              drillId: 'dr.8',
              variant: 0,
            ),
            prompt: promptFixture(
              speech: const SpeechDto(text: 'おばさん', kana: 'おばさん'),
              hide: true,
              autoplay: true,
            ),
            body: choiceBodyFixture(
              options: [
                optionFixture(
                  'a',
                  '阿姨',
                  speech: const SpeechDto(text: 'おばさん', kana: 'おばさん'),
                ),
                optionFixture(
                  'b',
                  '奶奶',
                  speech: const SpeechDto(text: 'おばあさん', kana: 'おばあさん'),
                ),
              ],
            ),
          ),
        ],
        backend: backend,
        tts: tts,
      );
      tts.spoken.clear();

      await tester.tap(find.text('阿姨'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(tts.spoken.map((r) => r.text), ['おばさん', 'おばあさん']);
    });

    testWidgets('Conjugate：顯示 correct_display 與羅馬字並朗讀', (tester) async {
      final tts = FakeTtsEngine();
      backend.drills.gradeStub.returns(
        const DrillResultDto(isCorrect: true, correctDisplay: '{ja:食べて|たべて}'),
      );
      await pumpQuiz(tester, [typingQuestion()], backend: backend, tts: tts);

      await tester.enterText(find.byType(TextField), 'tabete');
      await tester.pump();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();

      expect(tts.spoken.single.text, 'たべて');
      // FakeTextTools 的 romanizeReading 回傳原字串
      expect(find.text('たべて'), findsWidgets);
      expect(find.text('正確答案'), findsOneWidget);
    });

    testWidgets('Substitution：答後朗讀並提示跟著念', (tester) async {
      final tts = FakeTtsEngine();
      await pumpQuiz(
        tester,
        [
          choiceQuestion(
            type: QuestionType.substitution,
            prompt: promptFixture(plainText: '我是學生。', text: sentenceFixture()),
            body: choiceBodyFixture(
              options: [optionFixture('a', '学生'), optionFixture('b', '先生')],
              blank: 2,
            ),
          ),
        ],
        backend: backend,
        tts: tts,
      );

      await tester.tap(_jaOption('学生').last);
      await tester.pumpAndSettle();

      expect(tts.spoken.single.text, '私は学生です。');
      expect(find.text('跟著念一次。'), findsOneWidget);
    });
  });
}

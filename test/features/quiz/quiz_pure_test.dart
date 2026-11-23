import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/quiz/model/answer_factory.dart';
import 'package:japanese_learn_app/features/quiz/model/feedback_plan.dart';
import 'package:japanese_learn_app/features/quiz/model/match_board.dart';
import 'package:japanese_learn_app/features/quiz/model/question_hints.dart';
import 'package:japanese_learn_app/features/quiz/model/quiz_verdict.dart';
import 'package:japanese_learn_app/features/quiz/model/reorder_draft.dart';

import '../../support/fixtures.dart';
import 'quiz_fixtures.dart';

String _plain(String mixed) =>
    mixed.replaceAllMapped(RegExp(r'\{ja:([^|}]*)(\|[^}]*)?\}'), (m) => m[1]!);

void main() {
  group('questionHintOf', () {
    const expected = {
      QuestionType.recog: '看日文，選出意思。',
      QuestionType.vocabListen: '聽發音，選出意思。',
      QuestionType.produce: '看中文，先在心裡說出日文，再翻面自評。',
      QuestionType.kanaRead: '看字，選出讀音。',
      QuestionType.kanaListen: '聽音，選出聽到的字。',
      QuestionType.kanaMatch: '先點左邊的字，再點右邊的讀音。',
      QuestionType.kanaConfuse: '這幾個字長得很像，選出正確的那個。',
      QuestionType.minimalPair: '聽一次，選出你聽到的是哪一個。',
      QuestionType.kanaWord: '拼拼看這個詞，選出意思或打出讀音。',
      QuestionType.substitution: '依中文提示，選出要換進空格的字詞。',
      QuestionType.reorder: '點詞塊排出句子，再點一下可以放回去。',
      QuestionType.particleFill: '選出空格裡該放的助詞。',
      QuestionType.zhToJaChoice: '看中文，選出最自然的日文。',
      QuestionType.listenMeaning: '先聽，再選意思。答完才看得到文字。',
      QuestionType.situationResponse: '想想這個情境，選出最得體的回應。',
      QuestionType.conjugate: '用英文字母打出答案，上方會顯示假名。',
      QuestionType.registerConvert: '把這句換成指定的語氣，點詞塊排好。',
      QuestionType.shadowing: '聽完跟著念，再選跟得上的程度。不評分發音。',
      QuestionType.falseFriend: '字面長得像中文，選出它在日文的意思。',
    };

    test('涵蓋全部 19 種題型，文案與 §3.12 相同', () {
      expect(expected.length, QuestionType.values.length);
      for (final type in QuestionType.values) {
        expect(questionHintOf(type), expected[type], reason: type.name);
      }
    });
  });

  group('buildAnswer', () {
    test('reference 原樣帶回（含 variant）', () {
      final reference = refFixture(
        QuestionType.conjugate,
        drillId: 'dr.1',
        variant: 7,
      );
      final answer = buildAnswer(
        reference,
        const AnswerPayload.typing(input: 'tabete'),
        expectedReps: 4,
        durationMs: 321,
      );
      expect(identical(answer.reference, reference), isTrue);
      expect(answer.expectedReps, 4);
      expect(answer.durationMs, 321);
      expect(answer.hintUsed, isFalse);
      expect(answer.attempts, 1);
    });
  });

  group('ReorderDraft', () {
    test('點一下放上去，再點移回', () {
      const empty = ReorderDraft();
      final one = empty.toggle(2).toggle(0);
      expect(one.placed, [2, 0]);
      expect(one.isPlaced(2), isTrue);
      expect(one.toggle(2).placed, [0]);
      expect(empty.placed, isEmpty);
    });

    test('全部放完才算完成', () {
      final draft = const ReorderDraft().toggle(0).toggle(1);
      expect(draft.isComplete(3), isFalse);
      expect(draft.toggle(2).isComplete(3), isTrue);
    });
  });

  group('MatchBoard', () {
    const pairs = [
      MatchPairDto(leftId: 'ka.a', left: 'あ', rightId: 'ka.a', right: 'a'),
      MatchPairDto(leftId: 'ka.i', left: 'い', rightId: 'ka.i', right: 'i'),
      MatchPairDto(leftId: 'ka.u', left: 'う', rightId: 'ka.u', right: 'u'),
    ];

    test('右欄重排，不會和左欄同順序（Rust 只洗 pairs）', () {
      final board = MatchBoard.start(pairs, seed: 12345);
      expect(board.rightOrder.toSet(), {0, 1, 2});
      expect(board.rightOrder, isNot([0, 1, 2]));
    });

    test('同一個 seed 順序固定', () {
      expect(
        MatchBoard.start(pairs, seed: 7).rightOrder,
        MatchBoard.start(pairs, seed: 7).rightOrder,
      );
    });

    test('配對正確：兩邊都標成已配對，選取清空', () {
      final board = MatchBoard.start(pairs, seed: 1).tapLeft(1).tapRight(1);
      expect(board.isMatched(1), isTrue);
      expect(board.selectedLeft, isNull);
      expect(board.mistakes, 0);
    });

    test('配錯：記一次錯，標出錯的右欄，選取清空', () {
      final board = MatchBoard.start(pairs, seed: 1).tapLeft(0).tapRight(2);
      expect(board.mistakes, 1);
      expect(board.isMatched(0), isFalse);
      expect(board.wrongRight, 2);
      expect(board.selectedLeft, isNull);
    });

    test('沒選左欄時點右欄沒有作用', () {
      final board = MatchBoard.start(pairs, seed: 1);
      expect(identical(board.tapRight(0), board), isTrue);
    });

    test('已配對的不能再選', () {
      final done = MatchBoard.start(pairs, seed: 1).tapLeft(0).tapRight(0);
      expect(done.tapLeft(0).selectedLeft, isNull);
      expect(done.tapLeft(1).tapRight(0).isMatched(1), isFalse);
    });

    test('全對才算 allCorrect', () {
      var board = MatchBoard.start(pairs, seed: 1);
      for (final i in [0, 1, 2]) {
        board = board.tapLeft(i).tapRight(i);
      }
      expect(board.isComplete, isTrue);
      expect(board.allCorrect, isTrue);

      final slip = MatchBoard.start(pairs, seed: 1).tapLeft(0).tapRight(1);
      expect(slip.allCorrect, isFalse);
    });
  });

  group('feedbackPlanFor', () {
    final sentence = sentenceFixture(id: 'se.1');

    test('答對不顯示 why_zh；答錯才顯示', () {
      final q = choiceQuestion(
        body: choiceBodyFixture(
          options: [
            optionFixture('a', '貓'),
            optionFixture('b', '狗', whyZh: '狗是別的字'),
          ],
        ),
      );
      final right = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'a'),
        const QuizVerdict(isCorrect: true, correctDisplay: '貓'),
        plainOf: _plain,
      );
      final wrong = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'b'),
        const QuizVerdict(isCorrect: false, correctDisplay: '貓'),
        plainOf: _plain,
      );
      expect(right.whyZh, isNull);
      expect(wrong.whyZh, '狗是別的字');
    });

    test('Rust 回傳的 why_zh 優先於選項自帶的', () {
      final q = choiceQuestion(
        body: choiceBodyFixture(
          options: [optionFixture('b', '狗', whyZh: '本地')],
        ),
      );
      final plan = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'b'),
        const QuizVerdict(isCorrect: false, whyZh: 'Rust'),
        plainOf: _plain,
      );
      expect(plan.whyZh, 'Rust');
    });

    test('explain_zh 以 Rust 為優先，否則退回題目帶的', () {
      final q = choiceQuestion(explainZh: '題目說明');
      final own = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'a'),
        const QuizVerdict(isCorrect: true),
        plainOf: _plain,
      );
      final rust = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'a'),
        const QuizVerdict(isCorrect: true, explainZh: 'Rust 說明'),
        plainOf: _plain,
      );
      expect(own.explainZh, '題目說明');
      expect(rust.explainZh, 'Rust 說明');
    });

    test('correct_display 與 reveal 同句時不重複顯示', () {
      final q = choiceQuestion(type: QuestionType.zhToJaChoice);
      final plan = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'a'),
        QuizVerdict(
          isCorrect: false,
          correctDisplay: '{ja:私は学生です。|わたしはがくせいです。}',
          reveal: sentence,
        ),
        plainOf: _plain,
      );
      expect(plan.correctDisplay, isNull);
      expect(plan.sentence, sentence);
    });

    test('correct_display 提供新資訊時保留（reveal 是句子、display 是助詞）', () {
      final q = choiceQuestion(type: QuestionType.particleFill);
      final plan = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'a'),
        QuizVerdict(
          isCorrect: false,
          correctDisplay: '{ja:は}',
          reveal: sentence,
        ),
        plainOf: _plain,
      );
      expect(plan.correctDisplay, '{ja:は}');
    });

    test('空的 correct_display（Match）不顯示', () {
      final plan = feedbackPlanFor(
        matchQuestion(),
        const AnswerPayload.match(allCorrect: true),
        const QuizVerdict(isCorrect: true),
        plainOf: _plain,
      );
      expect(plan.correctDisplay, isNull);
    });

    test('reveal 就是題幹那句時，回饋條不重複畫句子', () {
      final q = choiceQuestion(
        type: QuestionType.listenMeaning,
        prompt: promptFixture(text: sentence, hide: true),
      );
      final plan = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'a'),
        QuizVerdict(isCorrect: true, reveal: sentence),
        plainOf: _plain,
      );
      expect(plan.sentenceInPrompt, isTrue);
      expect(plan.sentence, sentence);
    });

    test('單字題：reveal 是該字且題幹已有單字，視為題幹已顯示', () {
      final q = choiceQuestion(
        prompt: promptFixture(plainText: '{ja:猫|ねこ}'),
        reference: refFixture(QuestionType.recog, contentId: 'vo.neko'),
      );
      final plan = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'a'),
        QuizVerdict(isCorrect: true, reveal: sentenceFixture(id: 'vo.neko')),
        plainOf: _plain,
      );
      expect(plan.sentenceInPrompt, isTrue);
    });

    test('focus_ids 不含 ka.*（假名題沒有語法重點）', () {
      final q = choiceQuestion(focusIds: const ['ka.a', 'gr.wa', 'vo.neko']);
      final plan = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'a'),
        const QuizVerdict(isCorrect: true),
        plainOf: _plain,
      );
      expect(plan.focusIds, ['gr.wa', 'vo.neko']);
    });

    test('展開單字時不重複該字的語法重點', () {
      final q = choiceQuestion(focusIds: const ['vo.neko', 'gr.wa']);
      final plan = feedbackPlanFor(
        q,
        const AnswerPayload.choice(optionId: 'a'),
        const QuizVerdict(isCorrect: true),
        plainOf: _plain,
        vocabExpanded: true,
      );
      expect(plan.focusIds, ['gr.wa']);
    });
  });

  group('afterAnswerSpeechOf', () {
    const speech = SpeechDto(text: 'あ', kana: 'あ');

    test('KanaRead 與 KanaWord 答後念題幹', () {
      for (final type in [QuestionType.kanaRead, QuestionType.kanaWord]) {
        final q = choiceQuestion(
          type: type,
          prompt: promptFixture(plainText: '{ja:あ}', speech: speech),
        );
        expect(
          afterAnswerSpeechOf(q, const QuizVerdict(isCorrect: true)),
          speech,
          reason: type.name,
        );
      }
    });

    test('Substitution 答後念完整句', () {
      final sentence = sentenceFixture();
      final q = choiceQuestion(
        type: QuestionType.substitution,
        prompt: promptFixture(text: sentence),
      );
      expect(
        afterAnswerSpeechOf(q, const QuizVerdict(isCorrect: true)),
        sentence.speech,
      );
    });

    test('Conjugate 沒有 speech，用 expected_reading 念', () {
      final speechOut = afterAnswerSpeechOf(
        typingQuestion(),
        const QuizVerdict(isCorrect: false),
      );
      expect(speechOut?.text, 'たべて');
      expect(speechOut?.kana, 'たべて');
    });

    test('其他題型答後不自動念', () {
      expect(
        afterAnswerSpeechOf(
          choiceQuestion(
            type: QuestionType.listenMeaning,
            prompt: promptFixture(speech: speech),
          ),
          const QuizVerdict(isCorrect: true),
        ),
        isNull,
      );
    });
  });

  group('speechAllowedBeforeAnswer', () {
    test('KanaRead、KanaWord 作答前不能先聽（聽了就知道答案）', () {
      expect(speechAllowedBeforeAnswer(QuestionType.kanaRead), isFalse);
      expect(speechAllowedBeforeAnswer(QuestionType.kanaWord), isFalse);
    });

    test('KanaConfuse 的讀音題幹可先聽', () {
      expect(speechAllowedBeforeAnswer(QuestionType.kanaConfuse), isTrue);
    });
  });
}

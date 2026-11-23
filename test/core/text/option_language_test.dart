import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/display_context.dart';
import 'package:japanese_learn_app/core/text/option_language.dart';

void main() {
  test('optionLanguageOf 對照 §7.2 全部 19 值', () {
    const expected = {
      QuestionType.recog: OptionLanguage.zh,
      QuestionType.vocabListen: OptionLanguage.zh,
      QuestionType.produce: OptionLanguage.none,
      QuestionType.kanaRead: OptionLanguage.romaji,
      QuestionType.kanaListen: OptionLanguage.ja,
      QuestionType.kanaMatch: OptionLanguage.none,
      QuestionType.kanaConfuse: OptionLanguage.ja,
      QuestionType.minimalPair: OptionLanguage.zh,
      QuestionType.kanaWord: OptionLanguage.zh,
      QuestionType.substitution: OptionLanguage.ja,
      QuestionType.reorder: OptionLanguage.none,
      QuestionType.particleFill: OptionLanguage.ja,
      QuestionType.zhToJaChoice: OptionLanguage.ja,
      QuestionType.listenMeaning: OptionLanguage.zh,
      QuestionType.situationResponse: OptionLanguage.ja,
      QuestionType.conjugate: OptionLanguage.none,
      QuestionType.registerConvert: OptionLanguage.none,
      QuestionType.shadowing: OptionLanguage.none,
      QuestionType.falseFriend: OptionLanguage.zh,
    };

    expect(expected.length, QuestionType.values.length);
    for (final type in QuestionType.values) {
      expect(optionLanguageOf(type), expected[type], reason: '$type');
    }
  });

  group('questionContext', () {
    const peek = PeekDto(
      refId: 'vo.a',
      title: 'a',
      summaryZh: '',
      lessonId: 'le.l03',
    );

    test('有 peek 用其 lessonId，否則用 fallback', () {
      expect(questionContext(peek, 'le.l09').lessonId, 'le.l03');
      expect(questionContext(null, 'le.l09').lessonId, 'le.l09');
    });
  });
}

import '../backend/frb/dto.dart';

enum OptionLanguage { ja, zh, romaji, none }

/// §7.2：依題型決定 `OptionDto.text` 的語言。switch 窮舉，不寫 default，
/// 新增題型時編譯失敗。
OptionLanguage optionLanguageOf(QuestionType type) => switch (type) {
  QuestionType.kanaListen ||
  QuestionType.kanaConfuse ||
  QuestionType.substitution ||
  QuestionType.particleFill ||
  QuestionType.zhToJaChoice ||
  QuestionType.situationResponse => OptionLanguage.ja,
  QuestionType.recog ||
  QuestionType.vocabListen ||
  QuestionType.minimalPair ||
  QuestionType.kanaWord ||
  QuestionType.listenMeaning ||
  QuestionType.falseFriend => OptionLanguage.zh,
  QuestionType.kanaRead => OptionLanguage.romaji,
  QuestionType.produce ||
  QuestionType.kanaMatch ||
  QuestionType.reorder ||
  QuestionType.conjugate ||
  QuestionType.registerConvert ||
  QuestionType.shadowing => OptionLanguage.none,
};

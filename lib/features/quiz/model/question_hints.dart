import '../../../core/backend/frb/dto.dart';

/// 題型第一次出現時的操作提示（§3.12）。switch 窮舉，新增題型時編譯失敗。
/// 干擾項不足時，`Recog`、`VocabListen` 退回 `SelfGrade`（§3.4），不能寫「選出」。
bool isSelfGradeFallback(QuestionDto question) =>
    question.body is QuestionBodyDto_SelfGrade &&
    (question.questionType == QuestionType.recog ||
        question.questionType == QuestionType.vocabListen);

String _byListen(QuestionDto question, String listen, String see) =>
    question.questionType == QuestionType.vocabListen ? listen : see;

/// 依實際作答方式的操作提示。
String questionHintFor(QuestionDto question) => isSelfGradeFallback(question)
    ? _byListen(question, '先聽發音，想想意思，再翻面自評。', '先想想意思，再翻面自評。')
    : questionHintOf(question.questionType);

/// 題幹的說明行；`instruction_zh` 由 Rust 依題型給，退回自評時要換掉。
String instructionOf(QuestionDto question) => isSelfGradeFallback(question)
    ? _byListen(question, '聽聲音，想想是什麼意思，翻面看答案', '想想這是什麼意思，翻面看答案')
    : question.prompt.instructionZh;

String questionHintOf(QuestionType type) => switch (type) {
  QuestionType.recog => '看日文，選出意思。',
  QuestionType.vocabListen => '聽發音，選出意思。',
  QuestionType.produce => '看中文，先在心裡說出日文，再翻面自評。',
  QuestionType.kanaRead => '看字，選出讀音。',
  QuestionType.kanaListen => '聽音，選出聽到的字。',
  QuestionType.kanaMatch => '先點左邊的字，再點右邊的讀音。',
  QuestionType.kanaConfuse => '這幾個字長得很像，選出正確的那個。',
  QuestionType.minimalPair => '聽一次，選出你聽到的是哪一個。',
  QuestionType.kanaWord => '拼拼看這個詞，選出意思或打出讀音。',
  QuestionType.substitution => '依中文提示，選出要換進空格的字詞。',
  QuestionType.reorder => '點詞塊排出句子，再點一下可以放回去。',
  QuestionType.particleFill => '選出空格裡該放的助詞。',
  QuestionType.zhToJaChoice => '看中文，選出最自然的日文。',
  QuestionType.listenMeaning => '先聽，再選意思。答完才看得到文字。',
  QuestionType.situationResponse => '想想這個情境，選出最得體的回應。',
  QuestionType.conjugate => '用英文字母打出答案，上方會顯示假名。',
  QuestionType.registerConvert => '把這句換成指定的語氣，點詞塊排好。',
  QuestionType.shadowing => '聽完跟著念，再選跟得上的程度。不評分發音。',
  QuestionType.falseFriend => '字面長得像中文，選出它在日文的意思。',
};

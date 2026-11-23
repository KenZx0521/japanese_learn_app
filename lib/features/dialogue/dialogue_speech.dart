import '../../core/backend/frb/dto.dart';
import '../../core/tts/tts_engine.dart';

/// 連播時句與句之間的停頓。
const dialogueTurnGap = Duration(milliseconds: 500);

/// 逐詞播放的詞間停頓（課綱 §10.1）。
const dialogueWordGap = Duration(milliseconds: 400);

/// 同一句可能在對話裡出現兩次，用位置當語音 id，高亮才不會亮兩句。
String turnSpeechId(DialogueDto dialogue, int index) => '${dialogue.id}#$index';

/// [id] 是否屬於第 [index] 句（整句或逐詞）。
bool isTurnSpeech(String id, DialogueDto dialogue, int index) {
  final base = turnSpeechId(dialogue, index);
  return id == base || id.startsWith('$base.');
}

VoiceSlot voiceSlotOf(DialogueDto dialogue, String roleId) {
  for (final role in dialogue.roles) {
    if (role.id == roleId) {
      return role.voice == 'b' ? VoiceSlot.b : VoiceSlot.a;
    }
  }
  return VoiceSlot.a;
}

String roleNameOf(DialogueDto dialogue, String roleId) {
  for (final role in dialogue.roles) {
    if (role.id == roleId) return role.nameZh;
  }
  return roleId;
}

SpeechRequest turnRequest(DialogueDto dialogue, int index) {
  final turn = dialogue.turns[index];
  return SpeechRequest.fromDto(
    turnSpeechId(dialogue, index),
    turn.sentence.speech,
    voice: voiceSlotOf(dialogue, turn.role),
  );
}

/// 逐詞：`text`、`kana` 都送 `speech_kana`（§6.1，助詞 は 已是 わ）。
List<SpeechRequest> wordRequests(DialogueDto dialogue, int index) {
  final turn = dialogue.turns[index];
  final base = turnSpeechId(dialogue, index);
  final voice = voiceSlotOf(dialogue, turn.role);
  return [
    for (final (i, word) in turn.sentence.words.indexed)
      if (!word.isPunct && word.speechKana.isNotEmpty)
        SpeechRequest(
          id: '$base.w$i',
          text: word.speechKana,
          kana: word.speechKana,
          voice: voice,
        ),
  ];
}

List<SpeechRequest> allTurnRequests(DialogueDto dialogue) => [
  for (var i = 0; i < dialogue.turns.length; i++) turnRequest(dialogue, i),
];

import 'package:material_ui/material_ui.dart' show immutable;

import '../backend/frb/dto.dart';

enum TtsSpeed { normal, slow }

enum VoiceSlot { a, b }

enum TtsAvailabilityKind {
  unknown,
  ready,
  voiceNotDownloaded,
  noJapaneseVoice,
  engineMissing,
}

@immutable
final class TtsAvailability {
  const TtsAvailability(this.kind, {this.voiceName, this.voiceIds = const []});

  static const unknown = TtsAvailability(TtsAvailabilityKind.unknown);

  final TtsAvailabilityKind kind;
  final String? voiceName;

  /// 裝置上的日語語音（X2 語音選擇，§3.9；角色語音，§3.7）。
  final List<String> voiceIds;

  bool get isReady => kind == TtsAvailabilityKind.ready;

  @override
  bool operator ==(Object other) =>
      other is TtsAvailability &&
      other.kind == kind &&
      other.voiceName == voiceName &&
      _sameList(other.voiceIds, voiceIds);

  @override
  int get hashCode => Object.hash(kind, voiceName, voiceIds.length);

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 一句要念的內容。`id` 用內容 ID，例如 `se.l05.001`（§6.1）。
@immutable
final class SpeechRequest {
  const SpeechRequest({
    required this.id,
    required this.text,
    required this.kana,
    this.speed = TtsSpeed.normal,
    this.voice = VoiceSlot.a,
    this.voiceId,
  });

  factory SpeechRequest.fromDto(
    String id,
    SpeechDto dto, {
    TtsSpeed speed = TtsSpeed.normal,
    VoiceSlot voice = VoiceSlot.a,
  }) => SpeechRequest(
    id: id,
    text: dto.text,
    kana: dto.kana,
    speed: speed,
    voice: voice,
  );

  /// 行動平台送 text，Linux 送 kana（實證 #9）。
  final String id, text, kana;
  final TtsSpeed speed;
  final VoiceSlot voice;

  /// 使用者在 X2 選的語音，由 `TtsController` 依設定帶入。
  final String? voiceId;

  SpeechRequest withVoiceId(String? value) => SpeechRequest(
    id: id,
    text: text,
    kana: kana,
    speed: speed,
    voice: voice,
    voiceId: value,
  );

  SpeechRequest withSpeed(TtsSpeed value) => SpeechRequest(
    id: id,
    text: text,
    kana: kana,
    speed: value,
    voice: voice,
    voiceId: voiceId,
  );
}

@immutable
sealed class TtsEvent {
  const TtsEvent(this.id);
  final String id;
}

final class TtsStarted extends TtsEvent {
  const TtsStarted(super.id);
}

final class TtsCompleted extends TtsEvent {
  const TtsCompleted(super.id);
}

final class TtsFailed extends TtsEvent {
  const TtsFailed(super.id, this.reason);
  final String reason;
}

abstract interface class TtsEngine {
  Stream<TtsEvent> get events;
  Future<TtsAvailability> probe();
  Future<void> speak(SpeechRequest request);
  Future<void> stop();
}

/// §6.5：`rate <= 0.85` 為慢速，其餘一律當正常速度。
TtsSpeed speedFromRate(double rate) =>
    rate <= 0.85 ? TtsSpeed.slow : TtsSpeed.normal;

const speedRates = {TtsSpeed.slow: 0.7, TtsSpeed.normal: 1.0};

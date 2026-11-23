import 'package:material_ui/material_ui.dart' show immutable;

/// S4 固定四階段（§3.7）：1 盲聽、2 逐句、3 跟讀、4 角色扮演。
const allDialoguePhases = <int>[1, 2, 3, 4];

const dialoguePhaseNames = <int, String>{1: '盲聽', 2: '逐句', 3: '跟讀', 4: '角色扮演'};

const dialoguePhaseNumerals = <int, String>{1: '一', 2: '二', 3: '三', 4: '四'};

/// 無聲模式略過第一、三階段（§3.7）。
List<int> visibleDialoguePhases(List<int> requested, {required bool audio}) => [
  for (final phase in requested)
    if (audio || (phase != 1 && phase != 3)) phase,
];

@immutable
final class DialogueRun {
  const DialogueRun({
    required this.requested,
    required this.audio,
    required this.phase,
  });

  final List<int> requested;
  final bool audio;

  /// 目前階段；null 表示全部跑完。
  final int? phase;

  List<int> get visible => visibleDialoguePhases(requested, audio: audio);
  bool get isDone => phase == null;

  /// [phase] 是否為最後一個要跑的階段。
  bool get isLastPhase => visible.isNotEmpty && phase == visible.last;

  DialogueRun copyWith({bool? audio, required int? phase}) => DialogueRun(
    requested: requested,
    audio: audio ?? this.audio,
    phase: phase,
  );
}

@immutable
sealed class DialogueRunEvent {
  const DialogueRunEvent();
}

final class PhaseCompleted extends DialogueRunEvent {
  const PhaseCompleted();
}

/// 語音可用性改變（`audioAvailableProvider`）。
final class AudioChanged extends DialogueRunEvent {
  const AudioChanged(this.audio);
  final bool audio;
}

DialogueRun initialDialogueRun(List<int> requested, {required bool audio}) {
  final visible = visibleDialoguePhases(requested, audio: audio);
  return DialogueRun(
    requested: requested,
    audio: audio,
    phase: visible.isEmpty ? null : visible.first,
  );
}

DialogueRun reduceDialogueRun(DialogueRun run, DialogueRunEvent event) =>
    switch (event) {
      PhaseCompleted() => run.copyWith(phase: _phaseAfter(run, run.phase)),
      AudioChanged(:final audio) => _withAudio(run, audio),
    };

/// 嚴格大於 [from] 的下一個可見階段，沒有就回 null（結束）。
int? _phaseAfter(DialogueRun run, int? from) {
  if (from == null) return null;
  for (final phase in run.visible) {
    if (phase > from) return phase;
  }
  return null;
}

DialogueRun _withAudio(DialogueRun run, bool audio) {
  final next = run.copyWith(audio: audio, phase: run.phase);
  final current = next.phase;
  if (current == null || next.visible.contains(current)) return next;
  return next.copyWith(phase: _phaseAfter(next, current));
}

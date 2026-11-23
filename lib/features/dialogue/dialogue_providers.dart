import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../core/tts/audio_available.dart';
import 'model/dialogue_run.dart';

/// S3 對話列表（§3.7）。
final dialogueListProvider =
    FutureProvider.autoDispose<List<DialogueSummaryDto>>(
      (ref) => ref.watch(listeningRepositoryProvider).dialogues(),
    );

final dialogueDetailProvider = FutureProvider.autoDispose
    .family<DialogueDto, String>(
      (ref, id) => ref.watch(listeningRepositoryProvider).dialogue(id),
    );

typedef DialogueQuizArgs = ({int seed, String drillIdsKey});

/// 盲聽後的 `quiz_drill_ids`。語音探測完成前停在載入（§6.6），同 seed 重取。
final dialogueQuizProvider = FutureProvider.autoDispose
    .family<List<QuestionDto>, DialogueQuizArgs>((ref, args) {
      if (!ref.watch(audioResolvedProvider)) {
        return Completer<List<QuestionDto>>().future;
      }
      final audio = ref.watch(audioAvailableProvider);
      final ids = args.drillIdsKey.isEmpty
          ? const <String>[]
          : args.drillIdsKey.split(',');
      final filter = DrillFilterDto(drillIds: ids, count: ids.length);
      return ref
          .watch(drillRepositoryProvider)
          .session(filter, args.seed, audio);
    });

/// family 參數：`phases` 比內容，同一段對話重建時不重置進度。
@immutable
final class DialogueRunArgs {
  const DialogueRunArgs({required this.dialogueId, required this.phases});

  final String dialogueId;
  final List<int> phases;

  @override
  bool operator ==(Object other) =>
      other is DialogueRunArgs &&
      other.dialogueId == dialogueId &&
      other.phases.join(',') == phases.join(',');

  @override
  int get hashCode => Object.hash(dialogueId, phases.join(','));
}

final dialogueRunProvider = NotifierProvider.autoDispose
    .family<DialogueRunController, DialogueRun, DialogueRunArgs>(
      DialogueRunController.new,
    );

/// S4 的階段推進。語音可用性改變時由 reducer 決定是否略過目前階段。
class DialogueRunController extends Notifier<DialogueRun> {
  DialogueRunController(this.args);

  final DialogueRunArgs args;

  @override
  DialogueRun build() {
    ref.listen<bool>(audioAvailableProvider, (previous, next) {
      if (previous != next) _dispatch(AudioChanged(next));
    });
    return initialDialogueRun(
      args.phases,
      audio: ref.read(audioAvailableProvider),
    );
  }

  void _dispatch(DialogueRunEvent event) {
    state = reduceDialogueRun(state, event);
  }

  void completePhase() => _dispatch(const PhaseCompleted());
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../core/tts/audio_available.dart';

final soundGroupsProvider = FutureProvider.autoDispose<List<SoundGroupDto>>(
  (ref) => ref.watch(listeningRepositoryProvider).soundGroups(),
);

typedef ListenSessionArgs = ({String taskKey, int seed});

/// 今日 `Listen` 任務的題目。語音探測完成前停在載入（§6.6），可用性改變時同 seed 重取。
final listenQuestionsProvider = FutureProvider.autoDispose
    .family<List<QuestionDto>, ListenSessionArgs>((ref, args) {
      if (!ref.watch(audioResolvedProvider)) {
        return Completer<List<QuestionDto>>().future;
      }
      final audio = ref.watch(audioAvailableProvider);
      return ref
          .watch(todayRepositoryProvider)
          .listenSession(args.taskKey, args.seed, audio);
    });

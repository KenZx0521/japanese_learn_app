import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/backend/local_log.dart';
import '../../core/backend/providers.dart';
import '../../core/tts/audio_available.dart';
import '../today/flow/today_flow_reducer.dart';
import 'onboarding_draft.dart';

/// 建立計畫並回傳第一個 `NewContent` 的 key（§3.1 第 6 點）。
/// `create_plan` 成功後旗標就存在，重試時不再呼叫一次。
class FirstLessonStarter {
  bool _planCreated = false;

  Future<String?> start(WidgetRef ref) async {
    if (!_planCreated) {
      final input = ref.read(onboardingDraftProvider).toPlanInput();
      await ref.read(planRepositoryProvider).create(input);
      _planCreated = true;
      await _createMarker(ref);
    }
    final audio = ref.read(audioAvailableProvider);
    final view = await ref.read(todayRepositoryProvider).today(audio);
    return _firstNewContentKey(view) ?? firstRunnableKey(view);
  }

  /// 旗標寫不進去只少一次 O6，不值得擋住第一課。
  Future<void> _createMarker(WidgetRef ref) async {
    try {
      await ref.read(firstRunMarkerProvider).create();
    } on Exception catch (error, stack) {
      logLocal(error, stack);
    }
  }

  static String? _firstNewContentKey(TodayViewDto view) {
    for (final task in view.tasks) {
      if (task is TaskDto_NewContent && !task.done) return task.key;
    }
    return null;
  }
}

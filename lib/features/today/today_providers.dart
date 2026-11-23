import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../core/backend/today_view_provider.dart';
import '../../core/tts/audio_available.dart';
import 'flow/today_flow_reducer.dart';
import 'today_copy.dart';

const _calendarWeeks = 2;

/// 任務列的 `Checkpoint` 副標；讀不到只留空白，不擋任務列（§3.2）。
final milestoneTitleProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, id) async {
      final plan = await ref.watch(planRepositoryProvider).view();
      for (final milestone in plan.milestones) {
        if (milestone.id == id) return milestone.titleZh;
      }
      return null;
    });

final weekStudiedDaysProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  logicalDate,
) async {
  final days = await ref.watch(planRepositoryProvider).calendar(_calendarWeeks);
  return countStudiedThisWeek(days, logicalDate);
});

/// 學習進度變了之後，讓 T1、T3 重取今日任務與本週學習日。
/// invalidate 走 refresh，畫面不會閃骨架。
void refreshTodayData(WidgetRef ref) {
  ref
    ..invalidate(todayViewProvider)
    ..invalidate(weekStudiedDaysProvider);
}

/// T3 的本日分鐘與答題數。
final todayActivityProvider = FutureProvider.autoDispose
    .family<DayActivityDto?, String>((ref, logicalDate) async {
      final days = await ref
          .watch(planRepositoryProvider)
          .activity(logicalDate, logicalDate);
      return days.firstOrNull;
    });

/// 進過 T2 但沒結案的任務，回 T1 時該列顯示「繼續」。
final taskInProgressProvider = NotifierProvider<TaskInProgress, String?>(
  TaskInProgress.new,
);

class TaskInProgress extends Notifier<String?> {
  @override
  String? build() => null;

  void mark(String key) => state = key;

  void clear() => state = null;
}

/// `learn_more` 成功後回傳下一次進 T2 的起點；沒有新任務時回 null。
/// 寫入失敗往外拋，由呼叫端顯示（§3.2「再學一批」）。
Future<String?> learnMoreStart(WidgetRef ref) async {
  final audio = ref.read(audioAvailableProvider);
  final view = await ref.read(todayRepositoryProvider).learnMore(audio);
  ref.invalidate(todayViewProvider);
  return firstRunnableKey(view);
}

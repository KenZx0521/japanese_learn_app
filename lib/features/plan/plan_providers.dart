import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../core/backend/today_view_provider.dart';

const planCalendarWeeks = 4;

@immutable
final class PlanPageData {
  const PlanPageData({
    required this.view,
    required this.overview,
    required this.calendar,
    required this.stats,
  });

  final PlanViewDto view;
  final CourseOverviewDto overview;
  final List<CalendarDayDto> calendar;
  final StatsDto stats;

  ContentStage get stage => overview.contentStage;
}

/// 頁面資料一次取得：只有一個骨架與一個錯誤狀態（§2.3）。
final planPageProvider = FutureProvider.autoDispose<PlanPageData>((ref) async {
  final plan = ref.watch(planRepositoryProvider);
  final course = ref.watch(courseRepositoryProvider);
  final view = plan.view();
  final overview = course.overview();
  final calendar = plan.calendar(planCalendarWeeks);
  final stats = plan.stats();
  await Future.wait<Object?>([view, overview, calendar, stats]);
  return PlanPageData(
    view: await view,
    overview: await overview,
    calendar: await calendar,
    stats: await stats,
  );
});

/// `plan_preview` 只計算不寫入（rust-core §9.4）。呼叫端持有同一個 input 實例，
/// 使用者改動後才換新的。
final planPreviewProvider = FutureProvider.autoDispose
    .family<PlanViewDto, PlanInputDto>(
      (ref, input) => ref.watch(planRepositoryProvider).preview(input),
    );

/// 寫入計畫後，計畫頁與今日任務都要重算。
Future<void> applyPlanInput(WidgetRef ref, PlanInputDto input) async {
  await ref.read(planRepositoryProvider).update(input);
  ref
    ..invalidate(planPageProvider)
    ..invalidate(todayViewProvider);
}

PlanInputDto withMinutes(PlanInputDto input, int minutes) => PlanInputDto(
  dailyMinutes: minutes,
  weekdays: input.weekdays,
  startLevel: input.startLevel,
  targetDate: input.targetDate,
  knownKanaLessons: input.knownKanaLessons,
);

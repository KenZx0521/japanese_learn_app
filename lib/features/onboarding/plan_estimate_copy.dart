import '../../core/backend/frb/dto.dart';
import '../plan/scope_copy.dart';

/// §3.8 的完成日文案，與 P1 共用 `scope_copy`（flutter-app §3.1）。`P0a` 只能說「假名與入門七課」（O7）。
List<String> estimateLines(PlanViewDto plan, ContentStage? stage) {
  final end = plan.mainForecastEnd;
  if (end == null) return const [];
  return [forecastLine(stage, end)];
}

/// O4 的目標日期預設：N 個月後的同一天。
String targetDateAfterMonths(int months, {DateTime? from}) {
  final base = from ?? DateTime.now();
  final target = DateTime(base.year, base.month + months, base.day);
  final month = target.month.toString().padLeft(2, '0');
  final day = target.day.toString().padLeft(2, '0');
  return '${target.year}-$month-$day';
}

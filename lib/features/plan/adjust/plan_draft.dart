import 'dart:typed_data';

import 'package:material_ui/material_ui.dart' show immutable;

import '../../../core/backend/frb/dto.dart';
import '../scope_copy.dart';

const planMinuteOptions = [10, 20, 30, 45];
const defaultTargetOffset = Duration(days: 90);

/// 調整中的計畫，改動都回傳新值。
@immutable
final class PlanDraft {
  const PlanDraft({
    required this.minutes,
    required this.weekdays,
    required this.targetDate,
  });

  factory PlanDraft.of(PlanInputDto input) => PlanDraft(
    minutes: input.dailyMinutes,
    weekdays: Set.unmodifiable(input.weekdays),
    targetDate: input.targetDate,
  );

  final int minutes;
  final Set<int> weekdays;
  final String? targetDate;

  bool get isValid => weekdays.isNotEmpty;

  PlanDraft withMinutes(int value) =>
      PlanDraft(minutes: value, weekdays: weekdays, targetDate: targetDate);

  PlanDraft toggledDay(int day) => PlanDraft(
    minutes: minutes,
    weekdays: Set.unmodifiable(
      weekdays.contains(day)
          ? ({...weekdays}..remove(day))
          : ({...weekdays, day}),
    ),
    targetDate: targetDate,
  );

  PlanDraft withTarget(String? value) =>
      PlanDraft(minutes: minutes, weekdays: weekdays, targetDate: value);

  bool sameAs(PlanInputDto input) =>
      minutes == input.dailyMinutes &&
      targetDate == input.targetDate &&
      weekdays.length == input.weekdays.length &&
      weekdays.containsAll(input.weekdays);

  /// 程度與已會的假名課沿用原值，這裡只調整之後的安排。
  PlanInputDto toInput(PlanInputDto base) {
    final sortedDays = weekdays.toList()..sort();
    return PlanInputDto(
      dailyMinutes: minutes,
      weekdays: Uint32List.fromList(sortedDays),
      startLevel: base.startLevel,
      targetDate: targetDate,
      knownKanaLessons: base.knownKanaLessons,
    );
  }
}

String defaultTargetFrom(DateTime today) =>
    isoDateOf(today.add(defaultTargetOffset));

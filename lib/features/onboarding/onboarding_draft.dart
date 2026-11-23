import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/frb/dto.dart';

enum LevelChoice { none, some, hiragana }

const defaultDailyMinutes = 20;
const allWeekdays = {1, 2, 3, 4, 5, 6, 7};

/// O3–O4 累積的選擇，O5 用它建立計畫。
@immutable
final class OnboardingDraft {
  const OnboardingDraft({
    this.level = LevelChoice.none,
    this.knownLessons = const {},
    this.placementPassed = false,
    this.dailyMinutes = defaultDailyMinutes,
    this.weekdays = allWeekdays,
    this.targetDate,
  });

  final LevelChoice level;
  final Set<String> knownLessons;
  final bool placementPassed;
  final int dailyMinutes;
  final Set<int> weekdays;
  final String? targetDate;

  OnboardingDraft copy({
    LevelChoice? level,
    Set<String>? knownLessons,
    bool? placementPassed,
    int? dailyMinutes,
    Set<int>? weekdays,
    String? Function()? targetDate,
  }) => OnboardingDraft(
    level: level ?? this.level,
    knownLessons: knownLessons ?? this.knownLessons,
    placementPassed: placementPassed ?? this.placementPassed,
    dailyMinutes: dailyMinutes ?? this.dailyMinutes,
    weekdays: weekdays ?? this.weekdays,
    targetDate: targetDate == null ? this.targetDate : targetDate(),
  );

  StartLevel get startLevel => level == LevelChoice.hiragana && placementPassed
      ? StartLevel.hiragana
      : StartLevel.zero;

  /// §3.1 O3 的對照表：只有「會一點假名」會帶已會的課。
  List<String> get knownKanaLessons =>
      level == LevelChoice.some ? (knownLessons.toList()..sort()) : const [];

  List<int> get sortedWeekdays => weekdays.toList()..sort();

  PlanInputDto toPlanInput() => PlanInputDto(
    dailyMinutes: dailyMinutes,
    weekdays: Uint32List.fromList(sortedWeekdays),
    startLevel: startLevel,
    targetDate: targetDate,
    knownKanaLessons: knownKanaLessons,
  );

  /// `plan_preview` 的 family 參數：record 才有 `==`（architecture §5.2）。
  PlanPreviewKey get previewKey => (
    minutes: dailyMinutes,
    weekdays: sortedWeekdays.join(','),
    target: targetDate,
    level: startLevel,
    known: knownKanaLessons.join(','),
  );
}

typedef PlanPreviewKey = ({
  int minutes,
  String weekdays,
  String? target,
  StartLevel level,
  String known,
});

PlanInputDto planInputFromKey(PlanPreviewKey key) => PlanInputDto(
  dailyMinutes: key.minutes,
  weekdays: Uint32List.fromList([
    for (final day in key.weekdays.split(','))
      if (day.isNotEmpty) int.parse(day),
  ]),
  startLevel: key.level,
  targetDate: key.target,
  knownKanaLessons: key.known.isEmpty ? const [] : key.known.split(','),
);

final onboardingDraftProvider =
    NotifierProvider<OnboardingDraftController, OnboardingDraft>(
      OnboardingDraftController.new,
    );

class OnboardingDraftController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void setLevel(LevelChoice level) =>
      state = state.copy(level: level, placementPassed: false);

  void toggleKnownLesson(String id) {
    final known = {...state.knownLessons};
    known.contains(id) ? known.remove(id) : known.add(id);
    state = state.copy(knownLessons: known);
  }

  void setPlacementPassed(bool passed) =>
      state = state.copy(placementPassed: passed);

  void setDailyMinutes(int minutes) =>
      state = state.copy(dailyMinutes: minutes);

  void toggleWeekday(int day) {
    final days = {...state.weekdays};
    days.contains(day) ? days.remove(day) : days.add(day);
    state = state.copy(weekdays: days);
  }

  void setTargetDate(String? date) =>
      state = state.copy(targetDate: () => date);
}

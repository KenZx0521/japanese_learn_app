import 'dart:typed_data';

import 'package:japanese_learn_app/core/backend/frb/dto.dart';

PlanInputDto planInput({
  int minutes = 20,
  List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
  String? targetDate,
}) => PlanInputDto(
  dailyMinutes: minutes,
  weekdays: Uint32List.fromList(weekdays),
  startLevel: StartLevel.zero,
  targetDate: targetDate,
  knownKanaLessons: const ['le.k01'],
);

PlanViewDto planView({
  List<MilestoneDto> milestones = const [],
  String? current = 'le.l03',
  String? mainEnd = '2027-03-15',
  PlanStatus status = PlanStatus.noTarget,
  int? suggested,
  PlanInputDto? input,
}) => PlanViewDto(
  input: input ?? planInput(),
  currentLessonId: current,
  milestones: milestones,
  mainForecastEnd: mainEnd,
  status: status,
  suggestedMinutes: suggested,
);

MilestoneDto milestone({
  String id = 'ms.hira',
  String title = '平假名',
  bool passed = false,
  bool dismissed = false,
  String? forecast = '2026-12-20',
  int? best,
}) => MilestoneDto(
  id: id,
  titleZh: title,
  lessonId: 'le.k10',
  passRatio: 0.8,
  questions: 20,
  forecastDate: forecast,
  delayDays: 0,
  bestScorePercent: best,
  passed: passed,
  dismissed: dismissed,
);

LessonSummaryDto lessonSummary(String id, String title) => LessonSummaryDto(
  id: id,
  stageId: 'st.s1',
  titleZh: title,
  canDoZh: '能打招呼',
  status: LessonStatus.current,
);

CourseOverviewDto overview({
  ContentStage stage = ContentStage.p0A,
  List<LessonSummaryDto>? lessons,
}) => CourseOverviewDto(
  contentStage: stage,
  stages: const [],
  lessons: lessons ?? [lessonSummary('le.l03', '自我介紹')],
  currentLessonId: 'le.l03',
  notesAvailable: false,
);

/// 從週一起的 28 天。[restOffsets] 非學習日，[activeOffsets] 已學習。
List<CalendarDayDto> fourWeeks({
  DateTime? monday,
  Set<int> activeOffsets = const {},
  Set<int> restOffsets = const {},
  Map<int, String> milestones = const {},
}) {
  final start = monday ?? DateTime(2026, 11, 2);
  return [
    for (var i = 0; i < 28; i++)
      CalendarDayDto(
        date: _iso(start.add(Duration(days: i))),
        isStudyDay: !restOffsets.contains(i),
        isActive: activeOffsets.contains(i),
        lessonIds: const [],
        milestoneId: milestones[i],
      ),
  ];
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

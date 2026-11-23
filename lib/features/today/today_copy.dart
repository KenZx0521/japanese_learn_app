import 'dart:math' as math;

import '../../core/backend/frb/dto.dart';

// T1、T2、T3 共用的文案與格式（§3.2）。純函式，集中測試。

const _ordinals = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];

String ordinalLabel(int index) =>
    index < _ordinals.length ? _ordinals[index] : '${index + 1}';

String minutesLabel(double minutes) {
  final rounded = (minutes * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}

String estimatedLabel(double minutes) => '約 ${minutes.ceil()} 分鐘';

/// T3 的學習時間：不到一分鐘不顯示小數（§3.2）。
String studyTimeLabel(double minutes) =>
    minutes < 1 ? '不到 1 分鐘' : '${minutes.round()} 分鐘';

/// 可能含 `{ja:…}` 標記，一律用 `MixedText` 顯示。
String taskTitle(TaskDto task) => switch (task) {
  TaskDto_Review() => '複習',
  TaskDto_NewContent(:final titleZh) => '新內容 $titleZh',
  TaskDto_Integration(:final titleZh) => '對話 $titleZh',
  TaskDto_Drill() => '句型演練',
  TaskDto_Listen() => '聽力',
  TaskDto_Checkpoint() => '里程碑檢定',
};

/// T1 不列到期、學習中、收尾新卡都沒有的 `Review`；快照照舊，只改呈現（§3.2）。
List<TaskDto> visibleTasks(TodayViewDto view) => [
  for (final task in view.tasks)
    if (task is! TaskDto_Review || task.due + task.learning + task.newCards > 0)
      task,
];

/// 到期、學習中都沒有，只剩收尾新卡：後端回 `done`，但這些卡今天還沒碰過，
/// 清單跑完才會接觸（§3.2）。
bool isTailOnlyReview(TaskDto task) =>
    task is TaskDto_Review &&
    task.due + task.learning == 0 &&
    task.newCards > 0;

/// 分鐘數只算 [reviewCap] 內的卡，張數也要一致；積壓超過上限時不列出全部（B10）。
/// 只剩收尾新卡時不寫成「0 張」，也不用「收尾」這個詞（零基礎學習者看不懂）。
String _reviewDetail(TaskDto_Review task, int reviewCap) {
  final capped = math.min(task.due, reviewCap);
  final count = capped + task.learning;
  final minutes = minutesLabel(task.minutes);
  if (isTailOnlyReview(task)) {
    return '最後再看 ${task.newCards} 張新卡 · $minutes 分';
  }
  return capped < task.due
      ? '今天先做 $count 張，其餘之後再排 · $minutes 分'
      : '$count 張 · $minutes 分';
}

String taskDetail(
  TaskDto task, {
  required int reviewCap,
  String? milestoneTitle,
}) => switch (task) {
  TaskDto_Review() => _reviewDetail(task, reviewCap),
  TaskDto_NewContent() => _newContentDetail(task),
  TaskDto_Integration(:final phases, :final minutes) =>
    '${_phasesLabel(phases)} · ${minutesLabel(minutes)} 分',
  TaskDto_Drill(:final questions, :final minutes) =>
    '$questions 題 · ${minutesLabel(minutes)} 分',
  TaskDto_Listen(:final sentences, :final minutes) =>
    '$sentences 句 · ${minutesLabel(minutes)} 分',
  TaskDto_Checkpoint() => milestoneTitle ?? '',
};

String _newContentDetail(TaskDto_NewContent task) {
  final words = [
    if (task.words > 0) '${task.words} 字',
    if (task.grammar > 0) '${task.grammar} 文法',
  ].join('＋');
  final parts = [
    if (task.kana > 0) '${task.kana} 字',
    if (words.isNotEmpty) words,
    if (task.rules > 0) '${task.rules} 規則',
  ];
  return '${parts.join('、')} · ${minutesLabel(task.minutes)} 分';
}

const _allPhases = 4;

String _phasesLabel(List<int> phases) =>
    phases.length >= _allPhases ? '全部四段' : '第 ${phases.join('、')} 段';

/// 過場頁的「下一項」（§3.2）。
String transitionLabel(TaskDto task) {
  final minutes = _minutesOf(task);
  final title = taskTitle(task);
  return minutes == null ? title : '$title ${minutesLabel(minutes)} 分鐘';
}

double? _minutesOf(TaskDto task) => switch (task) {
  TaskDto_Review(:final minutes) ||
  TaskDto_NewContent(:final minutes) ||
  TaskDto_Integration(:final minutes) ||
  TaskDto_Drill(:final minutes) ||
  TaskDto_Listen(:final minutes) => minutes,
  TaskDto_Checkpoint() => null,
};

String todayHeadline(TodayViewDto view) {
  for (final task in view.tasks) {
    if (task is TaskDto_NewContent) return '今天，先把${task.titleZh}認熟。';
  }
  return '今天把學過的再練熟。';
}

DateTime? _parseDate(String date) => DateTime.tryParse(date);

String dateLabel(String date) {
  final parsed = _parseDate(date);
  return parsed == null ? date : '${parsed.month} 月 ${parsed.day} 日';
}

/// `3/12` 形式，給粗估完成日與下次學習日。
String shortDateLabel(String date) {
  final parsed = _parseDate(date);
  return parsed == null ? date : '${parsed.month}/${parsed.day}';
}

const _weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];

String weekdayLabel(String date) {
  final parsed = _parseDate(date);
  return parsed == null ? '' : _weekdays[parsed.weekday - 1];
}

/// 只算本週一到本週日的學習日（§3.2 T3）。
int countStudiedThisWeek(List<CalendarDayDto> days, String logicalDate) {
  final today = _parseDate(logicalDate);
  if (today == null) return 0;
  final monday = DateTime(
    today.year,
    today.month,
    today.day - today.weekday + 1,
  );
  final sunday = monday.add(const Duration(days: 6));
  return days.where((day) {
    final date = _parseDate(day.date);
    return day.isActive &&
        date != null &&
        !date.isBefore(monday) &&
        !date.isAfter(sunday);
  }).length;
}

/// 不給新內容的日子時間全給複習（RULINGS O11）。
/// 檢定照常列出，所以不說「只複習」；學完全部課後仍可能是 `Minimal`，
/// 沒有主線切片（[hasMainSlice] 為 false）時不說「學一小批新的」。
String recoveryMessage(
  RecoveryReason reason, {
  required bool minimalNew,
  required bool hasMainSlice,
}) {
  final learnsNew = minimalNew && hasMainSlice;
  return switch (reason) {
    RecoveryReason.returnAfterBreak => '歡迎回來。今天先複習，主線新內容暫停。',
    RecoveryReason.reviewBacklog when learnsNew => '複習還有一些，今天學一小批新的。',
    RecoveryReason.reviewBacklog when minimalNew => '複習還有一些，今天先複習。',
    RecoveryReason.reviewBacklog => '複習累積了一些，今天的時間先給複習，主線新內容暫停。',
    RecoveryReason.unseenNewCards when learnsNew => '前幾天的新內容還沒看完，今天先學一小批。',
    RecoveryReason.unseenNewCards => '前幾天的新內容還沒看完，今天先看完。',
  };
}

/// 今天有主線切片（新內容或整合日）。
bool hasMainSlice(TodayViewDto view) => view.tasks.any(
  (task) => task is TaskDto_NewContent || task is TaskDto_Integration,
);

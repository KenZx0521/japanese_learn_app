// 用真實 Rust API 把進度推到後面的課，給 L21 之後才走得到的內容用（J9）。
// 不寫資料庫、不造 DTO：建計畫、取今日快照、結案、「再學一批」都走 App 同一套 API，
// 只是不經過 UI 逐題作答（作答本身由 J1、J3、J5 用真實 UI 驗證）。
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/backend/repositories.dart';

import 'e2e_harness.dart';

/// 每批都做完，最多呼叫幾次「再學一批」；L08–L21 實測遠低於此。
const _maxBatches = 400;
const _taskDurationMs = 60000;
const _seed = 7;

const _everyDay = [1, 2, 3, 4, 5, 6, 7];

PlanInputDto _planInput(StartLevel level, int minutes) => PlanInputDto(
  dailyMinutes: minutes,
  weekdays: Uint32List.fromList(_everyDay),
  startLevel: level,
  knownKanaLessons: const [],
);

/// 引導只送 `zero`、`hiragana`（rust-core §7.1）；`basic` 是同一個計畫引擎保留給分級測驗的
/// 起點（略過假名課與 L01–L07），游標從 L08 開始，省掉 E2E 不需要重跑的前段。
PlanInputDto basicPlanInput({int minutes = 45}) =>
    _planInput(StartLevel.basic, minutes);

/// 新手引導選「完全沒學過」、預設每天都學時送出的計畫。
PlanInputDto zeroPlanInput({int minutes = 20}) =>
    _planInput(StartLevel.zero, minutes);

/// J1 走完第一天的狀態：零起點計畫，今天擋「再學一批」的任務都結案。
/// 給 J2、J6 自己建前置資料，不必依賴 J1 先跑。
Future<TodayViewDto> finishFirstDayThroughApi(
  E2eApp app, {
  int minutes = 20,
}) async {
  await app
      .read(planRepositoryProvider)
      .create(zeroPlanInput(minutes: minutes));
  final today = app.read(todayRepositoryProvider);
  return _finishOpenTasks(today, await today.today(true));
}

bool lessonDone(CourseOverviewDto course, String lessonId) =>
    course.lessons.any(
      (lesson) => lesson.id == lessonId && lesson.status == LessonStatus.done,
    );

/// 建計畫後在同一個邏輯日不斷「做完今天、再學一批」，直到 [lessonId] 完成。
/// 回傳最後的課程總覽。
Future<CourseOverviewDto> studyThroughApi(
  E2eApp app, {
  required String lessonId,
}) async {
  await app.read(planRepositoryProvider).create(basicPlanInput());
  final course = app.read(courseRepositoryProvider);
  final today = app.read(todayRepositoryProvider);
  for (var batch = 0; batch < _maxBatches; batch++) {
    final overview = await course.overview();
    if (lessonDone(overview, lessonId)) return overview;
    final view = await _finishOpenTasks(today, await today.today(true));
    expect(
      view.canLearnMore,
      isTrue,
      reason: '第 $batch 批之後不能再學一批，游標停在 ${overview.currentLessonId}',
    );
    await today.learnMore(true);
  }
  fail('$_maxBatches 批內沒有完成 $lessonId');
}

/// 「再學一批」要求複習、新內容／整合、演練、聽力都結案；檢定不擋。
Future<TodayViewDto> _finishOpenTasks(
  TodayRepository today,
  TodayViewDto view,
) async {
  var current = view;
  for (final task in view.tasks) {
    if (task.done || !_blocksLearnMore(task)) continue;
    if (task is TaskDto_NewContent) {
      // 與 T2 相同：先取當批內容（Rust 在這裡建卡），再結案
      await today.newContent(task.key, _seed, true);
    }
    current = await today.completeTask(task.key, _taskDurationMs, true);
  }
  return current;
}

bool _blocksLearnMore(TaskDto task) => switch (task) {
  TaskDto_Review() ||
  TaskDto_NewContent() ||
  TaskDto_Integration() ||
  TaskDto_Drill() ||
  TaskDto_Listen() => true,
  TaskDto_Checkpoint() => false,
};

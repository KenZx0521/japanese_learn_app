// J1 首次使用（含 p0 的 O4、O6 文案）、J2 持久化與中途關閉、J6 清除全部進度。
// 每個旅程各用一個資料目錄；J2、J6 的前置資料用真實 API 建（support/api_seed.dart），
// 可以用 `--plain-name` 單獨執行。執行方式見 integration_test/README.md。
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/features/today/done_view.dart';
import 'package:japanese_learn_app/features/today/today_screen.dart';
import 'package:material_ui/material_ui.dart' show TextField;

import 'support/api_seed.dart';
import 'support/e2e_harness.dart';
import 'support/journeys.dart';
import 'support/p0_copy_rules.dart';
import 'support/study_bot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J1 首次使用：引導到第一課、完成頁、今日呈現完成', _j1FirstRun);
  testWidgets('J2 同一資料目錄重開：進度還在，不回到新手引導', _j2Reopen);
  testWidgets('J2 第一課做到一半關掉：重開仍停在今日，答過的不重來', _j2ResumeHalfway);
  testWidgets('J6 清除全部進度：兩段式確認後回到新手引導，能重建計畫', _j6WipeAll);
}

bool _newContentDone(TodayViewDto today) =>
    today.tasks.any((t) => t is TaskDto_NewContent && t.done);

/// 新的資料目錄上開機，用真實 API 建出 J1 走完第一天的狀態，再關掉重開。
Future<E2eApp> _appAfterFirstDay(WidgetTester tester) async {
  final app = E2eApp(tester, dataDir: await E2eApp.newDataDir());
  await app.boot();
  await tester.pumpUntilFound(find.text('從五十音開始。'));
  final seeded = await finishFirstDayThroughApi(app);
  expect(_newContentDone(seeded), isTrue, reason: '前置資料：第一課已結案');
  await app.restart();
  await tester.pumpUntilFound(find.byType(HankoBadge));
  return app;
}

Future<void> _j1FirstRun(WidgetTester tester) async {
  final app = E2eApp(tester, dataDir: await E2eApp.newDataDir());
  await app.boot();
  final bot = StudyBot(tester);

  await onboardFromZero(tester);

  await tester.pumpUntilFound(find.text('あ'));
  await runToDone(bot);
  bot.expectAllCorrect();
  expect(bot.answered, isNotEmpty);
  expect(bot.advancedThrough, contains('知道了，繼續'), reason: 'O6 只在第一次');
  expect(bot.seenTexts, contains('本版到 L30，涵蓋參考 N5 範圍。'), reason: 'O6 p0');
  expectP0CopyOnly(bot.seenTexts, where: 'O6 與第一課');
  await tester.pumpUntilFound(find.text('今天完成了'));
  await _expectStudyTimeLine(tester);

  await backToTodayStamped(tester);
  final stats = await app.read(planRepositoryProvider).stats();
  expect(
    stats.kanaMastered + stats.cardsLearning + stats.cardsNew,
    greaterThan(0),
  );
  final today = await app.read(todayRepositoryProvider).today(true);
  expect(_newContentDone(today), isTrue);
  await _expectKanaLessonLabel(tester, app);
}

/// T3 的學習時間（裁決 U6）：第一課只走了幾秒，顯示「不到 1 分鐘」，不是小數。
Future<void> _expectStudyTimeLine(WidgetTester tester) async {
  expect(find.byType(DoneView), findsOneWidget);
  await tester.pumpUntil(
    () => tester.hasVisibleText('今天學了'),
    reason: 'T3 的學習時間',
  );
  final texts = tester.visibleTexts();
  expect(fractionalStudyTimeTexts(texts), isEmpty, reason: 'T3 不顯示小數分鐘');
  expect(tester.hasVisibleText('今天學了 不到 1 分鐘'), isTrue, reason: 'T3：$texts');
}

/// 假名課的 L2 標題是可讀的課名，不是內部 id（裁決 U11）；返回用同一個元件（U9）。
Future<void> _expectKanaLessonLabel(WidgetTester tester, E2eApp app) async {
  final course = await app.read(courseRepositoryProvider).overview();
  final digits = RegExp(r'^le\.k(\d+)$')
      .firstMatch(course.currentLessonId ?? '')
      ?.group(1);
  expect(digits, isNotNull, reason: '第一天結束還在假名課：${course.currentLessonId}');
  await goTab(tester, '學習');
  await tester.tapButton('看課程詳情');
  await tester.pumpPage(find.text('平假名第 ${int.parse(digits!)} 課'));
  expectNoErrorSlip(tester, 'L2 假名課');
  await tapBackLine(tester, 'L2 假名課');
}

Future<void> _j2Reopen(WidgetTester tester) async {
  final app = await _appAfterFirstDay(tester);
  expect(find.text('從五十音開始。'), findsNothing);
  final today = await app.read(todayRepositoryProvider).today(true);
  expect(_newContentDone(today), isTrue);
  final plan = await app.read(planRepositoryProvider).view();
  expect(plan.input.dailyMinutes, 20);

  final before = await app.read(settingsRepositoryProvider).load();
  expect(before.kanaTimeLimit, isTrue, reason: '假名時限預設開啟');
  await goTab(tester, '設定');
  await tester.pumpPage(find.text('假名時限'));
  await tester.tapWidget(find.text('假名時限'));
  await tester.pumpFor(const Duration(milliseconds: 300));

  await app.restart();
  await tester.pumpUntilFound(find.byType(HankoBadge));
  final settings = await app.read(settingsRepositoryProvider).load();
  expect(settings.kanaTimeLimit, isFalse, reason: '設定寫進資料庫');
}

Future<void> _j2ResumeHalfway(WidgetTester tester) async {
  final app = E2eApp(tester, dataDir: await E2eApp.newDataDir());
  await app.boot();
  final bot = StudyBot(tester);
  await onboardFromZero(tester);
  await tester.pumpUntilFound(find.text('あ'));
  // 跑過一段教學與第一題再關掉
  await bot.runUntil(() => bot.answered.isNotEmpty, reason: '答完第一題');

  await app.restart();
  await tester.pumpPage(find.byType(TodayScreen));
  expect(find.text('從五十音開始。'), findsNothing);
  final today = await app.read(todayRepositoryProvider).today(true);
  final firstLesson = today.tasks.whereType<TaskDto_NewContent>().first;
  expect(firstLesson.done, isFalse, reason: '沒做完不算完成');
  expect(
    await expectReviewRow(tester, today, 'J2 T1（第一天）'),
    ReviewRowKind.hidden,
    reason: '第一天沒有任何卡，複習列要收起來（U5）',
  );

  await tester.pumpPage(find.text('開始'));
  await tester.tapWidget(find.text('開始').first);
  await runToDone(bot);
  await backToTodayStamped(tester);
  final after = await app.read(todayRepositoryProvider).today(true);
  expect(after.tasks.whereType<TaskDto_NewContent>().first.done, isTrue);
}

/// 設定 → 清除全部進度：第一次確認、再打字確認，回到 O1。
Future<void> _wipeFromSettings(WidgetTester tester) async {
  await goTab(tester, '設定');
  await tester.pumpPage(find.text('語音與播放'));
  await tester.tapWidget(find.text('清除全部進度'));
  await tester.pumpPage(find.text('清除全部進度？'));
  await tester.tapButton('繼續');
  await tester.pumpPage(find.text('再確認一次'));
  expect(tester.hasEnabledButton('清除全部進度'), isFalse, reason: '沒打字不能清除');
  await tester.enterText(find.byType(TextField), '清除');
  await tester.pump();
  await tester.tapButton('清除全部進度');
  await tester.pumpPage(find.text('從五十音開始。'));
}

Future<void> _j6WipeAll(WidgetTester tester) async {
  final app = await _appAfterFirstDay(tester);
  await _wipeFromSettings(tester);

  await onboardFromZero(tester, minutes: 30);
  final bot = StudyBot(tester);
  await tester.pumpUntilFound(find.text('あ'));
  await runToDone(bot);
  bot.expectAllCorrect();

  final plan = await app.read(planRepositoryProvider).view();
  expect(plan.input.dailyMinutes, 30);
  expect(bot.advancedThrough, contains('知道了，繼續'), reason: '清除後 O6 再出現');
  await backToTodayStamped(tester);

  await app.restart();
  await tester.pumpUntilFound(find.byType(HankoBadge));
  final reopened = await app.read(planRepositoryProvider).view();
  expect(reopened.input.dailyMinutes, 30, reason: '清除後重建的計畫寫進新資料庫');
}

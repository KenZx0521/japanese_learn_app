// J3 多日累積：FixedClock 推進，複習到期、評分、統計與日曆變化。
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/features/today/today_screen.dart';

import 'support/e2e_harness.dart';
import 'support/journeys.dart';
import 'support/screenshots.dart';
import 'support/study_bot.dart';

// FSRS 初次 Good 約 3–5 天後到期，第 6 天起才會有到期卡
const _studyDays = 7;
const _shots = ShotBook('375');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J3 跨日：複習到期、提交評分、統計與日曆累積', _walkDays);
}

/// 第 [day] 天：確認 T1 的任務與複習列，再把今天跑完。
Future<({bool hadDueCards, ReviewRowKind row})> _studyDay(
  WidgetTester tester,
  E2eApp app,
  StudyBot bot,
  int day,
) async {
  await app.restart(advance: const Duration(days: 1));
  final view = await app.read(todayRepositoryProvider).today(true);
  expect(view.isStudyDay, isTrue, reason: '第 $day 天每天都學');
  expect(
    view.tasks.whereType<TaskDto_NewContent>(),
    isNotEmpty,
    reason: '第 $day 天應有新內容',
  );
  final hadDueCards = view.tasks.whereType<TaskDto_Review>().any(
    (review) => review.due > 0,
  );
  await tester.pumpPage(find.byType(TodayScreen));
  final row = await expectReviewRow(tester, view, '第 $day 天 T1');
  if (day == 2) await _shots.take(tester, 'today_s0');
  await studyToday(tester, bot);
  return (hadDueCards: hadDueCards, row: row);
}

Future<void> _walkDays(WidgetTester tester) async {
  final app = E2eApp(tester, dataDir: await E2eApp.newDataDir());
  await app.boot();
  final bot = StudyBot(tester);

  await onboardFromZero(tester);
  await runToDone(bot);
  await tester.tapButton('回到今日');
  final day1 = await app.read(planRepositoryProvider).stats();

  var reviewedDueCards = false;
  var tailOnlyDays = 0;
  for (var day = 2; day <= _studyDays; day++) {
    final result = await _studyDay(tester, app, bot, day);
    reviewedDueCards = reviewedDueCards || result.hadDueCards;
    if (result.row == ReviewRowKind.tailOnly) tailOnlyDays++;
  }

  expect(reviewedDueCards, isTrue, reason: '過幾天後應有到期複習卡');
  expect(tailOnlyDays, greaterThan(0), reason: 'S0 期間有只剩收尾新卡的日子（U5）');

  bot.expectAllCorrect();
  final after = await app.read(planRepositoryProvider).stats();
  expect(after.streakCurrent, _studyDays);
  expect(after.totalReviews, greaterThan(day1.totalReviews));
  expect(
    bot.answered.where(
      (a) => a.type == QuestionType.kanaRead || a.type == QuestionType.recog,
    ),
    isNotEmpty,
  );

  await goTab(tester, '計畫');
  await tester.pumpUntil(
    () => tester.hasVisibleText('本週已學 $_studyDays 天'),
    reason: '四週月曆累積',
  );
}

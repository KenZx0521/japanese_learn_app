// J5 進到 L01 主線：平假名畢業考捷徑，跑含振假名、選擇、排序、打字、配對、自評的真實題目，
// 確認每種題型都有真實題、Rust 判定與 Dart 顯示一致。
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/features/drill/drill_finished_view.dart';
import 'package:material_ui/material_ui.dart' show Size;

import 'support/e2e_harness.dart';
import 'support/journeys.dart';
import 'support/study_bot.dart';

const _maxDays = 8;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, size, textScale) in const [
    ('手機寬度 375', Size(375, 812), 1.0),
    ('最小寬度 320＋字級 2 倍', Size(320, 640), 2.0),
  ]) {
    testWidgets('J5 L01 主線：每種題型都有真實題，正解判對（$name）', (tester) async {
      await _walkMainLesson(tester, size, textScale);
    });
  }
}

Future<void> _walkMainLesson(
  WidgetTester tester,
  Size size,
  double textScale,
) async {
  final app = E2eApp(tester, dataDir: await E2eApp.newDataDir());
  await app.boot(size: size, textScale: textScale);
  final bot = StudyBot(tester);

  await onboardViaPlacement(tester, bot, minutes: 45);
  final plan = await app.read(planRepositoryProvider).view();
  expect(plan.currentLessonId, 'le.l01', reason: '畢業考通過後從 L01 開始');
  await runToDone(bot);
  await backToTodayStamped(tester);

  await _practiceKana(tester, bot);
  await _practiceDrillWithOneWrong(tester, bot);

  for (var day = 2; day <= _maxDays; day++) {
    await app.restart(advance: const Duration(days: 1));
    await studyToday(tester, bot);
    if (_coversAllBodies(bot)) break;
  }

  bot.expectAllCorrect();
  expect(
    bot.answered.where((a) => a.showedFurigana),
    isNotEmpty,
    reason: '要有含振假名的句子',
  );
  final bodies = bot.answered.map((a) => a.body).toSet();
  expect(
    bodies,
    containsAll(<String>[
      'choice',
      'reorder',
      'typing',
      'match',
      'self_grade',
      'shadow',
    ]),
  );
}

/// K2：從假名表進「が」行練習到完成。
Future<void> _practiceKana(WidgetTester tester, StudyBot bot) async {
  await goTab(tester, '學習');
  await tester.tapWidget(find.text('假名表'));
  await tester.pumpPage(find.text('が'));
  await tester.tapWidget(find.text('が').first);
  await tester.tapButton('練習這一課');
  await bot.runUntil(() => tester.hasEnabledButton('完成'), reason: 'K2 跑完');
  await tester.tapButton('完成');
  await tester.pumpFor(const Duration(milliseconds: 400));
}

/// D2：故意選錯一題，畫面要顯示不對，且本輪最後會再出一次。
Future<void> _practiceDrillWithOneWrong(
  WidgetTester tester,
  StudyBot bot,
) async {
  await goTab(tester, '學習');
  await tester.pumpUntilFound(find.text('句型演練'));
  await tester.tapWidget(find.text('句型演練'));
  await tester.pumpPage(find.text('接著練'));
  await tester.tapWidget(find.text('目前').first);
  bot.wrongChoicesToGive = 1;
  await bot.runUntil(
    () => find.byType(DrillFinishedView).evaluate().isNotEmpty,
    reason: 'D2 跑完',
  );
  await tester.tapButton('完成');
  await tester.pumpFor(const Duration(milliseconds: 400));
}

bool _coversAllBodies(StudyBot bot) {
  final bodies = bot.answered.map((a) => a.body).toSet();
  return const [
    'choice',
    'reorder',
    'typing',
    'match',
    'self_grade',
    'shadow',
  ].every(bodies.contains);
}

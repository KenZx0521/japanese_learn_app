// J4 全分頁可達：五個分頁與其子頁都用真實 p0 內容走一遍，窄版、最小寬度、桌面寬度各一次。
// p0 新露出的 N1 筆記（五個分頁）也在每種尺寸走一次。
// 測試框架會把 RenderFlex 溢位與未捕捉例外判為失敗，所以走完本身就是溢位檢查。
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' show RichText, Size;

import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/features/dialogue/view/dialogue_runner.dart';
import 'package:japanese_learn_app/features/dialogue/view/dialogue_summary_tile.dart';
import 'package:japanese_learn_app/features/quiz/view/question_view.dart';
import 'package:japanese_learn_app/features/today/today_screen.dart';

import 'support/e2e_harness.dart';
import 'support/journeys.dart';
import 'support/p0_screens.dart';
import 'support/screenshots.dart';
import 'support/study_bot.dart';

Future<void> visitLearnTab(WidgetTester tester, ShotBook? shots) async {
  await goTab(tester, '學習');
  await tester.pumpPage(find.text('看課程詳情'));
  expectNoErrorSlip(tester, 'L1');
  // O7：L1 標題下的範圍說法只有 p0a 有，p0 不在這裡宣稱範圍
  expect(tester.hasVisibleText('入門七課'), isFalse, reason: 'L1 p0 不沿用 p0a 文案');

  await visitNotes(tester, shots: shots);

  await tester.tapButton('看課程詳情');
  await tester.pumpUntil(() => tester.hasVisibleText('初次見面'));
  await tester.pumpFor(const Duration(milliseconds: 350));
  expectNoErrorSlip(tester, 'L2');
  await back(tester);

  await tester.tapWidget(find.text('假名表'));
  await tester.pumpPage(find.text('か'));
  expectNoErrorSlip(tester, 'K1');
  await tester.tapWidget(find.text('片假名').first);
  await tester.pumpPage(find.text('ア'));
  await back(tester);
}

Future<void> visitVocabAndGrammar(WidgetTester tester) async {
  await tester.tapWidget(find.text('單字'));
  await tester.pumpPage(find.text('全部單字'));
  expectNoErrorSlip(tester, 'V1');
  expectBackLine(tester, 'V1');

  await tester.tapWidget(find.text('全部單字'));
  await tester.pumpPage(find.text('はじめまして'));
  expectNoErrorSlip(tester, 'V2');
  expectBackLine(tester, 'V2');

  await tester.tapWidget(find.text('はじめまして'));
  await tester.pumpUntil(() => tester.hasVisibleText('初次見面'));
  await tester.pumpFor(const Duration(milliseconds: 350));
  expectNoErrorSlip(tester, 'V3');
  await tapBackLine(tester, 'V3');
  // V2 點單字時清單捲動過，頁首的返回元件已被懶載入回收，用系統返回鍵
  await back(tester);
  await tapBackLine(tester, 'V1');

  await tester.tapWidget(find.text('文法'));
  final waPoint = find.textContaining('提出這句話要談的主題', findRichText: true);
  await tester.pumpPage(waPoint);
  expectNoErrorSlip(tester, 'G1');

  await tester.tapWidget(waPoint.first);
  await tester.pumpUntil(() => tester.hasVisibleText('學生'));
  expectNoErrorSlip(tester, 'G2');
  await back(tester);
  await back(tester);

  await tester.tapWidget(find.text('句型演練'));
  await tester.pumpPage(find.text('接著練'));
  expectNoErrorSlip(tester, 'D1');
  await tester.tapWidget(find.text('目前').first);
  await tester.pumpFor(const Duration(milliseconds: 600));
  await tester.pumpUntil(
    () =>
        find.byType(QuestionView).evaluate().isNotEmpty ||
        tester.hasVisibleText('沒有題目'),
    reason: 'D2 載入完成',
  );
  expectNoErrorSlip(tester, 'D2');
  await back(tester);
  await back(tester);
}

Future<void> visitListenTab(WidgetTester tester) async {
  await goTab(tester, '聽說');
  await tester.pumpPage(find.text('語音示範'));
  expectNoErrorSlip(tester, 'S1');

  await tester.tapWidget(find.text('語音示範'));
  await tester.pumpUntil(() => tester.hasVisibleText('清音與濁音'));
  expectNoErrorSlip(tester, 'S2');
  await back(tester);

  await tester.tapWidget(find.text('對話'));
  final firstDialogue = find.textContaining('語言交換活動', findRichText: true);
  await tester.pumpPage(firstDialogue);
  expectNoErrorSlip(tester, 'S3');

  await tester.tapWidget(firstDialogue.first);
  await tester.pumpUntil(() => tester.hasVisibleText('情境'));
  await tester.pumpFor(const Duration(milliseconds: 350));
  expect(tester.hasVisibleText('語言交換活動'), isTrue, reason: '真實對話情境');
  expectNoErrorSlip(tester, 'S4');
  await back(tester);
  await _visitAheadDialogue(tester);
  await back(tester);
}

/// S3 還沒學到的對話也能點，列上標課次，進 S4 後標「還沒學到」，與 L2 相同（裁決 U12）。
Future<void> _visitAheadDialogue(WidgetTester tester) async {
  final dialogues = await readOf(
    tester,
    listeningRepositoryProvider,
  ).dialogues();
  final ahead = dialogues.firstWhere((d) => d.locked);
  final digits = RegExp(r'^le\.l(\d+)$').firstMatch(ahead.lessonId)?.group(1);
  expect(digits, isNotNull, reason: '主線課的對話：${ahead.lessonId}');
  final number = '第 ${int.parse(digits!)} 課';
  final tile = find.byWidgetPredicate(
    (w) => w is DialogueSummaryTile && w.dialogue.id == ahead.id,
  );
  expect(tile, findsOneWidget, reason: 'S3 列出還沒學到的對話');
  expect(
    find.descendant(of: tile, matching: find.text(number)),
    findsOneWidget,
  );

  await tester.tapWidget(
    find.descendant(of: tile, matching: find.byType(RichText)).first,
  );
  await tester.pumpPage(find.byType(DialogueRunner));
  await tester.pumpUntilFound(find.text('還沒學到$number，可以先聽聽看。'));
  expectNoErrorSlip(tester, 'S4 還沒學到 ${ahead.id}');
  await back(tester);
}

Future<void> visitPlanTab(WidgetTester tester) async {
  await goTab(tester, '計畫');
  await tester.pumpPage(find.text('里程碑'));
  expectNoErrorSlip(tester, 'P1');
  expect(tester.hasVisibleText('平假名'), isTrue, reason: '真實里程碑名稱');

  await tester.tapButton('調整計畫');
  await tester.pumpUntil(() => tester.hasVisibleText('粗估'));
  await tester.tapWidget(find.text('45 分').last);
  await tester.pumpUntil(() => tester.hasVisibleText('粗估'));
  expectNoErrorSlip(tester, 'plan_preview');
  await back(tester);
}

Future<void> visitSettingsTab(WidgetTester tester) async {
  await goTab(tester, '設定');
  await tester.pumpPage(find.text('語音與播放'));
  expectNoErrorSlip(tester, 'X1');
  // p0 才有 L09 以後的課，開關才有作用；關於的程度說明用 p0 開頭（O7）
  await tester.pumpUntilFound(find.text('L09 起收起羅馬字'));
  await tester.pumpUntilFound(find.text('本版到 L30，涵蓋參考 N5 範圍。'));

  await tester.tapWidget(find.text('語音與播放'));
  await tester.pumpPage(find.text('語音與說明'));
  expectNoErrorSlip(tester, 'X2');
  await back(tester);

  await tester.tapWidget(find.text('授權'));
  await tester.pumpUntil(() => tester.hasVisibleText('開放原始碼'));
  expectNoErrorSlip(tester, 'X3');
  await back(tester);
}

Future<void> walkAllTabs(
  WidgetTester tester,
  Size size,
  double textScale, {
  ShotBook? shots,
}) async {
  final app = E2eApp(tester, dataDir: await E2eApp.newDataDir());
  await app.boot(size: size, textScale: textScale);
  final bot = StudyBot(tester);

  await onboardViaPlacement(tester, bot);
  await tester.pumpPage(find.text('今天先到這'));
  await tester.tapWidget(find.text('今天先到這'));
  await tester.pumpPage(find.byType(TodayScreen));
  expectNoErrorSlip(tester, 'T1');

  await visitLearnTab(tester, shots);
  await visitVocabAndGrammar(tester);
  await visitListenTab(tester);
  await visitPlanTab(tester);
  await visitSettingsTab(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 截圖（JLA_SHOTS_DIR）只取 375 與 320＋2 倍字級兩種
  for (final (name, size, textScale, shots) in const [
    ('手機寬度 375', Size(375, 812), 1.0, ShotBook('375')),
    ('最小寬度 320', Size(320, 640), 1.0, null),
    ('最小寬度 320＋字級 2 倍', Size(320, 640), 2.0, ShotBook('320x2')),
    ('桌面寬度 1280', Size(1280, 800), 1.0, null),
  ]) {
    testWidgets(
      'J4 全分頁可達（$name）',
      (tester) => walkAllTabs(tester, size, textScale, shots: shots),
    );
  }
}

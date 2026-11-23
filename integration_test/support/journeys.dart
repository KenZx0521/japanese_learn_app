// 各旅程共用的步驟：新手引導、跑完今天、換分頁。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/back_line.dart';
import 'package:japanese_learn_app/design/widgets/choice_tile.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/ink_nav_bar.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/ruled_list.dart';
import 'package:japanese_learn_app/features/today/done_view.dart';
import 'package:japanese_learn_app/features/today/today_screen.dart';
import 'package:japanese_learn_app/features/today/today_task_list.dart';
import 'package:japanese_learn_app/features/vocab/vocab_detail_screen.dart';
import 'package:material_ui/material_ui.dart' show CustomPaint, Text;

import 'e2e_harness.dart';
import 'p0_copy_rules.dart';
import 'study_bot.dart';

Future<void> tapChoice(WidgetTester tester, String label) async {
  final tile = find.ancestor(
    of: find.text(label),
    matching: find.byType(ChoiceTile),
  );
  await tester.pumpUntilFound(tile);
  await tester.tapWidget(tile.first);
}

/// O1 按「開始」，直接進 O3。
Future<void> startOnboarding(WidgetTester tester) async {
  await tester.pumpUntilFound(find.text('從五十音開始。'));
  await tester.tapButton('開始');
  await tester.pumpUntilFound(find.text('你學過日文嗎？'));
}

/// O4 選分鐘數（預設 20），等粗估完成才按下一步。
/// p0 的完成日寫「本版到 L30」（§3.8 文案表）。
Future<void> finishTimeStep(WidgetTester tester, {int minutes = 20}) async {
  await tester.pumpUntilFound(find.text('每天多久？'));
  if (minutes != 20) await tester.tapWidget(find.text('$minutes 分鐘'));
  await tester.pumpUntil(
    () => tester.hasVisibleText('粗估'),
    reason: 'plan_preview 的粗估完成日',
  );
  expect(tester.hasVisibleText('本版到 L30，約在 '), isTrue, reason: 'O4 p0 完成日');
  expectP0CopyOnly(tester.visibleTexts(), where: 'O4');
  await tester.tapButton('下一步');
}

/// O5：語音可用時走「聽得到」，不可用時走「先用無聲模式」。
Future<void> finishVoiceStep(WidgetTester tester, {bool silent = false}) async {
  await tester.pumpUntilFound(find.text('聽得到聲音嗎？'));
  await tester.tapButton(silent ? '先用無聲模式' : '聽得到');
  await tester.tapButton('開始第一課');
  // create_plan 完成才離開 O5。不等的話，呼叫端緊接著的 plan_view 可能比
  // create_plan 先完成而拿到 NoPlanFailure（p0 內容下 J5 實測）
  await tester.pumpUntil(
    () => find.text('聽得到聲音嗎？').evaluate().isEmpty,
    reason: '開始第一課：create_plan 完成並離開 O5',
  );
}

/// 完全沒學過的新手引導，停在 T2 第一課。
Future<void> onboardFromZero(
  WidgetTester tester, {
  int minutes = 20,
  bool silent = false,
}) async {
  await startOnboarding(tester);
  await tester.tapButton('下一步');
  await finishTimeStep(tester, minutes: minutes);
  await finishVoiceStep(tester, silent: silent);
}

/// 回到今日並確認 T1 蓋了完成章；完成頁自己也有章，所以要先等 T1 出現。
Future<void> backToTodayStamped(WidgetTester tester) async {
  await tester.tapButton('回到今日');
  final stamped = find.descendant(
    of: find.byType(TodayScreen),
    matching: find.byType(HankoBadge),
  );
  await tester.pumpUntilFound(stamped);
}

/// O3「平假名都會」＋畢業考全對，主線從 L01 開始，停在 T2 第一課。
Future<void> onboardViaPlacement(
  WidgetTester tester,
  StudyBot bot, {
  int minutes = 20,
}) async {
  await startOnboarding(tester);
  await tapChoice(tester, '平假名都會');
  await tester.tapButton('去考一次');
  await bot.runUntil(
    () => find.text('每天多久？').evaluate().isNotEmpty,
    reason: '平假名畢業考跑到 O4',
  );
  await finishTimeStep(tester, minutes: minutes);
  await finishVoiceStep(tester);
}

Future<void> runToDone(StudyBot bot) => bot.runUntil(
  () => find.byType(DoneView).evaluate().isNotEmpty,
  reason: 'T2 跑到完成頁',
);

/// 從 T1 按「開始」把今天的任務做完，回到 T1。沒有任務時直接回傳 false。
Future<bool> studyToday(WidgetTester tester, StudyBot bot) async {
  await tester.pumpUntilFound(find.text('今日'));
  await tester.pumpUntil(
    () => tester.hasVisibleText('今天') || tester.hasVisibleText('開始'),
  );
  if (!tester.hasVisibleText('開始')) return false;
  await tester.tapWidget(find.text('開始').first);
  await runToDone(bot);
  await tester.tapButton('回到今日');
  await tester.pumpFor(const Duration(milliseconds: 400));
  return true;
}

Future<void> goTab(WidgetTester tester, String label) async {
  await tester.tapWidget(
    find.descendant(of: find.byType(InkNavBar), matching: find.text(label)),
  );
  await tester.pumpFor(const Duration(milliseconds: 400));
}

/// 系統返回鍵：回到上一頁或關閉 bottom sheet。
Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpFor(const Duration(milliseconds: 400));
}

void expectP0CopyOnly(Iterable<String> texts, {required String where}) {
  expect(p0CopyViolations(texts), isEmpty, reason: '$where 的文案違反 O7');
}

/// 畫面上每個 `Text` 的內容，並標出是否在 V3 單字詳情頁（級別標籤的豁免只在那裡）。
List<ShownText> shownTexts(WidgetTester tester) => [
  for (final element in find.byType(Text).evaluate())
    (
      text: textOf(element.widget as Text),
      inWordDetail:
          element.findAncestorWidgetOfExactType<VocabDetailScreen>() != null,
    ),
];

/// 每一站都不能有錯誤條（真實資料一旦有 DTO 問題就會落到 ErrorSlip）。
void expectNoErrorSlip(WidgetTester tester, String where) {
  expect(find.byType(ErrorSlip), findsNothing, reason: '$where 出現錯誤條');
  final shown = shownTexts(tester);
  expect(shownCopyViolations(shown), isEmpty, reason: '$where 的文案違反 O7');
  expect(
    rawMarkupTexts(shown.map((item) => item.text)),
    isEmpty,
    reason: '$where 露出 {ja:} 標記',
  );
  final texts = shown.map((item) => item.text);
  expect(rawLessonIdTexts(texts), isEmpty, reason: '$where 露出課的內部 id');
  expect(retiredSkipTexts(texts), isEmpty, reason: '$where 用了舊的略過文案');
}

/// 次層畫面的返回元件（裁決 U9）：同一個 `BackLine`，箭頭加「返回」。
final backLink = find.descendant(
  of: find.byType(BackLine),
  matching: find.text('返回'),
);

void expectBackLine(WidgetTester tester, String where) {
  expect(backLink, findsOneWidget, reason: '$where 的返回元件');
  expect(
    find.descendant(
      of: find.byType(BackLine),
      matching: find.byType(CustomPaint),
    ),
    findsWidgets,
    reason: '$where 的返回箭頭',
  );
}

/// 點畫面上的返回元件回上一頁（不是系統返回鍵）。
Future<void> tapBackLine(WidgetTester tester, String where) async {
  expectBackLine(tester, where);
  await tester.tapWidget(backLink);
  await tester.pumpFor(const Duration(milliseconds: 400));
}

/// T1 的複習列是哪一種呈現。
enum ReviewRowKind {
  /// 今天的任務沒有 `Review`。
  noTask,

  /// 有 `Review` 但到期、學習中、收尾新卡都沒有，不列（裁決 U5）。
  hidden,

  /// 只剩收尾新卡，副標寫「最後再看 N 張新卡」，不蓋完成章。
  tailOnly,

  /// 有到期或學習中的卡。
  cards,
}

ReviewRowKind reviewRowKindOf(TaskDto_Review? review) => switch (review) {
  null => ReviewRowKind.noTask,
  TaskDto_Review(due: 0, learning: 0, newCards: 0) => ReviewRowKind.hidden,
  TaskDto_Review(due: 0, learning: 0) => ReviewRowKind.tailOnly,
  TaskDto_Review() => ReviewRowKind.cards,
};

/// T1 的複習列（裁決 U5）：沒有卡時不列，只剩收尾新卡時寫「最後再看」，任何時候都不寫
/// 「0 張」。回傳這一天的呈現，呼叫端用它確認旅程真的走到想驗的情況。
Future<ReviewRowKind> expectReviewRow(
  WidgetTester tester,
  TodayViewDto view,
  String where,
) async {
  final list = find.byType(TodayTaskList);
  await tester.pumpUntilFound(list);
  await tester.pumpFor(const Duration(milliseconds: 350));
  final review = view.tasks.whereType<TaskDto_Review>().firstOrNull;
  final kind = reviewRowKindOf(review);
  final isListed =
      kind == ReviewRowKind.tailOnly || kind == ReviewRowKind.cards;
  expect(
    find.descendant(of: list, matching: find.text('複習', findRichText: true)),
    isListed ? findsOneWidget : findsNothing,
    reason: '$where 的複習列：$review',
  );
  expect(
    zeroReviewTexts(tester.visibleTexts()),
    isEmpty,
    reason: '$where 寫了 0 張',
  );
  if (review != null && kind == ReviewRowKind.tailOnly) {
    expect(
      tester.hasVisibleText('最後再看 ${review.newCards} 張新卡'),
      isTrue,
      reason: '$where 只剩收尾新卡的副標',
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.descendant(
            of: list,
            matching: find.text('複習', findRichText: true),
          ),
          matching: find.byType(RuledTile),
        ),
        matching: find.byType(HankoBadge),
      ),
      findsNothing,
      reason: '$where 只剩收尾新卡不蓋完成章',
    );
  }
  return kind;
}

bool isRealContentVisible(WidgetTester tester, Iterable<String> fragments) =>
    fragments.every(tester.hasVisibleText);

Set<QuestionType> answeredTypes(StudyBot bot) =>
    bot.answered.map((a) => a.type).toSet();

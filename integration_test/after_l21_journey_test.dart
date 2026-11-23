// J9 L21 之後：L22 與常體對話 UI 一天走不到，所以先用真實 API 推進
// （support/api_seed.dart：建計畫、結案、再學一批），再用真實 UI 走：
// 今日任務的 L22 新內容、常體對話（進 S4 跑完四階段再回列表）、L1 進度條、L22 的單字與文法頁。
// 375 與 320＋2 倍字級各一次；`--dart-define=JLA_SHOTS_DIR=<目錄>` 時沿途截圖。
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/design/widgets/grammar_teach_card.dart';
import 'package:japanese_learn_app/design/widgets/vocab_teach_card.dart';
import 'package:japanese_learn_app/features/dialogue/view/dialogue_runner.dart';
import 'package:japanese_learn_app/features/grammar/grammar_article.dart';
import 'package:japanese_learn_app/features/learn/learn_current_block.dart';
import 'package:japanese_learn_app/features/today/done_view.dart';
import 'package:japanese_learn_app/features/today/today_screen.dart';
import 'package:material_ui/material_ui.dart' show Brightness, Size, Theme;

import 'support/api_seed.dart';
import 'support/e2e_harness.dart';
import 'support/journeys.dart';
import 'support/p0_screens.dart';
import 'support/screenshots.dart';
import 'support/study_bot.dart';

/// API 推進到這一課完成，游標到 L22；常體對話（`lesson` 為這一課以後）在游標到這一課時就開放。
const _lastSeededLesson = 'le.l21';
const _nextLesson = 'le.l22';

/// 一種畫面尺寸。
typedef _Screen = ({String name, Size size, double textScale, ShotBook shots});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const screens = <_Screen>[
    (
      name: '手機寬度 375',
      size: Size(375, 812),
      textScale: 1.0,
      shots: ShotBook('375'),
    ),
    (
      name: '最小寬度 320＋字級 2 倍',
      size: Size(320, 640),
      textScale: 2.0,
      shots: ShotBook('320x2'),
    ),
  ];
  for (final screen in screens) {
    testWidgets(
      'J9 L21 之後：L22 新內容、常體對話、L22 的單字與文法頁（${screen.name}）',
      (tester) => _walkAfterL21(tester, screen),
    );
  }
}

Future<void> _walkAfterL21(WidgetTester tester, _Screen screen) async {
  final shots = screen.shots;
  final app = E2eApp(tester, dataDir: await E2eApp.newDataDir());
  await app.boot(size: screen.size, textScale: screen.textScale);
  await tester.pumpUntilFound(find.text('從五十音開始。'));
  final course = await studyThroughApi(app, lessonId: _lastSeededLesson);
  expect(course.currentLessonId, _nextLesson);

  await app.restart();
  await tester.pumpPage(find.byType(TodayScreen));
  expectNoErrorSlip(tester, 'T1（L22）');
  final bot = StudyBot(tester);

  await _studyFirstL22Batch(tester, bot, shots);
  await _visitCasualDialogue(tester, bot, shots);
  await _visitNextLesson(tester, shots);
  bot.expectAllCorrect();
}

bool _visible(Type type) => find.byType(type).evaluate().isNotEmpty;

/// T1→T2：L22 的第一批新內容，用 StudyBot 跑到完成頁。
Future<void> _studyFirstL22Batch(
  WidgetTester tester,
  StudyBot bot,
  ShotBook shots,
) async {
  await tester.tapWidget(find.text('開始').first);

  await bot.runUntil(() => _visible(VocabTeachCard), reason: 'T2 進到 L22 單字');
  expectNoErrorSlip(tester, 'T2 L22 單字');
  await shots.take(tester, 'today_vocab_teach_l22');

  await bot.runUntil(
    () => _visible(GrammarTeachCard) || _visible(DoneView),
    reason: 'L22 文法或完成頁',
  );
  if (_visible(GrammarTeachCard)) {
    expectNoErrorSlip(tester, 'T2 L22 文法');
    await shots.take(tester, 'today_grammar_teach_l22');
  }
  await runToDone(bot);
  await backToTodayStamped(tester);
}

/// S3 的常體對話（kind = casual）游標到 L21 起開放；進 S4 把四個階段跑完，按「回到列表」回 S3。
Future<void> _visitCasualDialogue(
  WidgetTester tester,
  StudyBot bot,
  ShotBook shots,
) async {
  final dialogues = await readOf(
    tester,
    listeningRepositoryProvider,
  ).dialogues();
  final casual = dialogues.firstWhere(
    (d) => d.kind == DialogueKindDto.casual && !d.locked,
  );
  await goTab(tester, '聽說');
  await tester.pumpPage(find.text('語音示範'));
  expectNoErrorSlip(tester, 'S1（L22）');
  await tester.tapWidget(find.text('對話'));
  await tester.pumpPage(find.text('常體對話'));
  await tester.tapWidget(richText(casual.sceneZh).first);
  await tester.pumpPage(find.byType(DialogueRunner));
  await tester.pumpUntil(() => tester.hasVisibleText('情境'));
  expectNoErrorSlip(tester, 'S4 常體 ${casual.id}');
  await shots.take(tester, 'casual_dialogue');

  await bot.runUntil(
    () => tester.hasEnabledButton('回到列表'),
    reason: '常體對話 ${casual.id} 四階段跑完',
  );
  expectNoErrorSlip(tester, 'S4 常體完成');
  await tester.tapButton('回到列表');
  await tester.pumpPage(find.text('常體對話'));
  await back(tester);
}

/// L2 的 L22（目前課）：V3 單字詳情與 G2 文法頁都用真實內容打開。
Future<void> _visitNextLesson(WidgetTester tester, ShotBook shots) async {
  final lesson = await readOf(
    tester,
    courseRepositoryProvider,
  ).lesson(_nextLesson);
  await goTab(tester, '學習');
  await _shotCourseStrip(tester, shots);
  await tester.tapButton('看課程詳情');
  await tester.pumpPage(find.text('目前學到這一課'));
  expectNoErrorSlip(tester, 'L2 $_nextLesson');

  final word = lesson.words.first;
  await tester.tapWidget(find.text(word.zh.join('、')).first);
  await tester.pumpPage(find.text('收藏'));
  expectNoErrorSlip(tester, 'V3 ${word.id}');
  await shots.take(tester, 'vocab_detail_l22');
  await back(tester);

  final grammar = lesson.grammar.firstWhere((g) => !g.meaningZh.contains('{'));
  await tester.tapWidget(richText(grammar.meaningZh).first);
  await tester.pumpPage(find.byType(GrammarArticle));
  expectNoErrorSlip(tester, 'G2 ${grammar.id}');
  await shots.take(tester, 'grammar_detail_l22');
  await back(tester);
  await back(tester);
}

/// L1 進度條在兩種主題下都截一張（裁決 U7）：`basic` 起點有略過的課，略過的格子有斜線。
Future<void> _shotCourseStrip(WidgetTester tester, ShotBook shots) async {
  final course = await readOf(tester, courseRepositoryProvider).overview();
  expect(
    course.lessons.where((l) => l.status == LessonStatus.skipped),
    isNotEmpty,
    reason: 'basic 起點略過假名課與 L01–L07',
  );
  final block = find.byType(LearnCurrentBlock);
  await tester.pumpPage(block);
  final dispatcher = tester.platformDispatcher;
  addTearDown(dispatcher.clearPlatformBrightnessTestValue);
  for (final (brightness, name) in const [
    (Brightness.light, 'learn_progress_light'),
    (Brightness.dark, 'learn_progress_dark'),
  ]) {
    dispatcher.platformBrightnessTestValue = brightness;
    await tester.pumpFor(const Duration(milliseconds: 400));
    expect(Theme.of(tester.element(block)).brightness, brightness);
    await shots.take(tester, name);
  }
  dispatcher.clearPlatformBrightnessTestValue();
  await tester.pumpFor(const Duration(milliseconds: 400));
}

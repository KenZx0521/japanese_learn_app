import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/kana_cell.dart';
import 'package:japanese_learn_app/design/widgets/paper_scaffold.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/design/widgets/speak_button.dart';
import 'package:japanese_learn_app/features/dialogue/view/dialogue_summary_tile.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../grammar/grammar_fixtures.dart';
import 'learn_fixtures.dart';

Finder _rich(String text) => find.textContaining(text, findRichText: true);

String _path(ProviderContainer c) =>
    c.read(appRouterProvider).state.uri.toString();

final _word = vocabSummaryFixture(surface: '猫', kana: 'ねこ', romaji: 'neko');

LessonDetailDto _main({
  LessonStatus status = LessonStatus.current,
  bool locked = false,
}) => lessonDetail(
  summary: mainSummary(status: status),
  words: [_word],
  grammar: [grammarSummaryFixture()],
  dialogue: dialogueOf(locked: locked),
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  String lessonId = 'le.l03',
  double width = 375,
  double textScale = 1,
  bool settle = true,
}) => pumpApp(
  tester,
  backend: backend,
  location: AppRoutes.lesson(lessonId),
  settings: settingsFixture(),
  width: width,
  height: 2000,
  textScale: textScale,
  settle: settle,
);

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.course.lessonStub.returns(_main());
  });

  group('狀態', () {
    testWidgets('載入超過 200ms 才顯示骨架', (tester) async {
      final gate = Completer<void>();
      backend.course.lessonStub.gate = gate.future;

      await _pump(tester, backend, settle: false);
      expect(find.byType(SkeletonLines), findsNothing);

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(SkeletonLines), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('第 3 課'), findsOneWidget);
    });

    testWidgets('讀不到課程時顯示 ErrorSlip，重試後恢復', (tester) async {
      backend.course.lessonStub.throws(const NotFoundFailure());

      await _pump(tester, backend);
      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.course.lessonStub.returns(_main());
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorSlip), findsNothing);
      expect(find.text('第 3 課'), findsOneWidget);
    });

    testWidgets('錯誤時仍有返回鈕，不會困在頁面裡', (tester) async {
      backend.course.lessonStub.throws(const NotFoundFailure());

      final container = await _pump(tester, backend);
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.learn);
    });

    testWidgets('課程內容全空時說明，不留白', (tester) async {
      backend.course.lessonStub.returns(lessonDetail());

      await _pump(tester, backend);

      expect(find.text('這一課的內容還沒準備好'), findsOneWidget);
    });

    testWidgets('以路由的 lessonId 取資料', (tester) async {
      await _pump(tester, backend, lessonId: 'le.l03');

      expect(backend.course.lessonStub.calls.first, ['le.l03']);
    });
  });

  group('主線課', () {
    testWidgets('呈現課次、標題、can-do 與各區', (tester) async {
      await _pump(tester, backend);

      expect(find.text('第 3 課'), findsOneWidget);
      expect(_rich('多少錢'), findsOneWidget);
      expect(_rich('能問價錢'), findsOneWidget);
      expect(find.text('新字'), findsOneWidget);
      expect(find.text('文法'), findsOneWidget);
      expect(find.text('對話'), findsOneWidget);
      expect(find.text('猫'), findsOneWidget);
    });

    testWidgets('沒有內容的區塊不顯示', (tester) async {
      await _pump(tester, backend);

      expect(find.text('規則卡'), findsNothing);
      expect(find.text('假名'), findsNothing);
    });

    testWidgets('單字連到 V3', (tester) async {
      final container = await _pump(tester, backend);

      await tester.tap(find.text('猫'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.vocabWord('vo.neko'));
    });

    testWidgets('文法連到 G2', (tester) async {
      final container = await _pump(tester, backend);

      await tester.tap(_rich('提出主題'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.grammarPoint('gr.wa'));
    });

    testWidgets('對話連到 S4', (tester) async {
      final container = await _pump(tester, backend);

      await tester.tap(_rich('在便利商店結帳'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.sessionDialogue('di.konbini'));
    });

    testWidgets('未到的對話也可點，標課次，與 S3 一致（裁決 U12）', (tester) async {
      backend.course.lessonStub.returns(_main(locked: true));

      final container = await _pump(tester, backend);
      expect(
        find.descendant(
          of: find.byType(DialogueSummaryTile),
          matching: find.text('第 3 課'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('開放'), findsNothing);

      await tester.tap(_rich('在便利商店結帳'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.sessionDialogue('di.konbini'));
    });

    testWidgets('可練這一課的句型（D2）', (tester) async {
      final container = await _pump(tester, backend);

      await tester.tap(find.text('練這一課的句型'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.sessionDrill(lesson: 'le.l03'));
    });

    testWidgets('主線課沒有假名練習', (tester) async {
      await _pump(tester, backend);

      expect(find.text('練這一課的假名'), findsNothing);
    });

    testWidgets('單字可以播放', (tester) async {
      await _pump(tester, backend);

      expect(find.byType(SpeakButton), findsOneWidget);
    });

    testWidgets('羅馬字依該課的顯示規則', (tester) async {
      await _pump(tester, backend);

      expect(find.text('neko'), findsOneWidget);
      expect(backend.settings.displayPolicyStub.calls.first, [
        const DisplayContext(lessonId: 'le.l03'),
      ]);
    });

    testWidgets('顯示規則隱藏羅馬字時不顯示', (tester) async {
      backend.settings.displayPolicyStub.returns(
        displayPolicyFixture(romaji: RomajiMode.hidden),
      );

      await _pump(tester, backend);

      expect(find.text('neko'), findsNothing);
      expect(find.text('ねこ'), findsOneWidget);
    });
  });

  group('假名課', () {
    LessonDetailDto kanaLesson({
      List<KanaCellDto>? kana,
      List<RuleCardDto> rules = const [],
    }) => lessonDetail(
      summary: kanaSummary(),
      kana: kana ?? [kanaCellFixture()],
      rules: rules,
    );

    testWidgets('呈現假名格，標題是假名課的課次（裁決 U11）', (tester) async {
      backend.course.lessonStub.returns(kanaLesson());

      await _pump(tester, backend, lessonId: 'le.k01');

      expect(find.text('平假名第 1 課'), findsOneWidget);
      expect(find.text('假名課'), findsNothing);
      expect(find.byType(KanaCell), findsOneWidget);
    });

    testWidgets('片假名課的標題', (tester) async {
      backend.course.lessonStub.returns(
        lessonDetail(
          summary: kanaSummary(id: 'le.kk03'),
          kana: [kanaCellFixture()],
        ),
      );

      await _pump(tester, backend, lessonId: 'le.kk03');

      expect(find.text('片假名第 3 課'), findsOneWidget);
    });

    testWidgets('可以進 K2 練習', (tester) async {
      backend.course.lessonStub.returns(kanaLesson());
      backend.kana.sessionStub.returns(const []);

      final container = await _pump(tester, backend, lessonId: 'le.k01');
      await tester.tap(find.text('練這一課的假名'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.kanaSession('le.k01'));
    });

    testWidgets('假名課沒有句型演練入口', (tester) async {
      backend.course.lessonStub.returns(kanaLesson());

      await _pump(tester, backend, lessonId: 'le.k01');

      expect(find.text('練這一課的句型'), findsNothing);
    });

    testWidgets('規則卡連到 K3', (tester) async {
      backend.course.lessonStub.returns(kanaLesson(rules: [ruleOf()]));
      backend.kana.ruleCardStub.returns(ruleCardFixture());

      final container = await _pump(tester, backend, lessonId: 'le.k01');
      await tester.tap(_rich('停一拍'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.kanaRule('ka.rule.sokuon'));
    });

    testWidgets('只有規則說明的課不提供練習按鈕，規則卡仍在', (tester) async {
      backend.course.lessonStub.returns(
        kanaLesson(kana: const [], rules: [ruleOf()]),
      );

      await _pump(tester, backend, lessonId: 'le.k18');

      expect(find.text('練這一課的假名'), findsNothing);
      expect(find.text('規則卡'), findsOneWidget);
    });

    testWidgets('總檢課沒有新字也能練，不顯示內容未準備', (tester) async {
      backend.course.lessonStub.returns(kanaLesson(kana: const []));

      await _pump(tester, backend, lessonId: 'le.k10');

      expect(find.text('練這一課的假名'), findsOneWidget);
      expect(find.text('這一課的內容還沒準備好'), findsNothing);
    });

    testWidgets('從練習回來會重新讀取假名進度', (tester) async {
      backend.course.lessonStub.returns(kanaLesson());
      backend.kana.sessionStub.returns(const []);
      await _pump(tester, backend, lessonId: 'le.k01');

      await tester.tap(find.text('練這一課的假名'));
      await tester.pumpAndSettle();
      // K2 自己也會讀課程內容，要在回來之前才開始算
      final before = backend.course.lessonStub.calls.length;
      await tester.tap(find.text('回上一頁'));
      await tester.pumpAndSettle();

      expect(backend.course.lessonStub.calls.length, greaterThan(before));
    });
  });

  group('課程狀態', () {
    testWidgets('未到的課標示，內容照常可看', (tester) async {
      backend.course.lessonStub.returns(_main(status: LessonStatus.notStarted));

      await _pump(tester, backend);

      expect(find.text('還沒學到這一課，可以先看內容。'), findsOneWidget);
      expect(find.text('猫'), findsOneWidget);
    });

    testWidgets('學完的課蓋章', (tester) async {
      backend.course.lessonStub.returns(_main(status: LessonStatus.done));

      await _pump(tester, backend);

      expect(find.byType(HankoBadge), findsOneWidget);
    });

    testWidgets('目前的課不蓋章', (tester) async {
      await _pump(tester, backend);

      expect(find.byType(HankoBadge), findsNothing);
    });
  });

  group('導覽與版面', () {
    testWidgets('返回：深連結進來時回到學習首頁', (tester) async {
      backend.course.overviewStub.returns(mixedOverview());

      final container = await _pump(tester, backend);
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.learn);
    });

    testWidgets('320 寬、字級 2.0 不溢位', (tester) async {
      backend.course.lessonStub.returns(
        lessonDetail(
          summary: kanaSummary(status: LessonStatus.notStarted),
          kana: [kanaCellFixture()],
          rules: [ruleOf()],
          words: [_word],
          grammar: [grammarSummaryFixture()],
          dialogue: dialogueOf(locked: true),
        ),
      );

      await _pump(tester, backend, width: 320, textScale: 2);

      expect(tester.takeException(), isNull);
    });

    testWidgets('寬度 1024 單欄不溢位，內容都在', (tester) async {
      await _pump(tester, backend, width: 1024);

      expect(tester.takeException(), isNull);
      expect(find.text('猫'), findsOneWidget);
      expect(find.text('文法'), findsOneWidget);
    });

    testWidgets('寬度 1280 時規則卡、對話、文法移到右欄', (tester) async {
      await _pump(tester, backend, width: 1280);

      expect(tester.takeException(), isNull);
      final scaffold = tester.widget<PaperScaffold>(find.byType(PaperScaffold));
      expect(scaffold.aside, isNotNull);
      expect(find.text('猫'), findsOneWidget);
      expect(find.text('文法'), findsOneWidget);
    });

    testWidgets('窄版沒有右欄', (tester) async {
      await _pump(tester, backend);

      final scaffold = tester.widget<PaperScaffold>(find.byType(PaperScaffold));
      expect(scaffold.aside, isNull);
    });
  });
}

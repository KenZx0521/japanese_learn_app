import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/paper_scaffold.dart';
import 'package:japanese_learn_app/design/widgets/ruled_list.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/features/learn/learn_course_list.dart';
import 'package:japanese_learn_app/features/learn/learn_current_block.dart';
import 'package:material_ui/material_ui.dart';

import '../grammar/grammar_fixtures.dart';
import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'learn_fixtures.dart';

Finder _rich(String text) => find.textContaining(text, findRichText: true);

String _path(ProviderContainer c) =>
    c.read(appRouterProvider).state.uri.toString();

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  double width = 375,
  double height = 2000,
  double textScale = 1,
  bool settle = true,
}) => pumpApp(
  tester,
  backend: backend,
  location: AppRoutes.learn,
  settings: settingsFixture(),
  width: width,
  height: height,
  textScale: textScale,
  settle: settle,
);

double _contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final dark in const [false, true]) {
    final theme = dark ? '深色' : '淺色';
    testWidgets('$theme：略過的格子和未開始、已完成都分得出來', (tester) async {
      await pumpApp(
        tester,
        dark: dark,
        child: LearnCurrentBlock(overview: mixedOverview()),
      );

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .firstWhere(
            (painter) => '${painter.runtimeType}'.contains('StripPainter'),
          );
      final fills = (painter as dynamic).fills as List<Color?>;
      final tokens = dark ? AppTokens.dark : AppTokens.light;
      final done = fills[0]!;
      final skipped = fills[1]!;

      expect(fills[4], isNull, reason: '未開始不填色');
      expect(_contrast(skipped, tokens.paper.base), greaterThan(1.5));
      expect(_contrast(skipped, done), greaterThan(1.5));
    });

    testWidgets('$theme：稿紙條只在略過的格子畫斜線（裁決 U7）', (tester) async {
      await pumpApp(
        tester,
        dark: dark,
        child: LearnCurrentBlock(overview: mixedOverview()),
      );
      final tokens = dark ? AppTokens.dark : AppTokens.light;
      final strip = tester.renderObject(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              '${widget.painter.runtimeType}'.contains('StripPainter'),
        ),
      );

      // 第 2 格（le.k02）略過；一格 14、間距 2。
      expect(strip, paintsExactlyCountTimes(#drawLine, 1));
      expect(
        strip,
        paints..line(
          p1: const Offset(16, 14),
          p2: const Offset(30, 0),
          color: tokens.ink.secondary,
        ),
      );
    });

    for (final (mode, tokensOf) in <(String, AppTokens Function(AppTokens))>[
      ('一般', (tokens) => tokens),
      ('高對比', (tokens) => tokens.highContrast),
    ]) {
      test('$theme、$mode：斜線畫在略過的填色上，對比要夠（review_f F4）', () {
        final tokens = tokensOf(dark ? AppTokens.dark : AppTokens.light);

        expect(
          _contrast(tokens.ink.secondary, tokens.line.grid),
          greaterThan(3),
        );
      });
    }

    testWidgets('$theme：課程列的方格也只在略過時畫斜線（裁決 U7）', (tester) async {
      final lessons = [
        lessonFixture('le.l01', status: LessonStatus.done),
        lessonFixture('le.l02', status: LessonStatus.skipped),
        lessonFixture('le.l03', status: LessonStatus.current),
        lessonFixture('le.l04'),
      ];
      await pumpApp(
        tester,
        dark: dark,
        height: 2000,
        child: LearnCourseList(
          overview: mixedOverview(lessons: lessons, currentLessonId: 'le.l03'),
        ),
      );
      final tokens = dark ? AppTokens.dark : AppTokens.light;
      final slash = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            '${widget.painter.runtimeType}'.contains('SkipSlash'),
      );

      expect(slash, findsOneWidget);
      expect(
        find.ancestor(of: slash, matching: find.byType(RuledTile)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.ancestor(of: slash, matching: find.byType(RuledTile)),
          matching: find.text('略過'),
        ),
        findsOneWidget,
      );
      expect(
        tester.renderObject(slash),
        paints..line(color: tokens.ink.secondary),
      );
    });
  }

  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.course.overviewStub.returns(mixedOverview());
  });

  group('狀態', () {
    testWidgets('載入超過 200ms 才顯示骨架', (tester) async {
      final gate = Completer<void>();
      backend.course.overviewStub.gate = gate.future;

      await _pump(tester, backend, settle: false);
      expect(find.byType(SkeletonLines), findsNothing);

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(SkeletonLines), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonLines), findsNothing);
      expect(find.text('目前課程'), findsOneWidget);
    });

    testWidgets('課綱損毀時顯示 ErrorSlip，重試後恢復', (tester) async {
      backend.course.overviewStub.throws(const ContentFailure(detail: 'x'));

      await _pump(tester, backend);
      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.course.overviewStub.returns(mixedOverview());
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorSlip), findsNothing);
      expect(find.text('目前課程'), findsOneWidget);
    });

    testWidgets('沒有任何課時說明，資料庫入口仍在', (tester) async {
      backend.course.overviewStub.returns(mixedOverview(lessons: const []));

      await _pump(tester, backend);

      expect(find.text('這一版還沒有課程內容'), findsOneWidget);
      expect(find.text('假名表'), findsOneWidget);
    });

    testWidgets('全部學完時蓋章，不顯示目前課程', (tester) async {
      backend.course.overviewStub.returns(mixedOverview(currentLessonId: null));

      await _pump(tester, backend);

      expect(find.text('目前課程'), findsNothing);
      expect(find.byType(HankoBadge), findsOneWidget);
      expect(_rich('這一版的內容都學完了'), findsOneWidget);
    });
  });

  group('目前位置', () {
    testWidgets('顯示目前的課、整體進度與下一課', (tester) async {
      await _pump(tester, backend);

      expect(find.text('目前課程'), findsOneWidget);
      expect(find.text('進度 4／7'), findsOneWidget);
      expect(_rich('能讀出 アイウエオ'), findsWidgets);
      expect(_rich('下一課：第 2 課  這是什麼'), findsOneWidget);
    });

    testWidgets('進入目前的課', (tester) async {
      final container = await _pump(tester, backend);

      await tester.tap(find.text('看課程詳情'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.lesson('le.kk01'));
    });

    testWidgets('從課程詳情回來會重新讀取進度', (tester) async {
      backend.course.lessonStub.returns(lessonDetail(summary: kanaSummary()));
      await _pump(tester, backend);
      final before = backend.course.overviewStub.calls.length;

      await tester.tap(find.text('看課程詳情'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(backend.course.overviewStub.calls.length, greaterThan(before));
    });
  });

  group('課程列表', () {
    testWidgets('階段分組，已發布的階段才出現，並標出完成數', (tester) async {
      await _pump(tester, backend);

      expect(_rich('假名與發音'), findsWidgets);
      expect(_rich('敬體基礎'), findsOneWidget);
      expect(_rich('參考 N4'), findsNothing);
      expect(find.text('2／4'), findsOneWidget);
      expect(find.text('1／3'), findsOneWidget);
    });

    testWidgets('目前的課所在的段落打開，其他收起，點標題可切換', (tester) async {
      await _pump(tester, backend);

      expect(_rich('サ行'), findsOneWidget);
      expect(_rich('か行'), findsNothing);

      await tester.tap(find.text('平假名與發音規則'));
      await tester.pumpAndSettle();
      expect(_rich('か行'), findsOneWidget);

      await tester.tap(find.text('片假名'));
      await tester.pumpAndSettle();
      expect(_rich('サ行'), findsNothing);
    });

    testWidgets('每一列都標出狀態，未到的課也有文字', (tester) async {
      await _pump(tester, backend);
      await tester.tap(find.text('平假名與發音規則'));
      await tester.pumpAndSettle();

      expect(find.text('學完了'), findsNWidgets(2));
      expect(find.text('略過'), findsOneWidget);
      expect(find.text('目前'), findsOneWidget);
      expect(find.text('還沒到'), findsNWidgets(3));
    });

    testWidgets('未到的課不鎖定，仍可點開', (tester) async {
      final container = await _pump(tester, backend);

      await tester.tap(_rich('多少錢'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.lesson('le.l03'));
    });

    testWidgets('假名課列也能點開', (tester) async {
      final container = await _pump(tester, backend);

      await tester.tap(_rich('サ行'));
      await tester.pumpAndSettle();

      expect(_path(container), AppRoutes.lesson('le.kk02'));
    });

    testWidgets('主線課顯示 can-do，未打開的假名課列不顯示', (tester) async {
      await _pump(tester, backend);

      expect(_rich('能問價錢'), findsOneWidget);
      expect(_rich('能讀出 サ'), findsNothing);
    });
  });

  group('資料庫入口', () {
    for (final (label, route) in [
      ('假名表', AppRoutes.kana),
      ('單字', AppRoutes.vocab),
      ('文法', '/learn/grammar'),
      ('句型演練', AppRoutes.drills),
    ]) {
      testWidgets('$label 連到對應頁面', (tester) async {
        final container = await _pump(tester, backend);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(_path(container), route);
      });
    }

    testWidgets('沒有筆記內容時不露出筆記入口', (tester) async {
      await _pump(tester, backend);

      expect(find.text('筆記'), findsNothing);
    });

    testWidgets('notes_available 為真才露出筆記入口', (tester) async {
      backend.course.overviewStub.returns(mixedOverview(notesAvailable: true));

      final container = await _pump(tester, backend);
      await tester.tap(find.text('筆記'));
      await tester.pumpAndSettle();

      expect(_path(container), '/learn/notes');
    });
  });

  group('範圍文案（O7）', () {
    testWidgets('p0a 只說假名與入門七課', (tester) async {
      await _pump(tester, backend);

      expect(_rich('假名與入門七課'), findsOneWidget);
      for (final banned in ['N4', '看懂日劇', '聽懂日劇']) {
        expect(_rich(banned), findsNothing);
      }
    });

    testWidgets('p0 不在 L1 宣稱範圍，也不沿用 p0a 的說法', (tester) async {
      final base = mixedOverview(notesAvailable: true);
      backend.course.overviewStub.returns(
        CourseOverviewDto(
          contentStage: ContentStage.p0,
          stages: base.stages,
          lessons: base.lessons,
          currentLessonId: base.currentLessonId,
          notesAvailable: true,
        ),
      );

      await _pump(tester, backend);

      expect(find.text('學習'), findsWidgets);
      expect(find.text('筆記'), findsOneWidget);
      for (final banned in ['入門七課', 'N4', 'L48', 'L31', '完整版']) {
        expect(_rich(banned), findsNothing, reason: banned);
      }
    });
  });

  group('版面', () {
    testWidgets('320 寬、字級 2.0 不溢位', (tester) async {
      backend.course.overviewStub.returns(mixedOverview(notesAvailable: true));

      await _pump(tester, backend, width: 320, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('筆記'), findsOneWidget);
    });

    testWidgets('320 寬、字級 1 時筆記入口也放得下', (tester) async {
      backend.course.overviewStub.returns(mixedOverview(notesAvailable: true));

      await _pump(tester, backend, width: 320);

      expect(tester.takeException(), isNull);
      expect(find.text('筆記'), findsOneWidget);
    });

    testWidgets('窄版沒有右欄，資料庫在主欄', (tester) async {
      await _pump(tester, backend);

      final scaffold = tester.widget<PaperScaffold>(find.byType(PaperScaffold));
      expect(scaffold.aside, isNull);
      expect(find.text('假名表'), findsOneWidget);
    });

    testWidgets('寬度 1024（扣掉側欄不到兩欄）單欄也不溢位', (tester) async {
      await _pump(tester, backend, width: 1024);

      expect(tester.takeException(), isNull);
      final scaffold = tester.widget<PaperScaffold>(find.byType(PaperScaffold));
      expect(scaffold.aside, isNull);
      expect(find.text('假名表'), findsOneWidget);
    });

    testWidgets('寬度 1280 時資料庫移到右欄', (tester) async {
      await _pump(tester, backend, width: 1280);

      expect(tester.takeException(), isNull);
      final scaffold = tester.widget<PaperScaffold>(find.byType(PaperScaffold));
      expect(scaffold.aside, isNotNull);
      expect(find.text('假名表'), findsOneWidget);
    });
  });
}

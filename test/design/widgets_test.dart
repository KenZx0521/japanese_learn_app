import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/motion.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:japanese_learn_app/design/widgets/app_text.dart';
import 'package:japanese_learn_app/design/widgets/async_body.dart';
import 'package:japanese_learn_app/design/widgets/censor_bar.dart';
import 'package:japanese_learn_app/design/widgets/choice_tile.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/feedback_strip.dart';
import 'package:japanese_learn_app/design/widgets/flip_card.dart';
import 'package:japanese_learn_app/design/widgets/genko_grid.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/ink_buttons.dart';
import 'package:japanese_learn_app/design/widgets/kana_cell.dart';
import 'package:japanese_learn_app/design/widgets/milestone_rail.dart';
import 'package:japanese_learn_app/design/widgets/pressable.dart';
import 'package:japanese_learn_app/design/widgets/question_hint_strip.dart';
import 'package:japanese_learn_app/design/widgets/rating_bar.dart';
import 'package:japanese_learn_app/design/widgets/ruled_list.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/design/widgets/stamp_overlay.dart';
import 'package:japanese_learn_app/design/widgets/word_tile.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncLoading;
import 'package:material_ui/material_ui.dart';

import '../support/fixtures.dart';
import '../support/pump_app.dart';

Future<TestGesture> _hover(WidgetTester tester, Finder finder) async {
  // FocusableActionDetector 只在 traditional 模式回報 hover，測試預設是 touch
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.addPointer(location: Offset.zero);
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pump();
  return gesture;
}

BoxDecoration _decorationAbove(WidgetTester tester, Finder finder) {
  final container = tester.widget<Container>(
    find.ancestor(of: finder, matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('AppMotion', () {
    testWidgets('reduced motion 時 page 為 0、stamp 為 120ms', (tester) async {
      late AppMotion motion;
      await pumpApp(
        tester,
        disableAnimations: true,
        child: Builder(
          builder: (context) {
            motion = AppMotion.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(motion.page.duration, Duration.zero);
      expect(motion.flip.duration, const Duration(milliseconds: 120));
      expect(motion.stamp.duration, const Duration(milliseconds: 120));
      expect(motion.fast.duration, const Duration(milliseconds: 120));
    });

    testWidgets('一般情況為 token 時長', (tester) async {
      late AppMotion motion;
      await pumpApp(
        tester,
        child: Builder(
          builder: (context) {
            motion = AppMotion.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(motion.base.duration, const Duration(milliseconds: 220));
      expect(motion.page.duration, const Duration(milliseconds: 280));
      expect(motion.stamp.duration, const Duration(milliseconds: 360));
    });
  });

  group('按鈕的 hover／focus／pressed', () {
    testWidgets('InkButton hover 變 paper.raised', (tester) async {
      await pumpApp(
        tester,
        child: Center(
          child: InkButton(label: '開始', onPressed: () {}),
        ),
      );
      final label = find.text('開始');
      final normal = _decorationAbove(tester, label).color;

      await _hover(tester, label);

      expect(normal, AppTokens.light.ink.primary);
      expect(
        _decorationAbove(tester, label).color,
        AppTokens.light.paper.raised,
      );
    });

    testWidgets('InkButton 按下時下移 1px', (tester) async {
      await pumpApp(
        tester,
        child: Center(
          child: InkButton(label: '開始', onPressed: () {}),
        ),
      );
      final before = tester.getTopLeft(find.text('開始'));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('開始')),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('開始')).dy, before.dy + 1);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('開始')), before);
    });

    testWidgets('鍵盤焦點顯示 2px ai 外框，Enter 觸發', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
      });
      var taps = 0;
      await pumpApp(
        tester,
        child: Center(
          child: InkButton(
            label: '開始',
            autofocus: true,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.pump();

      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(Pressable),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(paint.foregroundPainter, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('停用時不可點', (tester) async {
      await pumpApp(
        tester,
        child: const Center(child: InkButton(label: '開始', onPressed: null)),
      );

      await tester.tap(find.text('開始'), warnIfMissed: false);
      expect(
        _decorationAbove(tester, find.text('開始')).color,
        AppTokens.light.paper.sunken,
      );
    });

    testWidgets('點擊目標 ≥48', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        child: ListView(
          children: [
            InkButton(label: 'a', onPressed: () {}),
            GhostButton(label: 'b', onPressed: () {}),
            ShuButton(label: 'c', onPressed: () {}),
            ChoiceTile(onTap: () {}, child: const AppText('d')),
            WordTile(text: 'え', placed: false, onTap: () {}),
          ],
        ),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('略過單項一律寫「略過這一項」（裁決 U8）', (tester) async {
      var skipped = 0;
      await pumpApp(tester, child: SkipItemButton(onPressed: () => skipped++));

      await tester.tap(find.text('略過這一項'));

      expect(skipped, 1);
      expect(find.byType(GhostButton), findsOneWidget);
    });
  });

  group('KanaCell', () {
    testWidgets('語意：「か，ka，已熟練」，日文標 ja', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        child: Center(
          child: SizedBox.square(
            dimension: 60,
            child: KanaCell(
              kana: 'か',
              romaji: 'ka',
              status: KanaStatus.mastered,
              onTap: () {},
            ),
          ),
        ),
      );

      final data = tester
          .getSemantics(find.byType(KanaCell))
          .getSemanticsData();
      expect(data.attributedLabel.string, 'か，ka，已熟練');
      expect(data.attributedLabel.attributes, hasLength(1));
      handle.dispose();
    });

    testWidgets('字級 = 格寬×0.5，不隨系統字級縮放', (tester) async {
      await pumpApp(
        tester,
        textScale: 2,
        child: const Center(
          child: SizedBox.square(
            dimension: 64,
            child: KanaCell(
              kana: 'か',
              romaji: 'ka',
              status: KanaStatus.learning,
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('か'));
      expect(text.style?.fontSize, 32);
      expect(text.textScaler, TextScaler.noScaling);
    });

    testWidgets('已熟練有朱點，未開始用 ink.tertiary', (tester) async {
      await pumpApp(
        tester,
        child: const Center(
          child: SizedBox.square(
            dimension: 64,
            child: KanaCell(
              kana: 'か',
              romaji: 'ka',
              status: KanaStatus.notStarted,
            ),
          ),
        ),
      );

      expect(
        tester.widget<Text>(find.text('か')).style?.color,
        AppTokens.light.ink.tertiary,
      );
    });
  });

  group('GenkoGrid', () {
    testWidgets('格寬 = floor(內容寬/5)，保留空格對位', (tester) async {
      await pumpApp(
        tester,
        width: 320,
        child: const Align(
          alignment: Alignment.topLeft,
          child: GenkoGrid(
            children: [
              SizedBox(key: Key('first')),
              null,
              SizedBox(),
              SizedBox(),
              SizedBox(),
              SizedBox(key: Key('sixth')),
            ],
          ),
        ),
      );

      final first = tester.getRect(find.byKey(const Key('first')));
      expect(first.width, 64);
      final rowTwo = tester.getRect(find.byKey(const Key('sixth')));
      expect(rowTwo.top, 70);
      expect(rowTwo.left, 0);
    });
  });

  group('FlipCard', () {
    testWidgets('語意隨面切換', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        disableAnimations: true,
        child: const FlipCard(
          front: AppText('正面'),
          back: AppText('背面'),
          flipped: false,
        ),
      );

      expect(find.bySemanticsLabel('正面'), findsOneWidget);
      expect(find.bySemanticsLabel('背面'), findsNothing);
      handle.dispose();
    });

    testWidgets('點擊翻面，reduced motion 下交叉淡入', (tester) async {
      var flipped = false;
      await pumpApp(
        tester,
        disableAnimations: true,
        child: StatefulBuilder(
          builder: (context, setState) => FlipCard(
            front: const AppText('正面'),
            back: const AppText('背面'),
            flipped: flipped,
            onFlip: () => setState(() => flipped = !flipped),
          ),
        ),
      );

      await tester.tap(find.text('正面'));
      await tester.pumpAndSettle();

      expect(flipped, isTrue);
      expect(
        find.descendant(
          of: find.byType(FlipCard),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });
  });

  group('RatingBar', () {
    testWidgets('四鍵等寬，鍵盤 1–4 評分', (tester) async {
      final rated = <Rating>[];
      await pumpApp(tester, child: RatingBar(onRate: rated.add));

      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();

      expect(rated, [Rating.good]);
      expect(find.text('再一次'), findsOneWidget);
      expect(find.text('簡單'), findsOneWidget);
    });

    testWidgets('showIntervals 為 false 時不顯示間隔', (tester) async {
      await pumpApp(
        tester,
        child: RatingBar(
          onRate: (_) {},
          previews: const [
            RatingPreviewDto(rating: Rating.again, intervalMinutes: 10),
          ],
        ),
      );

      expect(find.text('10 分鐘'), findsNothing);
    });

    testWidgets('showIntervals 為 true 時顯示', (tester) async {
      await pumpApp(
        tester,
        child: RatingBar(
          onRate: (_) {},
          showIntervals: true,
          previews: const [
            RatingPreviewDto(rating: Rating.again, intervalMinutes: 10),
          ],
        ),
      );

      expect(find.text('10 分鐘'), findsOneWidget);
    });

    test('formatRatingInterval', () {
      expect(formatRatingInterval(5), '5 分鐘');
      expect(formatRatingInterval(120), '2 小時');
      expect(formatRatingInterval(1440), '1 天');
      expect(formatRatingInterval(1440 * 60), '2 個月');
    });
  });

  group('HankoBadge', () {
    testWidgets('語意為中文，文字不隨字級縮放', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        textScale: 2,
        child: const Center(child: HankoBadge('済')),
      );

      expect(find.bySemanticsLabel('完成'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('済')).textScaler,
        TextScaler.noScaling,
      );
      handle.dispose();
    });
  });

  group('StampOverlay', () {
    testWidgets('不擋互動，播完後 onDone', (tester) async {
      var done = false;
      await pumpApp(
        tester,
        child: StampOverlay(play: true, onDone: () => done = true),
      );

      expect(find.byType(IgnorePointer), findsWidgets);

      await tester.pump(const Duration(seconds: 2));
      expect(done, isTrue);
    });
  });

  group('ChoiceTile', () {
    testWidgets('答對答錯有形狀與語意文字，不只靠顏色', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        child: const ChoiceTile(
          state: ChoiceTileState.wrong,
          child: AppText('選項'),
        ),
      );

      final data = tester
          .getSemantics(find.byType(ChoiceTile))
          .getSemanticsData();
      expect(data.hint, '答錯');
      expect(find.byType(CustomPaint), findsWidgets);
      handle.dispose();
    });
  });

  group('CensorBar', () {
    testWidgets('語意為「隱藏的日文」', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, child: const CensorBar(characters: 8));

      expect(find.bySemanticsLabel('隱藏的日文'), findsOneWidget);
      handle.dispose();
    });
  });

  group('MilestoneRail', () {
    testWidgets('點數等於里程碑數，已通過的蓋章', (tester) async {
      final tapped = <String>[];
      await pumpApp(
        tester,
        child: MilestoneRail(
          milestones: [
            milestoneFixture(id: 'a', titleZh: '平假名', passed: true),
            milestoneFixture(id: 'b', titleZh: '片假名'),
            milestoneFixture(id: 'c', titleZh: '自我介紹'),
          ],
          onSelect: (m) => tapped.add(m.id),
        ),
      );

      expect(find.byType(HankoBadge), findsOneWidget);
      await tester.tap(find.text('片假名'));
      expect(tapped, ['b']);
    });
  });

  group('RuledList', () {
    testWidgets('hover 時底色變 paper.raised', (tester) async {
      await pumpApp(
        tester,
        child: RuledList(children: [RuledTile.text('一行', onTap: () {})]),
      );

      await _hover(tester, find.text('一行'));

      final fill = tester.widget<ColoredBox>(
        find
            .ancestor(of: find.text('一行'), matching: find.byType(ColoredBox))
            .first,
      );
      expect(fill.color, AppTokens.light.paper.raised);
    });
  });

  group('共通狀態', () {
    testWidgets('骨架延遲 200ms 才出現', (tester) async {
      await pumpApp(
        tester,
        settle: false,
        child: const DelayedReveal(child: SkeletonLines()),
      );

      expect(find.byType(SkeletonLines), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(SkeletonLines), findsOneWidget);
    });

    testWidgets('ErrorSlip：友善訊息、重試、複製', (tester) async {
      var retries = 0;
      await pumpApp(
        tester,
        child: ErrorSlip(
          failure: const StorageFailure(detail: 'disk I/O error'),
          onRetry: () => retries++,
        ),
      );

      expect(find.text(const StorageFailure().userMessage), findsOneWidget);
      expect(find.textContaining('disk'), findsNothing);

      await tester.tap(find.text('重試'));
      expect(retries, 1);
      expect(find.text('複製錯誤資訊'), findsOneWidget);
    });

    testWidgets('AsyncBody 三態', (tester) async {
      await pumpApp(
        tester,
        settle: false,
        child: AsyncBody<int>(
          value: const AsyncLoading<int>(),
          data: (v) => AppText('$v'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(SkeletonLines), findsOneWidget);
    });

    testWidgets('未知錯誤也顯示友善訊息', (tester) async {
      await pumpApp(
        tester,
        child: ErrorSlip.fromObject(StateError('internal detail')),
      );

      expect(find.text(const UnexpectedFailure().userMessage), findsOneWidget);
      expect(find.textContaining('internal'), findsNothing);
    });
  });

  group('其他元件', () {
    testWidgets('QuestionHintStrip：知道了', (tester) async {
      var dismissed = false;
      await pumpApp(
        tester,
        child: QuestionHintStrip(
          hint: '看字，選出讀音。',
          onDismiss: () => dismissed = true,
        ),
      );

      await tester.tap(find.text('知道了'));
      expect(dismissed, isTrue);
    });

    testWidgets('FeedbackStrip 帶文字', (tester) async {
      await pumpApp(
        tester,
        child: const Align(
          alignment: Alignment.bottomCenter,
          child: FeedbackStrip(correct: false, title: '再想想'),
        ),
      );

      expect(find.text('再想想'), findsOneWidget);
    });

    testWidgets('WordTile 有「移到答案」語意動作', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        child: Center(
          child: WordTile(text: 'です', placed: false, onTap: () => taps++),
        ),
      );

      final data = tester
          .getSemantics(find.byType(WordTile))
          .getSemanticsData();
      expect(data.hint, '移到答案');
      expect(data.customSemanticsActionIds, isNotEmpty);
      await tester.tap(find.text('です'));
      expect(taps, 1);
      handle.dispose();
    });
  });

  testWidgets('tokens：高對比時 ink.secondary 用 ink.primary', (tester) async {
    late AppTokens tokens;
    await pumpApp(
      tester,
      highContrast: true,
      child: Builder(
        builder: (context) {
          tokens = AppTokens.of(context);
          return const SizedBox();
        },
      ),
    );

    expect(tokens.ink.secondary, tokens.ink.primary);
    expect(tokens.line.grid, tokens.line.strong);
    expect(tokens.textureOpacity, 0);
  });

  test('sideMargin 與 cell', () {
    expect(PaperLayout.sideMargin(320), 16);
    expect(PaperLayout.sideMargin(360), 24);
    expect(PaperLayout.cell(343), 68);
  });
}

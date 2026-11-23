// U1：懸掛額度用完後，剩下的寬度依 JIS X 4051 的 1:2:1 分配到底字之間與兩端；
// 落在行首、行尾時內側懸出合計不超過一個 ruby 字寬。
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/ja_text.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:japanese_learn_app/core/text/ruby_box.dart';
import 'package:japanese_learn_app/core/text/ruby_line.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'ruby_geometry.dart';

const _eps = geometryEps;

DisplayPolicyDto _policy({bool spacing = false}) =>
    displayPolicyFixture(romaji: RomajiMode.hidden, wordSpacing: spacing);

/// 7 個假名配 2 個漢字：字級 24 時 ruby 84、底字 48，懸掛一字後還剩 24。
WordDto _longReading() => wordFixture(
  surface: '今日',
  kana: 'こんにちはさま',
  romaji: 'x',
  ruby: const [RubyPartDto(base: '今日', ruby: 'こんにちはさま')],
);

WordDto _kana(String surface) =>
    wordFixture(surface: surface, kana: surface, romaji: surface);

/// 1:2:1：字間相同，兩端各是字間的一半。
void _expectOneTwoOne(
  List<({double left, double right})> cells, {
  required double start,
  required double end,
}) {
  final gap = cells[1].left - cells[0].right;
  expect(gap, greaterThan(1));
  for (var i = 1; i < cells.length; i++) {
    expect(cells[i].left - cells[i - 1].right, closeTo(gap, _eps));
  }
  expect(cells.first.left - start, closeTo(gap / 2, _eps));
  expect(end - cells.last.right, closeTo(gap / 2, _eps));
}

Future<List<int>> _inkColumns(WidgetTester tester, TextPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset.zero);
  final picture = recorder.endRecording();
  final width = painter.width.ceil();
  final height = painter.height.ceil();
  final columns = await tester.runAsync(() async {
    final image = await picture.toImage(width, height);
    final data = await image.toByteData();
    if (data == null) return const <int>[];
    return [
      for (var x = 0; x < width; x++)
        if (Iterable.generate(height)
            .any((y) => data.getUint8((y * width + x) * 4 + 3) > 60))
          x,
    ];
  });
  return columns ?? const [];
}

void main() {
  // 1:2:1 靠這個引擎行為：字距前後各半。換引擎若改了，這裡要先壞。
  testWidgets('引擎把字距前後各半加在每個字兩側', (tester) async {
    TextPainter painterOf(double spacing) => TextPainter(
      text: TextSpan(
        text: '一一',
        style: jaStyle(
          TypeScale.jaBody,
          const Color(0xFF000000),
        ).copyWith(fontSize: 40, letterSpacing: spacing, height: 1.15),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final plain = painterOf(0);
    final spaced = painterOf(30);
    final plainInk = await _inkColumns(tester, plain);
    final spacedInk = await _inkColumns(tester, spaced);

    expect(spaced.width - plain.width, closeTo(60, 0.01));
    expect(spacedInk.first - plainInk.first, closeTo(15, 1));
    expect(spacedInk.last - plainInk.last, closeTo(45, 1));
    plain.dispose();
    spaced.dispose();
  });

  group('MixedText', () {
    testWidgets('列首「大丈夫？」：餘量 1:2:1，底字和標點之間沒有連續空白', (tester) async {
      await pumpApp(tester, child: const MixedText('{ja:大丈夫|だいじょうぶ}？：你還好嗎？'));

      final ruby = rectOf(tester, 'だいじょうぶ');
      final trailing = rectOf(tester, '？：');
      final cells = baseCells(tester, '大丈夫');

      _expectOneTwoOne(cells, start: ruby.left, end: trailing.left);
      expect(ruby.left, closeTo(0, _eps));
      expect(ruby.right - trailing.left, closeTo(ruby.width / 6, _eps));
    });

    testWidgets('列首「私：」：單一底字置中在盒裡', (tester) async {
      await pumpApp(tester, child: const MixedText('{ja:私|わたし}：歌詞裡的「我」'));

      final ruby = rectOf(tester, 'わたし');
      final trailing = rectOf(tester, '：');
      final cell = baseCells(tester, '私').single;
      final before = cell.left - ruby.left;
      final after = trailing.left - cell.right;

      expect(before, greaterThan(1));
      expect(after, closeTo(before, _eps));
    });

    testWidgets('行中兩側都懸滿一字，餘量分配後底字仍置中在 ruby 下', (tester) async {
      await pumpApp(tester, child: const MixedText('中文字{ja:私|わたくしさま}中文字'));

      final box = rectOf(tester, '私');
      final ruby = rectOf(tester, 'わたくしさま');
      final cell = baseCells(tester, '私').single;
      final oneChar = ruby.width / 6;

      expect(box.left - ruby.left, closeTo(oneChar, _eps));
      expect(ruby.right - box.right, closeTo(oneChar, _eps));
      expect((cell.left + cell.right) / 2, closeTo(ruby.center.dx, _eps));
    });

    testWidgets('320 寬、2 倍字級：行首行尾內側懸出合計 ≤ 一字，不懸出容器', (tester) async {
      final prefixes = [
        for (var n = 0; n <= 10; n++) '一二三四五六七八九十'.substring(0, n),
        for (var k = 1; k <= 40; k++) 'i' * k,
      ];
      for (final prefix in prefixes) {
        await pumpApp(
          tester,
          width: 320,
          textScale: 2,
          child: MixedText(
            '$prefix{ja:大丈夫|だいじょうぶ}の'
            '{ja:大丈夫|だいじょうぶ}是{ja:私|わたし}們',
          ),
        );
        expect(tester.takeException(), isNull, reason: prefix);
        for (final (rubyText, baseText, chars) in [
          ('だいじょうぶ', '大丈夫', 6),
          ('わたし', '私', 3),
        ]) {
          for (var i = 0; i < find.text(rubyText).evaluate().length; i++) {
            final ruby = rectOf(tester, rubyText, i);
            expect(ruby.left, greaterThanOrEqualTo(-0.01), reason: prefix);
            expect(ruby.right, lessThanOrEqualTo(320.01), reason: prefix);
            expectEdgeHang(
              base: rectOf(tester, baseText, i),
              ruby: ruby,
              rubyChars: chars,
              width: 320,
              reason: prefix,
            );
          }
        }
      }
    });

    testWidgets('各種寬度換行：行首行尾內側懸出合計 ≤ 一字', (tester) async {
      for (var width = 40.0; width <= 140; width += 1) {
        await pumpApp(
          tester,
          width: width,
          child: const MixedText('一二{ja:私|わたし}們是學生'),
        );
        expect(tester.takeException(), isNull, reason: '$width');
        expectEdgeHang(
          base: rectOf(tester, '私'),
          ruby: rectOf(tester, 'わたし'),
          rubyChars: 3,
          width: width,
          reason: '$width',
        );
      }
    });

    // 只改約束、widget 不重建（旋轉、調視窗）：字距和行首判定都要重算
    testWidgets('寬度變動後重排，結果和直接用那個寬度相同', (tester) async {
      const text = MixedText('一二三{ja:大丈夫|だいじょうぶ}四五六七八九十');
      late StateSetter resize;
      var width = 1024.0;
      await pumpApp(
        tester,
        width: 1024,
        child: StatefulBuilder(
          builder: (context, setState) {
            resize = setState;
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: text),
            );
          },
        ),
      );
      final fresh = rectOf(tester, '大丈夫');
      final freshCells = baseCells(tester, '大丈夫');

      // 寬 80 時換到行首：不能往前懸，底字拉開字距
      resize(() => width = 80);
      await tester.pump();
      final narrow = baseCells(tester, '大丈夫');
      expect(narrow[1].left - narrow[0].right, greaterThan(1));

      resize(() => width = 1024);
      await tester.pump();
      expect(rectOf(tester, '大丈夫'), fresh);
      expect(baseCells(tester, '大丈夫'), freshCells);
    });

    testWidgets('重建後字距仍在', (tester) async {
      late StateSetter rebuild;
      var color = const Color(0xFF000000);
      await pumpApp(
        tester,
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return MixedText('{ja:大丈夫|だいじょうぶ}？：你還好嗎？', color: color);
          },
        ),
      );
      final before = baseCells(tester, '大丈夫');

      rebuild(() => color = const Color(0xFF112233));
      await tester.pump();

      expect(baseCells(tester, '大丈夫'), before);
      expect(before[1].left - before[0].right, greaterThan(1));
      // 重建帶來的新樣式不能被舊文字蓋回去（review_f F8）
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text('大丈夫'), matching: find.byType(RichText)),
      );
      expect(paragraph.text.style?.color, color);
    });

    testWidgets('被 maxLines 截掉的 ruby 段不影響排版', (tester) async {
      await pumpApp(
        tester,
        width: 120,
        child: const MixedText(
          '一二三四五六七八九十{ja:大丈夫|だいじょうぶ}一二三四{ja:私|わたし}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('放在 IntrinsicWidth 裡量得到寬度', (tester) async {
      await pumpApp(
        tester,
        child: const Align(
          alignment: Alignment.topLeft,
          child: IntrinsicWidth(child: MixedText('{ja:大丈夫|だいじょうぶ}？：你還好嗎？')),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MixedText)).width, greaterThan(100));
    });

    testWidgets('字距套用後再量（dry、intrinsic）仍等於實際大小', (tester) async {
      await pumpApp(tester, child: const MixedText('{ja:大丈夫|だいじょうぶ}？：你還好嗎？'));

      final box = tester.renderObject<RenderRubyBox>(find.byType(RubyBox));
      final constraints = BoxConstraints(maxWidth: box.constraints.maxWidth);

      expect(
        box.getDryLayout(constraints).width,
        closeTo(box.size.width, _eps),
      );
      expect(
        box.getMaxIntrinsicWidth(double.infinity),
        closeTo(box.size.width, _eps),
      );
      expect(
        box.getMinIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(box.size.width + _eps),
      );
    });

    testWidgets('語意標籤不因字距改變', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, child: const MixedText('{ja:大丈夫|だいじょうぶ}？：你還好嗎？'));

      final data = tester.getSemantics(mixedParagraph()).getSemanticsData();

      expect(data.attributedLabel.string, '大丈夫？：\n你還好嗎？');
      expect(
        (data.attributedLabel.attributes.single as LocaleStringAttribute)
            .locale,
        jaLocale,
      );
      handle.dispose();
    });
  });

  group('RubyLine', () {
    testWidgets('句首：餘量 1:2:1，底字和下一個字之間沒有連續空白', (tester) async {
      await pumpApp(
        tester,
        child: RubyLine(words: [_longReading(), _kana('は')], policy: _policy()),
      );

      final ruby = rectOf(tester, 'こんにちはさま');
      final next = rectOf(tester, 'は');
      final cells = baseCells(tester, '今日');

      _expectOneTwoOne(cells, start: ruby.left, end: next.left);
      expect(ruby.right - next.left, closeTo(ruby.width / 7, _eps));
    });

    testWidgets('有分詞空格時，1:2:1 之外只多分詞空格', (tester) async {
      await pumpApp(
        tester,
        child: RubyLine(
          words: [_longReading(), _kana('は')],
          policy: _policy(spacing: true),
        ),
      );

      final cells = baseCells(tester, '今日');
      final gap = cells[1].left - cells[0].right;
      final next = rectOf(tester, 'は');

      expect(gap, greaterThan(1));
      expect(next.left - cells[1].right, closeTo(gap / 2 + 24 * 0.32, _eps));
    });

    testWidgets('2 倍字級：字距以實際字寬計算', (tester) async {
      await pumpApp(
        tester,
        textScale: 1.6,
        child: RubyLine(words: [_longReading(), _kana('は')], policy: _policy()),
      );

      final ruby = rectOf(tester, 'こんにちはさま');
      final next = rectOf(tester, 'は');
      final cells = baseCells(tester, '今日');

      _expectOneTwoOne(cells, start: ruby.left, end: next.left);
    });

    testWidgets('不同寬度換行：行首行尾內側懸出合計 ≤ 一字，不懸出容器', (tester) async {
      final words = [
        for (var i = 0; i < 3; i++) ...[
          ...sentenceWordsFixture(),
          _longReading(),
          _kana('は'),
        ],
      ];
      for (var width = 100.0; width <= 320; width += 3) {
        for (final scale in [1.0, 1.6]) {
          await pumpApp(
            tester,
            width: width,
            textScale: scale,
            child: RubyLine(words: words, policy: _policy()),
          );
          expect(tester.takeException(), isNull, reason: '$width');
          for (final (rubyText, baseText, chars) in [
            ('わたし', '私', 3),
            ('がくせい', '学生', 4),
            ('こんにちはさま', '今日', 7),
          ]) {
            for (var i = 0; i < find.text(rubyText).evaluate().length; i++) {
              final ruby = rectOf(tester, rubyText, i);
              final reason = '$width×$scale $rubyText#$i';
              expect(ruby.left, greaterThanOrEqualTo(-0.01), reason: reason);
              expect(
                ruby.right,
                lessThanOrEqualTo(width + 0.01),
                reason: reason,
              );
              expectEdgeHang(
                base: rectOf(tester, baseText, i),
                ruby: ruby,
                rubyChars: chars,
                width: width,
                reason: reason,
              );
            }
          }
        }
      }
    });

    testWidgets('字距拉開後點底字仍查到那個詞', (tester) async {
      final tapped = <String>[];
      await pumpApp(
        tester,
        child: RubyLine(
          words: [_longReading(), _kana('は')],
          policy: _policy(),
          onWordTap: (word) => tapped.add(word.surface),
        ),
      );
      final cells = baseCells(tester, '今日');
      final y = rectOf(tester, '今日').center.dy;

      await tester.tapAt(Offset((cells[0].left + cells[0].right) / 2, y));
      await tester.tapAt(Offset((cells[1].left + cells[1].right) / 2, y));
      await tester.tapAt(rectOf(tester, 'は').center);

      expect(tapped, ['今日', '今日', 'は']);
    });

    testWidgets('語意標籤不因字距改變', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        child: RubyLine(
          words: [_longReading(), _kana('は')],
          policy: _policy(),
          semanticLabel: '今日は',
        ),
      );

      final data = tester
          .getSemantics(find.byType(RubyLine))
          .getSemanticsData();

      expect(data.attributedLabel.string, '今日は');
      handle.dispose();
    });
  });
}

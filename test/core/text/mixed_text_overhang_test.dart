// U1：MixedText 的振假名可懸在相鄰、本身沒有 ruby 的字上（JIS X 4051 ルビの掛け）。
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:japanese_learn_app/design/tokens.dart';

import '../../support/pump_app.dart';
import 'ruby_geometry.dart';

const _eps = 0.5;

Rect _rect(WidgetTester tester, String text, [int index = 0]) =>
    tester.getRect(find.text(text).at(index));

const _quote = '語調上揚的「{ja:大丈夫|だいじょうぶ}？」是「你沒事吧？」';

/// 再往右懸一字就超出容器右緣 [right]，實際沒有往右懸（行尾分支，review_fc F7）。
bool _isHeldAtLineEnd(Rect base, Rect ruby, int chars, double right) =>
    ruby.width > base.width + _eps &&
    base.right + ruby.width / chars > right &&
    ruby.right <= base.right + 0.01;

void main() {
  testWidgets('段首的 ruby 往後懸在收尾標點上：底字貼齊段首，和標點之間不留白', (tester) async {
    await pumpApp(
      tester,
      child: const MixedText('{ja:大丈夫|だいじょうぶ}？：你還好嗎？', scale: TypeScale.title),
    );

    final base = _rect(tester, '大丈夫');
    final ruby = _rect(tester, 'だいじょうぶ');
    final trailing = _rect(tester, '？：');

    expect(ruby.width, greaterThan(base.width));
    expect(base.left, closeTo(0, _eps));
    expect(ruby.left, closeTo(0, _eps));
    expect(trailing.left - base.right, closeTo(0, _eps));
  });

  testWidgets('前後都有不帶 ruby 的字：ruby 置中兩側懸出，底字兩側不留白', (tester) async {
    await pumpApp(tester, child: const MixedText(_quote));

    final base = _rect(tester, '大丈夫');
    final ruby = _rect(tester, 'だいじょうぶ');
    final trailing = _rect(tester, '？」');
    final open = _rect(tester, '「');

    expect(base.left - open.right, closeTo(0, _eps));
    expect(trailing.left - base.right, closeTo(0, _eps));
    expect(ruby.center.dx, closeTo(base.center.dx, _eps));
    // 每側至多一個 ruby 字寬（ruby 6 個假名）
    expect(base.left - ruby.left, lessThanOrEqualTo(ruby.width / 6 + _eps));
  });

  testWidgets('字級 2 倍時同樣不留白', (tester) async {
    await pumpApp(tester, textScale: 2, child: const MixedText(_quote));

    final base = _rect(tester, '大丈夫');
    final trailing = _rect(tester, '？」');
    final open = _rect(tester, '「');

    expect(base.left - open.right, closeTo(0, 2 * _eps));
    expect(trailing.left - base.right, closeTo(0, 2 * _eps));
    expect(tester.takeException(), isNull);
  });

  testWidgets('兩段 ruby 只隔一個字：各自懸掛但不互相重疊', (tester) async {
    await pumpApp(
      tester,
      child: const MixedText('{ja:大丈夫|だいじょうぶ}の{ja:大丈夫|だいじょうぶ}'),
    );

    final first = _rect(tester, 'だいじょうぶ');
    final second = _rect(tester, 'だいじょうぶ', 1);

    expect(first.top, closeTo(second.top, _eps));
    expect(first.right, lessThanOrEqualTo(second.left + 0.01));
  });

  testWidgets('320 寬、2 倍字級換行：ruby 不懸出容器、同一行不重疊', (tester) async {
    // 全形字一次推 32px，窄的 i 一次推幾 px，ruby 段才會落在各種行首、行尾位置
    final prefixes = [
      for (var n = 0; n <= 10; n++) '一二三四五六七八九十'.substring(0, n),
      for (var k = 1; k <= 40; k++) 'i' * k,
    ];
    var sawShiftedLineStart = false;
    var sawShiftedLineEnd = false;
    for (final prefix in prefixes) {
      final n = prefix.length;
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

      final rubies = [
        for (final text in ['だいじょうぶ', 'わたし'])
          for (var i = 0; i < find.text(text).evaluate().length; i++)
            _rect(tester, text, i),
      ];
      final bases = [
        for (final text in ['大丈夫', '私'])
          for (var i = 0; i < find.text(text).evaluate().length; i++)
            _rect(tester, text, i),
      ];
      for (final (index, ruby) in rubies.indexed) {
        final chars = index < rubies.length - 1 ? 6 : 3;
        sawShiftedLineEnd |= _isHeldAtLineEnd(bases[index], ruby, chars, 320);
      }
      for (final ruby in rubies) {
        expect(ruby.left, greaterThanOrEqualTo(-0.01), reason: '$prefix $ruby');
        expect(ruby.right, lessThanOrEqualTo(320.01), reason: '$prefix $ruby');
        if (n > 0 && ruby.left < _eps && ruby.top > 1) {
          sawShiftedLineStart = true;
        }
      }
      for (final a in rubies) {
        for (final b in rubies) {
          if (identical(a, b) || (a.top - b.top).abs() > 1) continue;
          final overlap = a.overlaps(b) && a.intersect(b).width > 0.01;
          expect(overlap, isFalse, reason: '$prefix $a $b');
        }
      }
    }
    // 至少有一次是 ruby 段換到行首、原本會往左懸出的情況，也至少一次落在行尾
    expect(sawShiftedLineStart, isTrue);
    expect(sawShiftedLineEnd, isTrue);
  });

  // review_fc F7：行尾分支要有確定會走到的案例。寬 58 時「私」落在第一行行尾、「們」換行。
  testWidgets('行尾的 ruby 推回容器內，不懸出右緣', (tester) async {
    await pumpApp(
      tester,
      width: 58,
      child: const MixedText('一二{ja:私|わたし}們是學生'),
    );

    final base = _rect(tester, '私');
    final ruby = _rect(tester, 'わたし');

    expect(base.top, lessThan(_rect(tester, 'わたし').bottom + 1));
    expect(ruby.right, closeTo(58, 2));
    expect(ruby.right, lessThanOrEqualTo(58.01));
    expect(ruby.left, greaterThanOrEqualTo(-0.01));
  });

  // review_fc F2：併進盒子的收尾標點要念一次（不重複），不能整個漏掉。
  testWidgets('語意標籤：整段一個節點，日文段標 ja-JP，收尾標點念一次', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, child: const MixedText(_quote));

    final data = tester.getSemantics(mixedParagraph()).getSemanticsData();

    expect(data.attributedLabel.string, '語調上揚的「\n大丈夫？」\n是「你沒事吧？」');
    final attribute = data.attributedLabel.attributes.single;
    expect((attribute as LocaleStringAttribute).locale, jaLocale);
    expect(attribute.range, const TextRange(start: 7, end: 10));
    handle.dispose();
  });

  testWidgets('語意標籤：ruby 段後只剩標點時也念出標點', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, child: const MixedText('{ja:大丈夫|だいじょうぶ}？'));

    final data = tester.getSemantics(mixedParagraph()).getSemanticsData();

    expect(data.attributedLabel.string, '大丈夫？');
    final attribute = data.attributedLabel.attributes.single;
    expect(attribute.range, const TextRange(start: 0, end: 3));
    handle.dispose();
  });
}

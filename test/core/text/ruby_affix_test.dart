// review_f F8：併進盒子的字保留各自的字型與 locale；懸掛量不把盒內的字再算一次。
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/ruby_box.dart';
import 'package:japanese_learn_app/core/text/ruby_line.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'ruby_geometry.dart';
import 'spans_tools.dart';

const _longRuby = 'ごごごごご';
const _otherRuby = 'ななななな';

WordDto _word(String surface, String reading) => wordFixture(
  surface: surface,
  kana: reading,
  romaji: surface,
  ruby: [RubyPartDto(base: surface, ruby: reading)],
);

WordDto _punct(String surface) =>
    wordFixture(surface: surface, kana: surface, romaji: '', isPunct: true);

DisplayPolicyDto _policy() =>
    displayPolicyFixture(romaji: RomajiMode.hidden, wordSpacing: false);

/// 兩段 ruby 都想懸在中間那個窄字上時，各拿一半，不能重疊。
void _expectNoRubyOverlap(WidgetTester tester) {
  expect(
    rectOf(tester, _longRuby).right,
    lessThanOrEqualTo(rectOf(tester, _otherRuby).left + geometryEps),
    reason: '${rectOf(tester, _longRuby)} ${rectOf(tester, _otherRuby)}',
  );
}

Future<void> _pumpLine(WidgetTester tester, List<WordDto> words) => pumpApp(
  tester,
  child: RubyLine(words: words, policy: _policy()),
);

const _a = MixedSpanDto.ja(
  text: '語',
  ruby: [RubyPartDto(base: '語', ruby: _longRuby)],
);
const _b = MixedSpanDto.ja(
  text: '字',
  ruby: [RubyPartDto(base: '字', ruby: _otherRuby)],
);

void main() {
  group('併進盒子的字', () {
    testWidgets('日文與中文一起併進來時，各保留自己的 locale 與樣式', (tester) async {
      await pumpApp(
        tester,
        child: mixedWith(const [
          MixedSpanDto.ja(
            text: '知っ',
            ruby: [
              RubyPartDto(base: '知', ruby: 'し'),
              RubyPartDto(base: 'っ'),
            ],
          ),
          MixedSpanDto.zh(text: '。後面'),
        ]),
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText(includeSemanticsLabels: false) == 'っ。',
        ),
      );
      final spans = <TextSpan>[];
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) spans.add(span);
        return true;
      });

      expect(spans.map((span) => span.text), ['っ', '。']);
      expect(spans.first.locale, jaLocale);
      expect(spans.last.locale, isNull);
      expect(spans.first.style, isNot(spans.last.style));
    });

    testWidgets('日文段的開括號併進盒子時帶 ja locale', (tester) async {
      await pumpApp(
        tester,
        child: mixedWith(const [
          MixedSpanDto.ja(
            text: '「',
            ruby: [RubyPartDto(base: '「')],
          ),
          _a,
        ]),
      );

      expect(tester.widget<Text>(find.text('「')).locale, jaLocale);
    });

    testWidgets('中文段的開括號併進盒子時不帶 locale', (tester) async {
      await pumpApp(
        tester,
        child: mixedWith(const [MixedSpanDto.zh(text: '「'), _a]),
      );

      expect(tester.widget<Text>(find.text('「')).locale, isNull);
    });
  });

  group('邊界（review_f F8）', () {
    testWidgets('句尾多出來的開括號黏回前一個詞，不會被吃掉', (tester) async {
      await _pumpLine(tester, [_word('字', _otherRuby), _punct('「')]);

      final box = find.ancestor(
        of: find.text('「'),
        matching: find.byType(RubyBox),
      );
      expect(
        find.descendant(of: box, matching: find.text('字')),
        findsOneWidget,
      );
    });

    testWidgets('併進來的字比 ruby＋底字還高時，整段往下移，不超出盒子', (tester) async {
      const big = TextStyle(fontSize: 60, height: 1);
      const small = TextStyle(fontSize: 10, height: 1);
      await pumpApp(
        tester,
        child: const Align(
          alignment: Alignment.topLeft,
          child: RubyBox(
            base: Text('底', style: small),
            ruby: Text('よ', style: small),
            leading: Text('大', style: big),
            baseLength: 1,
            rubyLength: 1,
          ),
        ),
      );

      final box = tester.getRect(find.byType(RubyBox));
      final leading = rectOf(tester, '大');
      expect(leading.top, greaterThanOrEqualTo(box.top - geometryEps));
      expect(leading.bottom, lessThanOrEqualTo(box.bottom + geometryEps));
    });
  });

  group('懸掛量不重複計入盒內的字', () {
    testWidgets('RubyLine：收尾的半形標點夾在兩段 ruby 之間', (tester) async {
      await _pumpLine(tester, [
        _word('語', _longRuby),
        _punct(','),
        _word('字', _otherRuby),
      ]);

      _expectNoRubyOverlap(tester);
    });

    testWidgets('RubyLine：開頭的半形括號夾在兩段 ruby 之間', (tester) async {
      await _pumpLine(tester, [
        _word('語', _longRuby),
        _punct('('),
        _word('字', _otherRuby),
      ]);

      _expectNoRubyOverlap(tester);
    });

    testWidgets('MixedText：併進盒子的半形標點夾在兩段 ruby 之間', (tester) async {
      await pumpApp(
        tester,
        child: mixedWith(const [_a, MixedSpanDto.zh(text: ','), _b]),
      );

      _expectNoRubyOverlap(tester);
    });
  });
}

// U1：RubyLine 的振假名同樣可懸在相鄰、沒有 ruby 的字（送り仮名、助詞、標點）上。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/ruby_line.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

const _eps = 0.5;

Rect _rect(WidgetTester tester, String text, [int index = 0]) =>
    tester.getRect(find.text(text).at(index));

DisplayPolicyDto _policy({required bool spacing}) =>
    displayPolicyFixture(romaji: RomajiMode.hidden, wordSpacing: spacing);

/// 新しい：一個詞，漢字一個、讀音三個假名。
WordDto _atarashii() => wordFixture(
  surface: '新しい',
  kana: 'あたらしい',
  romaji: 'atarashii',
  ruby: const [
    RubyPartDto(base: '新', ruby: 'あたら'),
    RubyPartDto(base: 'しい'),
  ],
);

WordDto _gakusei() => wordFixture(
  surface: '学生',
  kana: 'がくせい',
  romaji: 'gakusei',
  ruby: const [RubyPartDto(base: '学生', ruby: 'がくせい')],
  isKnown: true,
);

void main() {
  // review_fc F6：unknownOnly 時已知詞的漢字不顯示讀音，但讀者會把懸上去的讀音當成那個漢字的。
  testWidgets('unknownOnly：讀音不懸到已知詞的漢字上', (tester) async {
    final unknown = wordFixture(
      surface: '私',
      kana: 'わたし',
      romaji: 'watashi',
      ruby: const [RubyPartDto(base: '私', ruby: 'わたし')],
    );
    await pumpApp(
      tester,
      child: RubyLine(
        words: [_gakusei(), unknown, _gakusei()],
        policy: displayPolicyFixture(
          romaji: RomajiMode.hidden,
          furigana: FuriganaMode.unknownOnly,
          wordSpacing: false,
        ),
      ),
    );

    final ruby = _rect(tester, 'わたし');

    expect(ruby.left, greaterThanOrEqualTo(_rect(tester, '学生').right - _eps));
    expect(ruby.right, lessThanOrEqualTo(_rect(tester, '学生', 1).left + _eps));
    expect(find.text('がくせい'), findsNothing);
  });

  testWidgets('句首「私」的 ruby 往後懸在「は」上，兩字之間不留白', (tester) async {
    await pumpApp(
      tester,
      child: RubyLine(
        words: sentenceWordsFixture(),
        policy: _policy(spacing: false),
      ),
    );

    final base = _rect(tester, '私');
    final ruby = _rect(tester, 'わたし');
    final next = _rect(tester, 'は');

    expect(ruby.width, greaterThan(base.width));
    expect(ruby.left, closeTo(base.left, _eps));
    expect(next.left - base.right, closeTo(0, _eps));
  });

  testWidgets('有分詞空格時，底字之間只剩分詞空格', (tester) async {
    await pumpApp(
      tester,
      child: RubyLine(
        words: sentenceWordsFixture(),
        policy: _policy(spacing: true),
      ),
    );

    final gap = _rect(tester, 'は').left - _rect(tester, '私').right;

    expect(gap, closeTo(24 * 0.32, _eps));
  });

  testWidgets('詞內的送り仮名：ruby 懸在「しい」上，不把漢字和假名撐開', (tester) async {
    await pumpApp(
      tester,
      child: RubyLine(words: [_atarashii()], policy: _policy(spacing: false)),
    );

    final gap = _rect(tester, 'しい').left - _rect(tester, '新').right;

    expect(gap, closeTo(0, _eps));
  });

  testWidgets('320 寬、2 倍字級換行：ruby 不懸出容器、同一行不重疊', (tester) async {
    final words = [
      ...sentenceWordsFixture().take(2),
      _atarashii(),
      ...sentenceWordsFixture(),
      _atarashii(),
      ...sentenceWordsFixture(),
    ];
    for (final spacing in [true, false]) {
      await pumpApp(
        tester,
        width: 320,
        textScale: 2,
        child: RubyLine(
          words: words,
          policy: _policy(spacing: spacing),
        ),
      );
      expect(tester.takeException(), isNull);

      final rubies = [
        for (final text in ['わたし', 'あたら', 'がくせい'])
          for (var i = 0; i < find.text(text).evaluate().length; i++)
            _rect(tester, text, i),
      ];
      for (final ruby in rubies) {
        expect(ruby.left, greaterThanOrEqualTo(-0.01), reason: '$ruby');
        expect(ruby.right, lessThanOrEqualTo(320.01), reason: '$ruby');
      }
      for (final a in rubies) {
        for (final b in rubies) {
          if (identical(a, b) || (a.top - b.top).abs() > 1) continue;
          final overlap = a.overlaps(b) && a.intersect(b).width > 0.01;
          expect(overlap, isFalse, reason: '$a $b');
        }
      }
    }
  });

  // review_fc F7：行尾推回要有案例會走到（原本的 320 掃描行尾 0 次）。
  testWidgets('不同寬度換行：行尾的 ruby 推回容器內', (tester) async {
    final words = [for (var i = 0; i < 3; i++) ...sentenceWordsFixture()];
    var sawShiftedLineEnd = false;
    for (var width = 60.0; width <= 240; width += 4) {
      await pumpApp(
        tester,
        width: width,
        child: RubyLine(words: words, policy: _policy(spacing: false)),
      );
      expect(tester.takeException(), isNull, reason: '$width');
      for (final (rubyText, baseText) in [('わたし', '私'), ('がくせい', '学生')]) {
        for (var i = 0; i < find.text(rubyText).evaluate().length; i++) {
          final ruby = _rect(tester, rubyText, i);
          final base = _rect(tester, baseText, i);
          expect(ruby.right, lessThanOrEqualTo(width + 0.01), reason: '$width');
          sawShiftedLineEnd |=
              base.center.dx + ruby.width / 2 > width + _eps &&
              ruby.right <= width + 0.01;
        }
      }
    }
    expect(sawShiftedLineEnd, isTrue);
  });

  // fui 宣稱 hit test 與繪製位置一致；點底字查到的是自己（review_fc F7）。
  testWidgets('點有 ruby 的詞的底字，查到的是那個詞', (tester) async {
    final tapped = <String>[];
    await pumpApp(
      tester,
      child: RubyLine(
        words: sentenceWordsFixture(),
        policy: _policy(spacing: false),
        onWordTap: (word) => tapped.add(word.surface),
      ),
    );

    await tester.tapAt(_rect(tester, '私').center);
    await tester.tapAt(_rect(tester, '学生').center);
    await tester.tapAt(_rect(tester, 'は').center);

    expect(tapped, ['私', '学生', 'は']);
  });
}

// U2：行首行尾禁則。開括號併進下一個盒子；小書き假名、ー、々ゝゞヽヾ 併進前一個盒子。
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
import 'spans_tools.dart';

Widget _mixed(List<MixedSpanDto> spans) => mixedWith(spans);

const _shitteru = MixedSpanDto.ja(
  text: '知ってる',
  ruby: [
    RubyPartDto(base: '知', ruby: 'し'),
    RubyPartDto(base: 'ってる'),
  ],
);

const _tallySample = [
  MixedSpanDto.zh(text: '每聽到一次（例如 '),
  _shitteru,
  MixedSpanDto.zh(text: '、'),
  MixedSpanDto.ja(
    text: '寝てた',
    ruby: [
      RubyPartDto(base: '寝', ruby: 'ね'),
      RubyPartDto(base: 'てた'),
    ],
  ),
  MixedSpanDto.zh(text: '）就畫一筆，最後數一數總共幾次。'),
];

WordDto _word(String surface, {String? reading}) => wordFixture(
  surface: surface,
  kana: reading ?? surface,
  romaji: surface,
  ruby: [RubyPartDto(base: surface, ruby: reading)],
);

WordDto _punct(String surface) =>
    wordFixture(surface: surface, kana: surface, romaji: '', isPunct: true);

DisplayPolicyDto _policy({bool spacing = false}) =>
    displayPolicyFixture(romaji: RomajiMode.hidden, wordSpacing: spacing);

const _rubies = {'し', 'ね', 'だいじょうぶ', 'わたし', 'がくせい', 'い', 'まな', ' '};

/// 中日文、振假名、標點密集交錯的說明文字。
List<MixedSpanDto> _quoteRuleSpans() {
  MixedSpanDto plain(String text) => MixedSpanDto.ja(
    text: text,
    ruby: [RubyPartDto(base: text)],
  );
  MixedSpanDto ruby(String base, String reading, String tail) =>
      MixedSpanDto.ja(
        text: '$base$tail',
        ruby: [
          RubyPartDto(base: base, ruby: reading),
          RubyPartDto(base: tail),
        ],
      );
  return [
    const MixedSpanDto.zh(text: '聽到 '),
    plain('って'),
    const MixedSpanDto.zh(text: ' 後面接 '),
    ruby('言', 'い', 'う'),
    const MixedSpanDto.zh(text: '、'),
    ruby('思', 'おも', 'う'),
    const MixedSpanDto.zh(text: '，這個 '),
    plain('って'),
    const MixedSpanDto.zh(text: ' 就是引用的 '),
    plain('と'),
    const MixedSpanDto.zh(text: '：'),
    const MixedSpanDto.ja(
      text: '来るって言ってた',
      ruby: [
        RubyPartDto(base: '来', ruby: 'く'),
        RubyPartDto(base: 'るって'),
        RubyPartDto(base: '言', ruby: 'い'),
        RubyPartDto(base: 'ってた'),
      ],
    ),
    const MixedSpanDto.zh(text: '＝他說會來。口語幾乎都用 '),
    plain('って'),
    const MixedSpanDto.zh(text: '，'),
    plain('と'),
    const MixedSpanDto.zh(text: ' 比較像書面語。'),
  ];
}

void main() {
  group('MixedText', () {
    testWidgets('開括號不落在行尾：各種寬度', (tester) async {
      for (var width = 90.0; width <= 340; width += 1) {
        await pumpApp(
          tester,
          width: width,
          child: const MixedText(
            '語調上揚的「{ja:大丈夫|だいじょうぶ}？」是「你沒事吧？」，'
            '回答時（{ja:私|わたし}）語調下降的『{ja:大丈夫|だいじょうぶ}』是「沒事」。',
          ),
        );
        expectKinsoku(
          linesOf(tester, find.byType(MixedText), ignore: _rubies),
          '$width',
        );
      }
    });

    testWidgets('開括號併進下一個盒子，緊貼底字、讀音可懸在括號上', (tester) async {
      await pumpApp(tester, child: const MixedText('中文「{ja:大丈夫|だいじょうぶ}」中文'));

      final open = rectOf(tester, '「');
      final base = rectOf(tester, '大丈夫');
      final ruby = rectOf(tester, 'だいじょうぶ');

      expect(open.right, closeTo(base.left, geometryEps));
      expect(ruby.left, lessThan(base.left));
    });

    for (final open in '「『（【〈《〔［｛([{'.split('')) {
      testWidgets('$open 併進下一個盒子', (tester) async {
        await pumpApp(tester, child: MixedText('中文$open{ja:私|わたし}中文'));

        expect(find.text(open), findsOneWidget);
      });
    }

    testWidgets('「知ってる」：不在 知 之後斷成「ってる」開頭', (tester) async {
      for (var width = 90.0; width <= 375; width += 1) {
        await pumpApp(tester, width: width, child: _mixed(_tallySample));
        expectKinsoku(
          linesOf(tester, find.byType(MixedText), ignore: _rubies),
          '$width',
        );
      }
    });

    testWidgets('小書き假名併進前一個盒子，底字、假名相連', (tester) async {
      await pumpApp(tester, child: _mixed(_tallySample));

      final base = rectOf(tester, '知');
      final small = rectOf(tester, 'っ');

      expect(find.text('てる'), findsOneWidget);
      expect(small.left, closeTo(base.right, geometryEps));
    });

    for (final (first, rest) in [
      ('ー', 'ると'),
      ('々', 'です'),
      ('ゝ', 'です'),
      ('ゞ', 'です'),
      ('ヽ', 'です'),
      ('ヾ', 'です'),
      ('ャ', 'ンプ'),
      ('ゎ', 'ない'),
    ]) {
      testWidgets('$first 併進前一個盒子', (tester) async {
        await pumpApp(
          tester,
          child: _mixed([
            MixedSpanDto.ja(
              text: '私$first$rest',
              ruby: [
                const RubyPartDto(base: '私', ruby: 'わたし'),
                RubyPartDto(base: '$first$rest'),
              ],
            ),
          ]),
        );

        expect(find.text(first), findsOneWidget);
      });
    }

    testWidgets('整段都是不能在行首的字：併進前一盒後不留空盒，後面的標點接著併', (tester) async {
      await pumpApp(
        tester,
        child: _mixed(const [
          MixedSpanDto.ja(
            text: '待っ',
            ruby: [
              RubyPartDto(base: '待', ruby: 'ま'),
              RubyPartDto(base: 'っ'),
            ],
          ),
          MixedSpanDto.zh(text: '。後面'),
        ]),
      );

      expect(find.text('っ。'), findsOneWidget);
      expect(
        rectOf(tester, 'っ。').left,
        closeTo(rectOf(tester, '待').right, geometryEps),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ruby 段後接不帶讀音的日文段：開頭的小書き假名併進盒子', (tester) async {
      await pumpApp(
        tester,
        child: _mixed(const [
          MixedSpanDto.ja(
            text: '知',
            ruby: [RubyPartDto(base: '知', ruby: 'し')],
          ),
          MixedSpanDto.ja(
            text: 'ってる',
            ruby: [RubyPartDto(base: 'ってる')],
          ),
        ]),
      );

      expect(find.text('っ'), findsOneWidget);
    });

    // review_f F3：中文後面的日文段開頭也不能在行首。
    testWidgets('中文接小書き假名開頭的日文段：各種寬度都不落在行首', (tester) async {
      const spans = [
        MixedSpanDto.zh(text: '說話時的語尾助詞會變成'),
        MixedSpanDto.ja(
          text: 'って',
          ruby: [RubyPartDto(base: 'って')],
        ),
        MixedSpanDto.zh(text: '，例如朋友之間'),
        MixedSpanDto.ja(
          text: 'ょう',
          ruby: [RubyPartDto(base: 'ょう')],
        ),
        MixedSpanDto.zh(text: '的說法。'),
      ];
      for (var width = 90.0; width <= 300; width += 1) {
        await pumpApp(tester, width: width, child: _mixed(spans));
        expect(tester.takeException(), isNull, reason: '$width');
        expectKinsoku(
          linesOf(tester, find.byType(MixedText), ignore: _rubies),
          '$width',
        );
      }
    });

    // 內容常寫「都用 {ja:って}」。空白剛好超出行寬時，引擎在空白之後換行，WORD JOINER 擋不住。
    testWidgets('空白接小書き假名：字級放大時不落在行首', (tester) async {
      await pumpApp(
        tester,
        width: 343,
        textScale: 1.3,
        child: _mixed(_quoteRuleSpans()),
      );

      expect(tester.takeException(), isNull);
      expectKinsoku(
        linesOf(
          tester,
          find.byType(MixedText),
          ignore: const {'い', 'おも', 'く', ' '},
        ),
        '343×1.3',
      );
    });

    testWidgets('段內空白接刪節號：字級放大時不落在行首', (tester) async {
      const spans = [MixedSpanDto.zh(text: '中文中文中文中文中文中文都用 …後面接否定。')];
      for (var width = 240.0; width <= 300; width += 0.25) {
        await pumpApp(
          tester,
          width: width,
          textScale: 1.3,
          child: _mixed(spans),
        );
        expect(tester.takeException(), isNull, reason: '$width');
        expectKinsoku(
          linesOf(tester, find.byType(MixedText), ignore: _rubies),
          '$width',
        );
      }
    });

    testWidgets('空白換成不換行的空白時，報讀仍是原文', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        child: _mixed(const [MixedSpanDto.zh(text: '加上 …')]),
      );

      expect(tester.getSemantics(mixedParagraph()).label, '加上 …');
      handle.dispose();
    });

    testWidgets('不換行的空白和一般空白等寬（字型沒有這個字時會露出方塊）', (tester) async {
      await pumpApp(tester, child: const SizedBox());
      double widthOf(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      for (final style in [
        TypeScale.body.style(const Color(0xFF000000)),
        jaStyle(TypeScale.jaBody, const Color(0xFF000000)),
      ]) {
        expect(
          widthOf('字\u00A0字', style),
          closeTo(widthOf('字 字', style), 0.01),
        );
      }
    });

    testWidgets('段落第一個字是小書き假名時可以在行首', (tester) async {
      await pumpApp(
        tester,
        child: _mixed(const [
          MixedSpanDto.ja(
            text: 'っ',
            ruby: [RubyPartDto(base: 'っ')],
          ),
          MixedSpanDto.zh(text: '是促音。'),
        ]),
      );

      expect(
        linesOf(tester, find.byType(MixedText), ignore: _rubies).first,
        startsWith('っ'),
      );
    });

    testWidgets('不帶讀音的日文段：文字和報讀都維持原文', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, child: const MixedText('念{ja:コーヒー}就好'));

      final data = tester.getSemantics(mixedParagraph()).getSemanticsData();

      expect(
        find.textContaining('念コーヒー就好', findRichText: true),
        findsOneWidget,
      );
      expect(data.attributedLabel.string, '念コーヒー就好');
      handle.dispose();
    });

    testWidgets('語意標籤：併進盒子的開括號仍念一次，順序不變', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, child: const MixedText('語調上揚的「{ja:大丈夫|だいじょうぶ}？」是'));

      final data = tester.getSemantics(mixedParagraph()).getSemanticsData();

      expect(data.attributedLabel.string, '語調上揚的「\n大丈夫？」\n是');
      handle.dispose();
    });

    testWidgets('語意標籤：段首只有開括號也念出來', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, child: const MixedText('「{ja:大丈夫|だいじょうぶ}」'));

      final data = tester.getSemantics(mixedParagraph()).getSemanticsData();

      expect(data.attributedLabel.string, '「\n大丈夫」');
      handle.dispose();
    });

    testWidgets('語意標籤：「知ってる」整段念一次，不因拆盒重複', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, child: _mixed(const [_shitteru]));

      final data = tester.getSemantics(mixedParagraph()).getSemanticsData();

      expect(data.attributedLabel.string, '知ってる');
      handle.dispose();
    });
  });

  group('RubyLine', () {
    final quoted = [
      _word('私', reading: 'わたし'),
      _word('は'),
      _punct('「'),
      _word('学生', reading: 'がくせい'),
      _punct('」'),
      _word('って'),
      _word('言'),
      _word('っす'),
      _punct('。'),
    ];

    testWidgets('開括號不落在行尾、って 不落在行首：各種寬度', (tester) async {
      for (final spacing in [false, true]) {
        for (var width = 160.0; width <= 340; width += 2) {
          await pumpApp(
            tester,
            width: width,
            child: RubyLine(
              words: quoted,
              policy: _policy(spacing: spacing),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$width');
          expectKinsoku(
            linesOf(tester, find.byType(RubyLine), ignore: _rubies),
            '$width $spacing',
          );
        }
      }
    });

    testWidgets('開括號放在下一個詞的盒子裡，分詞空格在括號前面', (tester) async {
      await pumpApp(
        tester,
        child: RubyLine(words: quoted, policy: _policy(spacing: true)),
      );

      final open = rectOf(tester, '「');

      expect(open.right, closeTo(rectOf(tester, '学生').left, geometryEps));
      expect(
        open.left - rectOf(tester, 'は').right,
        closeTo(24 * 0.32, geometryEps),
      );
    });

    testWidgets('って 的 っ 併進前一個詞的盒子，分詞空格不變、兩個字都查到 って', (tester) async {
      final tapped = <String>[];
      await pumpApp(
        tester,
        child: RubyLine(
          words: [_word('言'), _word('って')],
          policy: _policy(spacing: true),
          onWordTap: (word) => tapped.add(word.surface),
        ),
      );

      final gap = rectOf(tester, 'っ').left - rectOf(tester, '言').right;
      final inner = rectOf(tester, 'て').left - rectOf(tester, 'っ').right;
      await tester.tapAt(rectOf(tester, 'っ').center);
      await tester.tapAt(rectOf(tester, 'て').center);
      await tester.tapAt(rectOf(tester, '言').center);

      expect(gap, closeTo(24 * 0.32, geometryEps));
      expect(inner, closeTo(0, geometryEps));
      expect(tapped, ['って', 'って', '言']);
    });

    // review_f F1：詞組比一行還寬時只能在組內換行，っ 開頭的詞不能因此落在行首。
    for (final (name, words) in <(String, List<WordDto>)>[
      ('分かった ってば', [_word('分かった'), _word('ってば'), _punct('。')]),
      ('かわいい っしょ', [_word('この服、'), _word('かわいい'), _word('っしょ'), _punct('？')]),
      ('静か っていうか', [_word('静か'), _word('っていうか、'), _word('ちょっと寂しい')]),
    ]) {
      for (final spacing in [false, true]) {
        testWidgets('$name：288 寬、1.6 倍字級不落在行首（分詞空格 $spacing）', (tester) async {
          await pumpApp(
            tester,
            width: 288,
            textScale: 1.6,
            child: RubyLine(
              words: words,
              policy: _policy(spacing: spacing),
            ),
          );

          expect(tester.takeException(), isNull);
          expectKinsoku(
            linesOf(tester, find.byType(RubyLine), ignore: _rubies),
            name,
          );
        });
      }
    }

    testWidgets('前一個詞有收尾標點：っ 排在標點後面，順序不變', (tester) async {
      await pumpApp(
        tester,
        child: RubyLine(
          words: [_word('学生'), _punct('」'), _word('って')],
          policy: _policy(),
        ),
      );

      expect(
        rectOf(tester, '」').right,
        lessThanOrEqualTo(rectOf(tester, 'っ').left + geometryEps),
      );
      expect(
        rectOf(tester, 'っ').right,
        closeTo(rectOf(tester, 'て').left, geometryEps),
      );
    });

    testWidgets('挖空的詞不拆：答案的字不進樹', (tester) async {
      await pumpApp(
        tester,
        child: RubyLine(
          words: [_word('言'), _word('って')],
          policy: _policy(),
          blankWordIndex: 1,
        ),
      );

      expect(find.text('っ'), findsNothing);
      expect(find.text('って'), findsNothing);
    });

    testWidgets('前一個詞挖空時 って 不拆，整個詞照畫', (tester) async {
      await pumpApp(
        tester,
        child: RubyLine(
          words: [_word('言'), _word('って')],
          policy: _policy(),
          blankWordIndex: 0,
        ),
      );

      expect(find.text('って'), findsOneWidget);
    });

    testWidgets('沒有分段資料的詞不會讓排版例外', (tester) async {
      await pumpApp(
        tester,
        child: RubyLine(
          words: [
            _word('言'),
            wordFixture(
              surface: 'って',
              kana: 'って',
              romaji: 'tte',
              ruby: const [],
            ),
          ],
          policy: _policy(),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('整個詞都是不能在行首的字時不拆', (tester) async {
      await pumpApp(
        tester,
        child: RubyLine(
          words: [_word('言'), _word('っ'), _punct('。')],
          policy: _policy(),
        ),
      );

      final box = find.ancestor(
        of: find.text('。'),
        matching: find.byType(RubyBox),
      );
      expect(
        find.descendant(of: box, matching: find.text('っ')),
        findsOneWidget,
      );
    });

    testWidgets('比一行還長的詞：詞內換行也不讓小書き假名開頭', (tester) async {
      final word = wordFixture(
        surface: '東京大学っちゃ',
        kana: 'x',
        romaji: 'x',
        ruby: const [
          RubyPartDto(base: '東京大学', ruby: 'とうきょうだいがく'),
          RubyPartDto(base: 'っちゃ'),
        ],
      );
      for (var width = 90.0; width <= 200; width += 2) {
        await pumpApp(
          tester,
          width: width,
          child: RubyLine(words: [word], policy: _policy()),
        );
        expect(tester.takeException(), isNull, reason: '$width');
        expectKinsoku(
          linesOf(
            tester,
            find.byType(RubyLine),
            ignore: const {'とうきょうだいがく', ' '},
          ),
          '$width',
        );
      }
    });

    testWidgets('沒有讀音、比一行還長的詞：字中間換行也守禁則，報讀仍是原文', (tester) async {
      final handle = tester.ensureSemantics();
      final word = wordFixture(
        surface: 'いらっしゃいませちょっとコーヒー',
        kana: 'x',
        romaji: 'x',
      );
      for (var width = 80.0; width <= 300; width += 2) {
        await pumpApp(
          tester,
          width: width,
          child: RubyLine(words: [word], policy: _policy()),
        );
        expect(find.text(word.surface), findsOneWidget);
        expectKinsoku(
          linesOf(tester, find.byType(RubyLine), ignore: const {' '}),
          '$width',
        );
      }
      final data = tester
          .getSemantics(find.byType(RubyLine))
          .getSemanticsData();
      expect(data.attributedLabel.string, word.surface);
      handle.dispose();
    });

    testWidgets('挖空的詞前後有括號：括號在格子兩側，答案不進樹', (tester) async {
      await pumpApp(
        tester,
        child: RubyLine(words: quoted, policy: _policy(), blankWordIndex: 3),
      );

      expect(find.text('学生'), findsNothing);
      expect(find.text('がくせい'), findsNothing);
      expect(find.text('「'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('語意標籤不因併盒改變', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        child: RubyLine(words: quoted, policy: _policy()),
      );

      final data = tester
          .getSemantics(find.byType(RubyLine))
          .getSemanticsData();

      expect(data.attributedLabel.string, '私は「学生」って言っす。');
      handle.dispose();
    });
  });
}

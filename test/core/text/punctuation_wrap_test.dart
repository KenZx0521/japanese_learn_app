// 裁決 6：收尾標點不可單獨落到行首；SPEC-02：空格答案不進語意樹。
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:japanese_learn_app/core/text/ruby_line.dart';

import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

double _rowOf(WidgetTester tester, String text) =>
    tester.getBottomLeft(find.text(text)).dy;

void main() {
  group('MixedText', () {
    testWidgets('假名段後的句號和假名在同一行', (tester) async {
      // 剛好放得下假名段，句號若分開就會換到下一行
      await pumpApp(
        tester,
        width: 60,
        child: const MixedText('{ja:語|ご}。後面還有字'),
      );

      expect(find.text('。'), findsOneWidget);
      expect(_rowOf(tester, '。'), closeTo(_rowOf(tester, '語'), 10));
      expect(tester.takeException(), isNull);
    });

    testWidgets('比一行還長的假名段加句號也不溢位', (tester) async {
      await pumpApp(
        tester,
        width: 140,
        textScale: 2,
        child: const MixedText('{ja:どうもありがとうございました|どうもありがとうございました}。'),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('連續收尾標點一起併入', (tester) async {
      await pumpApp(tester, child: const MixedText('{ja:語|ご}」。後面'));

      expect(find.text('」。'), findsOneWidget);
      expect(find.textContaining('後面', findRichText: true), findsOneWidget);
    });

    testWidgets('沒有振假名的日文仍走文字段', (tester) async {
      await pumpApp(tester, child: const MixedText('{ja:は}。後面'));

      expect(find.text('。'), findsNothing);
    });
  });

  group('RubyLine', () {
    final longWord = wordFixture(
      surface: '東京大学',
      kana: 'とうきょうだいがく',
      romaji: '',
      ruby: const [
        RubyPartDto(base: '東京', ruby: 'とうきょう'),
        RubyPartDto(base: '大学', ruby: 'だいがく'),
      ],
    );
    final period = wordFixture(
      surface: '。',
      kana: '。',
      romaji: '',
      isPunct: true,
    );

    testWidgets('詞剛好滿行時句號不會單獨換行', (tester) async {
      await pumpApp(
        tester,
        // 版面寬度：兩段 ruby 不含句號剛好放得下
        width: 120,
        child: RubyLine(
          words: [longWord, period],
          policy: displayPolicyFixture(),
          baseSize: 24,
        ),
      );

      expect(_rowOf(tester, '。'), closeTo(_rowOf(tester, '大学'), 8));
      expect(tester.takeException(), isNull);
    });

    testWidgets('挖空的詞不進語意樹', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        child: RubyLine(
          words: sentenceWordsFixture(),
          policy: displayPolicyFixture(),
          semanticLabel: '私は学生です。',
          blankWordIndex: 2,
          onWordTap: (_) {},
        ),
      );

      final data = tester
          .getSemantics(find.byType(RubyLine))
          .getSemanticsData();
      final actions = [
        for (final id in data.customSemanticsActionIds ?? const <int>[])
          CustomSemanticsAction.getAction(id)?.label,
      ];

      expect(data.attributedLabel.string, '私は空格です。');
      expect(actions, isNot(contains('查詢 学生（2）')));
      expect(actions, contains('查詢 私（0）'));
      handle.dispose();
    });

    testWidgets('作答後語意回到完整句子', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        child: RubyLine(
          words: sentenceWordsFixture(),
          policy: displayPolicyFixture(),
          semanticLabel: '私は学生です。',
        ),
      );

      final data = tester
          .getSemantics(find.byType(RubyLine))
          .getSemanticsData();

      expect(data.attributedLabel.string, '私は学生です。');
      handle.dispose();
    });
  });
}

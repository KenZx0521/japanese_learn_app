import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/ja_text.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';

void main() {
  group('JaText', () {
    testWidgets('一律用 Klee 字型與 ja locale，fallback 留空', (tester) async {
      await pumpApp(tester, child: const JaText('こんにちは'));

      final text = tester.widget<Text>(find.text('こんにちは'));
      expect(text.locale, jaLocale);
      expect(text.style?.fontFamily, AppFonts.ja);
      expect(text.style?.locale, jaLocale);
      expect(text.style?.fontFamilyFallback, isEmpty);
    });

    testWidgets('語意的 attributedLabel 含 ja-JP', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, child: const JaText('猫'));

      final data = tester.getSemantics(find.text('猫')).getSemanticsData();

      final attribute = data.attributedLabel.attributes.single;
      expect(attribute, isA<LocaleStringAttribute>());
      expect((attribute as LocaleStringAttribute).locale, jaLocale);
      handle.dispose();
    });

    testWidgets('字級縮放受該級 clamp 限制', (tester) async {
      await pumpApp(
        tester,
        textScale: 3,
        child: const JaText('字', scale: TypeScale.jaHero),
      );

      final text = tester.widget<Text>(find.text('字'));
      expect(text.textScaler?.scale(10), closeTo(12, 0.01));
    });
  });

  group('MixedText', () {
    testWidgets('Zh 段用 NotoSansTC，Ja 段兩個 locale 都設', (tester) async {
      await pumpApp(tester, child: const MixedText('看{ja:あ}的發音'));

      final richText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('看'),
        ),
      );
      final spans = <TextSpan>[];
      richText.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) spans.add(span);
        return true;
      });

      final zh = spans.firstWhere((s) => s.text == '看');
      final ja = spans.firstWhere((s) => s.text == 'あ');
      expect(zh.style?.fontFamily, AppFonts.sans);
      expect(ja.style?.fontFamily, AppFonts.ja);
      expect(ja.locale, jaLocale);
      expect(ja.style?.locale, jaLocale);
    });

    testWidgets('有讀音時顯示振假名', (tester) async {
      await pumpApp(tester, child: const MixedText('吃飯：{ja:飯を食べる|めしをたべる}'));

      expect(find.text('めしをたべる'), findsOneWidget);
      expect(find.text('飯を食べる'), findsOneWidget);
    });

    testWidgets('語法錯誤時整段當中文', (tester) async {
      await pumpApp(tester, child: const MixedText('{ja:'));

      expect(find.textContaining('{ja:'), findsOneWidget);
    });

    testWidgets('呼叫 Rust 的 parse，不自行判定', (tester) async {
      final backend = FakeBackend();
      await pumpApp(tester, backend: backend, child: const MixedText('純中文'));

      expect(find.text('純中文'), findsOneWidget);
    });

    testWidgets('字級 1.5 倍、320 寬不溢位', (tester) async {
      await pumpApp(
        tester,
        width: 320,
        textScale: 1.5,
        child: const MixedText(
          '{ja:わたし|わたし}是「我」的意思，這一句話夠長，'
          '要讓它在窄螢幕上換行而不溢位，{ja:学校|がっこう}也一樣。',
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  test('FakeTextTools 解析 {ja:…|…}', () {
    final spans = const FakeTextTools().parseMixedText('看{ja:猫|ねこ}！');

    expect(spans, hasLength(3));
    expect(spans[1], isA<MixedSpanDto_Ja>());
    expect((spans[1] as MixedSpanDto_Ja).ruby.single.ruby, 'ねこ');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:material_ui/material_ui.dart' show Color;

void main() {
  const text = 4.5;
  const component = 3.0;

  void expectAll(
    String name,
    Iterable<Color> foreground,
    Iterable<Color> background,
    double minimum,
  ) {
    for (final fg in foreground) {
      for (final bg in background) {
        expect(
          contrastRatio(fg, bg),
          greaterThanOrEqualTo(minimum),
          reason: '$name：$fg 對 $bg 對比不足',
        );
      }
    }
  }

  for (final (label, t) in [
    ('淺色', AppTokens.light),
    ('深色', AppTokens.dark),
    ('淺色高對比', AppTokens.light.highContrast),
    ('深色高對比', AppTokens.dark.highContrast),
  ]) {
    group('對比度 $label', () {
      final surfaces = [t.paper.base, t.paper.raised, t.paper.sunken];

      test('文字色在所有紙面上 ≥4.5:1', () {
        expectAll(
          'ink',
          [t.ink.primary, t.ink.secondary, t.ink.tertiary],
          surfaces,
          text,
        );
        expectAll('語意色', [t.shu, t.ai, t.moegi, t.kincha], surfaces, text);
      });

      test('朱底文字 ≥4.5:1', () {
        expect(contrastRatio(t.onShu, t.shu), greaterThanOrEqualTo(text));
      });

      test('主按鈕 ink.primary 底配 paper.base 字 ≥4.5:1', () {
        expect(
          contrastRatio(t.paper.base, t.ink.primary),
          greaterThanOrEqualTo(text),
        );
      });

      test('元件邊界 line.strong ≥3:1', () {
        expectAll('line.strong', [t.line.strong], surfaces, component);
      });
    });
  }

  test('contrastRatio 符合 WCAG：黑白為 21:1、同色為 1:1', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
    expect(
      contrastRatio(const Color(0xFF123456), const Color(0xFF123456)),
      closeTo(1, 0.0001),
    );
  });

  test('表內數值與 §4.2 實測一致', () {
    expect(
      contrastRatio(AppTokens.light.ink.primary, AppTokens.light.paper.base),
      closeTo(15.1, 0.2),
    );
    expect(
      contrastRatio(AppTokens.dark.shu, AppTokens.dark.paper.base),
      closeTo(6.4, 0.2),
    );
  });
}

// U14：K3 規則卡在 320 寬，「。」不落到行首（真實內容，rust/content/kana/rules.json）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:japanese_learn_app/features/kana/rule_card_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'ruby_geometry.dart';

final _reading = RegExp(r'\{ja:[^|{}]*\|([^{}]*)\}');

List<Map<String, dynamic>> _rules() {
  final file = File('rust/content/kana/rules.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (json['items'] as List).cast<Map<String, dynamic>>();
}

RuleCardDto _card(Map<String, dynamic> rule) {
  final base = ruleCardFixture();
  return RuleCardDto(
    id: rule['id'] as String,
    lessonId: rule['lesson'] as String,
    titleZh: rule['title_zh'] as String,
    bodyZh: rule['body_zh'] as String,
    examples: base.examples,
    soundGroups: const [],
    drillIds: const [],
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  RuleCardDto card, {
  required double width,
  double textScale = 1,
}) async {
  final backend = FakeBackend();
  backend.kana.ruleCardStub.returns(card);
  await pumpApp(
    tester,
    backend: backend,
    width: width,
    textScale: textScale,
    settings: settingsFixture(),
    child: RuleCardScreen(ruleId: card.id),
  );
}

void main() {
  testWidgets('每張規則卡在 320 寬：說明文字的行首行尾都守禁則', (tester) async {
    for (final rule in _rules()) {
      final card = _card(rule);
      final readings = {
        ' ',
        for (final source in [card.titleZh, card.bodyZh])
          for (final match in _reading.allMatches(source)) match.group(1)!,
      };
      for (final scale in [1.0, 1.5, 2.0]) {
        await _pumpCard(tester, card, width: 320, textScale: scale);
        expect(tester.takeException(), isNull, reason: card.id);
        for (var i = 0; i < find.byType(MixedText).evaluate().length; i++) {
          expectKinsoku(
            linesOf(
              tester,
              find.byType(MixedText).at(i),
              ignore: readings,
              tolerance: 12 * scale,
            ),
            '${card.id} ×$scale',
          );
        }
      }
    }
  });

  testWidgets('音調入門卡：各種寬度下「。」和「飴」都在同一行', (tester) async {
    final rule = _rules().firstWhere(
      (rule) => rule['id'] == 'ka.rule.accent_intro',
    );
    final card = _card(rule);
    var sawLineEnd = false;
    for (var width = 300.0; width <= 375; width += 1) {
      await _pumpCard(tester, card, width: width);

      final candy = rectOf(tester, '飴');
      final period = rectOf(tester, '。');

      expect(period.left, closeTo(candy.right, geometryEps), reason: '$width');
      expect(
        (period.bottom - candy.bottom).abs(),
        lessThan(12),
        reason: '$width',
      );
      // 盒子落在行尾：若「。」沒有併進盒子，這裡就會單獨掉到下一行
      sawLineEnd |= period.right > width - 32 - period.width;
    }
    expect(sawLineEnd, isTrue);
  });

  testWidgets('不帶讀音的日文段（文字引擎自己換行）也守禁則', (tester) async {
    for (var width = 60.0; width <= 240; width += 1) {
      await pumpApp(
        tester,
        width: width,
        child: const MixedText(
          '{ja:ちょっとまってくださいしゅっぱつはきょうじゃなくてあしたです}。'
          '{ja:コーヒーとジュースをチェックしてショッピングセンターへ}。',
        ),
      );

      expectKinsoku(linesOf(tester, find.byType(MixedText)), '$width');
    }
  });
}

// U3：窄寬或大字級時「知道了」移到提示文字下方，文字不被擠成一行幾個字。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:japanese_learn_app/design/widgets/pressable.dart';
import 'package:japanese_learn_app/design/widgets/question_hint_strip.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump_app.dart';

const _hint = '語音由裝置合成，沒有角色情緒，縮約形也比真人清楚。這裡只是橋樑，真實語感要靠真人影音。';

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
  VoidCallback? onDismiss,
}) => pumpApp(
  tester,
  width: width,
  textScale: textScale,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
    child: QuestionHintStrip(hint: _hint, onDismiss: onDismiss ?? () {}),
  ),
);

void main() {
  testWidgets('375 寬、字級 1 倍：知道了在文字右側', (tester) async {
    await _pump(tester, width: 375, textScale: 1);

    final text = tester.getRect(find.text(_hint));
    final button = tester.getRect(find.text('知道了'));

    expect(button.left, greaterThanOrEqualTo(text.right));
    expect(button.top, lessThan(text.bottom));
  });

  testWidgets('320 寬、字級 2 倍：知道了移到文字下方，文字用滿整列', (tester) async {
    var dismissed = false;
    await _pump(
      tester,
      width: 320,
      textScale: 2,
      onDismiss: () => dismissed = true,
    );

    final text = tester.getRect(find.text(_hint));
    final button = tester.getRect(find.text('知道了'));
    final strip = tester.getRect(find.byType(QuestionHintStrip));

    expect(tester.takeException(), isNull);
    expect(button.top, greaterThanOrEqualTo(text.bottom));
    // 2 倍字級一個字 32px；文字欄至少放得下 8 個字（原本約 5 個）
    expect(text.width, greaterThanOrEqualTo(8 * 32));
    expect(text.right, lessThanOrEqualTo(strip.right + 0.01));
    // integ F2：疊放時靠右（不是置中），點擊範圍也不撐滿整列
    final pressable = tester.getRect(
      find.ancestor(of: find.text('知道了'), matching: find.byType(Pressable)),
    );
    expect(button.right, greaterThan(strip.right - AppSpace.s3 * 2 - 1));
    expect(pressable.width, lessThan(strip.width / 2));

    await tester.tap(find.text('知道了'));
    expect(dismissed, isTrue);
  });

  testWidgets('375 寬、字級 1.5 倍時也移到下方', (tester) async {
    await _pump(tester, width: 375, textScale: 1.5);

    final text = tester.getRect(find.text(_hint));
    final button = tester.getRect(find.text('知道了'));

    expect(button.top, greaterThanOrEqualTo(text.bottom));
  });
}

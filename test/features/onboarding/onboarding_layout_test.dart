// 視覺 QA 的版面回歸：標題位置與選項文字置中。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/text/ja_text.dart';
import 'package:japanese_learn_app/design/widgets/pressable.dart';

import '../quiz/quiz_fixtures.dart';
import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('步驟頭高度固定：O1 沒有「上一步」時標題也在同一位置', (tester) async {
    await pumpApp(
      tester,
      backend: FakeBackend(),
      location: '/welcome',
      onboarded: false,
    );
    final firstTop = tester.getTopLeft(find.text('從五十音開始。')).dy;

    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();
    final secondTop = tester.getTopLeft(find.text('你學過日文嗎？')).dy;

    // 兩個標題字級不同，行高中心才可比；頂端差不得超過字級差造成的 10
    expect((firstTop - secondTop).abs(), lessThanOrEqualTo(10));
  });

  testWidgets('O1 稿紙格：寬螢幕不會撐成大空格，字級是格寬的一半', (tester) async {
    await pumpApp(
      tester,
      backend: FakeBackend(),
      location: '/welcome',
      onboarded: false,
      width: 1024,
      height: 768,
    );

    final kana = tester.widget<JaText>(find.widgetWithText(JaText, 'あ'));
    expect(kana.fontSize, lessThanOrEqualTo(48));
    expect(kana.fontSize, greaterThanOrEqualTo(40));
  });

  testWidgets('320 寬與 2 倍字級：分鐘格的文字不在詞中換行', (tester) async {
    for (final scale in const [1.0, 2.0]) {
      await pumpApp(
        tester,
        backend: FakeBackend(),
        location: '/welcome/o4',
        onboarded: false,
        width: 320,
        height: 640,
        textScale: scale,
      );
      final lines = tester.getSize(find.text('10 分鐘')).height;
      expect(lines, lessThan(32), reason: '字級 $scale 不應該斷成兩行');
    }
  });

  testWidgets('畢業考開始頁有出口，可以回到 O3', (tester) async {
    final backend = FakeBackend();
    backend.drills.checkpointStartStub.returns([choiceQuestion()]);
    await pumpApp(
      tester,
      backend: backend,
      location: '/welcome/placement',
      onboarded: false,
    );

    expect(find.text('上一步'), findsOneWidget);
  });

  testWidgets('O4 分鐘格的文字在格子內垂直置中', (tester) async {
    await pumpApp(
      tester,
      backend: FakeBackend(),
      location: '/welcome/o4',
      onboarded: false,
    );

    final label = find.text('10 分鐘');
    final tile = find.ancestor(of: label, matching: find.byType(Pressable));
    final labelCenter = tester.getCenter(label).dy;
    final tileCenter = tester.getCenter(tile.first).dy;
    expect((labelCenter - tileCenter).abs(), lessThan(1.5));
    // 文字框等於一行高時才代表字形真的置中；被 Container 撐高時字會貼上緣
    expect(tester.getSize(label).height, lessThan(24));
  });
}

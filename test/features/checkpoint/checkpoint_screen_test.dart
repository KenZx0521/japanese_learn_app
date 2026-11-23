// 視覺 QA：D3 從計畫頁進來時畫面上要有出口（沒有題目時尤其需要）。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/features/session/drill/checkpoint_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('手動進入檢定時有「離開」', (tester) async {
    final backend = FakeBackend();
    backend.today.todayStub.returns(todayFixture());
    backend.plan.viewStub.returns(planViewFixture());
    backend.drills.checkpointStartStub.returns(const []);

    await pumpApp(
      tester,
      backend: backend,
      child: const CheckpointScreen(milestoneId: 'ms.survive'),
    );

    expect(find.text('這課目前沒有題目'), findsOneWidget);
    expect(find.text('離開'), findsOneWidget);
  });
}

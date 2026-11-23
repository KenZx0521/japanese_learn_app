// 視覺 QA：合格章要以整頁為範圍置中，不是壓在成績文字與按鈕上。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/stamp_overlay.dart';
import 'package:japanese_learn_app/features/checkpoint/checkpoint_result_view.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('通過時蓋章範圍撐滿可用高度', (tester) async {
    const available = 600.0;
    await pumpApp(
      tester,
      settle: false,
      child: SizedBox(
        height: available,
        child: CheckpointResultView(
          result: const CheckpointResultDto(
            milestoneId: 'ms.hira',
            correct: 20,
            total: 20,
            scorePercent: 100,
            passed: true,
            weakIds: [],
          ),
          passedNote: '通過了',
          failedNote: '沒關係',
          showWeak: false,
          continueLabel: '繼續',
          onContinue: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(StampOverlay)).height, available);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}

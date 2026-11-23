import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/paper_scaffold.dart';
import 'package:japanese_learn_app/features/dialogue/dialogue.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'dialogue_fixtures.dart';

Widget _runner(
  DialogueDto dialogue, {
  required List<int> phases,
  required VoidCallback onFinished,
  bool autoFinish = false,
}) => PaperScaffold(
  scrollable: false,
  body: DialogueRunner(
    dialogue: dialogue,
    phases: phases,
    autoFinish: autoFinish,
    onFinished: onFinished,
  ),
);

void main() {
  group('自動結束（T2）', () {
    testWidgets('跑完直接回報一次，不顯示完成面板', (tester) async {
      var finished = 0;
      await pumpApp(
        tester,
        tts: FakeTtsEngine(),
        child: _runner(
          dialogueFixture(),
          phases: const [2],
          autoFinish: true,
          onFinished: () => finished++,
        ),
      );

      await tester.ensureVisible(find.text('完成這段'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成這段'));
      await tester.pumpAndSettle();

      expect(finished, 1);
      expect(find.byType(HankoBadge), findsNothing);
      expect(find.text('這段對話練完了。'), findsNothing);
    });

    testWidgets('全部階段略過時仍說明原因，按了才回報', (tester) async {
      var finished = 0;
      await pumpApp(
        tester,
        settings: settingsFixture(silentMode: true),
        child: _runner(
          dialogueFixture(),
          phases: const [1, 3],
          autoFinish: true,
          onFinished: () => finished++,
        ),
      );

      expect(find.textContaining('要聽的部分先略過'), findsOneWidget);
      expect(finished, 0);

      await tester.tap(find.text('完成'));
      await tester.tap(find.text('完成'));
      await tester.pump();

      expect(finished, 1);
    });
  });
}

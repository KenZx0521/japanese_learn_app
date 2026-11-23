import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/hanko_badge.dart';
import '../../design/widgets/ink_buttons.dart';
import '../quiz/quiz.dart';

/// D2 結束頁：第一次作答的成績，重出的題不計。
class DrillFinishedView extends StatelessWidget {
  const DrillFinishedView({
    required this.outcome,
    required this.onRedo,
    required this.onDone,
    super.key,
  });

  final QuizOutcome outcome;
  final VoidCallback onRedo;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final correct = outcome.firstTryCorrect;
    final total = outcome.firstTryCount;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: AppText('這一輪練完了', scale: TypeScale.displayM)),
              SizedBox(width: AppSpace.s3),
              HankoBadge('済'),
            ],
          ),
          const SizedBox(height: AppSpace.s5),
          Semantics(
            liveRegion: true,
            child: AppText(
              '第一次就答對 $correct 題，共 $total 題',
              scale: TypeScale.title,
            ),
          ),
          if (correct < total) ...[
            const SizedBox(height: AppSpace.s2),
            AppText('答錯的題目都重新做過了。', color: t.ink.secondary),
          ],
          const SizedBox(height: AppSpace.s6),
          InkButton(
            label: '完成',
            expanded: true,
            autofocus: true,
            onPressed: onDone,
          ),
          const SizedBox(height: AppSpace.s2),
          GhostButton(label: '再做一次', expanded: true, onPressed: onRedo),
        ],
      ),
    );
  }
}

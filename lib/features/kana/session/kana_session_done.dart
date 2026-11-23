import 'package:material_ui/material_ui.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/hanko_badge.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../quiz/quiz.dart';

/// K2 收尾：本回合成績。熟練在答題當下寫入，這裡只呈現。
class KanaSessionDone extends StatelessWidget {
  const KanaSessionDone({
    required this.outcome,
    required this.onClose,
    required this.onRetry,
    super.key,
  });

  final QuizOutcome outcome;
  final VoidCallback onClose, onRetry;

  int get _masteredCount => {
    for (final record in outcome.records)
      if (record.verdict?.mastery case final mastery? when mastery.mastered)
        mastery.kanaId,
  }.length;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final mastered = _masteredCount;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HankoBadge('済'),
          const SizedBox(height: AppSpace.s4),
          AppText(
            '答對 ${outcome.firstTryCorrect}／${outcome.firstTryCount} 題',
            scale: TypeScale.title,
          ),
          if (mastered > 0) ...[
            const SizedBox(height: AppSpace.s2),
            AppText('這回合熟練了 $mastered 個字', color: t.ink.secondary),
          ],
          const SizedBox(height: AppSpace.s6),
          Wrap(
            spacing: AppSpace.s3,
            runSpacing: AppSpace.s3,
            children: [
              InkButton(label: '完成', onPressed: onClose, autofocus: true),
              GhostButton(label: '再練一次', onPressed: onRetry),
            ],
          ),
        ],
      ),
    );
  }
}

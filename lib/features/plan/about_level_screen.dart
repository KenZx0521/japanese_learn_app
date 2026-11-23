import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/ruled_list.dart';
import '../../design/widgets/side_rule_note.dart';
import 'scope_copy.dart';

final _stageProvider = FutureProvider.autoDispose<ContentStage>(
  (ref) async =>
      (await ref.watch(courseRepositoryProvider).overview()).contentStage,
);

/// P2 關於程度（§3.8）：只寫這一版實際做得到的事（課綱 §1.3、O7）。
class AboutLevelScreen extends ConsumerWidget {
  const AboutLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PaperScaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PopBackLine(),
        Semantics(
          header: true,
          child: const AppText('關於程度', scale: TypeScale.displayM),
        ),
        const SizedBox(height: AppSpace.s5),
        AsyncBody(
          value: ref.watch(_stageProvider),
          onRetry: () => ref.invalidate(_stageProvider),
          data: (stage) => _AboutBody(copy: scopeCopyOf(stage)),
        ),
      ],
    ),
  );
}

class _AboutBody extends StatelessWidget {
  const _AboutBody({required this.copy});
  final ScopeCopy copy;

  Widget _goals() => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EyebrowText('依目標來看'),
        const SizedBox(height: AppSpace.s3),
        RuledList(
          children: [
            for (final goal in copy.goals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
                child: _GoalRow(goal: goal),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _references(AppTokens t) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EyebrowText('參考基準'),
        const SizedBox(height: AppSpace.s3),
        for (final line in copy.references) ...[
          AppText(line, scale: TypeScale.caption, color: t.ink.secondary),
          const SizedBox(height: AppSpace.s2),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final notCovered = copy.notCovered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(copy.opening, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s5),
        SideRuleNote(title: '學完能做到', child: AppText(copy.canDo)),
        const SizedBox(height: AppSpace.s5),
        SideRuleNote(
          title: '做不到',
          tone: SideRuleTone.shu,
          child: AppText(copy.cannotDo),
        ),
        if (copy.goals.isNotEmpty) _goals(),
        if (copy.references.isNotEmpty) _references(t),
        if (notCovered != null) ...[
          const SizedBox(height: AppSpace.s5),
          AppText(notCovered, scale: TypeScale.caption),
        ],
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});
  final ScopeGoal goal;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(goal.goal, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s1),
        AppText(goal.reach),
        const SizedBox(height: AppSpace.s2),
        AppText(
          '做不到：${goal.limit}',
          scale: TypeScale.caption,
          color: t.ink.secondary,
        ),
      ],
    );
  }
}

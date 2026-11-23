import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/local_log.dart';
import '../../core/backend/providers.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/side_rule_note.dart';
import 'expectation_copy.dart';

final _contentStageProvider = FutureProvider.autoDispose<ContentStage>(
  (ref) async =>
      (await ref.watch(courseRepositoryProvider).overview()).contentStage,
);

/// O6（§3.1）：第一個 `NewContent` 完成後才顯示，看完刪除旗標。
class ExpectationView extends ConsumerStatefulWidget {
  const ExpectationView({super.key});

  @override
  ConsumerState<ExpectationView> createState() => _ExpectationViewState();
}

class _ExpectationViewState extends ConsumerState<ExpectationView> {
  bool _dismissing = false;

  /// 連點會 pop 兩次，把 T2 一起關掉。
  Future<void> _dismiss() async {
    if (_dismissing) return;
    setState(() => _dismissing = true);
    try {
      await ref.read(firstRunMarkerProvider).delete();
    } on Exception catch (error, stack) {
      logLocal(error, stack);
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.today);
    }
  }

  @override
  Widget build(BuildContext context) => PaperScaffold(
    body: AsyncBody(
      value: ref.watch(_contentStageProvider),
      onRetry: () => ref.invalidate(_contentStageProvider),
      data: (stage) => _content(expectationCopy(stage)),
    ),
  );

  Widget _content(ExpectationCopy copy) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppText('先說清楚能到哪裡', scale: TypeScale.displayM),
      const SizedBox(height: AppSpace.s4),
      AppText(copy.intro),
      const SizedBox(height: AppSpace.s5),
      SideRuleNote(title: '能做到', child: AppText(copy.can)),
      const SizedBox(height: AppSpace.s4),
      SideRuleNote(
        title: '做不到',
        tone: SideRuleTone.shu,
        child: AppText(copy.cannot),
      ),
      const SizedBox(height: AppSpace.s6),
      InkButton(
        label: '知道了，繼續',
        autofocus: true,
        onPressed: _dismissing ? null : () => unawaited(_dismiss()),
      ),
      const SizedBox(height: AppSpace.s2),
      GhostButton(
        label: '關於程度',
        onPressed: _dismissing
            ? null
            : () => unawaited(context.push(AppRoutes.planAbout)),
      ),
    ],
  );
}

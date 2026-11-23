import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/failures.dart';
import '../../core/backend/providers.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/paper_scaffold.dart';
import 'plan_providers.dart';
import 'view/plan_overview.dart';

/// P1 計畫總覽（§3.8）。
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  bool _visible = true;

  /// 殼層分頁與推入的學習頁都會關掉下層的 TickerMode，所以它轉回 true
  /// 就代表使用者剛回到這頁，學習進度可能變了。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    final cameBack = visible && !_visible;
    _visible = visible;
    if (cameBack) unawaited(Future.microtask(_refresh));
  }

  void _refresh() {
    if (mounted) ref.invalidate(planPageProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(resumeTickProvider, (_, _) => _refresh())
      ..listen(planPageProvider, (_, next) {
        if (next.error is NoPlanFailure) {
          ref.read(onboardingDoneProvider).value = false;
        }
      });
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const AppText('計畫', scale: TypeScale.displayM),
          ),
          const SizedBox(height: AppSpace.s5),
          AsyncBody(
            value: ref.watch(planPageProvider),
            onRetry: () => ref.invalidate(planPageProvider),
            data: (data) => PlanOverview(data: data),
          ),
        ],
      ),
    );
  }
}

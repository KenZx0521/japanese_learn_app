import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';
import '../../../core/backend/today_view_provider.dart';
import '../../../core/tts/audio_available.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/async_body.dart';
import '../../../design/widgets/back_line.dart';
import '../../../design/widgets/esc_to_leave.dart';
import '../../../design/widgets/paper_scaffold.dart';
import '../../checkpoint/checkpoint_flow.dart';

final _checkpointTitleProvider = FutureProvider.autoDispose
    .family<String, String>((ref, id) async {
      final plan = await ref.watch(planRepositoryProvider).view();
      for (final MilestoneDto milestone in plan.milestones) {
        if (milestone.id == id) return milestone.titleZh;
      }
      return '里程碑檢定';
    });

/// 從 P1 手動開始的 D3（§3.6）；T2 內的檢定用同一個 `CheckpointFlow`。
class CheckpointScreen extends ConsumerStatefulWidget {
  const CheckpointScreen({required this.milestoneId, super.key});

  final String milestoneId;

  @override
  ConsumerState<CheckpointScreen> createState() => _CheckpointScreenState();
}

class _CheckpointScreenState extends ConsumerState<CheckpointScreen> {
  /// 第一次拿到日期就定下來：回前景會 reload 今日資料，子樹不能跟著卸載。
  int? _seed;

  void _leave() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.plan);

  AsyncValue<int> get _seedValue {
    final known = _seed;
    if (known != null) return AsyncData(known);
    final value = ref
        .watch(todayViewProvider)
        .whenData((view) => sessionSeed(view.logicalDate));
    _seed = value.value;
    return value;
  }

  Widget _flow(int seed) => CheckpointFlow(
    milestoneId: widget.milestoneId,
    title:
        ref.watch(_checkpointTitleProvider(widget.milestoneId)).value ??
        '里程碑檢定',
    seed: seed,
    audio: ref.watch(audioAvailableProvider),
    onFinished: (_) => _leave(),
  );

  @override
  Widget build(BuildContext context) => EscToLeave(
    onEscape: _leave,
    child: PaperScaffold(
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackLine(onBack: _leave, label: '離開'),
          const SizedBox(height: AppSpace.s2),
          Expanded(
            child: AsyncBody(
              value: _seedValue,
              onRetry: () => ref.invalidate(todayViewProvider),
              data: _flow,
            ),
          ),
        ],
      ),
    ),
  );
}

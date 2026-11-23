import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/async_body.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../plan_providers.dart';
import '../scope_copy.dart';

/// `plan_preview` 的結果：主線完成日，標明粗估。
class PlanPreviewBlock extends ConsumerWidget {
  const PlanPreviewBlock({
    required this.input,
    required this.current,
    required this.stage,
    required this.onUseSuggested,
    super.key,
  });

  final PlanInputDto input;
  final PlanViewDto current;
  final ContentStage stage;
  final ValueChanged<int> onUseSuggested;

  /// 換值時內容會短暫清空，先留高度，面板才不會跳動。
  static const _reservedHeight = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = planPreviewProvider(input);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _reservedHeight),
      child: AsyncBody(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (preview) => _PreviewBody(
          preview: preview,
          current: current,
          stage: stage,
          onUseSuggested: onUseSuggested,
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.preview,
    required this.current,
    required this.stage,
    required this.onUseSuggested,
  });

  final PlanViewDto preview;
  final PlanViewDto current;
  final ContentStage stage;
  final ValueChanged<int> onUseSuggested;

  String? get _deltaLine {
    final before = current.mainForecastEnd;
    final after = preview.mainForecastEnd;
    if (before == null || after == null) return null;
    final delta = daysBetween(before, after);
    if (delta == 0) return '完成日和現在一樣';
    return delta < 0 ? '比現在的安排早 ${-delta} 天' : '比現在的安排晚 $delta 天';
  }

  @override
  Widget build(BuildContext context) {
    final mainEnd = preview.mainForecastEnd;
    final delta = _deltaLine;
    final suggested = preview.suggestedMinutes;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mainEnd != null) AppText(forecastLine(stage, mainEnd)),
          if (delta != null)
            AppText(
              delta,
              scale: TypeScale.caption,
              color: AppTokens.of(context).ink.secondary,
            ),
          if (preview.status == PlanStatus.onTrack)
            const AppText('照這個安排趕得上目標日期（粗估）'),
          if (preview.status == PlanStatus.behind) ...[
            const AppText('照這個安排趕不上目標日期（粗估）'),
            if (suggested != null) ...[
              const SizedBox(height: AppSpace.s2),
              GhostButton(
                label: '改成每天 $suggested 分鐘',
                onPressed: () => onUseSuggested(suggested),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

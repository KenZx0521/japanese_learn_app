import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../today/today_copy.dart';

const _totalSteps = 4;

/// O1、O3–O5 共用版面：左上步驟格、靠左大標、底部固定主要動作（§4.1）。
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    required this.step,
    required this.title,
    required this.child,
    this.bottom,
    this.titleScale = TypeScale.displayM,
    super.key,
  });

  /// 1 到 4。
  final int step;
  final String title;
  final TypeScale titleScale;
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => PaperScaffold(
    bottom: bottom,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTicks(step: step),
        const SizedBox(height: AppSpace.s5),
        AppText(title, scale: titleScale),
        const SizedBox(height: AppSpace.s4),
        child,
      ],
    ),
  );
}

class _StepTicks extends StatelessWidget {
  const _StepTicks({required this.step});

  final int step;

  static const _tickSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // 最低高度對齊「上一步」的 48，O1 沒有上一步時標題才不會跳動
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PaperLayout.minTarget),
      child: Row(
        children: [
          Semantics(
            label: '第 $step 步，共 $_totalSteps 步',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 1; i <= _totalSteps; i++)
                    Container(
                      width: _tickSize,
                      height: _tickSize,
                      margin: const EdgeInsets.only(right: AppSpace.s1),
                      decoration: BoxDecoration(
                        color: i <= step ? t.ink.primary : Colors.transparent,
                        border: Border.all(color: t.line.strong),
                      ),
                    ),
                  const SizedBox(width: AppSpace.s2),
                  AppText(
                    '${ordinalLabel(step - 1)}／${ordinalLabel(_totalSteps - 1)}',
                    scale: TypeScale.caption,
                    color: t.ink.secondary,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (context.canPop())
            BackLine(onBack: () => context.pop(), label: '上一步'),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../design/tokens.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../checkpoint/checkpoint_flow.dart';
import 'onboarding_draft.dart';

const _placementMilestone = 'ms.hira';
const _placementSeed = 0;

/// O3「平假名都會」：用 D3 元件考 `ms.hira`（§3.1）。
/// 尚未確認語音，`audio_available` 固定 false，也不寫今日快照。
class PlacementScreen extends ConsumerWidget {
  const PlacementScreen({super.key});

  void _toNextStep(BuildContext context, WidgetRef ref, bool passed) {
    ref.read(onboardingDraftProvider.notifier).setPlacementPassed(passed);
    unawaited(context.push(AppRoutes.welcomeStep('o4')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => PaperScaffold(
    scrollable: false,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BackLine(onBack: () => context.pop(), label: '上一步'),
        const SizedBox(height: AppSpace.s2),
        Expanded(
          child: CheckpointFlow(
            milestoneId: _placementMilestone,
            title: '平假名畢業考',
            seed: _placementSeed,
            audio: false,
            showWeak: false,
            passedNote: '平假名都會，就從片假名開始。',
            failedNote: '沒關係，從第一課開始，不扣任何進度。也可以回上一步改選「會一點假名」。',
            continueLabel: '下一步',
            secondaryLabel: '回上一步',
            onSecondary: () => context.pop(),
            onFinished: (CheckpointResultDto result) =>
                _toNextStep(context, ref, result.passed),
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/failures.dart';
import '../../core/backend/local_log.dart';
import '../../core/backend/providers.dart';
import '../../core/settings/settings_controller.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/ink_buttons.dart';

const _romajiOffFromLesson = 9;

final _romajiPromptDueProvider = FutureProvider.autoDispose<bool>((ref) async {
  final plan = await ref.watch(planRepositoryProvider).view();
  if (_lessonNumber(plan.currentLessonId) < _romajiOffFromLesson) return false;
  return plan.milestones.any((m) => m.id == 'ms.kata' && !m.passed);
});

int _lessonNumber(String? lessonId) {
  final match = RegExp(r'^le\.l(\d+)$').firstMatch(lessonId ?? '');
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// 游標到 L09 起的確認（§3.7）。「先留著」只在本次執行內記住，下次啟動再問。
class RomajiConfirmLine extends ConsumerStatefulWidget {
  const RomajiConfirmLine({super.key});

  @override
  ConsumerState<RomajiConfirmLine> createState() => _RomajiConfirmLineState();
}

class _RomajiConfirmLineState extends ConsumerState<RomajiConfirmLine> {
  bool _kept = false;
  String? _writeError;

  Future<void> _confirm() async {
    try {
      await ref
          .read(settingsProvider.notifier)
          .patch(settingsPatch(romajiOffConfirmed: true));
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) setState(() => _writeError = failure.userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = ref.watch(
      settingsProvider.select((s) => s.value?.romajiOffConfirmed ?? true),
    );
    final due = ref.watch(_romajiPromptDueProvider).value ?? false;
    if (confirmed || !due || _kept) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('片假名還沒考過。要把羅馬字收起來嗎？'),
          const SizedBox(height: AppSpace.s2),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              GhostButton(label: '收起來', onPressed: _confirm),
              GhostButton(
                label: '先留著',
                onPressed: () => setState(() => _kept = true),
              ),
            ],
          ),
          if (_writeError != null)
            AppText(
              _writeError!,
              scale: TypeScale.caption,
              color: AppTokens.of(context).shu,
            ),
        ],
      ),
    );
  }
}

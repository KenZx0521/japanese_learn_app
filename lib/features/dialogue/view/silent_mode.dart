import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/failures.dart';
import '../../../core/backend/local_log.dart';
import '../../../core/settings/settings_controller.dart';

/// `VoiceFailedPanel` 的「改用無聲模式」：只寫 `silent_mode`，
/// 階段由 `audioAvailableProvider` 的變化重新計算（§6.6）。
Future<void> useSilentMode(WidgetRef ref) async {
  try {
    await ref
        .read(settingsProvider.notifier)
        .patch(settingsPatch(silentMode: true));
  } on AppFailure catch (failure, stack) {
    logLocal(failure, stack);
  }
}

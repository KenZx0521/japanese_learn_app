import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/failures.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/local_log.dart';
import '../../core/settings/settings_controller.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import 'settings_labels.dart';
import 'widgets/setting_rows.dart';

final settingsWriteErrorProvider =
    NotifierProvider.autoDispose<SettingsWriteError, String?>(
      SettingsWriteError.new,
    );

class SettingsWriteError extends Notifier<String?> {
  @override
  String? build() => null;

  void report(String message) {
    if (ref.mounted) state = message;
  }

  void clear() {
    if (ref.mounted) state = null;
  }
}

/// 寫入失敗時設定維持舊值（`SettingsController.patch`），訊息顯示在頁面底部。
Future<void> saveSetting(WidgetRef ref, SettingsPatchDto patch) async {
  final errors = ref.read(settingsWriteErrorProvider.notifier);
  try {
    await ref.read(settingsProvider.notifier).patch(patch);
    errors.clear();
  } on AppFailure catch (failure, stack) {
    logLocal(failure, stack);
    errors.report(failure.userMessage);
  }
}

/// 開選擇面板，選了才寫入。[patch] 把選到的值轉成 `SettingsPatchDto`。
Future<void> pickSetting<T>(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required List<SettingOption<T>> options,
  required T selected,
  required SettingsPatchDto Function(T value) patch,
}) async {
  final choice = await showSettingChoices<T>(
    context,
    title: title,
    options: options,
    selected: selected,
  );
  if (choice == null || !context.mounted) return;
  await saveSetting(ref, patch(choice.value));
}

/// 固定在頁面底部，捲到哪裡都看得到。
class SettingsWriteErrorLine extends StatelessWidget {
  const SettingsWriteErrorLine({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: AppText(message, color: AppTokens.of(context).shu),
  );
}

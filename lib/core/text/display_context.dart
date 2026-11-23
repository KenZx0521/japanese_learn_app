import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/frb/dto.dart';
import '../backend/providers.dart';
import '../settings/settings_controller.dart';

/// V4、D2、D3、聽力任務的 `DisplayContext`（§3.7）。
DisplayContext questionContext(PeekDto? peeked, String fallbackLessonId) =>
    DisplayContext(lessonId: peeked?.lessonId ?? fallbackLessonId);

/// Rust 依內容所屬的課算出顯示規則，Dart 只套用（§3.7）。
final displayPolicyProvider = FutureProvider.autoDispose
    .family<DisplayPolicyDto, DisplayContext>((ref, context) {
      // Rust 依這些設定算規則，分頁掛著時也要跟著更新
      ref.watch(settingsProvider.select(_policyInputs));
      return ref.watch(settingsRepositoryProvider).displayPolicy(context);
    });

(RomajiMode?, FuriganaMode?, bool) _policyInputs(AsyncValue<SettingsDto> s) {
  final value = s.value;
  return (
    value?.romajiOverride,
    value?.furiganaOverride,
    value?.romajiOffConfirmed ?? false,
  );
}

/// `peek` 以 content id 快取（§3.7）。
final peekProvider = FutureProvider.family<PeekDto, String>(
  (ref, refId) => ref.watch(contentPeekRepositoryProvider).peek(refId),
);

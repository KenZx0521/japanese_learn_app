import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/failures.dart';
import '../../core/backend/local_log.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/tts/tts_engine.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'pressable.dart';

/// 語速切換（§6.5），偏好存入 `tts_rate`（0.7、1.0）。
class SpeedToggle extends ConsumerWidget {
  const SpeedToggle({super.key});

  static String labelOf(TtsSpeed speed) => switch (speed) {
    TtsSpeed.slow => '0.7 倍',
    TtsSpeed.normal => '1 倍',
  };

  TtsSpeed _next(TtsSpeed current) => switch (current) {
    TtsSpeed.normal => TtsSpeed.slow,
    TtsSpeed.slow => TtsSpeed.normal,
  };

  Future<void> _cycle(WidgetRef ref, TtsSpeed current) async {
    final rate = speedRates[_next(current)] ?? 1.0;
    try {
      await ref
          .read(settingsProvider.notifier)
          .patch(settingsPatch(ttsRate: rate));
    } on AppFailure catch (failure, stack) {
      // 偏好寫入失敗不打斷學習，下次切換再試
      logLocal(failure, stack);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final rate = ref.watch(
      settingsProvider.select((s) => s.value?.ttsRate ?? 1.0),
    );
    final speed = speedFromRate(rate);
    final label = labelOf(speed);
    // 放在撐滿的欄裡也只佔文字寬，不被拉成一整條線
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Pressable(
        onTap: () => unawaited(_cycle(ref, speed)),
        semanticLabel: '語速 $label，點一下切換',
        builder: (context, state) => Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
          color: state.hovered ? t.paper.raised : Colors.transparent,
          child: Center(
            widthFactor: 1,
            // 底線貼著文字；觸控區維持 Pressable 的 48
            child: Container(
              padding: const EdgeInsets.only(bottom: 1),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: state.pressed ? t.ink.primary : t.line.strong,
                  ),
                ),
              ),
              child: AppText(
                label,
                scale: TypeScale.caption,
                color: t.ink.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

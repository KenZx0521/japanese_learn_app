import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'app_text.dart';
import 'ink_buttons.dart';

/// 中途播放失敗且本題需要播放才能作答（§6.6）。不提供略過，也不記為答錯。
class VoiceFailedPanel extends StatelessWidget {
  const VoiceFailedPanel({
    required this.onRetry,
    required this.onSilent,
    super.key,
  });

  final VoidCallback onRetry;
  final VoidCallback onSilent;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.s4),
      color: t.paper.sunken,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(liveRegion: true, child: const AppText('這題要聽聲音，現在播不出來。')),
          const SizedBox(height: AppSpace.s3),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              InkButton(label: '重試', onPressed: onRetry),
              GhostButton(label: '改用無聲模式', onPressed: onSilent),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/sound_pair_view.dart';
import '../../design/widgets/speed_toggle.dart';
import 'listen_providers.dart';

/// S2 語音示範（§3.7）：依 `SoundGroupKindDto` 分區的 A/B 對照。
/// 語音不可用時由 `SpeakButton` 改為斜線喇叭，點擊開說明。
class SoundsScreen extends ConsumerWidget {
  const SoundsScreen({super.key});

  static const _kindOrder = [
    SoundGroupKindDto.voicing,
    SoundGroupKindDto.length,
    SoundGroupKindDto.sokuon,
    SoundGroupKindDto.yoon,
    SoundGroupKindDto.accent,
  ];

  static String _kindLabel(SoundGroupKindDto kind) => switch (kind) {
    SoundGroupKindDto.voicing => '清濁',
    SoundGroupKindDto.length => '長短音',
    SoundGroupKindDto.sokuon => '促音',
    SoundGroupKindDto.yoon => '拗音',
    SoundGroupKindDto.accent => '音調',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageBackLink(fallback: AppRoutes.listen),
          const SizedBox(height: AppSpace.s2),
          const AppText('語音示範', scale: TypeScale.displayM),
          const SizedBox(height: AppSpace.s1),
          AppText(
            '語音由裝置合成，音調可能不完全正確',
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
          const SizedBox(height: AppSpace.s2),
          const Align(alignment: Alignment.centerLeft, child: SpeedToggle()),
          const SizedBox(height: AppSpace.s4),
          AsyncBody<List<SoundGroupDto>>(
            value: ref.watch(soundGroupsProvider),
            onRetry: () => ref.invalidate(soundGroupsProvider),
            data: (groups) => _sections(groups),
          ),
        ],
      ),
    );
  }

  Widget _sections(List<SoundGroupDto> groups) {
    if (groups.isEmpty) return const AppText('這一版還沒有語音示範。');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in _kindOrder)
          if (groups.any((group) => group.kind == kind)) ...[
            EyebrowText(_kindLabel(kind)),
            const SizedBox(height: AppSpace.s2),
            for (final group in groups)
              if (group.kind == kind) _GroupView(group: group),
          ],
      ],
    );
  }
}

class _GroupView extends StatelessWidget {
  const _GroupView({required this.group});

  final SoundGroupDto group;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MixedText(group.titleZh, scale: TypeScale.title),
          const SizedBox(height: AppSpace.s1),
          MixedText(group.bodyZh, color: t.ink.secondary),
          if (group.kind == SoundGroupKindDto.accent) ...[
            const SizedBox(height: AppSpace.s1),
            AppText('由裝置合成，僅供參考', scale: TypeScale.caption, color: t.kincha),
          ],
          const SizedBox(height: AppSpace.s3),
          for (final (index, pair) in group.pairs.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s3),
              child: SoundPairView(pair: pair, pairId: '${group.id}.$index'),
            ),
          if (group.testDrillIds.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: GhostButton(
                label: '測試一下',
                onPressed: () => unawaited(
                  context.push(
                    AppRoutes.sessionDrill(drills: group.testDrillIds),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

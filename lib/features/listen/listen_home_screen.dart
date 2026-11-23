import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/today_view_provider.dart';
import '../../core/text/ja_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/refresh_on_return.dart';
import '../../design/widgets/ruled_list.dart';
import '../../design/widgets/vertical_title.dart';
import '../../design/widgets/voice_banner.dart';

/// S1 聽說首頁：入口與語音狀態（§2.3）。入口先畫，今日任務後補。
class ListenHomeScreen extends ConsumerWidget {
  const ListenHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshOnReturn(
    onReturn: () => ref.invalidate(todayViewProvider),
    child: PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const VoiceBanner(),
          const SizedBox(height: AppSpace.s3),
          const _Heading(),
          const SizedBox(height: AppSpace.s5),
          const _TodayListenEntry(),
          const EyebrowText('練習'),
          const SizedBox(height: AppSpace.s2),
          RuledList(
            children: [
              _Entry(
                glyph: '音',
                title: '語音示範',
                subtitle: '清濁、長短音、促音、拗音、音調',
                onTap: () => unawaited(context.push(AppRoutes.sounds)),
              ),
              _Entry(
                glyph: '話',
                title: '對話',
                subtitle: '先聽、再看字、跟讀、角色扮演',
                onTap: () => unawaited(context.push(AppRoutes.dialogues)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('聽說', scale: TypeScale.displayM),
            const SizedBox(height: AppSpace.s1),
            AppText('耳朵先熟，再跟著開口。', color: AppTokens.of(context).ink.secondary),
          ],
        ),
      ),
      const VerticalTitle('聴'),
    ],
  );
}

class _TodayListenEntry extends ConsumerWidget {
  const _TodayListenEntry();

  static TaskDto_Listen? _pendingListen(TodayViewDto today) {
    for (final task in today.tasks) {
      if (task case final TaskDto_Listen listen when !listen.done) {
        return listen;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(todayViewProvider)
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => _SoftError(
          message: '今天的聽力暫時讀不到',
          onRetry: () => ref.invalidate(todayViewProvider),
        ),
        data: (today) {
          final task = _pendingListen(today);
          if (task == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s5),
            child: RuledList(
              children: [
                _Entry(
                  glyph: '今',
                  title: '今天的聽力',
                  subtitle: '${task.sentences} 句，含跟讀',
                  onTap: () => unawaited(
                    context.push(AppRoutes.sessionToday(start: task.key)),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String glyph, title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RuledTile.text(
    title,
    subtitle: subtitle,
    leading: _GlyphCell(glyph: glyph),
    onTap: onTap,
  );
}

/// 稿紙格裡的一個字；裝飾用，不進語意。
class _GlyphCell extends StatelessWidget {
  const _GlyphCell({required this.glyph});
  final String glyph;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: t.line.strong)),
        child: JaText(
          glyph,
          color: t.ink.secondary,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

/// S1 的輔助資料讀不到時不佔版面，只留一行與重試。
class _SoftError extends StatelessWidget {
  const _SoftError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: AppText(
              message,
              scale: TypeScale.caption,
              color: t.ink.secondary,
            ),
          ),
        ),
        Pressable(
          onTap: onRetry,
          builder: (context, state) => Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
            child: AppText('重試', scale: TypeScale.label, color: t.ai),
          ),
        ),
      ],
    );
  }
}

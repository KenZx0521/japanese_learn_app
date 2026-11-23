import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/display_context.dart';
import '../../core/text/ja_text.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/ruled_list.dart';
import '../../design/widgets/stamp_overlay.dart';

/// D3 結果（§3.6）：通過才蓋章；未通過不鎖任何內容，只建議複習。
class CheckpointResultView extends StatelessWidget {
  const CheckpointResultView({
    required this.result,
    required this.passedNote,
    required this.failedNote,
    required this.showWeak,
    required this.continueLabel,
    required this.onContinue,
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  });

  final CheckpointResultDto result;
  final String passedNote, failedNote, continueLabel;
  final bool showWeak;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Stack(
    // expand：蓋章範圍是整頁，不是內容高度，否則印章會壓在分數與按鈕上
    fit: StackFit.expand,
    children: [
      SingleChildScrollView(child: _content(context)),
      Positioned.fill(
        child: StampOverlay(play: result.passed, text: '合格'),
      ),
    ],
  );

  Widget _content(BuildContext context) {
    final t = AppTokens.of(context);
    final secondary = onSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: AppText('${result.scorePercent}%', scale: TypeScale.displayL),
        ),
        AppText(
          '答對 ${result.correct} 題，共 ${result.total} 題',
          color: t.ink.secondary,
        ),
        const SizedBox(height: AppSpace.s3),
        AppText(result.passed ? passedNote : failedNote),
        if (showWeak && result.weakIds.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s5),
          const EyebrowText('可以多看的地方'),
          const SizedBox(height: AppSpace.s2),
          RuledList(
            children: [for (final id in result.weakIds) _WeakRow(refId: id)],
          ),
        ],
        const SizedBox(height: AppSpace.s5),
        InkButton(label: continueLabel, onPressed: onContinue, autofocus: true),
        if (secondaryLabel != null && secondary != null) ...[
          const SizedBox(height: AppSpace.s2),
          GhostButton(label: secondaryLabel!, onPressed: secondary),
        ],
      ],
    );
  }
}

/// 弱項列：`gr.*`、`vo.*` 另有「練這題」（§3.6）。
class _WeakRow extends ConsumerWidget {
  const _WeakRow({required this.refId});

  final String refId;

  bool get _isJapanese => refId.startsWith('vo.') || refId.startsWith('ka.');

  bool get _canDrill => refId.startsWith('gr.') || refId.startsWith('vo.');

  String get _detailRoute {
    if (refId.startsWith('gr.')) return AppRoutes.grammarPoint(refId);
    if (refId.startsWith('vo.')) return AppRoutes.vocabWord(refId);
    return AppRoutes.kana;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peek = ref.watch(peekProvider(refId)).value;
    final title = peek?.title ?? refId;
    return RuledTile(
      title: _isJapanese ? JaText(title) : MixedText(title),
      subtitle: peek == null ? null : MixedText(peek.summaryZh),
      onTap: () => unawaited(context.push(_detailRoute)),
      trailing: _canDrill
          ? GhostButton(
              label: '練這題',
              onPressed: () => unawaited(
                context.push(AppRoutes.sessionDrill(target: refId)),
              ),
            )
          : null,
    );
  }
}

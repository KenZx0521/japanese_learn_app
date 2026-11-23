import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/text/display_context.dart';
import '../../../core/text/ja_text.dart';
import '../../../core/text/mixed_text.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/side_rule_note.dart';
import '../../../design/widgets/skeleton_lines.dart';

/// 答後語法重點（§3.6）：`focus_ids` 逐一 `peek`，在回饋條內一次展開。
class FocusPoints extends StatelessWidget {
  const FocusPoints({required this.ids, super.key});
  final List<String> ids;

  @override
  Widget build(BuildContext context) => SideRuleNote(
    title: '語法重點',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, id) in ids.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpace.s2),
          _FocusPoint(refId: id),
        ],
      ],
    ),
  );
}

class _FocusPoint extends ConsumerWidget {
  const _FocusPoint({required this.refId});
  final String refId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(peekProvider(refId))
      .when(
        data: (peek) => _PeekRow(peek: peek),
        loading: () => const DelayedReveal(child: SkeletonLines(lines: 1)),
        error: (_, _) =>
            _PeekFailed(onRetry: () => ref.invalidate(peekProvider(refId))),
      );
}

class _PeekRow extends StatelessWidget {
  const _PeekRow({required this.peek});
  final PeekDto peek;

  /// §3.7：`vo.`、`ka.` 開頭用 `JaText`，其餘用 `MixedText`。
  bool get _titleIsJapanese =>
      peek.refId.startsWith('vo.') || peek.refId.startsWith('ka.');

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_titleIsJapanese)
        JaText(peek.title)
      else
        MixedText(peek.title, scale: TypeScale.label),
      MixedText(
        peek.summaryZh,
        scale: TypeScale.caption,
        color: AppTokens.of(context).ink.secondary,
      ),
    ],
  );
}

class _PeekFailed extends StatelessWidget {
  const _PeekFailed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        '這個重點暫時讀不出來。',
        scale: TypeScale.caption,
        color: AppTokens.of(context).ink.secondary,
      ),
      GhostButton(label: '重試', onPressed: onRetry),
    ],
  );
}

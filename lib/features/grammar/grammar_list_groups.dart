import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/course_groups.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/ruled_list.dart';

/// 依階段分組的文法列。區塊之間拉開，同階段以細線分隔（§4.1）。
class GrammarListGroups extends StatelessWidget {
  const GrammarListGroups({required this.groups, super.key});

  final List<StageGroup<GrammarSummaryDto>> groups;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, group) in groups.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpace.s6),
          MixedText(
            group.stage.titleZh,
            scale: TypeScale.label,
            color: t.ink.secondary,
          ),
          const SizedBox(height: AppSpace.s2),
          RuledList(
            children: [
              for (final item in group.items) _GrammarTile(item: item),
            ],
          ),
        ],
      ],
    );
  }
}

class _GrammarTile extends StatelessWidget {
  const _GrammarTile({required this.item});
  final GrammarSummaryDto item;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final faded = item.status == GrammarStatus.notStarted;
    return RuledTile(
      title: MixedText(item.titleZh, color: faded ? t.ink.tertiary : null),
      subtitle: MixedText(
        item.meaningZh,
        scale: TypeScale.caption,
        color: faded ? t.ink.tertiary : t.ink.secondary,
      ),
      trailing: _StatusLabel(item: item),
      onTap: () => unawaited(context.push(AppRoutes.grammarPoint(item.id))),
    );
  }
}

/// `GrammarStatus` 由 Rust 推導（§3.5）。狀態永遠有文字，色彩只是輔助。
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.item});
  final GrammarSummaryDto item;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final (text, color) = switch (item.status) {
      GrammarStatus.notStarted => (
        lessonNumberLabel(item.lessonId),
        t.ink.tertiary,
      ),
      GrammarStatus.introduced => ('讀過', t.ink.secondary),
      GrammarStatus.practiced => ('練過', t.moegi),
    };
    return AppText(text, scale: TypeScale.label, color: color);
  }
}

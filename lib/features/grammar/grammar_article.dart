import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/course_groups.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/pattern_blocks.dart';
import '../../design/widgets/ruled_list.dart';
import '../../design/widgets/side_rule_note.dart';
import 'grammar_examples.dart';
import 'grammar_quiz_section.dart';
import 'grammar_terms.dart';

/// 文章本體，順序固定，對應課綱 §5.4。
class GrammarArticle extends StatelessWidget {
  const GrammarArticle({required this.detail, super.key});

  final GrammarDetailDto detail;

  static const _blockGap = SizedBox(height: AppSpace.s7);
  static const _groupGap = SizedBox(height: AppSpace.s5);

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    final trap = detail.trapZh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Lead(detail: detail),
        _groupGap,
        SideRuleNote(title: '和中文比一比', child: MixedText(detail.compareZh)),
        if (trap != null) ...[
          _groupGap,
          SideRuleNote(
            title: '容易錯',
            tone: SideRuleTone.shu,
            child: MixedText(trap),
          ),
        ],
        if (detail.formation.isNotEmpty) ...[
          _blockGap,
          _FormationTable(rows: detail.formation),
        ],
        if (detail.examples.isNotEmpty) ...[
          _blockGap,
          GrammarExamples(
            examples: detail.examples,
            lessonId: summary.lessonId,
          ),
        ],
        if (detail.contrast.isNotEmpty) ...[
          _blockGap,
          _ContrastLinks(refs: detail.contrast),
        ],
        if (detail.terms.isNotEmpty) ...[
          _blockGap,
          GrammarTerms(terms: detail.terms),
        ],
        _blockGap,
        GrammarQuizSection(grammarId: summary.id, lessonId: summary.lessonId),
      ],
    );
  }
}

class _Lead extends StatelessWidget {
  const _Lead({required this.detail});
  final GrammarDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final summary = detail.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EyebrowText(lessonNumberLabel(summary.lessonId)),
        const SizedBox(height: AppSpace.s2),
        MixedText(summary.titleZh, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s4),
        PatternBlocks(summary.pattern),
        const SizedBox(height: AppSpace.s5),
        MixedText(
          summary.meaningZh,
          scale: TypeScale.title,
          color: t.ink.primary,
        ),
        const SizedBox(height: AppSpace.s3),
        MixedText(detail.explainZh),
      ],
    );
  }
}

class _FormationTable extends StatelessWidget {
  const _FormationTable({required this.rows});
  final List<FormationRowDto> rows;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EyebrowText('接續'),
        const SizedBox(height: AppSpace.s2),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.line.grid)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final row in rows) _FormationRow(row: row)],
          ),
        ),
      ],
    );
  }
}

class _FormationRow extends StatelessWidget {
  const _FormationRow({required this.row});
  final FormationRowDto row;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line.grid)),
      ),
      child: Row(
        children: [
          Expanded(child: MixedText(row.from)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
            child: ExcludeSemantics(child: AppText('→', color: t.ink.tertiary)),
          ),
          Expanded(child: MixedText(row.to)),
        ],
      ),
    );
  }
}

class _ContrastLinks extends StatelessWidget {
  const _ContrastLinks({required this.refs});
  final List<GrammarRefDto> refs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const EyebrowText('相近的文法'),
      const SizedBox(height: AppSpace.s2),
      RuledList(
        children: [
          for (final item in refs)
            RuledTile(
              title: MixedText(item.titleZh),
              onTap: () =>
                  unawaited(context.push(AppRoutes.grammarPoint(item.id))),
            ),
        ],
      ),
    ],
  );
}

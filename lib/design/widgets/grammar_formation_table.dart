import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../tokens.dart';
import 'app_text.dart';

/// 首次學習與文法詳情共用完整接續表，保留日文混排與振假名。
class GrammarFormationTable extends StatelessWidget {
  const GrammarFormationTable({required this.rows, super.key});

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
    final arrow = ExcludeSemantics(child: AppText('→', color: t.ink.tertiary));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line.grid)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 窄版讓變化例使用整行，避免兩欄擠窄振假名與長日文。
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MixedText(row.from),
                const SizedBox(height: AppSpace.s2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    arrow,
                    const SizedBox(width: AppSpace.s3),
                    Expanded(child: MixedText(row.to)),
                  ],
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: MixedText(row.from)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
                child: arrow,
              ),
              Expanded(child: MixedText(row.to)),
            ],
          );
        },
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/genko_grid.dart';

/// 累積紀錄：沿用稿紙格，八個數字加一格留白。
class PlanStats extends StatelessWidget {
  const PlanStats({required this.stats, super.key});

  final StatsDto stats;

  static const _narrowColumns = 3;
  static const _wideColumns = 4;
  static const _wideMinWidth = 520.0;
  static const _maxCellHeight = 96.0;

  /// 窄版三欄補一格留白；寬版四欄兩列剛好排滿。
  List<Widget?> get _cells => [
    _StatCell('熟練假名', stats.kanaMastered),
    _StatCell('認識單字', stats.vocabIntroduced),
    _StatCell('認識文法', stats.grammarIntroduced),
    _StatCell('待學字卡', stats.cardsNew),
    _StatCell('學習中', stats.cardsLearning),
    _StatCell('複習中', stats.cardsReview),
    _StatCell('已熟字卡', stats.cardsMastered),
    _StatCell('累積複習', stats.totalReviews),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= _wideMinWidth;
      return GenkoGrid(
        columns: wide ? _wideColumns : _narrowColumns,
        maxCellHeight: wide ? _maxCellHeight : null,
        children: wide ? _cells : [..._cells, null],
      );
    },
  );
}

class _StatCell extends StatelessWidget {
  const _StatCell(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s1),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText('$value', scale: TypeScale.title),
                AppText(
                  label,
                  scale: TypeScale.caption,
                  color: AppTokens.of(context).ink.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

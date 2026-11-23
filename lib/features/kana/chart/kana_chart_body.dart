import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/text/mixed_text.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/genko_grid.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/kana_cell.dart';
import '../../../design/widgets/pressable.dart';
import '../../../design/widgets/ruled_list.dart';
import '../../../design/widgets/voice_banner.dart';
import '../../../design/widgets/back_line.dart';

const _legend = '淡色：尚未開始　深色：學習中　朱點：已熟練　小圈：答得快';

/// K1 的主欄：標題、文字切換、語音狀態、分區格子。
class KanaChartBody extends StatelessWidget {
  const KanaChartBody({
    required this.script,
    required this.groups,
    required this.selectedId,
    required this.progressFailed,
    required this.onScriptChanged,
    required this.onCellTap,
    required this.onRetry,
    super.key,
  });

  final KanaScript script;
  final List<KanaGroupDto> groups;
  final String? selectedId;
  final bool progressFailed;
  final ValueChanged<KanaScript> onScriptChanged;
  final ValueChanged<KanaCellDto> onCellTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageBackLink(fallback: AppRoutes.learn),
      const SizedBox(height: AppSpace.s2),
      const AppText('五十音表', scale: TypeScale.displayM),
      const SizedBox(height: AppSpace.s3),
      const VoiceBanner(),
      KanaScriptToggle(script: script, onChanged: onScriptChanged),
      const SizedBox(height: AppSpace.s3),
      if (progressFailed) ...[
        _ProgressWarning(onRetry: onRetry),
        const SizedBox(height: AppSpace.s3),
      ],
      _ChartGroups(
        groups: groups,
        selectedId: selectedId,
        onCellTap: onCellTap,
      ),
      AppText(
        _legend,
        scale: TypeScale.caption,
        color: AppTokens.of(context).ink.secondary,
      ),
      const SizedBox(height: AppSpace.s4),
      RuledList(
        children: [
          RuledTile.text(
            '語音示範',
            subtitle: '清濁、長短音、促音，聽聽看差在哪裡',
            onTap: () => context.go(AppRoutes.sounds),
          ),
        ],
      ),
    ],
  );
}

/// 內容寬夠時分成兩欄：清音放左、濁音與拗音放右，格子不會被拉到海報大小。
class _ChartGroups extends StatelessWidget {
  const _ChartGroups({
    required this.groups,
    required this.selectedId,
    required this.onCellTap,
  });

  final List<KanaGroupDto> groups;
  final String? selectedId;
  final ValueChanged<KanaCellDto> onCellTap;

  static const _twoColumnMinWidth = 560.0;

  /// 依列數把分區分成左右兩欄，兩欄的高度才接近。
  int _splitIndex() {
    final total = groups.fold<int>(0, (sum, g) => sum + g.rows.length);
    var rows = 0;
    for (final (index, group) in groups.indexed) {
      rows += group.rows.length;
      if (rows * 2 >= total) return (index + 1).clamp(1, groups.length - 1);
    }
    return groups.length - 1;
  }

  Widget _column(Iterable<KanaGroupDto> part) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final group in part) _group(group, maxCell: _maxWideCell)],
  );

  Widget _group(KanaGroupDto group, {double? maxCell}) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s6),
    child: _ChartGroup(
      group: group,
      selectedId: selectedId,
      maxCell: maxCell,
      onCellTap: onCellTap,
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (groups.length < 2 || constraints.maxWidth < _twoColumnMinWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final group in groups) _group(group)],
        );
      }
      final split = _splitIndex();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _column(groups.take(split))),
          const SizedBox(width: AppSpace.s5),
          Expanded(child: _column(groups.skip(split))),
        ],
      );
    },
  );
}

const _maxWideCell = 72.0;

class _ChartGroup extends StatelessWidget {
  const _ChartGroup({
    required this.group,
    required this.selectedId,
    required this.onCellTap,
    this.maxCell,
  });

  final KanaGroupDto group;
  final String? selectedId;
  final ValueChanged<KanaCellDto> onCellTap;
  final double? maxCell;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MixedText(group.titleZh, scale: TypeScale.title),
      const SizedBox(height: AppSpace.s3),
      GenkoGrid(
        columns: group.columns,
        maxCell: maxCell,
        children: [
          for (final row in group.rows)
            for (final cell in row.cells)
              if (cell == null)
                null
              else
                KanaCell(
                  kana: cell.ch,
                  romaji: cell.romaji,
                  status: cell.status,
                  fastBadge: cell.fastBadge,
                  selected: cell.id == selectedId,
                  onTap: () => onCellTap(cell),
                ),
        ],
      ),
    ],
  );
}

/// 平假名／片假名切換。選中項以朱色底線＋粗體表示，不只靠顏色。
class KanaScriptToggle extends StatelessWidget {
  const KanaScriptToggle({
    required this.script,
    required this.onChanged,
    super.key,
  });

  final KanaScript script;
  final ValueChanged<KanaScript> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _Segment(
        label: '平假名',
        selected: script == KanaScript.hiragana,
        onTap: () => onChanged(KanaScript.hiragana),
      ),
      const SizedBox(width: AppSpace.s4),
      _Segment(
        label: '片假名',
        selected: script == KanaScript.katakana,
        onTap: () => onChanged(KanaScript.katakana),
      ),
    ],
  );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      builder: (context, state) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
        decoration: BoxDecoration(
          color: state.hovered ? t.paper.raised : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: selected ? t.shu : t.line.grid,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: AppText(
          label,
          scale: TypeScale.label,
          color: selected ? t.ink.primary : t.ink.secondary,
        ),
      ),
    );
  }
}

class _ProgressWarning extends StatelessWidget {
  const _ProgressWarning({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.only(left: AppSpace.s3),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: t.kincha, width: 3)),
      ),
      child: Wrap(
        spacing: AppSpace.s3,
        runSpacing: AppSpace.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            liveRegion: true,
            child: AppText(
              '進度暫時讀不到',
              scale: TypeScale.caption,
              color: t.ink.secondary,
            ),
          ),
          GhostButton(label: '重試', onPressed: onRetry),
        ],
      ),
    );
  }
}

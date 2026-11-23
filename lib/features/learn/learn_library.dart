import 'dart:async';
import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/text/ja_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/genko_grid.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/ruled_list.dart';

@immutable
final class _Entry {
  const _Entry(this.glyph, this.label, this.subtitle, this.route);
  final String glyph, label, subtitle, route;
}

/// 各資料庫入口。窄版是一排稿紙格，放不下（格子窄、字級大）或在右欄時改成列表。
class LearnLibrary extends StatelessWidget {
  const LearnLibrary({
    required this.notesAvailable,
    this.vertical = false,
    super.key,
  });

  /// 內容就緒才露出筆記入口（O7）。
  final bool notesAvailable;
  final bool vertical;

  List<_Entry> get _entries => [
    const _Entry('あ', '假名表', '查五十音、聽發音、看進度', AppRoutes.kana),
    const _Entry('語', '單字', '依主題看，或用搜尋找', AppRoutes.vocab),
    _Entry('文', '文法', '讀文法點，做小測驗', AppRoutes.grammar()),
    const _Entry('練', '句型演練', '選一課來練', AppRoutes.drills),
    if (notesAvailable) _Entry('記', '筆記', '同形異義、字形對照、讀音規律', AppRoutes.notes()),
  ];

  void _open(BuildContext context, _Entry entry) =>
      unawaited(context.push(entry.route));

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const EyebrowText('資料庫'),
      const SizedBox(height: AppSpace.s2),
      if (vertical)
        _rows(context)
      else
        LayoutBuilder(
          builder: (context, constraints) =>
              _fitsCells(context, constraints.maxWidth)
              ? _cells(context)
              : _rows(context),
        ),
    ],
  );

  /// 寬螢幕時格寬跟著內容寬，但高度不用跟著變成大方格。
  static const _maxCellHeight = 84.0;

  bool _fitsCells(BuildContext context, double width) {
    final entries = _entries;
    final longest = entries.map((entry) => entry.label.length).reduce(math.max);
    final cell = PaperLayout.cell(width, columns: entries.length);
    final label = TypeScale.caption
        .scaler(context)
        .scale(TypeScale.caption.size * longest);
    return cell >= label + AppSpace.s2;
  }

  Widget _cells(BuildContext context) => GenkoGrid(
    columns: _entries.length,
    maxCellHeight: _maxCellHeight,
    children: [
      for (final entry in _entries)
        _EntryCell(entry: entry, onTap: () => _open(context, entry)),
    ],
  );

  Widget _rows(BuildContext context) => RuledList(
    children: [
      for (final entry in _entries)
        RuledTile.text(
          entry.label,
          subtitle: entry.subtitle,
          leading: ExcludeSemantics(
            child: JaText(entry.glyph, scale: TypeScale.jaSentence),
          ),
          onTap: () => _open(context, entry),
        ),
    ],
  );
}

class _EntryCell extends StatelessWidget {
  const _EntryCell({required this.entry, required this.onTap});

  final _Entry entry;
  final VoidCallback onTap;

  Color _fill(AppTokens t, PressState state) {
    if (state.pressed) return t.paper.sunken;
    if (state.hovered) return t.paper.raised;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: entry.label,
      builder: (context, state) => ColoredBox(
        color: _fill(t, state),
        child: PressNudge(
          pressed: state.pressed,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JaText(
                  entry.glyph,
                  scale: TypeScale.jaSentence,
                  textScaler: TextScaler.noScaling,
                ),
                AppText(entry.label, scale: TypeScale.caption, maxLines: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

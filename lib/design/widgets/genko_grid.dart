import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// 稿紙格（§4.1）：`cell = floor(內容寬 / 欄數)`，列距 6。
/// `null` 子元件是留白格，例如や行、わ行維持母音對位。
class GenkoGrid extends StatelessWidget {
  const GenkoGrid({
    required this.children,
    this.columns = PaperLayout.genkoColumns,
    this.rowGap = PaperLayout.genkoRowGap,
    this.maxCell,
    this.maxCellHeight,
    super.key,
  });

  final List<Widget?> children;
  final int columns;
  final double rowGap;

  /// 格寬上限：內容寬放大時格子維持小方格（假名格），格子靠左。
  final double? maxCell;

  /// 列高上限：格寬仍填滿內容寬，只限制不要變得太高（月曆、入口）。
  final double? maxCellHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fitted = PaperLayout.cell(constraints.maxWidth, columns: columns);
      final cell = math.min(fitted, maxCell ?? fitted);
      final cellHeight = math.min(cell, maxCellHeight ?? cell);
      final rows = (children.length / columns).ceil();
      final height = rows * cellHeight + (rows - 1).clamp(0, rows) * rowGap;
      return SizedBox(
        width: cell * columns,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: GenkoPainter(
                    color: AppTokens.of(context).line.grid,
                    cell: cell,
                    cellHeight: cellHeight,
                    gap: rowGap,
                    columns: columns,
                    rows: rows,
                  ),
                ),
              ),
            ),
            for (final (index, child) in children.indexed)
              if (child != null)
                Positioned(
                  left: (index % columns) * cell,
                  top: (index ~/ columns) * (cellHeight + rowGap),
                  width: cell,
                  height: cellHeight,
                  child: child,
                ),
          ],
        ),
      );
    },
  );
}

class GenkoPainter extends CustomPainter {
  const GenkoPainter({
    required this.color,
    required this.cell,
    required this.gap,
    required this.columns,
    required this.rows,
    double? cellHeight,
  }) : cellHeight = cellHeight ?? cell;

  final Color color;
  final double cell, cellHeight, gap;
  final int columns, rows;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var row = 0; row < rows; row++) {
      final top = row * (cellHeight + gap);
      for (var column = 0; column < columns; column++) {
        canvas.drawRect(
          Rect.fromLTWH(column * cell, top, cell, cellHeight),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(GenkoPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cell != cell ||
      oldDelegate.cellHeight != cellHeight ||
      oldDelegate.rows != rows;
}

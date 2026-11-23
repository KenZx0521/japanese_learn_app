import 'package:material_ui/material_ui.dart';

/// 略過的課畫一條斜線，不靠填色：深色模式的填色和紙面太接近，
/// 看起來跟未開始的空格一樣（裁決 U7）。
void drawSkipSlash(Canvas canvas, Rect cell, Color color) => canvas.drawLine(
  cell.bottomLeft,
  cell.topRight,
  Paint()
    ..color = color
    ..strokeWidth = 1.2,
);

/// 單獨一格的斜線，放在方格內當 child。
class SkipSlashPainter extends CustomPainter {
  const SkipSlashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      drawSkipSlash(canvas, Offset.zero & size, color);

  @override
  bool shouldRepaint(SkipSlashPainter oldDelegate) =>
      oldDelegate.color != color;
}

import 'package:material_ui/material_ui.dart';

/// 喇叭線條圖：不用 Material Icons（§1）。`slashed` 是語音無法使用的斜線版。
class SpeakerIcon extends StatelessWidget {
  const SpeakerIcon({
    required this.color,
    this.size = 22,
    this.slashed = false,
    super.key,
  });

  final Color color;
  final double size;
  final bool slashed;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _SpeakerPainter(color: color, slashed: slashed),
    ),
  );
}

class _SpeakerPainter extends CustomPainter {
  const _SpeakerPainter({required this.color, required this.slashed});
  final Color color;
  final bool slashed;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.08
      ..strokeCap = StrokeCap.round;
    final body = Path()
      ..moveTo(s * 0.12, s * 0.38)
      ..lineTo(s * 0.3, s * 0.38)
      ..lineTo(s * 0.52, s * 0.18)
      ..lineTo(s * 0.52, s * 0.82)
      ..lineTo(s * 0.3, s * 0.62)
      ..lineTo(s * 0.12, s * 0.62)
      ..close();
    canvas.drawPath(body, paint);
    if (slashed) {
      canvas.drawLine(
        Offset(s * 0.1, s * 0.9),
        Offset(s * 0.9, s * 0.1),
        paint,
      );
      return;
    }
    final wave = Path()
      ..moveTo(s * 0.66, s * 0.34)
      ..quadraticBezierTo(s * 0.8, s * 0.5, s * 0.66, s * 0.66);
    canvas.drawPath(wave, paint);
  }

  @override
  bool shouldRepaint(_SpeakerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.slashed != slashed;
}

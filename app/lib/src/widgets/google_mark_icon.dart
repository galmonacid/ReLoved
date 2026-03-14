import "dart:math" as math;

import "package:flutter/material.dart";

class GoogleMarkIcon extends StatelessWidget {
  const GoogleMarkIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        key: const ValueKey("google-mark-icon"),
        size: Size.square(size),
        painter: const _GoogleMarkPainter(),
      ),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFDB4437);
  static const Color _yellow = Color(0xFFF4B400);
  static const Color _green = Color(0xFF0F9D58);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.18;
    final radiusInset = strokeWidth / 2;
    final arcRect = Rect.fromLTWH(
      radiusInset,
      radiusInset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    void drawArc(Color color, double startDeg, double sweepDeg) {
      paint.color = color;
      canvas.drawArc(
        arcRect,
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        paint,
      );
    }

    drawArc(_red, -42, 82);
    drawArc(_yellow, 40, 92);
    drawArc(_green, 132, 96);
    drawArc(_blue, 228, 134);

    paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 0
      ..color = _blue;
    final barHeight = strokeWidth * 0.95;
    final barWidth = size.width * 0.28;
    final barLeft = size.width * 0.53;
    final barTop = size.height / 2 - barHeight / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barTop, barWidth, barHeight),
        Radius.circular(barHeight / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

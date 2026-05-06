import 'package:flutter/material.dart';
import 'package:lexrush/app/theme/app_colors.dart';

class SequencingRouteBackground extends StatelessWidget {
  const SequencingRouteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(child: CustomPaint(painter: _RoutePainter())),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint pathPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final Paint dotPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final Path path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.84)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.72,
        size.width * 0.44,
        size.height * 0.80,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.90,
        size.width * 0.82,
        size.height * 0.76,
      );
    canvas.drawPath(path, pathPaint);
    for (final Offset dot in <Offset>[
      Offset(size.width * 0.16, size.height * 0.24),
      Offset(size.width * 0.82, size.height * 0.31),
      Offset(size.width * 0.30, size.height * 0.66),
      Offset(size.width * 0.70, size.height * 0.58),
    ]) {
      canvas.drawCircle(dot, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class InfinityLogo extends StatelessWidget {
  const InfinityLogo({super.key, this.size = AppSpacing.stackLg * 1.5});

  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: const _InfinityLogoPainter(),
      ),
    );
  }
}

class _InfinityLogoPainter extends CustomPainter {
  const _InfinityLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth =
        size.shortestSide / (AppSpacing.stackLg / AppSpacing.unit);
    final markStrokeWidth =
        strokeWidth / (AppSpacing.radiusDefault / AppSpacing.radiusSm);
    final logoPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.5)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.22,
        size.width * 0.38,
        size.height * 0.22,
        size.width * 0.5,
        size.height * 0.5,
      )
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.78,
        size.width * 0.82,
        size.height * 0.78,
        size.width * 0.82,
        size.height * 0.5,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.22,
        size.width * 0.62,
        size.height * 0.22,
        size.width * 0.5,
        size.height * 0.5,
      )
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.78,
        size.width * 0.18,
        size.height * 0.78,
        size.width * 0.18,
        size.height * 0.5,
      );

    canvas.drawPath(path, logoPaint);

    final markPaint = Paint()
      ..color = AppColors.inkNavy
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = markStrokeWidth;

    final leftCenter = Offset(size.width * 0.34, size.height * 0.5);
    final rightCenter = Offset(size.width * 0.66, size.height * 0.5);
    final markExtent =
        size.shortestSide / (AppSpacing.stackLg / AppSpacing.stackSm);
    final circleRadius =
        markExtent * (AppSpacing.radiusMd / AppSpacing.stackMd);

    canvas
      ..drawLine(
        Offset(leftCenter.dx - markExtent, leftCenter.dy - markExtent),
        Offset(leftCenter.dx + markExtent, leftCenter.dy + markExtent),
        markPaint,
      )
      ..drawLine(
        Offset(leftCenter.dx + markExtent, leftCenter.dy - markExtent),
        Offset(leftCenter.dx - markExtent, leftCenter.dy + markExtent),
        markPaint,
      )
      ..drawCircle(rightCenter, circleRadius, markPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

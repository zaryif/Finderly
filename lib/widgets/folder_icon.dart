import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:finderly/theme/folder_colors.dart';

class FolderIcon extends StatelessWidget {
  final FolderColor color;
  final double size;

  const FolderIcon({
    super.key,
    required this.color,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    // Exact native macOS folder aspect ratio (512x412)
    final width = size;
    final height = size * (412.0 / 512.0);

    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/folders/folder_${color.name}.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return CustomPaint(
            size: Size(width, height),
            painter: _FolderPainter(color: color),
          );
        },
      ),
    );
  }
}

class _FolderPainter extends CustomPainter {
  final FolderColor color;

  _FolderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final radius = w * 0.08;

    _drawShadow(canvas, w, h);
    _drawBackPanelAndTab(canvas, w, h, radius);
    _drawFrontPanel(canvas, w, h, radius);
    _drawTopEdgeHighlight(canvas, w, h, radius);
  }

  void _drawShadow(Canvas canvas, double w, double h) {
    final shadowPaint = Paint()
      ..color = color.shadow.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.97),
        width: w * 0.85,
        height: h * 0.08,
      ),
      shadowPaint,
    );
  }

  void _drawBackPanelAndTab(Canvas canvas, double w, double h, double radius) {
    final backTop = h * 0.25;
    final backColor = Color.lerp(color.primary, Colors.black, 0.15)!;
    final backPaint = Paint()..color = backColor;

    final tabLeft = w * 0.05;
    final tabRight = w * 0.45;
    final tabTop = h * 0.10;
    final tabCurveEndX = w * 0.55;

    final tabPath = Path()
      ..moveTo(tabLeft, backTop)
      ..lineTo(tabLeft, tabTop + radius * 0.5)
      ..quadraticBezierTo(tabLeft, tabTop, tabLeft + radius, tabTop)
      ..lineTo(tabRight - radius * 0.5, tabTop)
      ..cubicTo(
        tabRight + w * 0.02, tabTop,
        tabRight + w * 0.02, backTop,
        tabCurveEndX, backTop,
      );

    final combinedPath = Path()
      ..addPath(tabPath, Offset.zero)
      ..lineTo(w - radius, backTop)
      ..quadraticBezierTo(w, backTop, w, backTop + radius)
      ..lineTo(w, h * 0.97 - radius - h * 0.03)
      ..quadraticBezierTo(w, h * 0.97 - h * 0.03, w - radius, h * 0.97 - h * 0.03)
      ..lineTo(radius, h * 0.97 - h * 0.03)
      ..quadraticBezierTo(0, h * 0.97 - h * 0.03, 0, h * 0.97 - radius - h * 0.03)
      ..lineTo(0, backTop + radius)
      ..quadraticBezierTo(0, backTop, tabLeft, backTop)
      ..close();

    canvas.drawPath(combinedPath, backPaint);

    final backGradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          backColor.withOpacity(0.0),
          Colors.black.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, backTop, w, h * 0.72));
    canvas.drawPath(combinedPath, backGradientPaint);
  }

  void _drawFrontPanel(Canvas canvas, double w, double h, double radius) {
    final frontTop = h * 0.35;
    final frontBottom = h * 0.97;
    final frontRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, frontTop, w, frontBottom - frontTop),
      Radius.circular(radius),
    );

    final frontPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.highlight,
          color.primary,
          Color.lerp(color.primary, Colors.black, 0.05)!,
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromLTWH(0, frontTop, w, frontBottom - frontTop));

    canvas.drawRRect(frontRect, frontPaint);
  }

  void _drawTopEdgeHighlight(Canvas canvas, double w, double h, double radius) {
    final frontTop = h * 0.35;
    final highlightPaint = Paint()
      ..color = color.highlight.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, h * 0.015);

    canvas.drawLine(
      Offset(radius * 0.5, frontTop + highlightPaint.strokeWidth / 2),
      Offset(w - radius * 0.5, frontTop + highlightPaint.strokeWidth / 2),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_FolderPainter oldDelegate) => color != oldDelegate.color;
}

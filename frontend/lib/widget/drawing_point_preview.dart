import 'package:flutter/material.dart';
import 'package:frontend/items/drawingpoint_item.dart';

class DrawingThumbnailPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;
  final double scaleFactor;

  DrawingThumbnailPainter({
    required this.drawingPoints,
    required this.scaleFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;

    for (final point in drawingPoints) {
      paint
        ..color =
            point
                .color // Reduce opacity in preview
        ..strokeWidth = point.width * scaleFactor; // Scale stroke width

      for (int i = 0; i < point.offsets.length - 1; i++) {
        final Offset start = point.offsets[i] * scaleFactor;
        final Offset end = point.offsets[i + 1] * scaleFactor;
        canvas.drawLine(start, end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

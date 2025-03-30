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
    // Create a layer to properly handle blending modes
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final point in drawingPoints) {
      if (point.offsets.isEmpty) continue;

      final paint = Paint()
        ..color = point.tool == 'eraser' ? Colors.transparent : point.color
        ..strokeWidth = point.width * scaleFactor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode =
            point.tool == 'eraser' ? BlendMode.clear : BlendMode.srcOver;

      if (point.offsets.length > 1) {
        final path = Path();
        path.moveTo(point.offsets.first.dx * scaleFactor,
            point.offsets.first.dy * scaleFactor);
        for (int i = 1; i < point.offsets.length; i++) {
          path.lineTo(point.offsets[i].dx * scaleFactor,
              point.offsets[i].dy * scaleFactor);
        }
        canvas.drawPath(path, paint);
      } else if (point.offsets.length == 1) {
        canvas.drawCircle(point.offsets.first * scaleFactor,
            (point.width / 2) * scaleFactor, paint);
      }
    }

    canvas.restore(); // Restore the canvas state after drawing
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

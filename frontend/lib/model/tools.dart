import 'package:flutter/material.dart';
import 'package:frontend/model/drawingpoint.dart';

/*-----------------Pencil Tool-----------------*/
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    // First render all regular drawing strokes
    for (final point in drawingPoints) {
      if (point.offsets.isEmpty || point.isEraser) continue;

      final paint =
          Paint()
            ..color = point.color
            ..strokeWidth = point.width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;

      if (point.offsets.length > 1) {
        final path = Path();
        path.moveTo(point.offsets.first.dx, point.offsets.first.dy);

        for (int i = 1; i < point.offsets.length; i++) {
          path.lineTo(point.offsets[i].dx, point.offsets[i].dy);
        }

        canvas.drawPath(path, paint);
      } else if (point.offsets.length == 1) {
        canvas.drawCircle(point.offsets.first, point.width / 2, paint);
      }
    }

    // Then render eraser strokes with compositing
    final eraserPoints = drawingPoints.where((p) => p.isEraser).toList();
    if (eraserPoints.isNotEmpty) {
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

      for (final point in eraserPoints) {
        if (point.offsets.isEmpty) continue;

        final paint =
            Paint()
              ..color = Colors.white
              ..strokeWidth = point.width
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke
              ..blendMode =
                  BlendMode.srcOver; // This is key for a true eraser effect

        if (point.offsets.length > 1) {
          final path = Path();
          path.moveTo(point.offsets.first.dx, point.offsets.first.dy);

          for (int i = 1; i < point.offsets.length; i++) {
            path.lineTo(point.offsets[i].dx, point.offsets[i].dy);
          }

          canvas.drawPath(path, paint);
        } else if (point.offsets.length == 1) {
          canvas.drawCircle(point.offsets.first, point.width / 2, paint);
        }
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}

/*-----------------Eraser Tool-----------------*/

import 'package:flutter/material.dart';
import 'package:frontend/model/drawingpoint.dart';

/*-----------------Pencil Tool-----------------*/
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    // Create a single layer for all drawing operations
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Draw regular strokes
    for (final point in drawingPoints) {
      if (point.offsets.isEmpty) continue;

      final paint =
          Paint()
            ..color = point.isEraser ? Colors.red : point.color
            ..strokeWidth = point.width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke
            ..blendMode = point.isEraser ? BlendMode.clear : BlendMode.srcOver;

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

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}

/*-----------------Eraser Tool-----------------*/
enum EraserMode { point, stroke }

class EraserTool {
  double eraserWidth;
  EraserMode eraserMode;
  Offset? lastErasePosition;
  bool isErasing = false;
  List<DrawingPoint> currentEraseStrokes = [];

  // References to external data
  final List<DrawingPoint> drawingPoints;
  final List<List<DrawingPoint>> undoStack;
  final List<List<DrawingPoint>> redoStack;
  final VoidCallback onStateChanged; // Callback to trigger setState in Paper

  EraserTool({
    required this.eraserWidth,
    required this.eraserMode,
    required this.drawingPoints,
    required this.undoStack,
    required this.redoStack,
    required this.onStateChanged,
  });

  void startErasing(Offset position) {
    if (isErasing) return;

    // Save current state for undo
    undoStack.add(List<DrawingPoint>.from(drawingPoints));
    redoStack.clear();

    isErasing = true;
    currentEraseStrokes = [];
  }

  void eraseIntersectingStrokes(Offset position) {
    if (!isErasing) {
      startErasing(position);
    }

    final eraserRadius = eraserWidth;
    final toRemove = <DrawingPoint>[];

    for (final point in drawingPoints) {
      if (point.isEraser) continue;

      for (final offset in point.offsets) {
        if ((offset - position).distance <= eraserRadius) {
          toRemove.add(point);
          currentEraseStrokes.add(point);
          break;
        }
      }
    }

    if (toRemove.isNotEmpty) {
      drawingPoints.removeWhere((p) => toRemove.contains(p));
      final eraserPoint = DrawingPoint(
        id: DateTime.now().microsecondsSinceEpoch,
        offsets: [position],
        color: Colors.transparent,
        width: eraserWidth,
        isEraser: true,
      );
      drawingPoints.add(eraserPoint);
      onStateChanged(); // Trigger Paper's setState
    }
  }

  void eraseAtPoint(Offset point) {
    if (!isErasing) {
      startErasing(point);
    }

    final eraserPoint = DrawingPoint(
      id: DateTime.now().microsecondsSinceEpoch,
      offsets: [point],
      color: Colors.transparent,
      width: eraserWidth,
      isEraser: true,
    );
    drawingPoints.add(eraserPoint);
    lastErasePosition = point;
    onStateChanged(); // Trigger Paper's setState
  }

  void finishErasing() {
    if (!isErasing) return;

    isErasing = false;
    currentEraseStrokes = [];
    onStateChanged();
  }

  void handleErasing(Offset position, bool isWithinCanvas) {
    if (!isWithinCanvas) return;

    if (eraserMode == EraserMode.point) {
      eraseAtPoint(position);
    } else if (eraserMode == EraserMode.stroke) {
      eraseIntersectingStrokes(position);
    }
  }
}

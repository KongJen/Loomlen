import 'package:flutter/material.dart';
import 'package:frontend/items/drawingpoint_item.dart';

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
  final Map<String, List<DrawingPoint>> pageDrawingPoints;
  final List<Map<String, List<DrawingPoint>>> undoStack;
  final List<Map<String, List<DrawingPoint>>> redoStack;
  final VoidCallback onStateChanged; // Callback to trigger setState in Paper
  final String currentPaperId; // Current page being erased

  EraserTool({
    required this.eraserWidth,
    required this.eraserMode,
    required this.pageDrawingPoints,
    required this.undoStack,
    required this.redoStack,
    required this.onStateChanged,
    required this.currentPaperId,
  });

  void startErasing(Offset position) {
    if (isErasing) return;

    // Save current state for undo
    undoStack.add(
      pageDrawingPoints.map(
        (key, value) => MapEntry(key, List<DrawingPoint>.from(value)),
      ),
    );
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

    final pointsForPage = pageDrawingPoints[currentPaperId] ?? [];
    for (final point in pointsForPage) {
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
      pointsForPage.removeWhere((p) => toRemove.contains(p));
      final eraserPoint = DrawingPoint(
        id: DateTime.now().microsecondsSinceEpoch,
        offsets: [position],
        color: Colors.transparent,
        width: eraserWidth,
        isEraser: true,
      );
      pointsForPage.add(eraserPoint);
      pageDrawingPoints[currentPaperId] = pointsForPage;
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
    pageDrawingPoints[currentPaperId] ??= [];
    pageDrawingPoints[currentPaperId]!.add(eraserPoint);
    lastErasePosition = point;
    onStateChanged(); // Trigger Paper's setState
  }

  void finishErasing() {
    if (!isErasing) return;

    isErasing = false;
    currentEraseStrokes = [];
    onStateChanged();
  }

  void handleErasing(Offset position) {
    if (eraserMode == EraserMode.point) {
      eraseAtPoint(position);
    } else if (eraserMode == EraserMode.stroke) {
      eraseIntersectingStrokes(position);
    }
  }
}

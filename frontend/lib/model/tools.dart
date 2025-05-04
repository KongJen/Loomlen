import 'package:flutter/material.dart';
import 'package:frontend/items/drawingpoint_item.dart';

/*-----------------Pencil Tool-----------------*/
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;
  final double scaleFactor;

  DrawingPainter({required this.drawingPoints, this.scaleFactor = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    // Apply scale factor to the canvas
    canvas.save();
    canvas.scale(scaleFactor);

    // Create a single layer for all drawing operations
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Draw regular strokes
    for (final point in drawingPoints) {
      if (point.offsets.isEmpty) continue;

      final paint = Paint()
        ..color = point.tool == 'eraser' ? Colors.red : point.color
        ..strokeWidth = point.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode =
            point.tool == 'eraser' ? BlendMode.clear : BlendMode.srcOver;

      if (point.offsets.length > 1) {
        final path = Path();
        path.moveTo(point.offsets.first.dx, point.offsets.first.dy);
        for (int i = 1; i < point.offsets.length; i++) {
          path.lineTo(point.offsets[i].dx, point.offsets[i].dy);
        }
        canvas.drawPath(path, paint);
      } else if (point.offsets.length == 1) {
        // Draw a tiny line segment instead of a circle
        final path = Path();
        final offset = point.offsets.first;
        path.moveTo(offset.dx, offset.dy);
        path.lineTo(
            offset.dx + 0.1, offset.dy + 0.1); // Tiny offset to create a line
        canvas.drawPath(path, paint);
      }
    }

    canvas.restore(); // Restore the drawing layer
    canvas.restore(); // Restore the scale transformation
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
  List<int> deletedStrokeIds = [];

  // References to external data
  final Map<String, List<DrawingPoint>> pageDrawingPoints;
  final VoidCallback onStateChanged; // Callback to trigger setState in Paper
  final String currentPaperId;
  String? currentUserId;

  EraserTool({
    required this.eraserWidth,
    required this.eraserMode,
    required this.pageDrawingPoints,
    required this.onStateChanged,
    required this.currentPaperId,
    this.currentUserId,
  });

  void startErasing(Offset position) {
    if (isErasing) return;

    isErasing = true;
    currentEraseStrokes = [];
  }

  void eraseIntersectingStrokes(Offset position) {
    if (!isErasing) {
      startErasing(position);
    }

    final eraserRadius = eraserWidth;
    final toRemove = <DrawingPoint>[];
    deletedStrokeIds = [];

    final pointsForPage = pageDrawingPoints[currentPaperId] ?? [];
    for (final point in pointsForPage) {
      if (point.tool == 'eraser') continue;

      for (final offset in point.offsets) {
        if ((offset - position).distance <= eraserRadius) {
          toRemove.add(point);
          currentEraseStrokes.add(point);
          deletedStrokeIds.add(point.id);
          break;
        }
      }
    }

    // 🔥 Actually remove them
    pointsForPage.removeWhere((p) => toRemove.contains(p));

    onStateChanged(); // Force UI update
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
      tool: 'eraser',
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

import 'package:flutter/material.dart';
import 'package:note_taking_app/model/drawingpoint.dart';

class Paper extends StatefulWidget {
  const Paper({super.key});

  @override
  State<Paper> createState() => _PaperState();
}

class _PaperState extends State<Paper> {
  List<DrawingPoint> drawingPoints = [];
  List<DrawingPoint> historyDrawingPoints = [];
  DrawingPoint? currentDrawingPoint;

  Color selectedColor = Colors.black;
  double selectedWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Paper'),
      ),
      body: Center(
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.only(bottom: 20),
          minScale: 1,
          maxScale: 3.0,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    currentDrawingPoint = DrawingPoint(
                      id: DateTime.now().microsecondsSinceEpoch,
                      offsets: [details.localPosition],
                      color: selectedColor,
                      width: selectedWidth,
                    );
                    if (currentDrawingPoint == null) return;
                    drawingPoints.add(currentDrawingPoint!);
                    historyDrawingPoints = List.of(drawingPoints);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    if (currentDrawingPoint == null) return;

                    currentDrawingPoint = currentDrawingPoint?.copyWith(
                      offsets: currentDrawingPoint!.offsets
                        ..add(details.localPosition),
                    );
                    drawingPoints.last = currentDrawingPoint!;
                    historyDrawingPoints = List.of(drawingPoints);
                  });
                },
                onPanEnd: (_) {
                  currentDrawingPoint = null;
                },
                child: Container(
                  width: 210 * 3,
                  height: 297 * 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        offset: const Offset(0, 3),
                        blurRadius: 5,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: ClipRect(
                    child: CustomPaint(
                      painter: DrawingPainter(drawingPoints: drawingPoints),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    for (var drawingPoint in drawingPoints) {
      final paint = Paint()
        ..color = drawingPoint.color
        ..isAntiAlias = true
        ..strokeWidth = drawingPoint.width
        ..strokeCap = StrokeCap.round;

      for (var i = 0; i < drawingPoint.offsets.length; i++) {
        var notLastOffset = i != drawingPoint.offsets.length - 1;

        if (notLastOffset) {
          final current = drawingPoint.offsets[i];
          final next = drawingPoint.offsets[i + 1];
          canvas.drawLine(current, next, paint);
        } else {
          /// we do nothing
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

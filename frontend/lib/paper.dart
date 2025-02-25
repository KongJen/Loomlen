import 'package:flutter/material.dart';
import 'package:frontend/model/drawingpoint.dart';
import 'package:frontend/OBJ/object.dart';
import 'package:frontend/OBJ/provider.dart';
import 'package:provider/provider.dart';

enum DrawingMode { pencil, eraser }

enum EraserMode { point, stroke }

class Paper extends StatefulWidget {
  final String name;
  final String? fileId;

  const Paper({Key? key, required this.name, this.fileId}) : super(key: key);

  @override
  State<Paper> createState() => _PaperState();
}

class _PaperState extends State<Paper> {
  List<DrawingPoint> drawingPoints = [];
  List<DrawingPoint> historyDrawingPoints = [];
  DrawingPoint? currentDrawingPoint;

  Color selectedColor = Colors.black;
  double selectedWidth = 2.0;
  DrawingMode selectedMode = DrawingMode.pencil;

  double eraserWidth = 10.0;
  EraserMode eraserMode = EraserMode.point;
  Offset? lastErasePosition;

  DateTime _lastUpdate = DateTime.now(); // For throttling
  static const int _updateIntervalMs = 100;

  late PaperTemplate selectedTemplate = availableTemplates.first;
  List<PaperTemplate> availableTemplates = [
    const PaperTemplate(
      id: 'plain',
      name: 'Plain Paper',
      templateType: TemplateType.plain,
    ),
    const PaperTemplate(
      id: 'lined',
      name: 'Lined Paper',
      templateType: TemplateType.lined,
      spacing: 30.0,
    ),
    const PaperTemplate(
      id: 'grid',
      name: 'Grid Paper',
      templateType: TemplateType.grid,
      spacing: 30.0,
    ),
    const PaperTemplate(
      id: 'dotted',
      name: 'Dotted Paper',
      templateType: TemplateType.dotted,
      spacing: 30.0,
    ),
  ];

  // A4 dimensions in points (1mm = 2.83465 points, scaled for Flutter)
  static const double a4Width = 210 * 2.83465; // ~595 points
  static const double a4Height = 297 * 2.83465; // ~842 points

  late TransformationController _controller;

  final List<Color> availableColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
  ];
  @override
  void initState() {
    super.initState();
    _controller = TransformationController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCanvas();
    });

    if (widget.fileId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTemplateFromFile();
      });
    }
  }

  void _centerCanvas() {
    final screenWidth = MediaQuery.of(context).size.width;
    final initialX = (screenWidth - a4Width) / 2;
    const initialY = 20.0; // Start at top

    _controller.value = Matrix4.identity()..translate(initialX, initialY);
    print(
      'Centering - Screen Width: $screenWidth, Canvas Width: $a4Width, Initial X: $initialX',
    );
  }

  void _loadTemplateFromFile() {
    final fileProvider = Provider.of<FileProvider>(context, listen: false);
    final fileData = fileProvider.getFileById(widget.fileId!);

    if (fileData != null) {
      // Parse templateType from string
      TemplateType templateType = TemplateType.plain;
      if (fileData['templateType'] != null) {
        final typeString = fileData['templateType'];
        if (typeString.contains('lined')) {
          templateType = TemplateType.lined;
        } else if (typeString.contains('grid')) {
          templateType = TemplateType.grid;
        } else if (typeString.contains('dotted')) {
          templateType = TemplateType.dotted;
        }
      }

      // Create template from saved data
      setState(() {
        selectedTemplate = PaperTemplate(
          id: fileData['templateId'] ?? 'plain',
          name: templateType.toString().split('.').last.capitalize() + ' Paper',
          templateType: templateType,
          spacing: fileData['spacing']?.toDouble() ?? 30.0,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    drawingPoints.clear();
    historyDrawingPoints.clear();
    super.dispose();
  }

  // Eraser point
  void _eraseAtPoint(Offset point) {
    if (drawingPoints.isEmpty) return;

    try {
      if (eraserMode == EraserMode.stroke) {
        drawingPoints.removeWhere((drawingPoint) {
          for (int i = 0; i < drawingPoint.offsets.length - 1; i++) {
            if (_isPointNearSegment(
              point,
              drawingPoint.offsets[i],
              drawingPoint.offsets[i + 1],
              eraserWidth,
            )) {
              return true;
            }
          }
          return drawingPoint.offsets.any(
            (offset) => (offset - point).distance <= eraserWidth,
          );
        });
      } else if (eraserMode == EraserMode.point) {
        List<DrawingPoint> newPoints = [];

        for (var drawingPoint in drawingPoints) {
          List<Offset> currentSegment = [];
          bool modified = false;

          print('Processing stroke ${drawingPoint.id}');

          for (int i = 0; i < drawingPoint.offsets.length; i++) {
            Offset currentOffset = drawingPoint.offsets[i];
            bool eraseCurrent = (currentOffset - point).distance <= eraserWidth;

            // Check segment to previous point (if exists)
            if (i > 0 && !eraseCurrent) {
              Offset prevOffset = drawingPoint.offsets[i - 1];
              if (_isPointNearSegment(
                point,
                prevOffset,
                currentOffset,
                eraserWidth,
              )) {
                eraseCurrent = true;
                print('Segment erased between $prevOffset and $currentOffset');
              }
            }

            // Check segment to next point (if exists)
            if (i < drawingPoint.offsets.length - 1) {
              Offset nextOffset = drawingPoint.offsets[i + 1];
              if (_isPointNearSegment(
                point,
                currentOffset,
                nextOffset,
                eraserWidth,
              )) {
                eraseCurrent = true;
                if (currentSegment.isNotEmpty) {
                  newPoints.add(
                    drawingPoint.copyWith(offsets: List.from(currentSegment)),
                  );
                  print('Added segment before erase: $currentSegment');
                  currentSegment.clear();
                }
                modified = true;
                // Skip to next point since this one will be erased
                continue;
              }
            }

            if (!eraseCurrent) {
              currentSegment.add(currentOffset);
            } else {
              if (currentSegment.isNotEmpty) {
                newPoints.add(
                  drawingPoint.copyWith(offsets: List.from(currentSegment)),
                );
                print('Added segment before erased point: $currentSegment');
                currentSegment.clear();
              }
              modified = true;
              print('Point erased: $currentOffset');
            }
          }

          if (currentSegment.isNotEmpty) {
            newPoints.add(
              drawingPoint.copyWith(offsets: List.from(currentSegment)),
            );
            print('Added remaining segment: $currentSegment');
          } else if (!modified) {
            newPoints.add(drawingPoint);
            print('Stroke unchanged: ${drawingPoint.id}');
          }
        }

        drawingPoints.clear();
        drawingPoints.addAll(newPoints);
        print('Updated drawingPoints: ${drawingPoints.length} strokes');
      }
      historyDrawingPoints = List.from(drawingPoints);
    } catch (e, stackTrace) {
      print('Erase error: $e\n$stackTrace');
      drawingPoints.clear();
      historyDrawingPoints.clear();
    }
  }

  bool _isPointNearSegment(
    Offset point,
    Offset start,
    Offset end,
    double threshold,
  ) {
    final double segmentLength = (end - start).distance;
    if (segmentLength == 0) return (point - start).distance <= threshold;

    double t =
        ((point.dx - start.dx) * (end.dx - start.dx) +
            (point.dy - start.dy) * (end.dy - start.dy)) /
        (segmentLength * segmentLength);
    t = t.clamp(0.0, 1.0);

    final Offset closestPoint = start + (end - start) * t;
    final double distanceToLine = (point - closestPoint).distance;

    return distanceToLine <= threshold ||
        (point - start).distance <= threshold ||
        (point - end).distance <= threshold;
  }

  void _throttledRedraw() {
    final now = DateTime.now();
    if (now.difference(_lastUpdate).inMilliseconds >= _updateIntervalMs) {
      setState(() {
        _lastUpdate = now;
      });
    }
  }

  // Widget for the pencil settings bar
  Widget _buildPencilSettingsBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pencil Size Slider
          Row(
            children: [
              const Text('Size: ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Slider(
                  value: selectedWidth,
                  min: 1.0,
                  max: 20.0,
                  divisions: 19,
                  label: selectedWidth.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      selectedWidth = value;
                    });
                  },
                ),
              ),
            ],
          ),
          // Color Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children:
                availableColors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedColor = color;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              selectedColor == color
                                  ? Colors.white
                                  : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  // Eraser settings bar
  Widget _buildEraserSettingsBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eraser Size Slider
          Row(
            children: [
              const Text('Eraser Size: ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Slider(
                  value: eraserWidth,
                  min: 5.0,
                  max: 50.0,
                  divisions: 45,
                  label: eraserWidth.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      eraserWidth = value;
                    });
                  },
                ),
              ),
            ],
          ),
          // Eraser Mode Toggle
          Row(
            children: [
              const Text('Mode: ', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              ToggleButtons(
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: Colors.blue,
                constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
                isSelected: [
                  eraserMode == EraserMode.stroke,
                  eraserMode == EraserMode.point,
                ],
                children: const [Text('Stroke'), Text('Point')],
                onPressed: (index) {
                  setState(() {
                    eraserMode =
                        index == 0 ? EraserMode.stroke : EraserMode.point;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isWithinCanvas(Offset point) {
    return point.dx >= 0 &&
        point.dx <= a4Width &&
        point.dy >= 0 &&
        point.dy <= a4Height;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.name),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: selectedMode == DrawingMode.pencil ? Colors.blue : null,
            ),
            onPressed: () => setState(() => selectedMode = DrawingMode.pencil),
            tooltip: 'Pencil',
          ),
          IconButton(
            icon: Icon(
              Icons.delete,
              color: selectedMode == DrawingMode.eraser ? Colors.blue : null,
            ),
            onPressed: () => setState(() => selectedMode = DrawingMode.eraser),
            tooltip: 'Eraser',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                drawingPoints.clear();
                historyDrawingPoints.clear();
              });
            },
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        children: [
          if (selectedMode == DrawingMode.pencil) _buildPencilSettingsBar(),
          if (selectedMode == DrawingMode.eraser) _buildEraserSettingsBar(),
          Expanded(
            child: Center(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1.0,
                maxScale: 2.0,
                // Calculate boundary margin to allow scrolling only when zoomed
                boundaryMargin: EdgeInsets.symmetric(
                  horizontal:
                      (screenSize.width - a4Width) / 2 > 0
                          ? (screenSize.width - a4Width) / 2
                          : 0,
                  vertical:
                      (screenSize.height - a4Height) / 2 > 0
                          ? (screenSize.height - a4Height) / 2
                          : 20,
                ),
                constrained:
                    false, // Ensures the content fits within the viewer
                child: Center(
                  child: Container(
                    width: a4Width,
                    height: a4Height,
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
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        CustomPaint(
                          painter: TemplatePainter(template: selectedTemplate),
                          size: Size(a4Width, a4Height),
                        ),
                        GestureDetector(
                          onPanStart: (details) {
                            try {
                              Offset localPosition = details.localPosition;
                              if (!_isWithinCanvas(localPosition)) return;

                              if (selectedMode == DrawingMode.pencil) {
                                currentDrawingPoint = DrawingPoint(
                                  id: DateTime.now().microsecondsSinceEpoch,
                                  offsets: [localPosition],
                                  color: selectedColor,
                                  width: selectedWidth,
                                );
                                drawingPoints.add(currentDrawingPoint!);
                              } else if (selectedMode == DrawingMode.eraser) {
                                _eraseAtPoint(localPosition);
                                lastErasePosition = localPosition;
                              }
                              historyDrawingPoints = List.from(drawingPoints);
                              _throttledRedraw();
                            } catch (e, stackTrace) {
                              print('Pan start error: $e\n$stackTrace');
                            }
                          },
                          onPanUpdate: (details) {
                            try {
                              Offset localPosition = details.localPosition;
                              if (!_isWithinCanvas(localPosition)) return;

                              if (selectedMode == DrawingMode.pencil) {
                                if (currentDrawingPoint != null) {
                                  currentDrawingPoint = currentDrawingPoint!
                                      .copyWith(
                                        offsets:
                                            currentDrawingPoint!.offsets
                                              ..add(localPosition),
                                      );
                                  drawingPoints.last = currentDrawingPoint!;
                                }
                              } else if (selectedMode == DrawingMode.eraser) {
                                if (lastErasePosition != null) {
                                  double distance =
                                      (localPosition - lastErasePosition!)
                                          .distance;
                                  if (distance > eraserWidth) {
                                    for (int i = 0; i <= 1; i++) {
                                      Offset interpolatePoint =
                                          Offset.lerp(
                                            lastErasePosition!,
                                            localPosition,
                                            i / 1,
                                          )!;
                                      if (_isWithinCanvas(interpolatePoint)) {
                                        _eraseAtPoint(interpolatePoint);
                                      }
                                    }
                                    lastErasePosition = localPosition;
                                  }
                                } else {
                                  _eraseAtPoint(localPosition);
                                  lastErasePosition = localPosition;
                                }
                              }
                              historyDrawingPoints = List.from(drawingPoints);
                              _throttledRedraw();
                            } catch (e, stackTrace) {
                              print('Pan update error: $e\n$stackTrace');
                            }
                          },
                          onPanEnd: (_) {
                            try {
                              if (selectedMode == DrawingMode.pencil) {
                                currentDrawingPoint = null;
                              }
                              lastErasePosition = null;
                              historyDrawingPoints = List.from(drawingPoints);
                              setState(() {});
                            } catch (e, stackTrace) {
                              print('Pan end error: $e\n$stackTrace');
                            }
                          },
                          child: CustomPaint(
                            painter: DrawingPainter(
                              drawingPoints: drawingPoints,
                            ),
                            size: Size(a4Width, a4Height),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Updated DrawingPainter (no template)
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round;

    for (var drawingPoint in drawingPoints) {
      if (drawingPoint.offsets.isEmpty) continue;

      paint.color = drawingPoint.color;
      paint.strokeWidth = drawingPoint.width;

      for (int i = 0; i < drawingPoint.offsets.length - 1; i++) {
        canvas.drawLine(
          drawingPoint.offsets[i],
          drawingPoint.offsets[i + 1],
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// New TemplatePainter
class TemplatePainter extends CustomPainter {
  final PaperTemplate template;

  TemplatePainter({required this.template});

  void paint(Canvas canvas, Size size) {
    // Clip the canvas to the A4 size to ensure lines don’t draw outside
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    template.paintTemplate(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false; // Templates are static
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

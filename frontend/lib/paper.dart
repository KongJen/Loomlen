import 'package:flutter/material.dart';
import 'package:frontend/model/drawingpoint.dart';
import 'package:frontend/OBJ/object.dart';
import 'package:frontend/OBJ/provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';

enum DrawingMode { pencil, eraser }

enum EraserMode { point, stroke }

class Paper extends StatefulWidget {
  final String name;
  final String? fileId;

  const Paper({super.key, required this.name, this.fileId});

  @override
  State<Paper> createState() => _PaperState();
}

class _PaperState extends State<Paper> {
  final List<DrawingPoint> drawingPoints = [];
  final List<DrawingPoint> historyDrawingPoints = [];
  DrawingPoint? currentDrawingPoint;

  bool _hasUnsavedChanges = false;
  final List<Map<String, dynamic>> strokeHistory = [];
  final List<List<DrawingPoint>> undoStack = [];
  final List<List<DrawingPoint>> redoStack = [];

  Color selectedColor = Colors.black;
  double selectedWidth = 2.0;
  DrawingMode selectedMode = DrawingMode.pencil;

  double eraserWidth = 10.0;
  EraserMode eraserMode = EraserMode.point;
  Offset? lastErasePosition;

  DateTime _lastUpdate = DateTime.now();
  static const int _updateIntervalMs = 100;

  late PaperTemplate selectedTemplate;
  final List<PaperTemplate> availableTemplates = const [
    PaperTemplate(
      id: 'plain',
      name: 'Plain Paper',
      templateType: TemplateType.plain,
    ),
    PaperTemplate(
      id: 'lined',
      name: 'Lined Paper',
      templateType: TemplateType.lined,
      spacing: 30.0,
    ),
    PaperTemplate(
      id: 'grid',
      name: 'Grid Paper',
      templateType: TemplateType.grid,
      spacing: 30.0,
    ),
    PaperTemplate(
      id: 'dotted',
      name: 'Dotted Paper',
      templateType: TemplateType.dotted,
      spacing: 30.0,
    ),
  ];

  static const double a4Width = 210 * 2.83465; // A4 width in points (~595)
  static const double a4Height = 297 * 2.83465; // A4 height in points (~842)

  late final TransformationController _controller;
  final List<Color> availableColors = const [
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
    selectedTemplate = availableTemplates.first;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCanvas();
      if (widget.fileId != null) {
        _loadTemplateFromFile();
        _loadDrawingFromFile();
      }
    });
  }

  void _loadDrawingFromFile() {
    final fileProvider = context.read<FileProvider>();
    final fileData = fileProvider.getFileById(widget.fileId!);

    if (fileData?['drawingData'] == null) return;

    try {
      final List<dynamic> loadedStrokes = fileData!['drawingData'];
      setState(() {
        drawingPoints.clear();
        strokeHistory.clear();
        strokeHistory.addAll(loadedStrokes.cast<Map<String, dynamic>>());

        for (final stroke in strokeHistory) {
          if (stroke['type'] == 'drawing') {
            final point = DrawingPoint.fromJson(stroke['data']);
            if (point.offsets.isNotEmpty) drawingPoints.add(point);
          }
        }
        historyDrawingPoints.clear();
        historyDrawingPoints.addAll(drawingPoints);
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading drawing data: $e\n$stackTrace');
    }
  }

  Future<void> _saveDrawing() async {
    final fileProvider = context.read<FileProvider>();
    final cleanHistory =
        drawingPoints
            .map(
              (point) => {
                'type': 'drawing',
                'data': point.toJson(),
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              },
            )
            .toList();

    if (widget.fileId != null) {
      await fileProvider.updateFileDrawingData(widget.fileId!, cleanHistory);
    } else {
      fileProvider.addFile(
        widget.name,
        drawingPoints.length,
        selectedTemplate,
        cleanHistory,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drawing saved successfully')),
      );
    }
    _hasUnsavedChanges = false;
  }

  void _centerCanvas() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final initialX = (screenWidth - a4Width) / 2;
    const initialY = 20.0;
    _controller.value = Matrix4.identity()..translate(initialX, initialY);
  }

  void _loadTemplateFromFile() {
    final fileProvider = context.read<FileProvider>();
    final fileData = fileProvider.getFileById(widget.fileId!);

    if (fileData == null) return;

    final typeString = fileData['templateType']?.toString() ?? 'plain';
    final templateType = switch (typeString) {
      String s when s.contains('lined') => TemplateType.lined,
      String s when s.contains('grid') => TemplateType.grid,
      String s when s.contains('dotted') => TemplateType.dotted,
      _ => TemplateType.plain,
    };

    setState(() {
      selectedTemplate = PaperTemplate(
        id: fileData['templateId'] ?? 'plain',
        name: '${templateType.name.capitalize()} Paper',
        templateType: templateType,
        spacing: fileData['spacing']?.toDouble() ?? 30.0,
      );
    });
  }

  void _undo() {
    if (drawingPoints.isEmpty) return;
    setState(() {
      final lastStroke = drawingPoints.removeLast();
      undoStack.add([lastStroke]);
      _updateStrokeHistory();
    });
  }

  void _redo() {
    if (redoStack.isEmpty) return;
    setState(() {
      final redoPoints = redoStack.removeLast();
      drawingPoints.addAll(redoPoints);
      _updateStrokeHistory();
    });
  }

  void _updateStrokeHistory() {
    strokeHistory.clear();
    strokeHistory.addAll(
      drawingPoints.map(
        (point) => {
          'type': 'drawing',
          'data': point.toJson(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ),
    );
  }

  void _eraseAtPoint(Offset point) {
    if (drawingPoints.isEmpty) return;

    try {
      if (eraserMode == EraserMode.stroke) {
        final removedStrokeIds = <int>{};
        drawingPoints.removeWhere((dp) {
          for (var i = 0; i < dp.offsets.length - 1; i++) {
            if (_isPointNearSegment(
              point,
              dp.offsets[i],
              dp.offsets[i + 1],
              eraserWidth,
            )) {
              removedStrokeIds.add(dp.id);
              return true;
            }
          }
          return dp.offsets.any(
            (offset) => (offset - point).distance <= eraserWidth,
          );
        });
        strokeHistory.removeWhere(
          (stroke) =>
              stroke['type'] == 'drawing' &&
              removedStrokeIds.contains(stroke['data']['id']),
        );
      } else {
        final newPoints = <DrawingPoint>[];
        final updatedStrokes = <int, Map<String, dynamic>>{};
        final removedStrokeIds = <int>{};

        for (final dp in drawingPoints) {
          var currentSegment = <Offset>[];
          var modified = false;

          for (var i = 0; i < dp.offsets.length; i++) {
            final offset = dp.offsets[i];
            var erase = (offset - point).distance <= eraserWidth;

            if (i > 0 &&
                !erase &&
                _isPointNearSegment(
                  point,
                  dp.offsets[i - 1],
                  offset,
                  eraserWidth,
                )) {
              erase = true;
            }
            if (i < dp.offsets.length - 1 &&
                _isPointNearSegment(
                  point,
                  offset,
                  dp.offsets[i + 1],
                  eraserWidth,
                )) {
              erase = true;
            }

            if (!erase) {
              currentSegment.add(offset);
            } else if (currentSegment.isNotEmpty) {
              final newPoint = dp.copyWith(offsets: List.from(currentSegment));
              newPoints.add(newPoint);
              updatedStrokes[newPoint.id] = newPoint.toJson();
              currentSegment.clear();
              modified = true;
            }
          }

          if (currentSegment.isNotEmpty) {
            final newPoint = dp.copyWith(offsets: List.from(currentSegment));
            newPoints.add(newPoint);
            updatedStrokes[newPoint.id] = newPoint.toJson();
          } else if (modified) {
            removedStrokeIds.add(dp.id);
          } else {
            newPoints.add(dp);
          }
        }

        strokeHistory.removeWhere(
          (stroke) =>
              stroke['type'] == 'drawing' &&
              removedStrokeIds.contains(stroke['data']['id']),
        );
        for (var i = 0; i < strokeHistory.length; i++) {
          if (strokeHistory[i]['type'] == 'drawing') {
            final strokeId = strokeHistory[i]['data']['id'] as int;
            if (updatedStrokes.containsKey(strokeId))
              strokeHistory[i]['data'] = updatedStrokes[strokeId];
          }
        }

        drawingPoints.clear();
        drawingPoints.addAll(newPoints);
      }

      strokeHistory.add({
        'type': 'eraser',
        'position': {'x': point.dx, 'y': point.dy},
        'width': eraserWidth,
        'mode': eraserMode.name,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      historyDrawingPoints.clear();
      historyDrawingPoints.addAll(drawingPoints);
    } catch (e, stackTrace) {
      debugPrint('Erase error: $e\n$stackTrace');
    }
  }

  bool _isPointNearSegment(
    Offset point,
    Offset start,
    Offset end,
    double threshold,
  ) {
    final segmentLength = (end - start).distance;
    if (segmentLength == 0) return (point - start).distance <= threshold;

    final t =
        ((point.dx - start.dx) * (end.dx - start.dx) +
            (point.dy - start.dy) * (end.dy - start.dy)) /
        (segmentLength * segmentLength);
    final clampedT = t.clamp(0.0, 1.0);
    final closestPoint = start + (end - start) * clampedT;

    return (point - closestPoint).distance <= threshold ||
        (point - start).distance <= threshold ||
        (point - end).distance <= threshold;
  }

  void _throttledRedraw() {
    final now = DateTime.now();
    if (now.difference(_lastUpdate).inMilliseconds >= _updateIntervalMs) {
      setState(() => _lastUpdate = now);
    }
  }

  Widget _buildPencilSettingsBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  onChanged: (value) => setState(() => selectedWidth = value),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children:
                availableColors
                    .map(
                      (color) => GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
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
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEraserSettingsBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  onChanged: (value) => setState(() => eraserWidth = value),
                ),
              ),
            ],
          ),
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
                onPressed:
                    (index) => setState(
                      () =>
                          eraserMode =
                              index == 0 ? EraserMode.stroke : EraserMode.point,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isWithinCanvas(Offset point) =>
      point.dx >= 0 &&
      point.dx <= a4Width &&
      point.dy >= 0 &&
      point.dy <= a4Height;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
            if (_hasUnsavedChanges) _saveDrawing();
          },
        ),
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
            icon: const Icon(Icons.undo),
            onPressed: drawingPoints.isEmpty ? null : _undo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: redoStack.isEmpty ? null : _redo,
            tooltip: 'Redo',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveDrawing,
            tooltip: 'Save Drawing',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed:
                () => setState(() {
                  drawingPoints.clear();
                  historyDrawingPoints.clear();
                  undoStack.clear();
                  redoStack.clear();
                }),
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
                boundaryMargin: EdgeInsets.symmetric(
                  horizontal: max((screenSize.width - a4Width) / 2, 0),
                  vertical: max((screenSize.height - a4Height) / 2, 20),
                ),
                constrained: false,
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
                            final localPosition = details.localPosition;
                            if (!_isWithinCanvas(localPosition)) return;

                            try {
                              if (selectedMode == DrawingMode.pencil) {
                                currentDrawingPoint = DrawingPoint(
                                  id: DateTime.now().microsecondsSinceEpoch,
                                  offsets: [localPosition],
                                  color: selectedColor,
                                  width: selectedWidth,
                                );
                                drawingPoints.add(currentDrawingPoint!);
                              } else {
                                _eraseAtPoint(localPosition);
                                lastErasePosition = localPosition;
                              }
                              historyDrawingPoints.clear();
                              historyDrawingPoints.addAll(drawingPoints);
                              _throttledRedraw();
                              _hasUnsavedChanges = true;
                            } catch (e, stackTrace) {
                              debugPrint('Pan start error: $e\n$stackTrace');
                            }
                          },
                          onPanUpdate: (details) {
                            final localPosition = details.localPosition;
                            if (!_isWithinCanvas(localPosition)) return;

                            try {
                              if (selectedMode == DrawingMode.pencil &&
                                  currentDrawingPoint != null) {
                                currentDrawingPoint = currentDrawingPoint!
                                    .copyWith(
                                      offsets: List.from(
                                        currentDrawingPoint!.offsets,
                                      )..add(localPosition),
                                    );
                                drawingPoints.last = currentDrawingPoint!;
                              } else if (selectedMode == DrawingMode.eraser &&
                                  lastErasePosition != null) {
                                final distance =
                                    (localPosition - lastErasePosition!)
                                        .distance;
                                if (distance > eraserWidth) {
                                  for (var i = 0; i <= 1; i++) {
                                    final interpolatePoint =
                                        Offset.lerp(
                                          lastErasePosition!,
                                          localPosition,
                                          i / 1,
                                        )!;
                                    if (_isWithinCanvas(interpolatePoint))
                                      _eraseAtPoint(interpolatePoint);
                                  }
                                  lastErasePosition = localPosition;
                                }
                              }
                              historyDrawingPoints.clear();
                              historyDrawingPoints.addAll(drawingPoints);
                              _throttledRedraw();
                            } catch (e, stackTrace) {
                              debugPrint('Pan update error: $e\n$stackTrace');
                            }
                          },
                          onPanEnd: (_) {
                            try {
                              currentDrawingPoint = null;
                              lastErasePosition = null;
                              historyDrawingPoints.clear();
                              historyDrawingPoints.addAll(drawingPoints);
                              setState(() {});
                            } catch (e, stackTrace) {
                              debugPrint('Pan end error: $e\n$stackTrace');
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

  @override
  void dispose() {
    _controller.dispose();
    if (_hasUnsavedChanges) _saveDrawing();
    super.dispose();
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  const DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round;

    for (final point in drawingPoints) {
      if (point.offsets.isEmpty) continue;
      paint.color = point.color;
      paint.strokeWidth = point.width;

      for (var i = 0; i < point.offsets.length - 1; i++) {
        canvas.drawLine(point.offsets[i], point.offsets[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TemplatePainter extends CustomPainter {
  final PaperTemplate template;

  const TemplatePainter({required this.template});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    template.paintTemplate(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

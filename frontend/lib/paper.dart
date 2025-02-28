import 'package:flutter/material.dart';
import 'package:frontend/model/drawingpoint.dart';
import 'package:frontend/OBJ/object.dart';
import 'package:frontend/model/provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:frontend/widget/tool_bar.dart';
import 'package:frontend/OBJ/template_config.dart';
import 'package:frontend/model/tools.dart';

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

  // For eraser state management
  List<DrawingPoint> currentEraseStrokes = [];
  bool isErasing = false;

  late PaperTemplate selectedTemplate;

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
    selectedTemplate = TemplateConfig.getDefaultTemplate();

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
    if (undoStack.isEmpty) return;

    setState(() {
      // Save current state for redo
      redoStack.add(List<DrawingPoint>.from(drawingPoints));

      // Restore previous state
      final previousState = undoStack.removeLast();
      drawingPoints.clear();
      drawingPoints.addAll(previousState);

      historyDrawingPoints.clear();
      historyDrawingPoints.addAll(drawingPoints);
      _hasUnsavedChanges = true;
    });
  }

  void _redo() {
    if (redoStack.isEmpty) return;

    setState(() {
      // Save current state for undo
      undoStack.add(List<DrawingPoint>.from(drawingPoints));

      // Restore redone state
      final redoState = redoStack.removeLast();
      drawingPoints.clear();
      drawingPoints.addAll(redoState);

      historyDrawingPoints.clear();
      historyDrawingPoints.addAll(drawingPoints);
      _hasUnsavedChanges = true;
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

  void _startErasing(Offset position) {
    if (isErasing) return;

    // Save current state for undo
    undoStack.add(List<DrawingPoint>.from(drawingPoints));
    redoStack.clear();

    isErasing = true;
    currentEraseStrokes = [];
  }

  void _eraseIntersectingStrokes(Offset position) {
    if (!isErasing) {
      _startErasing(position);
    }

    // Find all strokes that intersect with the eraser
    final eraserRadius = eraserWidth / 2;
    final toRemove = <DrawingPoint>[];

    for (final point in drawingPoints) {
      // Skip eraser marks
      if (point.isEraser) continue;

      // Check if any point in this stroke intersects with our eraser
      for (final offset in point.offsets) {
        if ((offset - position).distance <= eraserRadius) {
          toRemove.add(point);
          currentEraseStrokes.add(point);
          break;
        }
      }
    }

    if (toRemove.isNotEmpty) {
      setState(() {
        drawingPoints.removeWhere((p) => toRemove.contains(p));

        // Add a transparent eraser point to show the path
        final eraserPoint = DrawingPoint(
          id: DateTime.now().microsecondsSinceEpoch,
          offsets: [position],
          color: Colors.transparent,
          width: eraserWidth,
          isEraser: true,
        );
        drawingPoints.add(eraserPoint);

        historyDrawingPoints.clear();
        historyDrawingPoints.addAll(drawingPoints);
        _hasUnsavedChanges = true;
      });
    }
  }

  bool _isErasingSession = false;
  bool _hasEraserChanges = false;

  void _eraseAtPoint(Offset point) {
    // Start a new eraser session if needed
    if (!_isErasingSession) {
      _isErasingSession = true;
      // Save current state for undo only at the beginning of an eraser session
      undoStack.add(List<DrawingPoint>.from(drawingPoints));
      redoStack.clear();
    }

    setState(() {
      // Simple point erasing - creates a single transparent point
      currentDrawingPoint = DrawingPoint(
        id: DateTime.now().microsecondsSinceEpoch,
        offsets: [point],
        color: Colors.transparent,
        width: eraserWidth,
        isEraser: true,
      );
      drawingPoints.add(currentDrawingPoint!);
      lastErasePosition = point;

      // Update the history
      historyDrawingPoints.clear();
      historyDrawingPoints.addAll(drawingPoints);
      _hasUnsavedChanges = true;
      _hasEraserChanges = true;
    });
  }

  // Modify onPanEnd to end the eraser session
  void _endEraserSession() {
    if (_isErasingSession && _hasEraserChanges) {
      _isErasingSession = false;
      _hasEraserChanges = false;
      _updateStrokeHistory();
    }
  }

  void _finishErasing() {
    if (!isErasing) return;

    isErasing = false;
    currentEraseStrokes = [];
    _updateStrokeHistory();
  }

  void _handleErasing(Offset position) {
    if (!_isWithinCanvas(position)) return;

    if (eraserMode == EraserMode.point) {
      _eraseAtPoint(position);
    } else if (eraserMode == EraserMode.stroke) {
      _eraseIntersectingStrokes(position);
    }
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
            onPressed: undoStack.isEmpty ? null : _undo,
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
          if (selectedMode == DrawingMode.pencil)
            buildPencilSettingsBar(
              selectedWidth: selectedWidth,
              selectedColor: selectedColor,
              availableColors: availableColors,
              onWidthChanged: (value) => setState(() => selectedWidth = value),
              onColorChanged: (color) => setState(() => selectedColor = color),
            ),
          if (selectedMode == DrawingMode.eraser)
            buildEraserSettingsBar(
              eraserWidth: eraserWidth,
              eraserMode: eraserMode,
              onWidthChanged: (value) => setState(() => eraserWidth = value),
              onModeChanged: (mode) => setState(() => eraserMode = mode),
            ),
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
                                // For drawing, save current state for undo
                                undoStack.add(
                                  List<DrawingPoint>.from(drawingPoints),
                                );
                                redoStack.clear();

                                setState(() {
                                  currentDrawingPoint = DrawingPoint(
                                    id: DateTime.now().microsecondsSinceEpoch,
                                    offsets: [localPosition],
                                    color: selectedColor,
                                    width: selectedWidth,
                                    isEraser: false,
                                  );
                                  drawingPoints.add(currentDrawingPoint!);
                                  historyDrawingPoints.clear();
                                  historyDrawingPoints.addAll(drawingPoints);
                                  _hasUnsavedChanges = true;
                                });
                              } else if (selectedMode == DrawingMode.eraser) {
                                _handleErasing(localPosition);
                              }
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
                                setState(() {
                                  currentDrawingPoint = currentDrawingPoint!
                                      .copyWith(
                                        offsets: List.from(
                                          currentDrawingPoint!.offsets,
                                        )..add(localPosition),
                                      );
                                  drawingPoints.last = currentDrawingPoint!;
                                  historyDrawingPoints.clear();
                                  historyDrawingPoints.addAll(drawingPoints);
                                  _hasUnsavedChanges = true;
                                });
                              } else if (selectedMode == DrawingMode.eraser) {
                                _handleErasing(localPosition);
                              }
                            } catch (e, stackTrace) {
                              debugPrint('Pan update error: $e\n$stackTrace');
                            }
                          },

                          onPanEnd: (_) {
                            try {
                              currentDrawingPoint = null;

                              if (selectedMode == DrawingMode.eraser) {
                                _finishErasing();
                                _endEraserSession(); // Add this line
                              }
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

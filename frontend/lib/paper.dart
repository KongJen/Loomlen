import 'package:flutter/material.dart';
import 'package:frontend/model/drawingpoint.dart';
import 'package:frontend/OBJ/object.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as ml_kit;
import 'package:frontend/OBJ/provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';

enum DrawingMode {
  pencil,
  eraser,
}

enum EraserMode {
  point,
  stroke,
}

class Paper extends StatefulWidget {
  final String name;
  final String? fileId;

  const Paper({
    Key? key,
    required this.name,
    this.fileId,
  }) : super(key: key);

  @override
  State<Paper> createState() => _PaperState();
}

class _PaperState extends State<Paper> {
  List<DrawingPoint> drawingPoints = [];
  List<DrawingPoint> historyDrawingPoints = [];
  DrawingPoint? currentDrawingPoint;

  List<Map<String, dynamic>> strokeHistory = [];

  List<List<DrawingPoint>> undoStack = [];
  List<List<DrawingPoint>> redoStack = [];

  Color selectedColor = Colors.black;
  double selectedWidth = 2.0;
  DrawingMode selectedMode = DrawingMode.pencil;

  double eraserWidth = 10.0;
  EraserMode eraserMode = EraserMode.point;
  Offset? lastErasePosition;
  DateTime _lastUpdate = DateTime.now(); // For throttling
  static const int _updateIntervalMs = 120;

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

  // Digital Ink Recognition related variables
  final ml_kit.DigitalInkRecognizer _digitalInkRecognizer =
      ml_kit.DigitalInkRecognizer(languageCode: 'th');
  final ml_kit.DigitalInkRecognizerModelManager _modelManager =
      ml_kit.DigitalInkRecognizerModelManager();
  final ml_kit.Ink _ink = ml_kit.Ink();
  List<ml_kit.StrokePoint> _strokePoints = [];
  String recognizedText = '';
  bool _modelDownloaded = false;
  var _language = 'th';

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
    _downloadModel();

    if (widget.fileId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTemplateFromFile();
        _loadDrawingFromFile();
      });
    }
  }

  void _loadDrawingFromFile() {
    final fileProvider = Provider.of<FileProvider>(context, listen: false);
    final fileData = fileProvider.getFileById(widget.fileId!);

    if (fileData != null && fileData['drawingData'] != null) {
      try {
        final List<dynamic> loadedStrokes = fileData['drawingData'];
        print("Loading ${loadedStrokes.length} strokes from file");

        setState(() {
          drawingPoints = [];
          strokeHistory = List<Map<String, dynamic>>.from(loadedStrokes);

          int pointsCount = 0;
          // Reconstruct drawingPoints from saved data
          for (var stroke in strokeHistory) {
            if (stroke['type'] == 'drawing') {
              try {
                final Map<String, dynamic> data = stroke['data'];

                final DrawingPoint point = DrawingPoint.fromJson(data);

                if (point.offsets.isNotEmpty) {
                  drawingPoints.add(point);
                  pointsCount += point.offsets.length;
                } else {
                  print("Warning: Skipping stroke with no offsets");
                }
              } catch (e) {
                print("Error processing stroke: $e");
              }
            }
          }

          historyDrawingPoints = List.from(drawingPoints);
        });
      } catch (e, stackTrace) {
        print('Error loading drawing data: $e');
        print(stackTrace);
      }
    }
  }

  Future<void> saveDrawing() async {
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    List<Map<String, dynamic>> cleanHistory = [];

    //save the current drawing points as drawing actions
    for (var point in drawingPoints) {
      cleanHistory.add({
        'type': 'drawing',
        'data': point.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    if (widget.fileId != null) {
      await fileProvider.updateFileDrawingData(
        widget.fileId!,
        cleanHistory,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drawing saved successfully')),
      );
    } else {
      // For new files
      final String fileId = fileProvider.addFile(
        widget.name,
        drawingPoints.length,
        selectedTemplate,
        cleanHistory,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New drawing saved successfully')),
        );
      }
    }
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

  void undo() {
    if (drawingPoints.isEmpty) return;

    setState(() {
      if (drawingPoints.isNotEmpty) {
        // Save last stroke to redo stack
        DrawingPoint lastPoint = drawingPoints.removeLast();
        redoStack
            .add([lastPoint]); // Add as a list to maintain format consistency

        // Update the stroke history to match current drawing points
        _updateStrokeHistoryFromDrawingPoints();
      }
    });
  }

  void redo() {
    if (redoStack.isEmpty) return;

    setState(() {
      // Get the last undone stroke
      List<DrawingPoint> redoPoints = redoStack.removeLast();

      // Add it back to drawing points
      drawingPoints.addAll(redoPoints);

      // Update the stroke history to match current drawing points
      _updateStrokeHistoryFromDrawingPoints();
    });
  }

  void _updateStrokeHistoryFromDrawingPoints() {
    // Convert current drawing points to a cleaned-up history
    List<Map<String, dynamic>> cleanHistory = [];

    //save the current drawing points as drawing actions
    for (var point in drawingPoints) {
      cleanHistory.add({
        'type': 'drawing',
        'data': point.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    strokeHistory = cleanHistory;
  }

  Future<void> _downloadModel() async {
    try {
      final bool response = await _modelManager.downloadModel(_language);
      setState(() {
        _modelDownloaded = response;
      });
      if (response) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model downloaded successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading model: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _digitalInkRecognizer.close();
    drawingPoints.clear();
    historyDrawingPoints.clear();
    _ink.strokes.clear();
    _strokePoints.clear();
    super.dispose();
  }

  Future<void> _recognizeText() async {
    if (!_modelDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the model to download'),
        ),
      );
      return;
    }

    if (_ink.strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something first'),
        ),
      );
      return;
    }

    try {
      setState(() {
        recognizedText = 'Recognizing...';
      });

      final List<ml_kit.RecognitionCandidate> candidates =
          await _digitalInkRecognizer.recognize(_ink);

      if (candidates.isNotEmpty) {
        setState(() {
          recognizedText = candidates.first.text;
          print('Recognized text: $recognizedText'); // For debugging
        });
      } else {
        setState(() {
          recognizedText = 'No text recognized';
        });
      }
    } catch (e) {
      setState(() {
        recognizedText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recognizing text: $e')),
        );
      }
    }
  }

  void _addNewStroke(Offset point, int timestamp) {
    // Convert drawing point to StrokePoint for ML Kit
    final ml_kit.StrokePoint strokePoint = ml_kit.StrokePoint(
      x: point.dx,
      y: point.dy,
      t: timestamp,
    );
    _strokePoints.add(strokePoint);
  }

  void _finishStroke() {
    if (_strokePoints.isNotEmpty) {
      final stroke = ml_kit.Stroke()..points = _strokePoints;
      _ink.strokes.add(stroke);
      _strokePoints = [];
    }
  }

  // Eraser point
  void _eraseAtPoint(Offset point) {
    if (drawingPoints.isEmpty) return;

    try {
      List<int> removedStrokeIds = [];

      if (eraserMode == EraserMode.stroke) {
        // Collect IDs of strokes to be removed
        drawingPoints.where((drawingPoint) {
          for (int i = 0; i < drawingPoint.offsets.length - 1; i++) {
            if (_isPointNearSegment(point, drawingPoint.offsets[i],
                drawingPoint.offsets[i + 1], eraserWidth)) {
              removedStrokeIds.add(drawingPoint.id);
              return true;
            }
          }
          return drawingPoint.offsets
              .any((offset) => (offset - point).distance <= eraserWidth);
        }).forEach((point) => removedStrokeIds.add(point.id));

        // Remove from drawingPoints
        drawingPoints.removeWhere((dp) => removedStrokeIds.contains(dp.id));

        // Remove corresponding entries from strokeHistory
        strokeHistory.removeWhere((stroke) =>
            stroke['type'] == 'drawing' &&
            removedStrokeIds.contains(stroke['data']['id']));
      } else if (eraserMode == EraserMode.point) {
        // Track which strokes are modified or removed
        List<DrawingPoint> newPoints = [];
        Map<int, Map<String, dynamic>> updatedStrokes = {};

        for (var drawingPoint in drawingPoints) {
          List<Offset> currentSegment = [];
          bool modified = false;

          for (int i = 0; i < drawingPoint.offsets.length; i++) {
            Offset currentOffset = drawingPoint.offsets[i];
            bool eraseCurrent = (currentOffset - point).distance <= eraserWidth;

            // Check segment to previous point (if exists)
            if (i > 0 && !eraseCurrent) {
              Offset prevOffset = drawingPoint.offsets[i - 1];
              if (_isPointNearSegment(
                  point, prevOffset, currentOffset, eraserWidth)) {
                eraseCurrent = true;
              }
            }

            if (!eraseCurrent) {
              currentSegment.add(currentOffset);
            } else {
              if (currentSegment.isNotEmpty) {
                var newPoint =
                    drawingPoint.copyWith(offsets: List.from(currentSegment));
                newPoints.add(newPoint);
                updatedStrokes[newPoint.id] = newPoint.toJson();
                currentSegment.clear();
              }
              modified = true;
            }
          }

          if (currentSegment.isNotEmpty) {
            var newPoint =
                drawingPoint.copyWith(offsets: List.from(currentSegment));
            newPoints.add(newPoint);
            updatedStrokes[newPoint.id] = newPoint.toJson();
          } else if (!modified) {
            newPoints.add(drawingPoint);
          } else {
            // If fully erased, track ID to remove from history
            removedStrokeIds.add(drawingPoint.id);
          }
        }

        // Update strokeHistory to match the new state
        // Remove fully erased strokes
        strokeHistory.removeWhere((stroke) =>
            stroke['type'] == 'drawing' &&
            removedStrokeIds.contains(stroke['data']['id']));

        // Update modified strokes
        for (int i = 0; i < strokeHistory.length; i++) {
          if (strokeHistory[i]['type'] == 'drawing') {
            int strokeId = strokeHistory[i]['data']['id'];
            if (updatedStrokes.containsKey(strokeId)) {
              strokeHistory[i]['data'] = updatedStrokes[strokeId];
            }
          }
        }

        drawingPoints.clear();
        drawingPoints.addAll(newPoints);
      }

      // Add the eraser action to strokeHistory
      strokeHistory.add({
        'type': 'eraser',
        'position': {'x': point.dx, 'y': point.dy},
        'width': eraserWidth,
        'mode': eraserMode.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      historyDrawingPoints = List.from(drawingPoints);
    } catch (e, stackTrace) {
      print('Erase error: $e\n$stackTrace');
    }
  }

  bool _isPointNearSegment(
      Offset point, Offset start, Offset end, double threshold) {
    final double segmentLength = (end - start).distance;
    if (segmentLength == 0) return (point - start).distance <= threshold;

    double t = ((point.dx - start.dx) * (end.dx - start.dx) +
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
            children: availableColors.map((color) {
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
                      color: selectedColor == color
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
                constraints: const BoxConstraints(
                  minHeight: 36,
                  minWidth: 80,
                ),
                isSelected: [
                  eraserMode == EraserMode.stroke,
                  eraserMode == EraserMode.point,
                ],
                children: const [
                  Text('Stroke'),
                  Text('Point'),
                ],
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

  @override
  Widget build(BuildContext context) {
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
            onPressed: () {
              setState(() {
                selectedMode = DrawingMode.pencil;
              });
            },
            tooltip: 'Pencil',
          ),
          IconButton(
            icon: Icon(
              Icons.delete,
              color: selectedMode == DrawingMode.eraser ? Colors.blue : null,
            ),
            onPressed: () {
              setState(() {
                selectedMode = DrawingMode.eraser;
              });
            },
            tooltip: 'Eraser',
          ),
          if (!_modelDownloaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: CircularProgressIndicator(),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _modelDownloaded ? _recognizeText : null,
            tooltip: _modelDownloaded ? 'Recognize Text' : 'Loading model...',
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: drawingPoints.isEmpty ? null : undo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: redoStack.isEmpty ? null : redo,
            tooltip: 'Redo',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: saveDrawing,
            tooltip: 'Save Drawing',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                drawingPoints.clear();
                historyDrawingPoints.clear();
                _ink.strokes.clear();
                _strokePoints.clear();
                recognizedText = '';
                undoStack.clear();
        redoStack.clear();
              });
            },
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        children: [
          // Show pencil settings bar only in pencil mode
          if (selectedMode == DrawingMode.pencil) _buildPencilSettingsBar(),
          if (selectedMode == DrawingMode.eraser) _buildEraserSettingsBar(),
          Expanded(
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
                    child: GestureDetector(
                      onPanStart: (details) {
                        try {
                          if (selectedMode == DrawingMode.pencil) {
                            // Clear redo stack when starting a new drawing action
                            redoStack.clear();

                            // Create the current drawing point
                            currentDrawingPoint = DrawingPoint(
                              id: DateTime.now().microsecondsSinceEpoch,
                              offsets: [details.localPosition],
                              color: selectedColor,
                              width: selectedWidth,
                            );

                            // Add to drawing points
                            drawingPoints.add(currentDrawingPoint!);

                            // Add to stroke history
                            strokeHistory.add({
                              'type': 'drawing',
                              'data': currentDrawingPoint!.toJson(),
                              'timestamp':
                                  DateTime.now().millisecondsSinceEpoch,
                            });

                            _addNewStroke(
                              details.localPosition,
                              DateTime.now().millisecondsSinceEpoch,
                            );
                          } else if (selectedMode == DrawingMode.eraser) {
                            // Store eraser action in history
                            final eraserAction = {
                              'type': 'eraser',
                              'position': {
                                'x': details.localPosition.dx,
                                'y': details.localPosition.dy
                              },
                              'width': eraserWidth,
                              'mode': eraserMode.toString(),
                              'timestamp':
                                  DateTime.now().millisecondsSinceEpoch,
                            };
                            strokeHistory.add(eraserAction);

                            // Save current state before erasing for undo
                            undoStack.add(List.from(drawingPoints));

                            _eraseAtPoint(details.localPosition);
                            lastErasePosition = details.localPosition;
                          }
                          historyDrawingPoints = List.from(drawingPoints);
                          _throttledRedraw();
                        } catch (e, stackTrace) {
                          print('Pan start error: $e\n$stackTrace');
                        }
                      },
                      onPanUpdate: (details) {
                        try {
                          if (selectedMode == DrawingMode.pencil) {
                            if (currentDrawingPoint != null) {
                              // Update the current drawing point with the new offset
                              currentDrawingPoint =
                                  currentDrawingPoint!.copyWith(
                                offsets: currentDrawingPoint!.offsets
                                  ..add(details.localPosition),
                              );
                              drawingPoints.last = currentDrawingPoint!;

                              // Important: Update the stroke in the history with all updated offsets
                              if (strokeHistory.isNotEmpty &&
                                  strokeHistory.last['type'] == 'drawing' &&
                                  strokeHistory.last['data']['id'] ==
                                      currentDrawingPoint!.id) {
                                // Update the existing stroke's data
                                strokeHistory.last['data'] =
                                    currentDrawingPoint!.toJson();
                              }

                              _addNewStroke(
                                details.localPosition,
                                DateTime.now().millisecondsSinceEpoch,
                              );
                            }
                          } else if (selectedMode == DrawingMode.eraser) {
                            // Your existing eraser code...
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
                            // Only add to undo stack if we've made a complete stroke
                            if (currentDrawingPoint != null) {
                              // Instead of adding historyDrawingPoints, we're keeping track of individual strokes
                              undoStack.add([currentDrawingPoint!]);
                              currentDrawingPoint = null;
                              _finishStroke();
                            }
                          } else if (selectedMode == DrawingMode.eraser) {
                            // For eraser, we need to track what was erased
                            // This is more complex, but we'll simplify for now
                            lastErasePosition = null;
                          }
                          setState(() {}); // Final update on pan end
                        } catch (e, stackTrace) {
                          print('Pan end error: $e\n$stackTrace');
                        }
                      },
                      // Paper Size
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
                            painter: DrawingPainter(
                              drawingPoints: drawingPoints,
                              template: selectedTemplate,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Display recognized text
          if (recognizedText.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.grey.shade200,
              child: Text(
                'Recognized Text: $recognizedText',
                style: const TextStyle(fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;
  final PaperTemplate template;

  DrawingPainter({required this.drawingPoints, required this.template});

  @override
  void paint(Canvas canvas, Size size) {
    template.paintTemplate(canvas, size);

    final paint = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;

    for (var drawingPoint in drawingPoints) {
      if (drawingPoint.offsets.isEmpty) continue;

      paint.color = drawingPoint.color;
      paint.strokeWidth = drawingPoint.width;

      for (int i = 0; i < drawingPoint.offsets.length - 1; i++) {
        canvas.drawLine(
            drawingPoint.offsets[i], drawingPoint.offsets[i + 1], paint);
      }

      if (drawingPoint.offsets.length == 1) {
        canvas.drawCircle(
            drawingPoint.offsets[0], drawingPoint.width / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

class TemplateThumbnailPainter extends CustomPainter {
  final PaperTemplate template;

  TemplateThumbnailPainter({required this.template});

  @override
  void paint(Canvas canvas, Size size) {
    template.paintTemplate(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

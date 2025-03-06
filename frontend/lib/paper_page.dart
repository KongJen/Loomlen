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

class PaperPage extends StatefulWidget {
  final String name;
  final String? fileId;
  final List<String>? initialPageIds;
  final Function? onFileUpdated;

  const PaperPage({
    super.key,
    required this.name,
    this.fileId,
    this.initialPageIds,
    this.onFileUpdated,
  });

  @override
  State<PaperPage> createState() => _PaperPageState();
}

class _PaperPageState extends State<PaperPage> {
  // Drawing and interaction variables
  final List<DrawingPoint> drawingPoints = [];
  final List<DrawingPoint> historyDrawingPoints = [];
  DrawingPoint? currentDrawingPoint;

  bool _hasUnsavedChanges = false;
  final List<Map<String, dynamic>> strokeHistory = [];
  Map<String, List<DrawingPoint>> pageDrawingPoints = {};
  List<Map<String, List<DrawingPoint>>> undoStack = [];
  List<Map<String, List<DrawingPoint>>> redoStack = [];

  // Drawing settings
  Color selectedColor = Colors.black;
  double selectedWidth = 2.0;
  DrawingMode selectedMode = DrawingMode.pencil;

  // Page and drawing tools
  late EraserTool eraserTool;
  List<String> pageIds = [];

  // Canvas dimensions
  static const double a4Width = 210 * 2.83465;
  static const double a4Height = 297 * 2.83465;

  // Controllers
  late final TransformationController _controller;
  final ScrollController _scrollController = ScrollController();

  // Color palette
  final List<Color> availableColors = const [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
  ];

  // Add a map to store templates for each paper
  Map<String, PaperTemplate> paperTemplates = {};

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();

    pageIds = widget.initialPageIds ?? [];

    // Initialize EraserTool (we'll pass the paperId dynamically later)
    eraserTool = EraserTool(
      eraserWidth: 10.0,
      eraserMode: EraserMode.point,
      pageDrawingPoints: pageDrawingPoints,
      undoStack: undoStack,
      redoStack: redoStack,
      onStateChanged: () {
        setState(() {
          historyDrawingPoints.clear();
          historyDrawingPoints.addAll(
            pageDrawingPoints.values.expand((points) => points),
          );
          _hasUnsavedChanges = true;
        });
        _updateStrokeHistory();
      },
      currentPaperId: '', // We'll set this dynamically in ListView.builder
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCanvas();
      if (widget.fileId != null) {
        _loadDrawingFromPaper();
      }

      if (pageIds.isEmpty && widget.fileId != null) {
        _addNewPaperPage();
      }
    });
  }

  // Load templates for all papers
  void _loadTemplatesForPapers(List<Map<String, dynamic>> papers) {
    final Map<String, PaperTemplate> tempTemplates = {};

    for (final paper in papers) {
      final String paperId = paper['id'];
      final String templateId = paper['templateId'] ?? 'plain';
      final String typeString = paper['templateType']?.toString() ?? 'plain';
      final TemplateType templateType = switch (typeString) {
        String s when s.contains('lined') => TemplateType.lined,
        String s when s.contains('grid') => TemplateType.grid,
        String s when s.contains('dotted') => TemplateType.dotted,
        _ => TemplateType.plain,
      };

      tempTemplates[paperId] = PaperTemplate(
        id: templateId,
        name: '${templateType.name.capitalize()} Paper',
        templateType: templateType,
        spacing: paper['spacing']?.toDouble() ?? 30.0,
      );
    }

    // If pageIds exist but no papers are found, use default templates
    for (final pageId in pageIds) {
      if (!tempTemplates.containsKey(pageId)) {
        tempTemplates[pageId] = PaperTemplate(
          id: 'plain',
          name: 'Plain Paper',
          templateType: TemplateType.plain,
          spacing: 30.0,
        );
      }
    }

    debugPrint('Loaded paperTemplates: $tempTemplates');

    setState(() {
      paperTemplates = tempTemplates;
    });
  }

  // Updated _addNewPaperPage to ensure templates are set correctly
  void _addNewPaperPage() {
    final fileProvider = context.read<FileProvider>();
    final paperProvider = context.read<PaperProvider>();

    // Determine the template to use for the new page
    PaperTemplate newPageTemplate;
    int newPageNumber = 1;

    if (pageIds.isNotEmpty) {
      final lastPaperId = pageIds.last;
      final lastPaperData = paperProvider.getPaperById(lastPaperId);
      newPageNumber = (lastPaperData?['PageNumber'] ?? 0) + 1;

      if (paperTemplates.containsKey(lastPaperId)) {
        newPageTemplate = paperTemplates[lastPaperId]!;
      } else {
        newPageTemplate = PaperTemplate(
          id: 'plain',
          name: 'Plain Paper',
          templateType: TemplateType.plain,
          spacing: 30.0,
        );
      }
    } else {
      newPageTemplate = PaperTemplate(
        id: 'plain',
        name: 'Plain Paper',
        templateType: TemplateType.plain,
        spacing: 30.0,
      );
    }

    // Add the new paper using the paper provider
    final String newPaperId = paperProvider.addPaper(
      newPageTemplate,
      newPageNumber,
    );

    // Add the new paper page to the file
    if (widget.fileId != null) {
      fileProvider.addPaperPageToFile(widget.fileId!, newPaperId);
    }

    // Update the pageIds and paperTemplates
    setState(() {
      paperTemplates[newPaperId] = newPageTemplate;
    });

    // Scroll to the bottom after adding a new page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _loadDrawingFromPaper() {
    final paperProvider = context.read<PaperProvider>();

    pageDrawingPoints.clear();
    strokeHistory.clear();
    undoStack.clear();
    redoStack.clear();

    for (final pageId in pageIds) {
      final paperData = paperProvider.getPaperById(pageId);
      final List<DrawingPoint> pointsForPage = [];
      if (paperData?['drawingData'] != null) {
        try {
          final List<dynamic> loadedStrokes = paperData!['drawingData'];
          final List<Map<String, dynamic>> pageStrokeHistory = [];

          for (final stroke in loadedStrokes) {
            if (stroke['type'] == 'drawing') {
              final point = DrawingPoint.fromJson(stroke['data']);
              if (point.offsets.isNotEmpty) {
                pointsForPage.add(point);
                pageStrokeHistory.add(stroke);
              }
            }
          }

          strokeHistory.addAll(pageStrokeHistory);
        } catch (e, stackTrace) {
          debugPrint(
            'Error loading drawing data for page $pageId: $e\n$stackTrace',
          );
        }
      }
      pageDrawingPoints[pageId] = pointsForPage;
    }

    setState(() {
      historyDrawingPoints.clear();
      historyDrawingPoints.addAll(
        pageDrawingPoints.values.expand((points) => points),
      );
    });
  }

  Future<void> _saveDrawing() async {
    final paperProvider = context.read<PaperProvider>();

    for (final pageId in pageIds) {
      final pointsForPage = pageDrawingPoints[pageId] ?? [];
      final cleanHistory =
          pointsForPage
              .map(
                (point) => {
                  'type': 'drawing',
                  'data': point.toJson(),
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                },
              )
              .toList();

      await paperProvider.updatePaperDrawingData(pageId, cleanHistory);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drawing saved successfully')),
      );
    }
    _hasUnsavedChanges = false;
  }

  // Center canvas
  void _centerCanvas() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final initialX = (screenWidth - a4Width) / 2;
    const initialY = 20.0;
    _controller.value = Matrix4.identity()..translate(initialX, initialY);
  }

  void _undo() {
    if (undoStack.isEmpty) return;

    setState(() {
      redoStack.add(
        pageDrawingPoints.map(
          (key, value) => MapEntry(key, List<DrawingPoint>.from(value)),
        ),
      );
      final previousState = undoStack.removeLast();
      pageDrawingPoints.clear();
      pageDrawingPoints.addAll(previousState);
      historyDrawingPoints.clear();
      historyDrawingPoints.addAll(
        pageDrawingPoints.values.expand((points) => points),
      );
      _hasUnsavedChanges = true;
    });
  }

  void _redo() {
    if (redoStack.isEmpty) return;

    setState(() {
      undoStack.add(
        pageDrawingPoints.map(
          (key, value) => MapEntry(key, List<DrawingPoint>.from(value)),
        ),
      );
      final redoState = redoStack.removeLast();
      pageDrawingPoints.clear();
      pageDrawingPoints.addAll(redoState);
      historyDrawingPoints.clear();
      historyDrawingPoints.addAll(
        pageDrawingPoints.values.expand((points) => points),
      );
      _hasUnsavedChanges = true;
    });
  }

  // Update stroke history
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

  // Check if point is within canvas
  bool _isWithinCanvas(Offset point) =>
      point.dx >= 0 &&
      point.dy >= 0 &&
      point.dx <= a4Width &&
      point.dy <= a4Height;

  @override
  Widget build(BuildContext context) {
    final fileProvider = Provider.of<FileProvider>(context);
    final paperProvider = Provider.of<PaperProvider>(context);

    final fileId = widget.fileId;
    final file = fileProvider.files.firstWhere(
      (file) => file['id'] == fileId,
      orElse: () => <String, dynamic>{},
    );

    final List<String> currentPaperIds =
        (file['pageIds'] as List<dynamic>?)?.cast<String>() ?? [];
    final papers =
        paperProvider.papers
            .where((paper) => currentPaperIds.contains(paper['id']))
            .toList();

    debugPrint('Current papers: $papers');
    debugPrint('Current paperIds from file: $currentPaperIds');

    // Sync pageIds with currentPaperIds and load templates
    if (currentPaperIds.isNotEmpty && pageIds.isEmpty) {
      setState(() {
        pageIds = currentPaperIds;
      });
    }

    // Load templates after papers are computed
    _loadTemplatesForPapers(papers);

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
            icon: const Icon(Icons.add),
            onPressed: _addNewPaperPage,
            tooltip: 'Add New Page',
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
              eraserWidth: eraserTool.eraserWidth,
              eraserMode: eraserTool.eraserMode,
              onWidthChanged:
                  (value) => setState(() => eraserTool.eraserWidth = value),
              onModeChanged:
                  (mode) => setState(() => eraserTool.eraserMode = mode),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenSize = MediaQuery.of(context).size;
                return InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1.0,
                  maxScale: 2.0,
                  boundaryMargin: EdgeInsets.symmetric(
                    horizontal: max((screenSize.width - a4Width) / 2, 0),
                    vertical: max((screenSize.height - a4Height) / 2, 20),
                  ),
                  constrained: false,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      children:
                          currentPaperIds.map((paperId) {
                            final template =
                                paperTemplates[paperId] ??
                                PaperTemplate(
                                  id: 'plain',
                                  name: 'Plain Paper',
                                  templateType: TemplateType.plain,
                                );

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
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
                                        painter: TemplatePainter(
                                          template: template,
                                        ),
                                        size: Size(a4Width, a4Height),
                                      ),
                                      GestureDetector(
                                        onPanStart: (details) {
                                          final localPosition =
                                              details.localPosition;
                                          if (!_isWithinCanvas(localPosition)) {
                                            return;
                                          }

                                          try {
                                            if (selectedMode ==
                                                DrawingMode.pencil) {
                                              undoStack.add(
                                                pageDrawingPoints.map(
                                                  (key, value) => MapEntry(
                                                    key,
                                                    List<DrawingPoint>.from(
                                                      value,
                                                    ),
                                                  ),
                                                ),
                                              );
                                              redoStack.clear();

                                              setState(() {
                                                currentDrawingPoint = DrawingPoint(
                                                  id:
                                                      DateTime.now()
                                                          .microsecondsSinceEpoch,
                                                  offsets: [localPosition],
                                                  color: selectedColor,
                                                  width: selectedWidth,
                                                  isEraser: false,
                                                );
                                                pageDrawingPoints[paperId] ??=
                                                    [];
                                                pageDrawingPoints[paperId]!.add(
                                                  currentDrawingPoint!,
                                                );
                                                historyDrawingPoints.clear();
                                                historyDrawingPoints.addAll(
                                                  pageDrawingPoints.values
                                                      .expand(
                                                        (points) => points,
                                                      ),
                                                );
                                                _hasUnsavedChanges = true;
                                              });
                                            } else if (selectedMode ==
                                                DrawingMode.eraser) {
                                              // Update eraserTool with the current paperId
                                              eraserTool = EraserTool(
                                                eraserWidth:
                                                    eraserTool.eraserWidth,
                                                eraserMode:
                                                    eraserTool.eraserMode,
                                                pageDrawingPoints:
                                                    pageDrawingPoints,
                                                undoStack: undoStack,
                                                redoStack: redoStack,
                                                onStateChanged:
                                                    eraserTool.onStateChanged,
                                                currentPaperId: paperId,
                                              );
                                              eraserTool.handleErasing(
                                                localPosition,
                                                _isWithinCanvas(localPosition),
                                              );
                                            }
                                          } catch (e, stackTrace) {
                                            debugPrint(
                                              'Pan start error: $e\n$stackTrace',
                                            );
                                          }
                                        },
                                        onPanUpdate: (details) {
                                          final localPosition =
                                              details.localPosition;
                                          if (!_isWithinCanvas(localPosition)) {
                                            return;
                                          }

                                          try {
                                            if (selectedMode ==
                                                    DrawingMode.pencil &&
                                                currentDrawingPoint != null) {
                                              setState(() {
                                                currentDrawingPoint =
                                                    currentDrawingPoint!
                                                        .copyWith(
                                                          offsets: List.from(
                                                            currentDrawingPoint!
                                                                .offsets,
                                                          )..add(localPosition),
                                                        );
                                                pageDrawingPoints[paperId]!
                                                        .last =
                                                    currentDrawingPoint!;
                                                historyDrawingPoints.clear();
                                                historyDrawingPoints.addAll(
                                                  pageDrawingPoints.values
                                                      .expand(
                                                        (points) => points,
                                                      ),
                                                );
                                                _hasUnsavedChanges = true;
                                              });
                                            } else if (selectedMode ==
                                                DrawingMode.eraser) {
                                              eraserTool.handleErasing(
                                                localPosition,
                                                _isWithinCanvas(localPosition),
                                              );
                                            }
                                          } catch (e, stackTrace) {
                                            debugPrint(
                                              'Pan update error: $e\n$stackTrace',
                                            );
                                          }
                                        },
                                        onPanEnd: (_) {
                                          try {
                                            currentDrawingPoint = null;
                                            if (selectedMode ==
                                                DrawingMode.eraser) {
                                              eraserTool.finishErasing();
                                            }
                                          } catch (e, stackTrace) {
                                            debugPrint(
                                              'Pan end error: $e\n$stackTrace',
                                            );
                                          }
                                        },
                                        child: CustomPaint(
                                          painter: DrawingPainter(
                                            drawingPoints:
                                                pageDrawingPoints[paperId] ??
                                                [],
                                          ),
                                          size: Size(a4Width, a4Height),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                );
              },
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

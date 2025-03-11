// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/model/drawingpoint.dart';
import 'package:frontend/OBJ/object.dart';
import 'package:frontend/model/provider.dart';
import 'package:frontend/widget/overlay_loading.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:frontend/widget/tool_bar.dart';
import 'package:frontend/OBJ/template_config.dart';
import 'package:frontend/model/tools.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/widget/export_dialog.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'dart:typed_data';
import 'dart:math' as math;

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
  final List<DrawingPoint> drawingPoints = [];
  final List<DrawingPoint> historyDrawingPoints = [];
  DrawingPoint? currentDrawingPoint;
  bool _hasUnsavedChanges = false;
  final List<Map<String, dynamic>> strokeHistory = [];
  Map<String, List<DrawingPoint>> pageDrawingPoints = {};
  List<Map<String, List<DrawingPoint>>> undoStack = [];
  List<Map<String, List<DrawingPoint>>> redoStack = [];
  Color selectedColor = Colors.black;
  double selectedWidth = 2.0;
  DrawingMode selectedMode = DrawingMode.pencil;
  late EraserTool eraserTool;
  List<String> pageIds = [];
  final TransformationController _controller = TransformationController();
  final ScrollController _scrollController = ScrollController();
  final List<Color> availableColors = const [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
  ];
  Map<String, PaperTemplate> paperTemplates = {};
  bool _isDrawing = false;

  final ScreenshotController _screenshotcontroller = ScreenshotController();

  @override
  void initState() {
    super.initState();
    pageIds = widget.initialPageIds ?? [];
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
      currentPaperId: '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.fileId != null) {
        _loadDrawingFromPaper();
      }
      if (pageIds.isEmpty && widget.fileId != null) {
        _addNewPaperPage();
      }
    });
    _centerContent();
  }

  void _centerContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || pageIds.isEmpty) return;

      final fileProvider = Provider.of<FileProvider>(context, listen: false);
      final paperProvider = Provider.of<PaperProvider>(context, listen: false);
      final file = fileProvider.files.firstWhere(
        (file) => file['id'] == widget.fileId,
        orElse: () => <String, dynamic>{},
      );
      final currentPaperIds =
          (file['pageIds'] as List<dynamic>?)?.cast<String>() ?? [];
      if (currentPaperIds.isEmpty) return;

      final firstPaper = paperProvider.getPaperById(currentPaperIds.first);
      final double paperWidth = firstPaper?['width'] as double? ?? 595.0;
      final double paperHeight = firstPaper?['height'] as double? ?? 842.0;

      final double totalHeight = currentPaperIds.length * (paperHeight + 16.0);
      final screenSize = MediaQuery.of(context).size;
      final double screenWidth = screenSize.width;
      final double screenHeight = screenSize.height;

      final double xOffset = (screenWidth - paperWidth) / 2;
      final double yOffset =
          (screenHeight - totalHeight) / 2 > 0
              ? (screenHeight - totalHeight) / 2
              : 0;

      _controller.value = Matrix4.identity()..translate(xOffset, yOffset);
    });
  }

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
    setState(() {
      paperTemplates = tempTemplates;
    });
  }

  void _addNewPaperPage() {
    final fileProvider = context.read<FileProvider>();
    final paperProvider = context.read<PaperProvider>();
    PaperTemplate newPageTemplate;
    int newPageNumber = 1;

    if (pageIds.isNotEmpty) {
      final lastPaperId = pageIds.last;
      final lastPaperData = paperProvider.getPaperById(lastPaperId);
      newPageNumber = (lastPaperData?['PageNumber'] as int? ?? 0) + 1;
      newPageTemplate =
          paperTemplates[lastPaperId] ??
          PaperTemplate(
            id: 'plain',
            name: 'Plain Paper',
            templateType: TemplateType.plain,
            spacing: 30.0,
          );
    } else {
      newPageTemplate = PaperTemplate(
        id: 'plain',
        name: 'Plain Paper',
        templateType: TemplateType.plain,
        spacing: 30.0,
      );
    }

    final String newPaperId = paperProvider.addPaper(
      newPageTemplate,
      newPageNumber,
      null,
      null,
      595.0,
      842.0,
    );

    if (widget.fileId != null) {
      fileProvider.addPaperPageToFile(widget.fileId!, newPaperId);
    }

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
          for (final stroke in loadedStrokes) {
            if (stroke['type'] == 'drawing') {
              final point = DrawingPoint.fromJson(stroke['data']);
              if (point.offsets.isNotEmpty) {
                pointsForPage.add(point);
              }
            }
          }
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

    if (currentPaperIds.isNotEmpty && pageIds.isEmpty) {
      setState(() {
        pageIds = currentPaperIds;
      });
    }

    _loadTemplatesForPapers(papers);
    _centerContent();

    // Calculate total height of all papers
    double totalHeight = 0;
    for (var paperId in currentPaperIds) {
      final paperData = paperProvider.getPaperById(paperId);
      final double paperHeight = paperData?['height'] as double? ?? 842.0;
      totalHeight += paperHeight + 16.0; // Add padding (8.0 top + 8.0 bottom)
    }

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
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: exportToPdf,
            tooltip: 'Export to PDF',
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
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 8.0,
              radius: const Radius.circular(4.0),
              interactive: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics:
                    _isDrawing
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: totalHeight,
                  child: InteractiveViewer(
                    transformationController: _controller,
                    minScale: 1.0,
                    maxScale: 2.0,
                    boundaryMargin: EdgeInsets.symmetric(
                      horizontal: max(
                        (MediaQuery.of(context).size.width -
                                (papers.isNotEmpty
                                    ? papers.first['width'] as double? ?? 595.0
                                    : 595.0)) /
                            2,
                        0,
                      ),
                      vertical: 20,
                    ),
                    constrained: false,
                    panEnabled:
                        false, // Disable panning to avoid conflicts with drawing
                    scaleEnabled: true,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children:
                              currentPaperIds.map((paperId) {
                                final template =
                                    paperTemplates[paperId] ??
                                    PaperTemplate(
                                      id: 'plain',
                                      name: 'Plain Paper',
                                      templateType: TemplateType.plain,
                                    );
                                final paperData = paperProvider.getPaperById(
                                  paperId,
                                );
                                final double paperWidth =
                                    paperData?['width'] as double? ?? 595.0;
                                final double paperHeight =
                                    paperData?['height'] as double? ?? 842.0;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Container(
                                    width: paperWidth,
                                    height: paperHeight,
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
                                          size: Size(paperWidth, paperHeight),
                                        ),
                                        if (paperData != null &&
                                            paperData['pdfPath'] != null)
                                          Image.file(
                                            File(paperData['pdfPath']),
                                            width: paperWidth,
                                            height: paperHeight,
                                            fit: BoxFit.contain,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              debugPrint(
                                                'Error loading image for $paperId: $error',
                                              );
                                              return const Center(
                                                child: Text(
                                                  'Failed to load image',
                                                ),
                                              );
                                            },
                                          ),
                                        Listener(
                                          onPointerDown: (details) {
                                            final localPosition =
                                                details.localPosition;
                                            if (!_isWithinCanvas(
                                              localPosition,
                                              paperWidth,
                                              paperHeight,
                                            ))
                                              return;

                                            setState(() {
                                              _isDrawing =
                                                  true; // Disable scrolling when drawing starts
                                            });

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
                                              );
                                            }
                                          },
                                          onPointerMove: (details) {
                                            final localPosition =
                                                details.localPosition;
                                            if (!_isWithinCanvas(
                                              localPosition,
                                              paperWidth,
                                              paperHeight,
                                            ))
                                              return;

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
                                              );
                                            }
                                          },
                                          onPointerUp: (_) {
                                            setState(() {
                                              _isDrawing =
                                                  false; // Re-enable scrolling when drawing ends
                                            });
                                            currentDrawingPoint = null;
                                            if (selectedMode ==
                                                DrawingMode.eraser) {
                                              eraserTool.finishErasing();
                                            }
                                          },
                                          child: CustomPaint(
                                            painter: DrawingPainter(
                                              drawingPoints:
                                                  pageDrawingPoints[paperId] ??
                                                  [],
                                            ),
                                            size: Size(paperWidth, paperHeight),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
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

  bool _isWithinCanvas(Offset position, double width, double height) {
    return position.dx >= 0 &&
        position.dx <= width &&
        position.dy >= 0 &&
        position.dy <= height;
  }

  Future<void> exportToPdf() async {
    // Show loading indicator
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Save any unsaved changes first
      if (_hasUnsavedChanges) await _saveDrawing();

      // Prepare initial values for the dialog
      final initialFileName = widget.name.replaceAll(' ', '_');
      final hasMultiplePages = pageIds.length > 1;

      // Show dialog to get export options from user
      final Map<String, dynamic>? exportOptions =
          await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (BuildContext context) {
              return PdfExportDialog(
                filename: initialFileName,
                hasMultiplePages: hasMultiplePages,
              );
            },
          );

      // If user cancelled the dialog, return
      if (exportOptions == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('PDF export cancelled')),
        );
        return;
      }

      // Extract options from dialog result
      String fileName = exportOptions['filename'] as String;
      final bool includePdfBackgrounds =
          exportOptions['includePdfBackgrounds'] as bool;
      final bool includeAllPages = exportOptions['includeAllPages'] as bool;
      final List<int> selectedPageIndices =
          exportOptions['selectedPageIndices'] as List<int>;
      final double quality = exportOptions['quality'] as double;

      // Ensure filename has .pdf extension
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = '$fileName.pdf';
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Generating PDF...')),
      );

      // Create PDF document
      final pdf = pw.Document();
      final screenshotController = ScreenshotController();
      int count = 0;

      // Determine if we need to handle multiple pages
      final paperProvider = Provider.of<PaperProvider>(context, listen: false);

      final loadingOverlay = LoadingOverlay(
        context: context,
        message: 'Preparing to export PDF',
        subMessage: 'Please wait while we export your file',
      );

      loadingOverlay.show();

      // Determine which pages to process
      List<String> pagesToProcess = [];
      if (!hasMultiplePages || includeAllPages) {
        pagesToProcess = List.from(pageIds);
      } else {
        // Only include selected pages
        for (int index in selectedPageIndices) {
          if (index < pageIds.length) {
            pagesToProcess.add(pageIds[index]);
          }
        }
      }

      // Process pages in batches of 10
      final int batchSize = 10;
      for (int i = 0; i < pagesToProcess.length; i += batchSize) {
        loadingOverlay.updateMessage(
          'Processing pages ${i + 1} to ${math.min(i + batchSize, pagesToProcess.length)} of ${pagesToProcess.length}',
        );

        final batch = pagesToProcess.sublist(
          i,
          math.min(i + batchSize, pagesToProcess.length),
        );

        // Process each selected page
        for (final paperId in batch) {
          final paperData = paperProvider.getPaperById(paperId);
          if (paperData == null) continue;

          final double paperWidth = paperData['width'] as double? ?? 595.0;
          final double paperHeight = paperData['height'] as double? ?? 842.0;

          // Create a repaint boundary with just this page
          final template =
              paperTemplates[paperId] ??
              PaperTemplate(
                id: 'plain',
                name: 'Plain Paper',
                templateType: TemplateType.plain,
              );

          // Create a widget for this specific page
          final pageWidget = SizedBox(
            width: paperWidth,
            height: paperHeight,
            child: Stack(
              children: [
                // Background template
                CustomPaint(
                  painter: TemplatePainter(template: template),
                  size: Size(paperWidth, paperHeight),
                ),
                // PDF image if exists and should be included
                if (includePdfBackgrounds && paperData['pdfPath'] != null)
                  Image.file(
                    File(paperData['pdfPath']),
                    width: paperWidth,
                    height: paperHeight,
                    fit: BoxFit.contain,
                  ),
                // Drawings
                CustomPaint(
                  painter: DrawingPainter(
                    drawingPoints: pageDrawingPoints[paperId] ?? [],
                  ),
                  size: Size(paperWidth, paperHeight),
                ),
              ],
            ),
          );

          // Capture screenshot of this page with the selected quality
          final Uint8List imageBytes = await screenshotController
              .captureFromWidget(
                pageWidget,
                pixelRatio: quality, // Use the quality from dialog
                targetSize: Size(paperWidth.toDouble(), paperHeight.toDouble()),
                context: context,
              );

          // Add the captured image to the PDF
          final image = pw.MemoryImage(imageBytes);

          // Add page to PDF with the correct dimensions
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(paperWidth, paperHeight),
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.SizedBox(
                      width: paperWidth,
                      height: paperHeight,
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    ),
                  ),
                );
              },
            ),
          );
          count++;
          print("Page: $count");
        }

        await Future.delayed(Duration(milliseconds: 200));
      }
      // Get bytes of the PDF
      final pdfBytes = await pdf.save();

      loadingOverlay.hide();

      String? filePath;

      if (Platform.isAndroid) {
        // For Android
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          String downloadPath = "";
          List<String> paths = directory.path.split("/");
          for (int i = 1; i < paths.length; i++) {
            String folder = paths[i];
            if (folder != "Android") {
              downloadPath += "/$folder";
            } else {
              break;
            }
          }
          downloadPath += "/Download";

          final downloadsDir = Directory(downloadPath);

          // Create Downloads directory if it doesn't exist
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }

          final file = File('${downloadsDir.path}/$fileName');
          await file.writeAsBytes(pdfBytes);
          filePath = file.path;
        }
      } else if (Platform.isIOS) {
        // For iOS:
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        filePath = file.path;
      } else {
        // Desktop
        final directory =
            await getDownloadsDirectory(); // Gets the Downloads folder on desktop
        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(pdfBytes);
          filePath = file.path;
        } else {
          // Fallback to application documents directory
          final docDir = await getApplicationDocumentsDirectory();
          final file = File('${docDir.path}/$fileName');
          await file.writeAsBytes(pdfBytes);
          filePath = file.path;
        }
      }

      // Show success message
      if (filePath != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('PDF saved to: $filePath'),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('PDF saved successfully'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error exporting PDF: $e\n$stackTrace');
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    if (_hasUnsavedChanges) _saveDrawing();
    super.dispose();
  }
}

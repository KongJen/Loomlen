// Main file: paper_page.dart
// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:frontend/widget/tool_bar.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/services/drawing_service.dart';
import 'package:frontend/services/pdf_export_service.dart';
import 'package:frontend/services/paper_service.dart';
import 'package:frontend/widget/sharefile_dialog.dart';

enum DrawingMode { pencil, eraser }

class PaperPage extends StatefulWidget {
  final String name;
  final String fileId;
  final Function? onFileUpdated;
  final String roomId;

  const PaperPage({
    super.key,
    required this.name,
    required this.fileId,
    this.onFileUpdated,
    required this.roomId,
  });

  @override
  State<PaperPage> createState() => _PaperPageState();
}

class _PaperPageState extends State<PaperPage> {
  late final DrawingService _drawingService;
  late final PaperService _paperService;
  late final PDFExportService _pdfExportService;

  final TransformationController _controller = TransformationController();
  final ScrollController _scrollController = ScrollController();

  DrawingMode selectedMode = DrawingMode.pencil;
  Color selectedColor = Colors.black;
  double selectedWidth = 2.0;
  bool _isDrawing = false;
  bool _hasUnsavedChanges = false;

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
    _drawingService = DrawingService();
    _paperService = PaperService();
    _pdfExportService = PDFExportService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final paperProvider = Provider.of<PaperProvider>(context, listen: false);

      // Load folders for the specific room
      paperProvider.loadPapers();

      _loadDrawingData();
      _centerContent();
    });
  }

  void _centerContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final papers = _paperService.getPapersForFile(
        context.read<PaperProvider>(),
        context.read<PaperDBProvider>(),
        widget.fileId,
        false,
      );

      if (papers.isEmpty) return;

      final firstPaper = papers.first;
      final double paperWidth = firstPaper['width'] as double? ?? 595.0;
      final double paperHeight = firstPaper['height'] as double? ?? 842.0;
      final double totalHeight = papers.length * (paperHeight + 16.0);

      final screenSize = MediaQuery.of(context).size;
      final double screenWidth = screenSize.width;
      final double screenHeight = screenSize.height;

      // Calculate the center position
      final double xOffset = max(0, (screenWidth - paperWidth) / 2);
      final double yOffset = max(0, (screenHeight - totalHeight) / 2);

      // Reset to identity matrix and then translate
      _controller.value = Matrix4.identity()..translate(xOffset, yOffset);

      // Force scroll to top when app restarts
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _loadDrawingData() {
    final paperProvider = context.read<PaperProvider>();

    _drawingService.loadFromProvider(
      paperProvider,
      widget.fileId,
      onDataLoaded: () {
        setState(() {
          // Update UI after data is loaded
        });
      },
    );
  }

  Future<void> _saveDrawing() async {
    await _drawingService.saveDrawings(context.read<PaperProvider>());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drawing saved successfully')),
      );
    }

    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  void _addNewPaperPage() async {
    // First, save current drawings to ensure nothing is lost
    await _drawingService.saveDrawings(context.read<PaperProvider>());

    // Add the new page
    _paperService.addNewPage(
      context.read<PaperProvider>(),
      context.read<PaperDBProvider>(),
      widget.fileId,
      _drawingService.getTemplateForLastPage(),
      widget.roomId,
      false,
    );

    // Reload paper data AFTER saving and adding
    final paperProvider = context.read<PaperProvider>();
    _drawingService.loadFromProvider(paperProvider, widget.fileId);

    setState(() {
      _hasUnsavedChanges = true;
    });

    // Scroll to the bottom after UI updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // void _reloadPaperData() {
  //   final paperProvider = context.read<PaperProvider>();

  //   _drawingService.loadFromProvider(paperProvider, widget.fileId);

  //   setState(() {
  //     _hasUnsavedChanges = true;
  //   });

  //   _centerContent();
  // }

  Future<void> exportToPdf() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (_hasUnsavedChanges) await _saveDrawing();

      final exportResult = await _pdfExportService.exportNotesToPdf(
        context: context,
        fileName: widget.name.replaceAll(' ', '_'),
        pageIds: _drawingService.getPageIds(),
        paperTemplates: _drawingService.getPaperTemplates(),
        pageDrawingPoints: _drawingService.getPageDrawingPoints(),
        paperProvider: context.read<PaperProvider>(),
      );

      if (exportResult.success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              exportResult.filePath != null
                  ? 'PDF saved to: ${exportResult.filePath}'
                  : 'PDF saved successfully',
            ),
            duration: Duration(seconds: exportResult.filePath != null ? 5 : 3),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('PDF export cancelled')),
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
  Widget build(BuildContext context) {
    final paperProvider = Provider.of<PaperProvider>(context);
    final paperDBProvider = Provider.of<PaperDBProvider>(context);
    final papers = _paperService.getPapersForFile(
        paperProvider, paperDBProvider, widget.fileId, false);

    if (papers.isNotEmpty && _drawingService.getPageIds().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDrawingData();
        _centerContent();
      });
    }

    double totalHeight = papers.fold(
      0.0,
      (height, paper) => height + (paper['height'] as double? ?? 842.0) + 16.0,
    );

    return Scaffold(
      appBar: buildAppBar(),
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
              eraserWidth: _drawingService.getEraserWidth(),
              eraserMode: _drawingService.getEraserMode(),
              onWidthChanged: (value) {
                setState(() {
                  _drawingService.setEraserWidth(value);
                });
              },
              onModeChanged: (mode) {
                setState(() {
                  _drawingService.setEraserMode(mode);
                });
              },
            ),
          Expanded(
              child: buildPaperCanvas(
                  totalHeight, papers, paperProvider, paperDBProvider)),
        ],
      ),
    );
  }

  AppBar buildAppBar() {
    return AppBar(
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
          onPressed: _drawingService.canUndo()
              ? () => setState(() => _drawingService.undo())
              : null,
          tooltip: 'Undo',
        ),
        IconButton(
          icon: const Icon(Icons.redo),
          onPressed: _drawingService.canRedo()
              ? () => setState(() => _drawingService.redo())
              : null,
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
        // IconButton(
        //   icon: const Icon(Icons.share),
        //   tooltip: 'Share this file',
        //   onPressed: () {
        //     showDialog(
        //       context: context,
        //       builder: (context) =>
        //           ShareDialog(fileId: widget.fileId, fileName: widget.name),
        //     );
        //   },
        // ),
      ],
    );
  }

  Widget buildPaperCanvas(double totalHeight, List<Map<String, dynamic>> papers,
      PaperProvider paperProvider, PaperDBProvider paperDBProvider) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      thickness: 8.0,
      radius: const Radius.circular(4.0),
      interactive: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: _isDrawing
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
            panEnabled: !_isDrawing,
            scaleEnabled: !_isDrawing,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: paperProvider
                      .getPaperIdsByFileId(widget.fileId)
                      .map(
                        (paperId) => _buildPaperPage(
                            paperId, paperProvider, paperDBProvider),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaperPage(String paperId, PaperProvider paperProvider,
      PaperDBProvider paperDBProvider) {
    final paperData = paperProvider.getPaperById(paperId);
    final PaperTemplate template;
    final double paperWidth;
    final double paperHeight;

    template = PaperTemplateFactory.getTemplate(paperData?['templateId']);
    paperWidth = paperData?['width'] as double? ?? 595.0;
    paperHeight = paperData?['height'] as double? ?? 842.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
          border: Border.all(color: Colors.grey.shade400, width: 1.5),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Template background
            CustomPaint(
              painter: TemplatePainter(template: template),
              size: Size(paperWidth, paperHeight),
            ),
            // PDF background if available
            if (paperData != null && paperData['pdfPath'] != null)
              Image.file(
                File(paperData['pdfPath']),
                width: paperWidth,
                height: paperHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading image for $paperId: $error');
                  return const Center(child: Text('Failed to load image'));
                },
              ),
            // Drawing interaction surface
            Listener(
              onPointerDown: (details) => _handlePointerDown(
                details,
                paperId,
                paperWidth,
                paperHeight,
              ),
              onPointerMove: (details) => _handlePointerMove(
                details,
                paperId,
                paperWidth,
                paperHeight,
              ),
              onPointerCancel: (_) => _handlePointerCancel(),
              onPointerUp: (_) => _handlePointerUp(paperId),
              child: CustomPaint(
                painter: DrawingPainter(
                  drawingPoints: _drawingService.getDrawingPointsForPage(
                    paperId,
                  ),
                ),
                size: Size(paperWidth, paperHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _activePointerCount = 0;
  Timer? _drawingDelayTimer;
  // static const _drawingDelayDuration = Duration(milliseconds: 0);

  void _handlePointerDown(
    PointerDownEvent details,
    String paperId,
    double paperWidth,
    double paperHeight,
  ) {
    _activePointerCount++;

    final localPosition = details.localPosition;
    if (!_isWithinCanvas(localPosition, paperWidth, paperHeight)) return;

    _drawingDelayTimer?.cancel();

    if (_activePointerCount == 1) {
      // _drawingDelayTimer = Timer(_drawingDelayDuration, () {
      // Only proceed if we still have exactly one finger down
      if (_activePointerCount == 1 && mounted) {
        setState(() {
          _isDrawing = true;
          _hasUnsavedChanges = true;
        });

        if (selectedMode == DrawingMode.pencil) {
          _drawingService.startDrawing(
            paperId,
            localPosition,
            selectedColor,
            selectedWidth,
          );
          setState(() {});
        } else if (selectedMode == DrawingMode.eraser) {
          _drawingService.startErasing(paperId, localPosition);
          setState(() {});
        }
      }
    } else {
      // If more than one finger, cancel drawing mode
      setState(() {
        _isDrawing = false;
      });
    }
  }

  void _handlePointerMove(
    PointerMoveEvent details,
    String paperId,
    double paperWidth,
    double paperHeight,
  ) {
    final localPosition = details.localPosition;
    if (!_isWithinCanvas(localPosition, paperWidth, paperHeight)) return;
    if (_activePointerCount == 1 && _isDrawing) {
      setState(() {
        _isDrawing = true;
      });

      if (selectedMode == DrawingMode.pencil) {
        _drawingService.continueDrawing(paperId, localPosition);
        setState(() {
          _hasUnsavedChanges = true;
        });
      } else if (selectedMode == DrawingMode.eraser) {
        _drawingService.continueErasing(paperId, localPosition);
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
    }
  }

  void _handlePointerUp(String paperId) {
    _activePointerCount = max(0, _activePointerCount - 1);

    _drawingDelayTimer?.cancel();

    // End drawing if we were drawing
    if (_isDrawing) {
      setState(() {
        _isDrawing = false;
      });

      if (selectedMode == DrawingMode.pencil) {
        _drawingService.endDrawing();
      } else if (selectedMode == DrawingMode.eraser) {
        _drawingService.endErasing();
      }
    }
  }

  void _handlePointerCancel() {
    // Decrement pointer count (never below 0)
    _activePointerCount = max(0, _activePointerCount - 1);

    _drawingDelayTimer?.cancel();

    // Cancel drawing
    setState(() {
      _isDrawing = false;
    });
  }

  bool _isWithinCanvas(Offset position, double width, double height) {
    return position.dx >= 0 &&
        position.dx <= width &&
        position.dy >= 0 &&
        position.dy <= height;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    if (_hasUnsavedChanges) _saveDrawing();
    super.dispose();
  }
}

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

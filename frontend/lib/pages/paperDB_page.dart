// Main file: paper_page.dart
// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/api/socketService.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:frontend/services/drawingDb_service.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:frontend/widget/tool_bar.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/services/drawing_service.dart';
import 'package:frontend/services/pdf_export_service.dart';
import 'package:frontend/services/paper_service.dart';
import 'package:frontend/widget/sharefile_dialog.dart';

enum DrawingMode { pencil, eraser }

class PaperDBPage extends StatefulWidget {
  final bool collab;
  final String name;
  final String fileId;
  final String roomId;
  final String role;
  final Function? onFileUpdated;
  final SocketService? socket;

  const PaperDBPage({
    super.key,
    required this.collab,
    required this.name,
    required this.fileId,
    required this.roomId,
    required this.role,
    this.onFileUpdated,
    this.socket,
  });

  @override
  State<PaperDBPage> createState() => _PaperDBPageState();
}

class _PaperDBPageState extends State<PaperDBPage> {
  late final DrawingService _drawingService;
  late final DrawingDBService _drawingDBService;
  late final PaperService _paperService;
  late final PDFExportService _pdfExportService;

  final TransformationController _controller = TransformationController();
  final ScrollController _scrollController = ScrollController();

  late String role;
  VoidCallback? _roleUpdateListener;

  DrawingMode selectedMode = DrawingMode.pencil;
  Color selectedColor = Colors.black;
  double selectedWidth = 2.0;
  bool _isDrawing = false;
  bool _hasUnsavedChanges = false;
  bool get isReadOnly => role == 'read';

  final List<Color> availableColors = const [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
  ];

  @override
  @override
  void initState() {
    super.initState();
    role = widget.role;
    _drawingDBService = DrawingDBService(
        roomId: widget.roomId,
        fileId: widget.fileId,
        socketService: widget.socket);
    _paperService = PaperService();
    _pdfExportService = PDFExportService();
    _drawingDBService.onDataChanged = () {
      if (mounted) setState(() {});
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final paperProvider = Provider.of<PaperProvider>(context, listen: false);

      // Load folders for the specific room
      paperProvider.loadPapers();
      _subscribeToRoleChanges();
      _loadDrawingData();
      _centerContent();
    });
  }

  void _subscribeToRoleChanges() {
    final roomDBProvider = Provider.of<RoomDBProvider>(context, listen: false);

    // Define the update function
    void updateRoleFromProvider() {
      if (!mounted)
        return; // Add this check to prevent setState on unmounted widget

      final updatedRoom = roomDBProvider.rooms.firstWhere(
        (r) => r['id'] == widget.roomId,
      );

      if (updatedRoom['role_id'] != role) {
        if (mounted) {
          // Double-check we're still mounted
          setState(() {
            role = updatedRoom['role_id'] ?? 'viewer';
          });
          print("Role updated to: $role");
        }
      }
    }

    // Store reference to our listener so we can remove it later
    _roleUpdateListener = updateRoleFromProvider;

    // Initial check
    updateRoleFromProvider();

    // Setup a listener for future changes
    roomDBProvider.addListener(updateRoleFromProvider);
  }

  void _centerContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final papers = _paperService.getPapersForFile(
        context.read<PaperProvider>(),
        context.read<PaperDBProvider>(),
        widget.fileId,
        widget.collab,
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
    final paperDBProvider = context.read<PaperDBProvider>();
    if (widget.collab) {
      _drawingDBService.loadFromProvider(
        paperDBProvider,
        widget.fileId,
        onDataLoaded: () {
          setState(() {
            // Update UI after data is loaded
          });
        },
      );
    }
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

  void _addNewPaperPage() {
    if (widget.collab) {
      _paperService.addNewPage(
        context.read<PaperProvider>(),
        context.read<PaperDBProvider>(),
        widget.fileId,
        _drawingDBService.getTemplateForLastPage(),
        widget.roomId,
        widget.collab,
      );
    }

    _reloadPaperData();

    // Scroll to the bottom after UI updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _reloadPaperData() {
    final paperProvider = context.read<PaperProvider>();
    final paperDBProvider = context.read<PaperDBProvider>();

    _drawingService.loadFromProvider(paperProvider, widget.fileId);
    _drawingDBService.loadFromProvider(paperDBProvider, widget.fileId);

    setState(() {
      _hasUnsavedChanges = true;
    });

    _centerContent();
  }

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
        paperProvider, paperDBProvider, widget.fileId, widget.collab);

    if (widget.collab) {
      if (papers.isNotEmpty && _drawingDBService.getPageIds().isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadDrawingData();
          _centerContent();
        });
      }
    }

    double totalHeight = papers.fold(
      0.0,
      (height, paper) => height + (paper['height'] as double? ?? 842.0) + 16.0,
    );

    return Scaffold(
      appBar: buildAppBar(),
      body: Column(
        children: [
          if (!isReadOnly && selectedMode == DrawingMode.pencil)
            buildPencilSettingsBar(
              selectedWidth: selectedWidth,
              selectedColor: selectedColor,
              availableColors: availableColors,
              onWidthChanged: (value) => setState(() => selectedWidth = value),
              onColorChanged: (color) => setState(() => selectedColor = color),
            ),
          if (!isReadOnly && selectedMode == DrawingMode.eraser)
            buildEraserSettingsBar(
              eraserWidth: _drawingDBService.getEraserWidth(),
              eraserMode: _drawingDBService.getEraserMode(),
              onWidthChanged: (value) {
                setState(() {
                  _drawingDBService.setEraserWidth(value);
                });
              },
              onModeChanged: (mode) {
                setState(() {
                  _drawingDBService.setEraserMode(mode);
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
      actions: isReadOnly
          ? []
          : [
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color:
                      selectedMode == DrawingMode.pencil ? Colors.blue : null,
                ),
                onPressed: () =>
                    setState(() => selectedMode = DrawingMode.pencil),
                tooltip: 'Pencil',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color:
                      selectedMode == DrawingMode.eraser ? Colors.blue : null,
                ),
                onPressed: () =>
                    setState(() => selectedMode = DrawingMode.eraser),
                tooltip: 'Eraser',
              ),
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _drawingDBService.canUndo()
                    ? () => setState(() => _drawingDBService.undo())
                    : null,
                tooltip: 'Undo',
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                onPressed: _drawingDBService.canRedo()
                    ? () => setState(() => _drawingDBService.redo())
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
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share this file',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ShareDialog(
                        fileId: widget.fileId, fileName: widget.name),
                  );
                },
              ),
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
            panEnabled: false,
            scaleEnabled: true,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width,
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: paperDBProvider
                        .getPaperIdsByFileId(widget.fileId)
                        .map(
                          (paperId) => _buildPaperPage(
                              paperId, paperProvider, paperDBProvider),
                        )
                        .toList()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaperPage(String paperId, PaperProvider paperProvider,
      PaperDBProvider paperDBProvider) {
    final paperDBData = paperDBProvider.getPaperDBById(paperId);
    final paperData = paperProvider.getPaperById(paperId);
    final PaperTemplate template;
    final double paperWidth;
    final double paperHeight;
    template = PaperTemplateFactory.getTemplate(paperDBData['template_id']);
    paperWidth = (paperDBData['width'] as num?)?.toDouble() ?? 595.0;
    paperHeight = (paperDBData['height'] as num?)?.toDouble() ?? 595.0;

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
            isReadOnly
                ? CustomPaint(
                    painter: DrawingPainter(
                      drawingPoints:
                          _drawingDBService.getDrawingPointsForPage(paperId),
                    ),
                    size: Size(paperWidth, paperHeight),
                  )
                : Listener(
                    onPointerDown: (details) => _handlePointerDown(
                        details, paperId, paperWidth, paperHeight),
                    onPointerMove: (details) => _handlePointerMove(
                        details, paperId, paperWidth, paperHeight),
                    onPointerUp: (_) => _handlePointerUp(paperId),
                    child: CustomPaint(
                      painter: DrawingPainter(
                        drawingPoints:
                            _drawingDBService.getDrawingPointsForPage(paperId),
                      ),
                      size: Size(paperWidth, paperHeight),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _handlePointerDown(
    PointerDownEvent details,
    String paperId,
    double paperWidth,
    double paperHeight,
  ) {
    final localPosition = details.localPosition;
    if (!_isWithinCanvas(localPosition, paperWidth, paperHeight)) return;

    setState(() {
      _isDrawing = true;
      _hasUnsavedChanges = true;
    });

    if (selectedMode == DrawingMode.pencil) {
      _drawingDBService.startDrawing(
        paperId,
        localPosition,
        selectedColor,
        selectedWidth,
      );
      setState(() {});
    } else if (selectedMode == DrawingMode.eraser) {
      _drawingDBService.startErasing(paperId, localPosition);
      setState(() {});
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

    if (selectedMode == DrawingMode.pencil) {
      _drawingDBService.continueDrawing(paperId, localPosition);
      setState(() {
        _hasUnsavedChanges = true;
      });
    } else if (selectedMode == DrawingMode.eraser) {
      _drawingDBService.continueErasing(paperId, localPosition);
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  void _handlePointerUp(String paperId) {
    setState(() {
      _isDrawing = false;
    });

    if (selectedMode == DrawingMode.pencil) {
      _drawingDBService.endDrawing();
    } else if (selectedMode == DrawingMode.eraser) {
      _drawingDBService.endErasing();
    }
  }

  bool _isWithinCanvas(Offset position, double width, double height) {
    return position.dx >= 0 &&
        position.dx <= width &&
        position.dy >= 0 &&
        position.dy <= height;
  }

  @override
  void dispose() {
    if (_roleUpdateListener != null) {
      final roomDBProvider =
          Provider.of<RoomDBProvider>(context, listen: false);
      roomDBProvider.removeListener(_roleUpdateListener!);
    }
    _controller.dispose();
    _scrollController.dispose();
    _drawingDBService.leavefile();
    if (_hasUnsavedChanges) _saveDrawing();
    super.dispose();
  }
}

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

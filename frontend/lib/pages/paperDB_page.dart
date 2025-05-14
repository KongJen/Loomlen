// Main file: paper_page.dart
// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/api/socketService.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:frontend/services/PDF_DB_export_service.dart';
import 'package:frontend/services/drawingDb_service.dart';
import 'package:frontend/widget/manage_paperDB_page.dart';
import 'package:frontend/widget/text_annotation_widget.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:frontend/widget/tool_bar.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/services/drawing_service.dart';
import 'package:frontend/services/pdf_export_service.dart';
import 'package:frontend/services/paper_service.dart';
import 'package:collection/collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum DrawingMode { pencil, eraser, text, read, bubble }

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
  late final PDFDBExportService _pdfDBExportService;

  final TransformationController _controller = TransformationController();
  final ScrollController _scrollController = ScrollController();

  late String role;
  VoidCallback? _roleUpdateListener;

  DrawingMode selectedMode = DrawingMode.pencil;
  Color selectedColor = Colors.black;
  double selectedWidth = 2.0;
  bool _isDrawing = false;
  bool _hasUnsavedChanges = false;

  double selectedFontSize = 16.0;
  TextAlign selectedTextAlign = TextAlign.left;
  bool selectedTextBold = false;
  bool selectedTextItalic = false;
  bool get isRead => selectedMode == DrawingMode.read;
  bool get isReadOnly => role == 'read';

  final GlobalKey _settingsBarKey = GlobalKey();

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

    final isPhone = WidgetsBinding.instance.window.physicalSize.width /
            WidgetsBinding.instance.window.devicePixelRatio <
        600;

    if (isPhone) selectedMode = DrawingMode.read;

    _drawingDBService = DrawingDBService(
        roomId: widget.roomId,
        fileId: widget.fileId,
        socketService: widget.socket);
    _paperService = PaperService();
    _pdfDBExportService = PDFDBExportService();
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

  void _saveDrawing() {
    _drawingDBService.saveAllDrawingsToDatabase();

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
    final paperDBProvider = context.read<PaperDBProvider>();

    _drawingDBService.loadFromProvider(paperDBProvider, widget.fileId);

    setState(() {
      _hasUnsavedChanges = true;
    });

    _centerContent();
  }

  Future<void> exportToPdf() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (_hasUnsavedChanges) _saveDrawing();

      final exportResult = await _pdfDBExportService.exportNotesDBToPdf(
        context: context,
        fileName: widget.name.replaceAll(' ', '_'),
        pageIds: _drawingDBService.getPageIds(),
        paperTemplates: _drawingDBService.getPaperTemplates(),
        pageDrawingPoints: _drawingDBService.getPageDrawingPoints(),
        paperDBProvider: context.read<PaperDBProvider>(),
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

    MouseCursor cursor = SystemMouseCursors.basic;
    if (selectedMode == DrawingMode.read) {
      cursor = SystemMouseCursors.click;
    } else if (selectedMode == DrawingMode.pencil) {
      cursor = SystemMouseCursors.precise;
    } else if (selectedMode == DrawingMode.eraser) {
      cursor = SystemMouseCursors.precise;
    } else if (selectedMode == DrawingMode.text) {
      cursor = SystemMouseCursors.text;
    }

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
          if (!isReadOnly && selectedMode == DrawingMode.text)
            buildTextSettingsBar(
              key: _settingsBarKey,
              selectedColor: selectedColor,
              availableColors: availableColors,
              onColorChanged: (color) {
                setState(() {
                  selectedColor = color;

                  // Update the selected annotation if there is one
                  final selectedAnnotation =
                      _drawingDBService.getSelectedTextAnnotation();
                  if (selectedAnnotation != null) {
                    final pageIds = _drawingDBService.getPageIds();
                    for (final pageId in pageIds) {
                      final annotations =
                          _drawingDBService.getTextAnnotationsForPage(pageId);
                      if (annotations.contains(selectedAnnotation)) {
                        _drawingDBService.updateTextAnnotation(
                          pageId,
                          selectedAnnotation.id,
                          color: color,
                          isBubble: false,
                        );
                        break;
                      }
                    }
                  }
                });
              },
              fontSize: selectedFontSize,
              onFontSizeChanged: (value) {
                setState(() {
                  selectedFontSize = value;

                  // Update the selected annotation if there is one
                  final selectedAnnotation =
                      _drawingDBService.getSelectedTextAnnotation();
                  if (selectedAnnotation != null) {
                    final pageIds = _drawingDBService.getPageIds();
                    for (final pageId in pageIds) {
                      final annotations =
                          _drawingDBService.getTextAnnotationsForPage(pageId);
                      if (annotations.contains(selectedAnnotation)) {
                        _drawingDBService.updateTextAnnotation(
                          pageId,
                          selectedAnnotation.id,
                          fontSize: value,
                          isBubble: false,
                        );
                        break;
                      }
                    }
                  }
                });
              },
              textAlign: selectedTextAlign,
              onTextAlignChanged: (align) {
                setState(() {
                  selectedTextAlign = align;

                  // Update the selected annotation if there is one
                  final selectedAnnotation =
                      _drawingDBService.getSelectedTextAnnotation();
                  if (selectedAnnotation != null) {
                    final pageIds = _drawingDBService.getPageIds();
                    for (final pageId in pageIds) {
                      final annotations =
                          _drawingDBService.getTextAnnotationsForPage(pageId);
                      if (annotations.contains(selectedAnnotation)) {
                        _drawingDBService.updateTextAnnotation(
                          pageId,
                          selectedAnnotation.id,
                          isBubble: false,
                        );
                        break;
                      }
                    }
                  }
                });
              },
              isBold: selectedTextBold,
              onBoldChanged: (value) {
                setState(() {
                  selectedTextBold = value;

                  // Update the selected annotation if there is one
                  final selectedAnnotation =
                      _drawingDBService.getSelectedTextAnnotation();
                  if (selectedAnnotation != null) {
                    final pageIds = _drawingDBService.getPageIds();
                    for (final pageId in pageIds) {
                      final annotations =
                          _drawingDBService.getTextAnnotationsForPage(pageId);
                      if (annotations.contains(selectedAnnotation)) {
                        _drawingDBService.updateTextAnnotation(
                          pageId,
                          selectedAnnotation.id,
                          isBold: value,
                          isBubble: false,
                        );
                        break;
                      }
                    }
                  }
                });
              },
              isItalic: selectedTextItalic,
              onItalicChanged: (value) {
                setState(() {
                  selectedTextItalic = value;

                  // Update the selected annotation if there is one
                  final selectedAnnotation =
                      _drawingDBService.getSelectedTextAnnotation();
                  if (selectedAnnotation != null) {
                    final pageIds = _drawingDBService.getPageIds();
                    for (final pageId in pageIds) {
                      final annotations =
                          _drawingDBService.getTextAnnotationsForPage(pageId);
                      if (annotations.contains(selectedAnnotation)) {
                        _drawingDBService.updateTextAnnotation(
                          pageId,
                          selectedAnnotation.id,
                          isItalic: value,
                          isBubble: false,
                        );
                        break;
                      }
                    }
                  }
                });
              },
            ),
          Expanded(
            child: MouseRegion(
              cursor: cursor,
              child: buildPaperCanvas(
                  totalHeight, papers, paperProvider, paperDBProvider),
            ),
          ),
        ],
      ),
    );
  }

  AppBar buildAppBar() {
    final isPhone = MediaQuery.of(context).size.width < 600;

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
      actions: isPhone
          ? _buildPhoneActions() // 🔧 Phone layout
          : _buildFullActions(), // 💻 Tablet/Desktop layout
    );
  }

  List<Widget> _buildPhoneActions() {
    return [
      IconButton(
        icon: FaIcon(
          FontAwesomeIcons.handPointer,
          color: selectedMode == DrawingMode.read ? Colors.blue : null,
        ),
        onPressed: () => setState(() => selectedMode = DrawingMode.read),
        tooltip: 'Reading Mode',
      ),
      IconButton(
        icon: Icon(
          Icons.circle,
          color: selectedMode == DrawingMode.bubble ? Colors.blue : null,
        ),
        onPressed: () => setState(() => selectedMode = DrawingMode.bubble),
        tooltip: 'Bubble',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: _handleMoreMenuAction,
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'Pencil', child: Text('Pencil')),
          PopupMenuItem(value: 'Eraser', child: Text('Eraser')),
          PopupMenuItem(value: 'Text', child: Text('Text Mode')),
          PopupMenuItem(value: 'Undo', child: Text('Undo')),
          PopupMenuItem(value: 'Redo', child: Text('Redo')),
          PopupMenuItem(value: 'Handwriting', child: Text('Handwriting')),
          PopupMenuItem(value: 'Export PDF', child: Text('Export to PDF')),
          PopupMenuItem(value: 'Edit Paper', child: Text('Edit Paper')),
          PopupMenuItem(value: 'Save', child: Text('Save Drawing')),
        ],
      ),
    ];
  }

  void _handleMoreMenuAction(String value) {
    switch (value) {
      case 'Pencil':
        setState(() => selectedMode = DrawingMode.pencil);
        break;
      case 'Eraser':
        setState(() => selectedMode = DrawingMode.eraser);
        break;
      case 'Text':
        setState(() => selectedMode = DrawingMode.text);
        break;
      case 'Undo':
        if (_drawingDBService.canUndo()) {
          setState(() => _drawingDBService.undo());
        }
        break;
      case 'Redo':
        if (_drawingDBService.canRedo()) {
          setState(() => _drawingDBService.redo());
        }
        break;
      case 'Export PDF':
        exportToPdf();
        break;
      case 'Edit Paper':
        _showEditPaperDialog();
        break;
      case 'Save':
        _saveDrawing();
        break;
    }
  }

  List<Widget> _buildFullActions() {
    return [
      IconButton(
        icon: Icon(
          Icons.edit,
          color: selectedMode == DrawingMode.pencil ? Colors.blue : null,
        ),
        onPressed: () => setState(() => selectedMode = DrawingMode.pencil),
        tooltip: 'Pencil',
      ),
      IconButton(
        icon: FaIcon(
          FontAwesomeIcons.eraser,
          color: selectedMode == DrawingMode.eraser ? Colors.blue : null,
        ),
        onPressed: () => setState(() => selectedMode = DrawingMode.eraser),
        tooltip: 'Eraser',
      ),
      IconButton(
        icon: Icon(
          Icons.circle,
          color: selectedMode == DrawingMode.bubble ? Colors.blue : null,
        ),
        onPressed: () => setState(() => selectedMode = DrawingMode.bubble),
        tooltip: 'Bubble',
      ),
      IconButton(
        icon: Icon(
          Icons.text_fields,
          color: selectedMode == DrawingMode.text ? Colors.blue : null,
        ),
        onPressed: () => setState(() => selectedMode = DrawingMode.text),
        tooltip: 'Text',
      ),
      IconButton(
        // Add pointing finger icon for reading mode
        icon: FaIcon(
          FontAwesomeIcons.handPointer, // Or Icons.touch_app for Material icon
          color: selectedMode == DrawingMode.read ? Colors.blue : null,
        ),
        onPressed: () => setState(() => selectedMode = DrawingMode.read),
        tooltip: 'Reading Mode',
      ),
      IconButton(
        icon: const Icon(Icons.undo),
        onPressed: _drawingDBService.canUndo()
            ? () => setState(() => _drawingDBService.clickUndo())
            : null,
        tooltip: 'Undo',
      ),
      IconButton(
        icon: const Icon(Icons.redo),
        onPressed: _drawingDBService.canRedo()
            ? () => setState(() => _drawingDBService.clickRedo())
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
        icon: const Icon(Icons.book),
        onPressed: () {
          showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Dismiss',
            pageBuilder: (context, animation, secondaryAnimation) {
              return Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.white,
                  elevation: 8,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width *
                        0.35, // Adjust width as needed
                    height: MediaQuery.of(context).size.height,
                    child: ManagePaperDBPage(
                      fileId: widget.fileId,
                      paperDBProvider: Provider.of<PaperDBProvider>(context),
                      roomId: widget.roomId,
                      drawingDBService: _drawingDBService,
                    ),
                  ),
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
            transitionBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0), // From right
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ).then((_) {
            // Call _reloadPaperData when the dialog is closed
            _reloadPaperData();
          });
        },
        tooltip: 'Edit Paper',
      )
      // IconButton(
      //   icon: const Icon(Icons.share),
      //   tooltip: 'Share this file',
      //   onPressed: () {
      //     showDialog(
      //       context: context,
      //       builder: (context) => ShareDialog(
      //           fileId: widget.fileId, fileName: widget.name),
      //     );
      //   },
      // ),
    ];
  }

  void _showEditPaperDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.white,
            elevation: 8,
            child: SizedBox(
              width: isPhone ? screenWidth * 0.7 : screenWidth * 0.35,
              height: MediaQuery.of(context).size.height,
              child: ManagePaperDBPage(
                fileId: widget.fileId,
                paperDBProvider: Provider.of<PaperDBProvider>(context),
                roomId: widget.roomId,
                drawingDBService: _drawingDBService,
              ),
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
    ).then((_) {
      _reloadPaperData();
    });
  }

  Widget buildPaperCanvas(double totalHeight, List<Map<String, dynamic>> papers,
      PaperProvider paperProvider, PaperDBProvider paperDBProvider) {
    return GestureDetector(
      // Detect taps on the background (outside paper)
      onTapDown: (TapDownDetails details) {
        // Deselect all text annotations when tapping outside the paper
        for (String paperId
            in paperProvider.getPaperIdsByFileId(widget.fileId)) {
          if (!_isDrawing) {
            _drawingDBService.deselectAllTextAnnotations(paperId);
            // final annotations =
            //     _drawingDBService.getTextAnnotationsForPage(paperId);
            // for (final annotation in annotations) {
            //   setState(() {
            //     _drawingDBService.updateTextAnnotation(
            //       paperId,
            //       annotation.id,
            //       isEditing: false,
            //       isSelected: false,
            //       isBubble: annotation.isBubble,
            //       finishEdit: true,
            //     );
            //     _isDrawing = false;
            //     _hasUnsavedChanges = true;
            //   });
            // }
          }
          ;
        }
        setState(() {});
      },
      behavior: HitTestBehavior.translucent,
      child: Scrollbar(
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
      ),
    );
  }

  Widget _buildPaperPage(String paperId, PaperProvider paperProvider,
      PaperDBProvider paperDBProvider) {
    final paperDBData = paperDBProvider.getPaperDBById(paperId);

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

            if (paperDBData['background_image'] != '')
              Image.network(
                paperDBData['background_image'],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error: $error');
                  return Center(child: Text('Failed to load image'));
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
                    onPointerCancel: (_) => _handlePointerCancel(),
                    child: CustomPaint(
                      painter: DrawingPainter(
                        drawingPoints:
                            _drawingDBService.getDrawingPointsForPage(paperId),
                      ),
                      size: Size(paperWidth, paperHeight),
                    ),
                  ),
            ...(_drawingDBService
                .getTextAnnotationsForPage(paperId)
                .sorted((a, b) {
              // Editing annotations come last, then selected ones
              if (a.isEditing != b.isEditing) {
                return a.isEditing ? 1 : -1;
              } else if (a.isSelected != b.isSelected) {
                return a.isSelected ? 1 : -1;
              }
              return 0;
            }).map((annotation) {
              return TextAnnotationWidget(
                annotation: annotation,
                canvasWidth: paperWidth,
                canvasHeight: paperHeight,
                onTextChanged: (text) {
                  if ((selectedMode == DrawingMode.text &&
                          !annotation.isBubble) ||
                      (annotation.isBubble)) {
                    setState(() {
                      _isDrawing = true;
                      _drawingDBService.updateTextAnnotation(
                        paperId,
                        annotation.id,
                        text: text,
                        isBubble: annotation.isBubble,
                      );
                      _hasUnsavedChanges = true;
                    });
                  }
                },
                onPositionChanged: (position) {
                  if ((selectedMode == DrawingMode.text &&
                          !annotation.isBubble) ||
                      (annotation.isBubble)) {
                    setState(() {
                      _isDrawing = true;
                      _drawingDBService.updateTextAnnotation(
                        paperId,
                        annotation.id,
                        position: position,
                        isBubble: annotation.isBubble,
                      );
                      _hasUnsavedChanges = true;
                    });
                  }
                },
                onStartEditing: () {
                  if ((selectedMode == DrawingMode.text &&
                          !annotation.isBubble) ||
                      (annotation.isBubble)) {
                    _isDrawing = true;
                    setState(() {
                      _drawingDBService.updateTextAnnotation(
                        paperId,
                        annotation.id,
                        isEditing: true,
                        isSelected: false,
                        color: selectedColor,
                        fontSize: selectedFontSize,
                        isBold: selectedTextBold,
                        isItalic: selectedTextItalic,
                        isBubble: annotation.isBubble,
                      );
                    });
                  }
                },
                onDelete: () {
                  if ((selectedMode == DrawingMode.text &&
                          !annotation.isBubble) ||
                      (annotation.isBubble)) {
                    setState(() {
                      _isDrawing = false;
                      _drawingDBService.deleteTextAnnotation(
                        paperId,
                        annotation.id,
                        annotation.isBubble,
                      );
                      _hasUnsavedChanges = true;
                    });
                  }
                },
                onEditingComplete: () {
                  setState(() {
                    _isDrawing = false;
                    _drawingDBService.updateTextAnnotation(
                      paperId,
                      annotation.id,
                      isEditing: false,
                      isSelected: false,
                      color: selectedColor,
                      fontSize: selectedFontSize,
                      isBold: selectedTextBold,
                      isItalic: selectedTextItalic,
                      isBubble: annotation.isBubble,
                      finishEdit: true,
                    );
                    _hasUnsavedChanges = true;
                  });
                },
                onTap: () {
                  if ((selectedMode == DrawingMode.text &&
                          !annotation.isBubble) ||
                      (annotation.isBubble)) {
                    setState(() {
                      _drawingDBService.updateTextAnnotation(
                        paperId,
                        annotation.id,
                        isSelected: true,
                        color: annotation.color,
                        isBubble: annotation.isBubble,
                      );
                    });
                  }
                },
                onColorChanged: selectedColor,
                fontSize: selectedFontSize,
                isBold: selectedTextBold,
                isItalic: selectedTextItalic,
                settingsBarKey: _settingsBarKey,
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  int _activePointerCount = 0;
  Timer? _drawingDelayTimer;
  // static const _drawingDelayDuration = Duration(milliseconds: 80);

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
      bool foundEditingAnnotation = false;

      for (final annotation
          in _drawingDBService.getTextAnnotationsForPage(paperId)) {
        if (annotation.isEditing) {
          _drawingDBService.updateTextAnnotation(
            paperId,
            annotation.id,
            isEditing: false,
            isSelected: false,
            isBubble: annotation.isBubble,
          );

          foundEditingAnnotation = true;
          _hasUnsavedChanges = true;
          setState(() {
            _isDrawing = false;
          });

          // If we found an annotation in edit mode, exit early
          // This prevents immediate creation of a new annotation
          if (foundEditingAnnotation) {
            return;
          }
        }
      }

      if (selectedMode == DrawingMode.text) {
        // Check if we clicked on an existing text annotation
        bool clickedOnText = false;
        final textAnnotations =
            _drawingDBService.getTextAnnotationsForPage(paperId);

        _drawingDBService.deselectAllTextAnnotations(paperId);

        for (final annotation in textAnnotations) {
          // Simple hit test - could be improved with more precise text bounds
          final textWidth =
              _calculateTextWidth(annotation.text, annotation.fontSize);
          final textHeight =
              annotation.fontSize * 1.5; // Approximate height based on fontSize

          final rect = Rect.fromLTWH(annotation.position.dx,
              annotation.position.dy, textWidth, textHeight);

          if (rect.contains(localPosition)) {
            clickedOnText = true;
            setState(() {
              _drawingDBService.updateTextAnnotation(
                paperId,
                annotation.id,
                isSelected: true,
                color: annotation.color,
                fontSize: annotation.fontSize,
                isBold: annotation.isBold,
                isItalic: annotation.isItalic,
                isBubble: annotation.isBubble,
              );
            });
            break;
          }
        }

        if (!clickedOnText) {
          // Create a new text annotation at this position with current settings
          setState(() {
            _isDrawing = true;
            _drawingDBService.deselectAllTextAnnotations(paperId);
            _drawingDBService.addTextAnnotation(
                paperId,
                localPosition,
                selectedColor,
                selectedFontSize,
                selectedTextBold,
                selectedTextItalic,
                false);
            _hasUnsavedChanges = true;
          });
        }
        return;
      }

      if (selectedMode == DrawingMode.bubble) {
        // Check if we clicked on an existing text annotation
        bool clickedOnText = false;
        final textAnnotations =
            _drawingDBService.getTextAnnotationsForPage(paperId);

        _drawingDBService.deselectAllTextAnnotations(paperId);

        for (final annotation in textAnnotations) {
          // Simple hit test - could be improved with more precise text bounds
          final textWidth =
              _calculateTextWidth(annotation.text, annotation.fontSize);
          final textHeight =
              annotation.fontSize * 1.5; // Approximate height based on fontSize

          final rect = Rect.fromLTWH(annotation.position.dx,
              annotation.position.dy, textWidth, textHeight);

          if (rect.contains(localPosition)) {
            clickedOnText = true;
            setState(() {
              _drawingDBService.updateTextAnnotation(
                paperId,
                annotation.id,
                isSelected: true,
                color: annotation.color,
                fontSize: annotation.fontSize,
                isBold: annotation.isBold,
                isItalic: annotation.isItalic,
                isBubble: annotation.isBubble,
              );
            });
            break;
          }
        }

        if (!clickedOnText) {
          // Create a new text annotation at this position with current settings
          setState(() {
            _isDrawing = true;
            _drawingDBService.deselectAllTextAnnotations(paperId);
            _drawingDBService.addTextAnnotation(
                paperId,
                localPosition,
                selectedColor,
                selectedFontSize,
                selectedTextBold,
                selectedTextItalic,
                true);
            _hasUnsavedChanges = true;
          });
        }
        return;
      }
      // _drawingDelayTimer = Timer(_drawingDelayDuration, () {
      // Only proceed if we still have exactly one finger down
      if (_activePointerCount == 1 && mounted) {
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

    // Only continue drawing if exactly one finger is down
    if (_activePointerCount == 1 && _isDrawing) {
      setState(() {
        _isDrawing = true;
      });
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
        _drawingDBService.endDrawing(paperId);
      } else if (selectedMode == DrawingMode.eraser) {
        _drawingDBService.endErasing(paperId);
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
    // if (_roleUpdateListener != null) {
    //   roomDBProvider.removeListener(_roleUpdateListener!);
    // }

    _controller.dispose();
    _scrollController.dispose();
    _drawingDBService.leavefile();
    _drawingDBService.disposeListeners();
    super.dispose();
  }
}

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

double _calculateTextWidth(String text, double fontSize) {
  if (text.isEmpty) return 0;

  // Basic calculation based on average character width
  // This is an approximation - for more accuracy you would need TextPainter
  final avgCharWidth =
      fontSize * 0.6; // Approximate width of an average character
  return text.length * avgCharWidth;
}

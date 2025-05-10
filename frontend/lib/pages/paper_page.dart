// Main file: paper_page.dart
// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:frontend/widget/manage_paper_page.dart';
import 'package:frontend/widget/text_annotation_widget.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:frontend/widget/tool_bar.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/services/drawing_service.dart';
import 'package:frontend/services/pdf_export_service.dart';
import 'package:frontend/services/paper_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as ml_kit;
import 'package:frontend/services/textRecognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DrawingMode { pencil, eraser, handwriting, text, read, bubble }

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

  double selectedFontSize = 16.0;
  TextAlign selectedTextAlign = TextAlign.left;
  bool selectedTextBold = false;
  bool selectedTextItalic = false;
  bool get isReadOnly => selectedMode == DrawingMode.read;

  final List<Color> availableColors = const [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
  ];

  // Digital Ink Recognition related variables
  bool _isHandwritingMode = false;
  Map<String, List<TextRecognitionResult>> _recognizedTexts = {};
  final ml_kit.DigitalInkRecognizer _digitalInkRecognizer =
      ml_kit.DigitalInkRecognizer(languageCode: 'en');
  final ml_kit.DigitalInkRecognizerModelManager _modelManager =
      ml_kit.DigitalInkRecognizerModelManager();
  final ml_kit.Ink _ink = ml_kit.Ink();
  List<ml_kit.StrokePoint> _strokePoints = [];
  String recognizedText = '';
  bool _modelDownloaded = false;
  var _language = 'en';

  @override
  void initState() {
    super.initState();
    _drawingService = DrawingService();
    _paperService = PaperService();
    _pdfExportService = PDFExportService();
    _loadModelStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final paperProvider = Provider.of<PaperProvider>(context, listen: false);

      // Load folders for the specific room
      paperProvider.loadPapers();

      _loadDrawingData();
      _centerContent();
    });
  }

  Future<void> _loadModelStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isDownloaded = prefs.getBool('ml_model_downloaded') ?? false;
    setState(() {
      _modelDownloaded = isDownloaded;
    });
  }

  void _onHandwritingModeSelected() async {
    if (_modelDownloaded) {
      setState(() {
        selectedMode = DrawingMode.handwriting;
        _isHandwritingMode = true;
      });
    } else {
      final shouldDownload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Download ML Model?'),
          content: const Text(
              'To use handwriting recognition, the language model needs to be downloaded. Do you want to download it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Download'),
            ),
          ],
        ),
      );

      if (shouldDownload == true) {
        await _downloadModel();
        if (_modelDownloaded) {
          setState(() {
            selectedMode = DrawingMode.handwriting;
            _isHandwritingMode = true;
          });
        }
      }
    }
  }

  Future<void> _downloadModel() async {
    try {
      final bool response = await _modelManager.downloadModel(_language);
      if (response) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('ml_model_downloaded', true);

        setState(() {
          _modelDownloaded = true;
        });

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

  void _reloadPaperData() {
    final paperProvider = context.read<PaperProvider>();

    _drawingService.loadFromProvider(paperProvider, widget.fileId);

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
        paperProvider, paperDBProvider, widget.fileId, false);

    // Load selected text properties from selected annotation
    final selectedTextAnnotation = _drawingService.getSelectedTextAnnotation();
    if (selectedTextAnnotation != null && selectedMode == DrawingMode.text) {
      selectedFontSize = selectedTextAnnotation.fontSize;
      selectedTextBold = selectedTextAnnotation.isBold;
      selectedTextItalic = selectedTextAnnotation.isItalic;
    }

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
          // Add the text settings bar when in text mode
          if (selectedMode == DrawingMode.text)
            buildTextSettingsBar(
              selectedColor: selectedColor,
              availableColors: availableColors,
              onColorChanged: (color) {
                setState(() {
                  selectedColor = color;

                  // Update the selected annotation if there is one
                  final selectedAnnotation =
                      _drawingService.getSelectedTextAnnotation();
                  if (selectedAnnotation != null) {
                    final pageIds = _drawingService.getPageIds();
                    for (final pageId in pageIds) {
                      final annotations =
                          _drawingService.getTextAnnotationsForPage(pageId);
                      if (annotations.contains(selectedAnnotation)) {
                        _drawingService.updateTextAnnotation(
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
                      _drawingService.getSelectedTextAnnotation();
                  if (selectedAnnotation != null) {
                    final pageIds = _drawingService.getPageIds();
                    for (final pageId in pageIds) {
                      final annotations =
                          _drawingService.getTextAnnotationsForPage(pageId);
                      if (annotations.contains(selectedAnnotation)) {
                        _drawingService.updateTextAnnotation(
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
                      _drawingService.getSelectedTextAnnotation();
                  if (selectedAnnotation != null) {
                    final pageIds = _drawingService.getPageIds();
                    for (final pageId in pageIds) {
                      final annotations =
                          _drawingService.getTextAnnotationsForPage(pageId);
                      if (annotations.contains(selectedAnnotation)) {
                        _drawingService.updateTextAnnotation(
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
                      _drawingService.getSelectedTextAnnotation();
                  if (selectedAnnotation != null) {
                    final pageIds = _drawingService.getPageIds();
                    for (final pageId in pageIds) {
                      final annotations =
                          _drawingService.getTextAnnotationsForPage(pageId);
                      if (annotations.contains(selectedAnnotation)) {
                        _drawingService.updateTextAnnotation(
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
                      _drawingService.getSelectedTextAnnotation();
                  if (selectedAnnotation != null) {
                    final pageIds = _drawingService.getPageIds();
                    for (final pageId in pageIds) {
                      final annotations =
                          _drawingService.getTextAnnotationsForPage(pageId);
                      if (annotations.contains(selectedAnnotation)) {
                        _drawingService.updateTextAnnotation(
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
          tooltip: 'Text',
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
            FontAwesomeIcons
                .handPointer, // Or Icons.touch_app for Material icon
            color: selectedMode == DrawingMode.read ? Colors.blue : null,
          ),
          onPressed: () => setState(() => selectedMode = DrawingMode.read),
          tooltip: 'Reading Mode',
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
        _isHandwritingMode
            ? IconButton(
                icon: const Icon(
                  Icons.check,
                  color: Colors.red, // Use red to indicate "confirm" action
                ),
                onPressed: () {
                  // Process the handwriting when confirm button is clicked
                  _processHandwritingConfirm();

                  // Toggle handwriting mode off
                  setState(() {
                    _isHandwritingMode = false;
                    selectedMode =
                        DrawingMode.pencil; // Switch back to pencil mode
                  });
                },
                tooltip: 'Confirm Handwriting',
              )
            : IconButton(
                icon: FaIcon(FontAwesomeIcons.signature),
                onPressed: () {
                  _onHandwritingModeSelected();
                },
                tooltip: 'Handwriting Mode',
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
                      child: ManagePaperPage(
                        fileId: widget.fileId,
                        paperProvider: Provider.of<PaperProvider>(context),
                      ),
                    ),
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
              transitionBuilder:
                  (context, animation, secondaryAnimation, child) {
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
    return GestureDetector(
      // Detect taps on the background (outside paper)
      onTapDown: (TapDownDetails details) {
        // Deselect all text annotations when tapping outside the paper
        for (String paperId
            in paperProvider.getPaperIdsByFileId(widget.fileId)) {
          if (!_isDrawing) {
            _drawingService.deselectAllTextAnnotations(paperId);
            final annotations =
                _drawingService.getTextAnnotationsForPage(paperId);
            for (final annotation in annotations) {
              if (annotation.isEditing) {
                setState(() {
                  _drawingService.updateTextAnnotation(
                    paperId,
                    annotation.id,
                    isEditing: false,
                    isSelected: false,
                    isBubble: annotation.isBubble,
                  );
                  _isDrawing = false;
                  _hasUnsavedChanges = true;
                });
              }
            }
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

            isReadOnly
                ? CustomPaint(
                    painter: DrawingPainter(
                      drawingPoints: _drawingService.getDrawingPointsForPage(
                        paperId,
                      ),
                    ),
                    size: Size(paperWidth, paperHeight),
                  )
                : Listener(
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
            ...(_drawingService
                .getTextAnnotationsForPage(paperId)
                .map((annotation) {
              return TextAnnotationWidget(
                annotation: annotation,
                // Pass canvas dimensions to constrain positions
                canvasWidth: paperWidth,
                canvasHeight: paperHeight,
                onTextChanged: (text) {
                  if ((selectedMode == DrawingMode.text &&
                          !annotation.isBubble) ||
                      (annotation.isBubble) ||
                      (selectedMode == DrawingMode.handwriting)) {
                    setState(() {
                      _isDrawing = true;
                      _drawingService.updateTextAnnotation(
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
                      (annotation.isBubble) ||
                      (selectedMode == DrawingMode.handwriting)) {
                    setState(() {
                      _isDrawing = true;
                      _drawingService.updateTextAnnotation(
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
                      (annotation.isBubble) ||
                      (selectedMode == DrawingMode.handwriting)) {
                    _isDrawing = true;
                    setState(() {
                      _drawingService.updateTextAnnotation(
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
                      (annotation.isBubble) ||
                      (selectedMode == DrawingMode.handwriting)) {
                    setState(() {
                      _isDrawing = false;
                      _drawingService.deleteTextAnnotation(
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
                    _drawingService.updateTextAnnotation(
                      paperId,
                      annotation.id,
                      isEditing: false,
                      isSelected: false,
                      color: selectedColor,
                      fontSize: selectedFontSize,
                      isBold: selectedTextBold,
                      isItalic: selectedTextItalic,
                      isBubble: annotation.isBubble,
                    );
                    _hasUnsavedChanges = true;
                  });
                },
                onTap: () {
                  if ((selectedMode == DrawingMode.text &&
                          !annotation.isBubble) ||
                      (annotation.isBubble) ||
                      (selectedMode == DrawingMode.handwriting)) {
                    setState(() {
                      _drawingService.updateTextAnnotation(
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
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecognizedTexts(String paperId) {
    final texts = _drawingService.getRecognizedTextsForPage(paperId);
    if (texts.isEmpty) {
      return [];
    }

    return texts.map((result) {
      return Positioned(
        left:
            result.position.dx - (result.text.length * result.fontSize * 0.25),
        top: result.position.dy - (result.fontSize * 0.5),
        child: Text(
          result.text,
          style: TextStyle(
            color: result.color,
            fontSize: result.fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }).toList();
  }

  void _clearHandwritingData() {
    _ink.strokes.clear();
    _strokePoints = [];
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
      // Regardless of mode, first check if any text annotation is currently in editing mode
      // If so, save its changes and exit edit mode
      bool foundEditingAnnotation = false;

      for (final annotation
          in _drawingService.getTextAnnotationsForPage(paperId)) {
        if (annotation.isEditing) {
          _drawingService.updateTextAnnotation(
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
            _drawingService.getTextAnnotationsForPage(paperId);

        _drawingService.deselectAllTextAnnotations(paperId);

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
              _drawingService.updateTextAnnotation(
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
            _drawingService.deselectAllTextAnnotations(paperId);
            _drawingService.addTextAnnotation(
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
            _drawingService.getTextAnnotationsForPage(paperId);

        _drawingService.deselectAllTextAnnotations(paperId);

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
              _drawingService.updateTextAnnotation(
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
            _drawingService.deselectAllTextAnnotations(paperId);
            _drawingService.addTextAnnotation(
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

      if (selectedMode == DrawingMode.handwriting && _isHandwritingMode) {
        bool clickedOnText = false;
        final textAnnotations =
            _drawingService.getTextAnnotationsForPage(paperId);

        _drawingService.deselectAllTextAnnotations(paperId);

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
              _drawingService.updateTextAnnotation(
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
          // Start collecting stroke points for handwriting recognition
          _drawingService.startDrawing(
            paperId,
            localPosition,
            selectedColor,
            selectedWidth,
            isHandwriting: true, // Mark this stroke as handwriting
          );

          // Prepare for new stroke points
          _strokePoints = [];

          // Add the first point to our ML Kit stroke
          final ml_kit.StrokePoint strokePoint = ml_kit.StrokePoint(
            x: localPosition.dx,
            y: localPosition.dy,
            t: DateTime.now().millisecondsSinceEpoch,
          );
          _strokePoints.add(strokePoint);

          setState(() {});
        }
      }

      // Handle pencil and eraser modes as before
      if (_activePointerCount == 1 && mounted) {
        setState(() {
          _isDrawing = true;
          _hasUnsavedChanges = true;

          // Deselect all text annotations when drawing
          _drawingService.deselectAllTextAnnotations(paperId);
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
      } else if (selectedMode == DrawingMode.handwriting &&
          _isHandwritingMode) {
        // Continue drawing and collecting stroke points
        _drawingService.continueDrawing(paperId, localPosition);

        // Add point to our ML Kit stroke
        final ml_kit.StrokePoint strokePoint = ml_kit.StrokePoint(
          x: localPosition.dx,
          y: localPosition.dy,
          t: DateTime.now().millisecondsSinceEpoch,
        );
        _strokePoints.add(strokePoint);

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
      } else if (selectedMode == DrawingMode.handwriting) {
        _drawingService.endDrawing();

        // If we have collected points and in handwriting mode, add them to the ink
        // but don't process them immediately
        if (_strokePoints.isNotEmpty) {
          // Add the stroke to the ink
          _ink.strokes.add(ml_kit.Stroke()..points = _strokePoints);

          // Clear stroke points for the next stroke
          _strokePoints = [];
        }
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

  Future<void> _processHandwritingConfirm() async {
    if (!_modelDownloaded || _ink.strokes.isEmpty) return;

    try {
      final List<ml_kit.RecognitionCandidate> candidates =
          await _digitalInkRecognizer.recognize(_ink);

      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text recognized')),
        );
        return;
      }

      final recognizedText = candidates.first.text;

      // Determine bounds of handwriting
      double minX = double.infinity, minY = double.infinity;
      double maxX = -double.infinity, maxY = -double.infinity;

      for (final stroke in _ink.strokes) {
        for (final point in stroke.points) {
          minX = min(minX, point.x);
          maxX = max(maxX, point.x);
          minY = min(minY, point.y);
          maxY = max(maxY, point.y);
        }
      }

      final position = Offset((minX + maxX) / 2, (minY + maxY) / 2);
      final handwritingHeight = maxY - minY;
      final handwritingWidth = maxX - minX;

      double fontSize = handwritingHeight * 0.7;
      fontSize = fontSize.clamp(12.0, 48.0);

      final aspectRatio = handwritingWidth / handwritingHeight;
      if (aspectRatio > 8) fontSize *= 0.7;
      if (aspectRatio < 1) fontSize *= 0.9;

      final String paperId = _drawingService.getCurrentPageId();

      setState(() {
        final annotationId = _drawingService.addTextAnnotation(
          paperId,
          position,
          selectedColor,
          fontSize,
          selectedTextBold,
          selectedTextItalic,
          false,
        );

        if (annotationId != null) {
          final success = _drawingService.updateTextAnnotation(
            paperId,
            annotationId,
            text: recognizedText,
            isEditing: false,
            isSelected: false,
            isBubble: false,
          );

          if (!success) {
            debugPrint('⚠️ Failed to update annotation text.');
          }
        } else {
          debugPrint('⚠️ Failed to add annotation.');
        }

        _drawingService.removeHandwritingStrokes(paperId);
        _ink.strokes.clear();
        _hasUnsavedChanges = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recognized text: $recognizedText')),
      );
    } catch (e) {
      debugPrint('❌ Error in handwriting confirm: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recognizing text: $e')),
      );
    }
  }

  void removeLastStroke(String paperId) {
    final pagePoints = _drawingService.getDrawingPointsForPage(paperId);
    if (pagePoints.isNotEmpty) {
      final lastStrokeId = pagePoints.last.id;
      _drawingService
          .getDrawingPointsForPage(paperId)
          .removeWhere((point) => point.id == lastStrokeId);
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
    _controller.dispose();
    _scrollController.dispose();
    if (_hasUnsavedChanges) _saveDrawing();
    _digitalInkRecognizer.close();
    _clearHandwritingData();
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

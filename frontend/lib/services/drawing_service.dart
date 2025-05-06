// Create file: lib/services/drawing_service.dart

import 'package:flutter/material.dart';
import 'package:frontend/items/text_annotation_item.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/services/textRecognition.dart';

/// Service responsible for managing drawing operations and state
class DrawingService {
  final Map<String, List<DrawingPoint>> _pageDrawingPoints = {};
  final Map<String, List<TextAnnotation>> _pageTextAnnotations = {};

  // Combined state for undo/redo operations
  final List<_DrawingState> _undoStack = [];
  final List<_DrawingState> _redoStack = [];
  final Map<String, List<TextRecognitionResult>> _pageRecognizedTexts = {};
  final Set<int> _handwritingStrokeIds = {};
  String? _currentDrawingPageId;

  List<String> _pageIds = [];
  Map<String, PaperTemplate> _paperTemplates = {};
  DrawingPoint? _currentDrawingPoint;
  TextAnnotation? _selectedTextAnnotation;

  // Eraser configuration
  late EraserTool _eraserTool;
  double _eraserWidth = 10.0;
  EraserMode _eraserMode = EraserMode.point;

  DrawingService() {
    _eraserTool = EraserTool(
      eraserWidth: _eraserWidth,
      eraserMode: _eraserMode,
      pageDrawingPoints: _pageDrawingPoints,
      onStateChanged: _onEraserStateChanged,
      currentPaperId: '',
    );
  }

  String getCurrentPageId() {
    return _currentDrawingPageId ?? '';
  }

  // Public getters
  List<String> getPageIds() => _pageIds;
  Map<String, PaperTemplate> getPaperTemplates() => _paperTemplates;
  Map<String, List<DrawingPoint>> getPageDrawingPoints() => _pageDrawingPoints;
  List<DrawingPoint> getDrawingPointsForPage(String pageId) =>
      _pageDrawingPoints[pageId] ?? [];
  Map<String, List<TextRecognitionResult>> getPageRecognizedTexts() =>
      _pageRecognizedTexts;
  List<TextRecognitionResult> getRecognizedTextsForPage(String pageId) =>
      _pageRecognizedTexts[pageId] ?? [];
  double getEraserWidth() => _eraserWidth;
  EraserMode getEraserMode() => _eraserMode;
  bool canUndo() => _undoStack.isNotEmpty;
  bool canRedo() => _redoStack.isNotEmpty;
  Map<String, List<TextAnnotation>> getPageTextAnnotations() =>
      _pageTextAnnotations;
  List<TextAnnotation> getTextAnnotationsForPage(String pageId) =>
      _pageTextAnnotations[pageId] ?? [];
  TextAnnotation? getSelectedTextAnnotation() => _selectedTextAnnotation;

  // Public setters
  void setEraserWidth(double width) {
    _eraserWidth = width;
    _updateEraserTool();
  }

  void setEraserMode(EraserMode mode) {
    _eraserMode = mode;
    _updateEraserTool();
  }

  void _updateEraserTool() {
    _eraserTool = EraserTool(
      eraserWidth: _eraserWidth,
      eraserMode: _eraserMode,
      pageDrawingPoints: _pageDrawingPoints,
      onStateChanged: _onEraserStateChanged,
      currentPaperId: _eraserTool.currentPaperId,
    );
  }

  void _onEraserStateChanged() {
    // This will be called when the eraser changes state
  }

  PaperTemplate getTemplateForPage(String pageId) {
    return _paperTemplates[pageId] ??
        PaperTemplate(id: 'plain', name: 'Plain Paper');
  }

  PaperTemplate getTemplateForLastPage() {
    if (_pageIds.isEmpty) {
      return PaperTemplate(id: 'plain', name: 'Plain Paper', spacing: 30.0);
    }

    final lastPageId = _pageIds.last;
    return _paperTemplates[lastPageId] ??
        PaperTemplate(id: 'plain', name: 'Plain Paper', spacing: 30.0);
  }

  // Load drawing data from PaperProvider
  void loadFromProvider(
    PaperProvider provider,
    String fileId, {
    VoidCallback? onDataLoaded,
  }) {
    final papers =
        provider.papers.where((paper) => paper['fileId'] == fileId).toList();
    _pageIds = papers.map((paper) => paper['id'].toString()).toList();
    _loadTemplatesForPapers(_pageIds, provider);
    loadDrawingPoints(_pageIds, provider);
    loadRecognizedTexts(_pageIds, provider); // Add this line

    if (onDataLoaded != null) {
      onDataLoaded();
    }
  }

  void loadRecognizedTexts(List<String> pageIds, PaperProvider paperProvider) {
    _pageRecognizedTexts.clear();

    for (final pageId in pageIds) {
      final paperData = paperProvider.getPaperById(pageId);
      final List<TextRecognitionResult> textsForPage = [];

      if (paperData?['recognizedTexts'] != null) {
        try {
          final List<dynamic> loadedTexts = paperData!['recognizedTexts'];
          for (final textData in loadedTexts) {
            final text = TextRecognitionResult.fromJson(textData);
            textsForPage.add(text);
          }
        } catch (e, stackTrace) {
          debugPrint(
            'Error loading recognized texts for page $pageId: $e\n$stackTrace',
          );
        }
      }

      _pageRecognizedTexts[pageId] = textsForPage;
    }
  }

  void _loadTemplatesForPapers(
    List<String> pageIds,
    PaperProvider paperProvider,
  ) {
    final Map<String, PaperTemplate> tempTemplates = {};

    for (final pageId in pageIds) {
      final paperData = paperProvider.getPaperById(pageId);

      if (paperData != null) {
        final String templateId = paperData['templateId'] ?? 'plain';
        final String typeString =
            paperData['templateType']?.toString() ?? 'plain';

        final TemplateType templateType = switch (typeString) {
          String s when s.contains('lined') => TemplateType.lined,
          String s when s.contains('grid') => TemplateType.grid,
          String s when s.contains('dotted') => TemplateType.dotted,
          _ => TemplateType.plain,
        };

        tempTemplates[pageId] = PaperTemplate(
          id: templateId,
          name: '${templateType.name.capitalize()} Paper',
          spacing: paperData['spacing']?.toDouble() ?? 30.0,
        );
      } else {
        // If no paper data exists for the pageId, set a default template
        tempTemplates[pageId] = PaperTemplate(
          id: 'plain',
          name: 'Plain Paper',
          spacing: 30.0,
        );
      }
    }

    _paperTemplates = tempTemplates;
  }

  void loadDrawingPoints(List<String> pageIds, PaperProvider paperProvider) {
    _pageIds = pageIds;
    _pageDrawingPoints.clear();
    _pageTextAnnotations.clear();
    _undoStack.clear();
    _redoStack.clear();

    for (final pageId in pageIds) {
      final paperData = paperProvider.getPaperById(pageId);
      final List<DrawingPoint> pointsForPage = [];
      final List<TextAnnotation> textAnnotationsForPage = [];

      if (paperData?['drawingData'] != null) {
        try {
          final List<dynamic> loadedStrokes = paperData!['drawingData'];
          for (final stroke in loadedStrokes) {
            if (stroke['type'] == 'drawing') {
              final point = DrawingPoint.fromJson(stroke['data']);
              if (point.offsets.isNotEmpty) {
                pointsForPage.add(point);
              }
            } else if (stroke['type'] == 'text') {
              final annotation = TextAnnotation.fromJson(stroke['data']);
              textAnnotationsForPage.add(annotation);
            }
          }
        } catch (e, stackTrace) {
          debugPrint(
            'Error loading drawing data for page $pageId: $e\n$stackTrace',
          );
        }
      }

      _pageDrawingPoints[pageId] = pointsForPage;
      _pageTextAnnotations[pageId] = textAnnotationsForPage;
    }
  }

  // Drawing operations
  void startDrawing(String pageId, Offset position, Color color, double width,
      {bool isHandwriting = false}) {
    // We'll save state when drawing completes, not when it starts
    _currentDrawingPageId = pageId;

    final int strokeId = DateTime.now().microsecondsSinceEpoch;

    if (isHandwriting) {
      _handwritingStrokeIds.add(strokeId);
    }

    _currentDrawingPoint = DrawingPoint(
      id: strokeId,
      offsets: [position],
      color: color,
      width: width,
      tool: 'pencil',
    );

    _pageDrawingPoints[pageId] ??= [];
    _pageDrawingPoints[pageId]!.add(_currentDrawingPoint!);
  }

  void continueDrawing(String pageId, Offset position) {
    if (_currentDrawingPoint == null) return;

    _currentDrawingPoint = _currentDrawingPoint!.copyWith(
      offsets: List.from(_currentDrawingPoint!.offsets)..add(position),
    );

    _pageDrawingPoints[pageId]!.last = _currentDrawingPoint!;
  }

  // Returns true if drawing was meaningful (more than one point)
  bool endDrawing() {
    if (_currentDrawingPoint == null) return false;

    // Save state only if there are multiple points (meaningful drawing)
    bool isMeaningfulDrawing = _currentDrawingPoint!.offsets.length > 1;

    if (isMeaningfulDrawing) {
      _saveStateForUndo();
      _redoStack.clear();
    }

    _currentDrawingPoint = null;
    return isMeaningfulDrawing;
  }

  // Erasing operations
  void startErasing(String pageId, Offset position) {
    // We'll track if anything was actually erased
    _eraserTool = EraserTool(
      eraserWidth: _eraserWidth,
      eraserMode: _eraserMode,
      pageDrawingPoints: _pageDrawingPoints,
      onStateChanged: _onEraserStateChanged,
      currentPaperId: pageId,
    );

    // Capture the current state before erasing starts
    _tempStateBeforeErasing = _captureCurrentState();
    _eraserTool.handleErasing(position);
  }

  void continueErasing(String pageId, Offset position) {
    _eraserTool.handleErasing(position);
  }

  // Returns true if anything was erased
  bool endErasing() {
    bool anythingErased = false;

    if (_tempStateBeforeErasing != null) {
      // Compare previous state with current state to see if anything changed
      anythingErased = _isStateChanged(_tempStateBeforeErasing!);

      if (anythingErased) {
        // If something was erased, save the previous state for undo
        _undoStack.add(_tempStateBeforeErasing!);
        _redoStack.clear();
      }

      _tempStateBeforeErasing = null;
    }

    _eraserTool.finishErasing();
    return anythingErased;
  }

  // Helper to check if state changed after erasing
  bool _isStateChanged(_DrawingState previousState) {
    // Check if drawing points count changed on any page
    for (final entry in _pageDrawingPoints.entries) {
      final pageId = entry.key;
      final currentPoints = entry.value;
      final previousPoints = previousState.drawingPoints[pageId] ?? [];

      if (currentPoints.length != previousPoints.length) {
        return true;
      }

      // If same count, check if any points were modified (e.g., partial erasing)
      for (int i = 0; i < currentPoints.length; i++) {
        if (currentPoints[i].offsets.length !=
            previousPoints[i].offsets.length) {
          return true;
        }
      }
    }

    return false;
  }

  // Temporary state storage for eraser operations
  _DrawingState? _tempStateBeforeErasing;

  // Undo/Redo operations with support for text annotations
  void undo() {
    if (_undoStack.isEmpty) return;

    // Save current state for redo
    _saveStateForRedo();

    // Restore previous state
    final previousState = _undoStack.removeLast();
    _restoreState(previousState);
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    // Save current state for undo
    _saveStateForUndo();

    // Restore redo state
    final redoState = _redoStack.removeLast();
    _restoreState(redoState);
  }

  void _saveStateForUndo() {
    _undoStack.add(_captureCurrentState());
  }

  void _saveStateForRedo() {
    _redoStack.add(_captureCurrentState());
  }

  _DrawingState _captureCurrentState() {
    // Deep copy of drawing points
    final drawingPointsCopy = <String, List<DrawingPoint>>{};
    _pageDrawingPoints.forEach((pageId, points) {
      drawingPointsCopy[pageId] = points.map((p) => p.copyWith()).toList();
    });

    // Deep copy of text annotations
    final textAnnotationsCopy = <String, List<TextAnnotation>>{};
    _pageTextAnnotations.forEach((pageId, annotations) {
      textAnnotationsCopy[pageId] =
          annotations.map((a) => a.copyWith()).toList();
    });

    return _DrawingState(
      drawingPoints: drawingPointsCopy,
      textAnnotations: textAnnotationsCopy,
    );
  }

  void _restoreState(_DrawingState state) {
    // Restore drawing points
    _pageDrawingPoints.clear();
    _pageDrawingPoints.addAll(state.drawingPoints);

    // Restore text annotations
    _pageTextAnnotations.clear();
    _pageTextAnnotations.addAll(state.textAnnotations);

    // Reset selected annotation
    _selectedTextAnnotation = null;

    // Look for any selected annotation in the restored state
    for (final pageAnnotations in _pageTextAnnotations.values) {
      for (final annotation in pageAnnotations) {
        if (annotation.isSelected) {
          _selectedTextAnnotation = annotation;
          break;
        }
      }
      if (_selectedTextAnnotation != null) break;
    }
  }

  void removeLastStroke(String paperId) {
    final points = _pageDrawingPoints[paperId];
    if (points == null || points.isEmpty) return;

    final lastId = points.last.id;

    points.removeWhere((point) => point.id == lastId);

    // Update state
    _pageDrawingPoints[paperId] = points;
  }

  // Save drawing to persistent storage
  Future<void> saveDrawings(PaperProvider paperProvider) async {
    for (final pageId in _pageIds) {
      // Save drawing points
      final pointsForPage = _pageDrawingPoints[pageId] ?? [];
      final textAnnotationsForPage = _pageTextAnnotations[pageId] ?? [];

      final List<Map<String, dynamic>> cleanHistory = [];

      // Add drawing points
      for (final point in pointsForPage) {
        cleanHistory.add({
          'type': 'drawing',
          'data': point.toJson(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Add text annotations
      for (final annotation in textAnnotationsForPage) {
        cleanHistory.add({
          'type': 'text',
          'data': annotation.toJson(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      await paperProvider.updatePaperDrawingData(pageId, cleanHistory);

      // Save recognized texts
      final textsForPage = _pageRecognizedTexts[pageId] ?? [];
      final textsJson = textsForPage.map((text) => text.toJson()).toList();
      await paperProvider.updatePaperRecognizedTexts(pageId, textsJson);
    }
  }

  void addRecognizedText(String pageId, TextRecognitionResult text) {
    _pageRecognizedTexts[pageId] ??= [];
    _pageRecognizedTexts[pageId]!.add(text);
  }

  void removeHandwritingStrokes(String pageId) {
    if (!_pageDrawingPoints.containsKey(pageId)) return;

    _saveStateForUndo();
    final pointsList = _pageDrawingPoints[pageId]!;
    pointsList.removeWhere((point) => _handwritingStrokeIds.contains(point.id));

    _handwritingStrokeIds.clear();
  }

  bool isHandwritingStroke(int strokeId) {
    return _handwritingStrokeIds.contains(strokeId);
  }

  void clearHandwritingData() {
    _handwritingStrokeIds.clear();
  }

  // Returns true if update was successful
  bool updateTextAnnotation(
    String pageId,
    String annotationId, {
    String? text,
    Offset? position,
    Color? color,
    double? fontSize,
    bool? isEditing,
    bool? isSelected,
    bool? isBold,
    bool? isItalic,
  }) {
    if (_pageTextAnnotations[pageId] == null) return false;

    final index =
        _pageTextAnnotations[pageId]!.indexWhere((a) => a.id == annotationId);
    if (index == -1) return false;

    // If we're making significant changes (not just selection states),
    // and coming out of edit mode, save state for undo
    bool significantChange = text != null ||
        position != null ||
        color != null ||
        fontSize != null ||
        isBold != null ||
        isItalic != null;
    bool finishingEdit = isEditing == false &&
        _pageTextAnnotations[pageId]![index].isEditing == true;

    if (significantChange && finishingEdit) {
      _saveStateForUndo();
      _redoStack.clear();
    }

    final annotation = _pageTextAnnotations[pageId]![index];
    _pageTextAnnotations[pageId]![index] = annotation.copyWith(
      text: text ?? annotation.text,
      position: position ?? annotation.position,
      color: color ?? annotation.color,
      fontSize: fontSize ?? annotation.fontSize,
      isEditing: isEditing ?? annotation.isEditing,
      isSelected: isSelected ?? annotation.isSelected,
      isBold: isBold ?? annotation.isBold,
      isItalic: isItalic ?? annotation.isItalic,
    );

    if (isSelected == true) {
      // Deselect all other annotations
      for (int i = 0; i < _pageTextAnnotations[pageId]!.length; i++) {
        if (i != index) {
          _pageTextAnnotations[pageId]![i] =
              _pageTextAnnotations[pageId]![i].copyWith(
            isSelected: false,
            isEditing: false,
          );
        }
      }
      _selectedTextAnnotation = _pageTextAnnotations[pageId]![index];
    }

    if (isSelected == false && _selectedTextAnnotation?.id == annotationId) {
      _selectedTextAnnotation = null;
    }

    return true;
  }

  // Returns the ID of the new annotation if successful, null otherwise
  String? addTextAnnotation(
    String pageId,
    Offset position,
    Color color,
    double fontSize,
    bool isBold,
    bool isItalic,
  ) {
    // We'll save state only when the annotation is completed (not empty text)
    // So we don't save state here, but when the user finishes editing
    _saveStateForUndo();
    _redoStack.clear();

    final String annotationId =
        DateTime.now().microsecondsSinceEpoch.toString();
    final newAnnotation = TextAnnotation(
      id: annotationId,
      text: '',
      position: position,
      color: color,
      fontSize: fontSize,
      isBold: isBold,
      isItalic: isItalic,
      isEditing: true,
      isSelected: true,
    );

    _pageTextAnnotations[pageId] ??= [];
    _pageTextAnnotations[pageId]!.add(newAnnotation);
    _selectedTextAnnotation = newAnnotation;

    return annotationId;
  }

  // Returns true if deletion was successful
  bool deleteTextAnnotation(String pageId, String annotationId) {
    if (_pageTextAnnotations[pageId] == null) return false;

    final index =
        _pageTextAnnotations[pageId]!.indexWhere((a) => a.id == annotationId);
    if (index == -1) return false;

    final annotation = _pageTextAnnotations[pageId]![index];

    // Only save state if we're deleting a non-empty annotation
    if (annotation.text.trim().isNotEmpty) {
      _saveStateForUndo();
      _redoStack.clear();
    }

    _pageTextAnnotations[pageId]!.removeAt(index);

    if (_selectedTextAnnotation?.id == annotationId) {
      _selectedTextAnnotation = null;
    }

    return true;
  }

  // Returns true if any non-empty annotations were deselected
  bool deselectAllTextAnnotations(String pageId) {
    if (_pageTextAnnotations[pageId] == null) return false;

    final annotations = _pageTextAnnotations[pageId]!;

    // Check if there are any non-empty selected annotations that were being edited
    bool hadMeaningfulEdits = annotations
        .any((a) => (a.isSelected || a.isEditing) && a.text.trim().isNotEmpty);

    // Check for empty annotations to remove
    List<TextAnnotation> emptyAnnotations =
        annotations.where((a) => a.text.trim().isEmpty).toList();

    // If we had meaningful edits being committed, save state
    if (hadMeaningfulEdits) {
      _saveStateForUndo();
      _redoStack.clear();
    }

    // Remove annotations with empty text
    if (emptyAnnotations.isNotEmpty) {
      annotations.removeWhere((annotation) => annotation.text.trim().isEmpty);
    }

    // Deselect the rest
    for (int i = 0; i < annotations.length; i++) {
      annotations[i] = annotations[i].copyWith(
        isSelected: false,
        isEditing: false,
      );
    }

    _selectedTextAnnotation = null;
    return hadMeaningfulEdits;
  }

  // Merge text annotations functionality
  // Returns the ID of the merged annotation if successful, null otherwise
  String? mergeTextAnnotations(String pageId, List<String> annotationIds) {
    if (_pageTextAnnotations[pageId] == null || annotationIds.length < 2)
      return null;

    // Get all annotations to merge
    final annotationsToMerge = _pageTextAnnotations[pageId]!
        .where((a) => annotationIds.contains(a.id))
        .toList();

    if (annotationsToMerge.isEmpty) return null;

    // Check if all annotations to merge have text
    bool allHaveText =
        annotationsToMerge.every((a) => a.text.trim().isNotEmpty);

    if (allHaveText) {
      _saveStateForUndo();
      _redoStack.clear();
    }

    // Sort by vertical position (top to bottom)
    annotationsToMerge.sort((a, b) => a.position.dy.compareTo(b.position.dy));

    // Create merged text
    final mergedText = annotationsToMerge.map((a) => a.text).join('\n');

    // Use properties from the first annotation
    final first = annotationsToMerge.first;
    final String newId = DateTime.now().microsecondsSinceEpoch.toString();
    final mergedAnnotation = TextAnnotation(
      id: newId,
      text: mergedText,
      position: first.position,
      color: first.color,
      fontSize: first.fontSize,
      isEditing: false,
      isSelected: true,
      isBold: first.isBold,
      isItalic: first.isItalic,
    );

    // Remove old annotations
    _pageTextAnnotations[pageId]!
        .removeWhere((a) => annotationIds.contains(a.id));

    // Add new merged annotation
    _pageTextAnnotations[pageId]!.add(mergedAnnotation);
    _selectedTextAnnotation = mergedAnnotation;

    return newId;
  }
}

// Private class to represent drawing state for undo/redo operations
class _DrawingState {
  final Map<String, List<DrawingPoint>> drawingPoints;
  final Map<String, List<TextAnnotation>> textAnnotations;

  _DrawingState({
    required this.drawingPoints,
    required this.textAnnotations,
  });
}

extension StringCapitalizeExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

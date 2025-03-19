// Create file: lib/services/drawing_service.dart

import 'package:flutter/material.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/providers/paper_provider.dart';

/// Service responsible for managing drawing operations and state
class DrawingService {
  final Map<String, List<DrawingPoint>> _pageDrawingPoints = {};
  final List<Map<String, List<DrawingPoint>>> _undoStack = [];
  final List<Map<String, List<DrawingPoint>>> _redoStack = [];

  List<String> _pageIds = [];
  Map<String, PaperTemplate> _paperTemplates = {};
  DrawingPoint? _currentDrawingPoint;

  // Eraser configuration
  late EraserTool _eraserTool;
  double _eraserWidth = 10.0;
  EraserMode _eraserMode = EraserMode.point;

  DrawingService() {
    _eraserTool = EraserTool(
      eraserWidth: _eraserWidth,
      eraserMode: _eraserMode,
      pageDrawingPoints: _pageDrawingPoints,
      undoStack: _undoStack,
      redoStack: _redoStack,
      onStateChanged: _onEraserStateChanged,
      currentPaperId: '',
    );
  }

  // Public getters
  List<String> getPageIds() => _pageIds;
  Map<String, PaperTemplate> getPaperTemplates() => _paperTemplates;
  Map<String, List<DrawingPoint>> getPageDrawingPoints() => _pageDrawingPoints;
  List<DrawingPoint> getDrawingPointsForPage(String pageId) =>
      _pageDrawingPoints[pageId] ?? [];
  double getEraserWidth() => _eraserWidth;
  EraserMode getEraserMode() => _eraserMode;
  bool canUndo() => _undoStack.isNotEmpty;
  bool canRedo() => _redoStack.isNotEmpty;

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
      undoStack: _undoStack,
      redoStack: _redoStack,
      onStateChanged: _onEraserStateChanged,
      currentPaperId: _eraserTool.currentPaperId,
    );
  }

  void _onEraserStateChanged() {
    // This will be called when the eraser changes state
  }

  PaperTemplate getTemplateForPage(String pageId) {
    return _paperTemplates[pageId] ??
        PaperTemplate(
          id: 'plain',
          name: 'Plain Paper',
          templateType: TemplateType.plain,
        );
  }

  PaperTemplate getTemplateForLastPage() {
    if (_pageIds.isEmpty) {
      return PaperTemplate(
        id: 'plain',
        name: 'Plain Paper',
        templateType: TemplateType.plain,
        spacing: 30.0,
      );
    }

    final lastPageId = _pageIds.last;
    return _paperTemplates[lastPageId] ??
        PaperTemplate(
          id: 'plain',
          name: 'Plain Paper',
          templateType: TemplateType.plain,
          spacing: 30.0,
        );
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

    if (onDataLoaded != null) {
      onDataLoaded();
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
          templateType: templateType,
          spacing: paperData['spacing']?.toDouble() ?? 30.0,
        );
      } else {
        // If no paper data exists for the pageId, set a default template
        tempTemplates[pageId] = PaperTemplate(
          id: 'plain',
          name: 'Plain Paper',
          templateType: TemplateType.plain,
          spacing: 30.0,
        );
      }
    }

    _paperTemplates = tempTemplates;
  }

  void loadDrawingPoints(List<String> pageIds, PaperProvider paperProvider) {
    _pageIds = pageIds;
    _pageDrawingPoints.clear();
    _undoStack.clear();
    _redoStack.clear();

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

      _pageDrawingPoints[pageId] = pointsForPage;
    }
  }

  // Drawing operations
  void startDrawing(String pageId, Offset position, Color color, double width) {
    // Save current state for undo
    _saveStateForUndo();
    _redoStack.clear();

    _currentDrawingPoint = DrawingPoint(
      id: DateTime.now().microsecondsSinceEpoch,
      offsets: [position],
      color: color,
      width: width,
      isEraser: false,
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

  void endDrawing() {
    _currentDrawingPoint = null;
  }

  // Erasing operations
  void startErasing(String pageId, Offset position) {
    _eraserTool = EraserTool(
      eraserWidth: _eraserWidth,
      eraserMode: _eraserMode,
      pageDrawingPoints: _pageDrawingPoints,
      undoStack: _undoStack,
      redoStack: _redoStack,
      onStateChanged: _onEraserStateChanged,
      currentPaperId: pageId,
    );

    _eraserTool.handleErasing(position);
  }

  void continueErasing(String pageId, Offset position) {
    _eraserTool.handleErasing(position);
  }

  void endErasing() {
    _eraserTool.finishErasing();
  }

  // Undo/Redo operations
  void undo() {
    if (_undoStack.isEmpty) return;

    _redoStack.add(
      _pageDrawingPoints.map(
        (key, value) => MapEntry(key, List<DrawingPoint>.from(value)),
      ),
    );

    final previousState = _undoStack.removeLast();
    _pageDrawingPoints.clear();
    _pageDrawingPoints.addAll(previousState);
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    _saveStateForUndo();

    final redoState = _redoStack.removeLast();
    _pageDrawingPoints.clear();
    _pageDrawingPoints.addAll(redoState);
  }

  void _saveStateForUndo() {
    _undoStack.add(
      _pageDrawingPoints.map(
        (key, value) => MapEntry(key, List<DrawingPoint>.from(value)),
      ),
    );
  }

  // Save drawing to persistent storage
  Future<void> saveDrawings(PaperProvider paperProvider) async {
    for (final pageId in _pageIds) {
      final pointsForPage = _pageDrawingPoints[pageId] ?? [];
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
  }
}

extension StringCapitalizeExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

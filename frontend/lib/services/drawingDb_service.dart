import 'package:flutter/material.dart';
import 'package:frontend/api/socketService.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/items/text_annotation_item.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

/// Service responsible for managing drawing operations and state
class DrawingDBService {
  Function? onDataChanged;
  final Map<String, List<DrawingPoint>> _pageDrawingPoints = {};
  final Map<String, List<TextAnnotation>> _pageTextAnnotations = {};
  final Map<String, List<TextAnnotation>> _pageBubbleAnnotations = {};
  // final Map<String, List<DrawingPoint>> _pageDrawingPointsSocket = {};
  final List<_DrawingState> _undoStack = [];
  final List<_DrawingState> _redoStack = [];

  List<String> _pageIds = [];
  Map<String, PaperTemplate> _paperTemplates = {};
  DrawingPoint? _currentDrawingPoint;
  TextAnnotation? _selectedTextAnnotation;
  String _roomId = '';
  String _fileId = '';
  late SocketService? _socketService;

  // Eraser configuration
  late EraserTool _eraserTool;
  double _eraserWidth = 10.0;
  EraserMode _eraserMode = EraserMode.point;

  List<String> users = [];

  Offset? position = Offset(0, 0);

  DrawingDBService({
    bool isCollab = false,
    String roomId = '',
    String fileId = '',
    SocketService? socketService,
  }) {
    _socketService = socketService;
    _roomId = roomId;
    _fileId = fileId;
    _eraserTool = EraserTool(
      eraserWidth: _eraserWidth,
      eraserMode: _eraserMode,
      pageDrawingPoints: _pageDrawingPoints,
      onStateChanged: _onEraserStateChanged,
      currentPaperId: '',
    );

    _initializeSocketListeners();
    setfile();
  }

  void _initializeSocketListeners() {
    _socketService!.on('file_users_update', (data) {
      users = data['users'].cast<String>();
    });

    // Listen for drawing updates from other clients
    _socketService!.on('drawing', (data) {
      if (data['fileId'] == _fileId) {
        _handleIncomingDrawing(data['drawing'], data['pageId'], data['state']);
      }
    });

    _socketService!.on('updatetext', (data) {
      if (data['fileId'] == _fileId) {
        _handleIncomingTextAnnotationUpdate(
            data['textAnnotation'], data['pageId'], data['isBubble'] ?? false);
      }
    });

    _socketService!.on('deletetext', (data) {
      if (data['fileId'] == _fileId) {
        _handleIncomingTextAnnotationDelete(
            data['annotationId'], data['pageId'], data['isBubble'] ?? false);
      }
    });

    // Add listener for eraser events
    _socketService!.on('eraser', (data) {
      if (data['fileId'] == _fileId) {
        _handleIncomingEraser(
            data['eraserAction'], data['pageId'], data['state']);
      }
    });

    _socketService!.on('canvas_state', (data) {
      if (data['canvasState'] != null &&
          data['textAnnotations'] != null &&
          data['bubbleAnnotations'] != null &&
          data['fileId'] == _fileId) {
        _handleIncomingCanvasState(data['canvasState'], data['textAnnotations'],
            data['bubbleAnnotations'], data['pageId'], data);
      }
    });

    // Add listener for canvas state requests
    _socketService!.on('request_canvas_state', (data) {
      String requestingClientId = data['clientId'];
      String pageId = data['pageId'];

      // Only respond if we have data for this page and we're not the requester
      if (_pageDrawingPoints.containsKey(pageId) &&
          _pageDrawingPoints[pageId]!.isNotEmpty &&
          _socketService!.socket?.id != requestingClientId) {
        _sendCanvasState(pageId, requestingClientId);
      }
    });

    _socketService!.on('undo', (data) {
      if (data['fileId'] == _fileId) {
        undo();
      }
    });

    _socketService!.on('redo', (data) {
      if (data['fileId'] == _fileId) {
        redo();
      }
    });
  }

//--------------------------
  void saveAllDrawingsToDatabase() {
    // Implement your logic to save all drawings to the database
    // This could involve iterating over _pageIds and saving each page's data
    print("Saving all drawings to database...");
    final paperDBProvider = PaperDBProvider();
    for (String pageId in _pageIds) {
      List<DrawingPoint> points = _pageDrawingPoints[pageId] ?? [];
      paperDBProvider.saveDrawingData(pageId, points);
      // Save points to the database for the given pageId
      // Example: paperDBProvider.saveDrawingData(pageId, points);
      List<TextAnnotation> texts = _pageTextAnnotations[pageId] ?? [];
      paperDBProvider.saveTextData(pageId, texts);

      List<TextAnnotation> bubbles = _pageBubbleAnnotations[pageId] ?? [];
      paperDBProvider.saveTextData(pageId, bubbles);
    }
  }

  void setfile() {
    _socketService!.emit('join_file', {
      'roomId': _roomId,
      'fileId': _fileId,
    });
  }

  void leavefile() {
    if (users.length == 1) {
      saveAllDrawingsToDatabase();
    }
    _socketService!.emit('leave_file', {
      'roomId': _roomId,
      'fileId': _fileId,
    });
  }

  void requestCanvasState(String pageId) {
    _socketService!.emit('request_canvas_state', {
      'roomId': _roomId,
      'pageId': pageId,
    });
  }

// Add to your DrawingDBService class
  void _sendCanvasState(String pageId, String requestingClientId) {
    // Serialize drawing points
    List<Map<String, dynamic>> serializedPoints =
        (_pageDrawingPoints[pageId] ?? [])
            .map((point) => point.toJson())
            .toList();

    // Serialize undo stack
    List<Map<String, dynamic>> serializedUndoStack = _undoStack.map((state) {
      return {
        'drawingPoints': {
          for (var entry in state.drawingPoints.entries)
            entry.key: entry.value.map((point) => point.toJson()).toList()
        },
        'textAnnotations': {
          for (var entry in state.textAnnotations.entries)
            entry.key:
                entry.value.map((annotation) => annotation.toJson()).toList()
        },
      };
    }).toList();

    // Serialize redo stack
    List<Map<String, dynamic>> serializedRedoStack = _redoStack.map((state) {
      return {
        'drawingPoints': {
          for (var entry in state.drawingPoints.entries)
            entry.key: entry.value.map((point) => point.toJson()).toList()
        },
        'textAnnotations': {
          for (var entry in state.textAnnotations.entries)
            entry.key:
                entry.value.map((annotation) => annotation.toJson()).toList()
        },
      };
    }).toList();

    Map<String, dynamic> data = {
      "roomId": _roomId,
      "fileId": _fileId,
      "pageId": pageId,
      "clientId": requestingClientId,
      "canvasState": serializedPoints,
      "undoStack": serializedUndoStack,
      "redoStack": serializedRedoStack,
      "textAnnotations": (_pageTextAnnotations[pageId] ?? [])
          .map((annotation) => annotation.toJson())
          .toList(),
      "bubbleAnnotations": (_pageBubbleAnnotations[pageId] ?? [])
          .map((annotation) => annotation.toJson())
          .toList(),
    };

    _socketService!.emit('canvas_state', data);
  }

  void _handleIncomingCanvasState(
      List<dynamic> canvasState,
      List<dynamic> textAnnotation,
      List<dynamic> bubbleAnnotation,
      String pageId,
      Map<String, dynamic> data) {
    if (onDataChanged == null) return;

    _pageDrawingPoints[pageId] = [];
    _pageTextAnnotations.putIfAbsent(pageId, () => []);
    _pageBubbleAnnotations.putIfAbsent(pageId, () => []);

    _pageTextAnnotations[pageId]!.clear();
    _pageBubbleAnnotations[pageId]!.clear();

    // Process each drawing point in the canvas state
    for (var pointData in canvasState) {
      try {
        // Ensure x and y are double values
        List<dynamic> offsetsData = pointData['offsets'];

        // Correctly map the offsets data to Offset objects
        List<Offset> offsets = offsetsData
            .map((e) => Offset(e['x'].toDouble(), e['y'].toDouble()))
            .toList();

        // Create a DrawingPoint instance
        DrawingPoint point = DrawingPoint(
          id: pointData['id'],
          offsets: offsets,
          color: Color(pointData['color']),
          tool: pointData['tool'],
          width: pointData['width'].toDouble(),
        );

        if (point.offsets.isNotEmpty) {
          _pageDrawingPoints[pageId]!.add(point);
        }
      } catch (e) {
        print("Error processing drawing point: $e");
      }
    }

    for (var textData in textAnnotation) {
      try {
        final annotation = TextAnnotation.fromJson(textData);

        // Add to your annotation list
        _pageTextAnnotations[pageId]!.add(annotation);
      } catch (e) {
        print("Error processing text annotation: $e");
      }
    }

    for (var textData in bubbleAnnotation) {
      try {
        print("textData: $textData");
        final annotation = TextAnnotation.fromJson(textData);

        // Add to your annotation list
        _pageBubbleAnnotations[pageId]!.add(annotation);
      } catch (e) {
        print("Error processing text annotation: $e");
      }
    }

    // 🆕 Handle undoStack and redoStack if they exist
    if (data.containsKey('undoStack') && data['undoStack'] != null) {
      _undoStack.clear();
      for (var stateData in data['undoStack']) {
        final state = _parseStateFromJson(stateData);
        if (state != null) {
          _undoStack.add(state);
        }
      }
    }

    if (data.containsKey('redoStack') && data['redoStack'] != null) {
      _redoStack.clear();
      for (var stateData in data['redoStack']) {
        final state = _parseStateFromJson(stateData);
        if (state != null) {
          _redoStack.add(state);
        }
      }
    }

    if (onDataChanged != null) {
      onDataChanged!();
    }
  }

  _DrawingState? _parseStateFromJson(Map<String, dynamic> json) {
    try {
      // Parse drawing points
      final drawingPoints = <String, List<DrawingPoint>>{};
      if (json['drawingPoints'] != null) {
        (json['drawingPoints'] as Map<String, dynamic>)
            .forEach((pageId, points) {
          drawingPoints[pageId] = (points as List)
              .map((pointData) => DrawingPoint.fromJson(pointData))
              .toList();
        });
      }

      // Parse text annotations
      final textAnnotations = <String, List<TextAnnotation>>{};
      if (json['textAnnotations'] != null) {
        (json['textAnnotations'] as Map<String, dynamic>)
            .forEach((pageId, annotations) {
          textAnnotations[pageId] = (annotations as List)
              .map((annotationData) => TextAnnotation.fromJson(annotationData))
              .toList();
        });
      }

      return _DrawingState(
        drawingPoints: drawingPoints,
        textAnnotations: textAnnotations,
      );
    } catch (e) {
      print("Error parsing state from JSON: $e");
      return null;
    }
  }

  void _handleIncomingDrawing(
    Map<String, dynamic> data,
    String pageId,
    String state,
  ) {
    // Check if offsets data is properly formatted
    List<dynamic> offsetsData = data['offsets'];

    List<Offset> offsets = offsetsData
        .map((e) => Offset(e['x'].toDouble(), e['y'].toDouble()))
        .toList();

    DrawingPoint drawingPoint = DrawingPoint(
      id: data['id'],
      offsets: offsets,
      color: Color(data['color']),
      width: data['width'].toDouble(),
      tool: data['tool'],
    );
    if (state == 'start') {
      _saveStateForUndo();
      _redoStack.clear();
      _pageDrawingPoints[pageId] ??= [];
      _pageDrawingPoints[pageId]!.add(drawingPoint);
    } else if (state == 'continue') {
      _pageDrawingPoints[pageId]!.last = drawingPoint;
    } else {
      _currentDrawingPoint = null;
    }

    if (onDataChanged != null) {
      onDataChanged!();
    }
  }

  void _handleIncomingEraser(
      Map<String, dynamic> eraserAction, String pageId, String state) {
    if (!_pageDrawingPoints.containsKey(pageId)) {
      _pageDrawingPoints[pageId] = [];
    }

    String type = eraserAction['type'];
    Map<String, dynamic> positionData = eraserAction['position'];
    Offset position =
        Offset(positionData['x'].toDouble(), positionData['y'].toDouble());
    double width = eraserAction['width'].toDouble();

    // Create or update the eraser tool
    if (state == 'start') {
      _saveStateForUndo();
      _redoStack.clear();

      // Create a new eraser tool for the session
      _eraserTool = EraserTool(
        eraserWidth: width,
        eraserMode: type == 'point' ? EraserMode.point : EraserMode.stroke,
        pageDrawingPoints: _pageDrawingPoints,
        onStateChanged: () {
          if (onDataChanged != null) {
            onDataChanged!();
          }
        },
        currentPaperId: pageId,
      );
    }

    // Apply the eraser action
    _eraserTool.handleErasing(position);

    // Finish erasing if this is the end state
    if (state == 'end') {
      _eraserTool.finishErasing();
    }
  }

  void _handleIncomingTextAnnotationUpdate(
      Map<String, dynamic> data, String pageId, bool isBubble) {
    // Create TextAnnotation object from the received data
    final annotation = TextAnnotation.fromJson(data);

    // Handle based on whether it's a bubble annotation or regular text
    if (isBubble) {
      if (_pageBubbleAnnotations[pageId] == null) {
        // Add new annotation
        _pageBubbleAnnotations.putIfAbsent(pageId, () => []);

        _pageBubbleAnnotations[pageId]!.add(annotation);
      }

      final index = _pageBubbleAnnotations[pageId]!
          .indexWhere((a) => a.id == annotation.id);

      if (index != -1) {
        _pageBubbleAnnotations[pageId]![index] = annotation;
      } else {
        // Add new annotation
        _pageBubbleAnnotations[pageId]!.add(annotation);
      }
    } else {
      if (_pageTextAnnotations[pageId] == null) {
        _saveStateForUndo();
        _redoStack.clear();
        // Add new annotation
        _pageTextAnnotations.putIfAbsent(pageId, () => []);
        _pageTextAnnotations[pageId]!.add(annotation);
      }

      final index = _pageTextAnnotations[pageId]!
          .indexWhere((a) => a.id == annotation.id);

      if (index != -1) {
        // Track if this is a significant change (for undo/redo)
        final oldAnnotation = _pageTextAnnotations[pageId]![index];
        final significantChange = oldAnnotation.text != annotation.text ||
            oldAnnotation.position != annotation.position ||
            oldAnnotation.color != annotation.color ||
            oldAnnotation.fontSize != annotation.fontSize ||
            oldAnnotation.isBold != annotation.isBold ||
            oldAnnotation.isItalic != annotation.isItalic;

        // Save state for undo if this is a significant change and we're finishing editing
        if (significantChange &&
            !annotation.isEditing &&
            oldAnnotation.isEditing) {
          _saveStateForUndo();
          _redoStack.clear();
        }

        _pageTextAnnotations[pageId]![index] = annotation;
      } else {
        _saveStateForUndo();
        _redoStack.clear();
        // Add new annotation
        _pageTextAnnotations[pageId]!.add(annotation);
      }
    }

    // Notify UI to update
    if (onDataChanged != null) {
      onDataChanged!();
    }
  }

  void _handleIncomingTextAnnotationDelete(
      String annotationId, String pageId, bool isBubble) {
    // Handle based on whether it's a bubble annotation or regular text
    if (isBubble) {
      if (_pageBubbleAnnotations[pageId] == null) return;

      final index = _pageBubbleAnnotations[pageId]!
          .indexWhere((a) => a.id == annotationId);

      if (index != -1) {
        _pageBubbleAnnotations[pageId]!.removeAt(index);
      }
    } else {
      if (_pageTextAnnotations[pageId] == null) return;

      final index =
          _pageTextAnnotations[pageId]!.indexWhere((a) => a.id == annotationId);

      if (index != -1) {
        final annotation = _pageTextAnnotations[pageId]![index];

        // Only save state if we're deleting a non-empty annotation
        if (annotation.text.trim().isNotEmpty) {
          _saveStateForUndo();
          _redoStack.clear();
        }

        _pageTextAnnotations[pageId]!.removeAt(index);
      }
    }

    // Clear selected annotation if it was deleted
    if (_selectedTextAnnotation?.id == annotationId) {
      _selectedTextAnnotation = null;
    }

    // Notify UI to update
    if (onDataChanged != null) {
      onDataChanged!();
    }
  }

  void _sendDrawingToServer(
      String pageId, DrawingPoint? drawingPoint, String state) {
    Map<String, dynamic> data = {
      "roomId": _roomId,
      "fileId": _fileId,
      "pageId": pageId,
      "drawing": drawingPoint?.toJson(),
      "sender": getId(),
      "state": state
    };
    _socketService!.emit('drawing', data);
  }

  // Add this method to DrawingDBService to send eraser stroke deletion data
  void _sendStrokeEraserToServer(String pageId, Offset position, String state) {
    Map<String, dynamic> data = {
      "roomId": _roomId,
      "fileId": _fileId,
      "pageId": pageId,
      "eraserAction": {
        "type": "stroke",
        "position": {"x": position.dx, "y": position.dy},
        "width": _eraserWidth,
      },
      "state": state
    };
    _socketService!.emit('eraser', data);
  }

// Add this method to DrawingDBService to send point eraser data
  void _sendPointEraserToServer(String pageId, Offset position, String state) {
    Map<String, dynamic> data = {
      "roomId": _roomId,
      "fileId": _fileId,
      "pageId": pageId,
      "eraserAction": {
        "type": "point",
        "position": {"x": position.dx, "y": position.dy},
        "width": _eraserWidth,
      },
      "state": state,
    };
    _socketService!.emit('eraser', data);
  }

// Similarly, ensure these other methods use the correct event names
  void _sendTextAnnotationUpdateToServer(
      String pageId, TextAnnotation annotation) {
    Map<String, dynamic> data = {
      "roomId": _roomId,
      "fileId": _fileId,
      "pageId": pageId,
      "textAnnotation": annotation.toJson(),
      "sender": getId(),
      "isBubble": annotation.isBubble
    };
    // This should be 'updatetext' to match the listener
    _socketService!.emit('updatetext', data);
  }

  void _sendTextAnnotationDeleteToServer(
      String pageId, int annotationId, bool isBubble) {
    Map<String, dynamic> data = {
      "roomId": _roomId,
      "fileId": _fileId,
      "pageId": pageId,
      "annotationId": annotationId,
      "sender": getId(),
      "isBubble": isBubble
    };
    // This should be 'deletetext' to match the listener
    _socketService!.emit('deletetext', data);
  }

  // Public getters
  List<String> getPageIds() => _pageIds;
  Map<String, PaperTemplate> getPaperTemplates() => _paperTemplates;
  Map<String, List<DrawingPoint>> getPageDrawingPoints() => _pageDrawingPoints;
  String getId() => _socketService!.socket?.id ?? '';
  List<DrawingPoint> getDrawingPointsForPage(String pageId) {
    final localPoints = _pageDrawingPoints[pageId] ?? [];
    return [...localPoints];
  }

  double getEraserWidth() => _eraserWidth;
  EraserMode getEraserMode() => _eraserMode;
  bool canUndo() => _undoStack.isNotEmpty;
  bool canRedo() => _redoStack.isNotEmpty;

  Map<String, List<TextAnnotation>> getPageTextAnnotations() =>
      {..._pageTextAnnotations, ..._pageBubbleAnnotations};

  List<TextAnnotation> getTextAnnotationsForPage(String pageId) =>
      [...?_pageTextAnnotations[pageId], ...?_pageBubbleAnnotations[pageId]];

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
    PaperDBProvider provider,
    String fileId, {
    VoidCallback? onDataLoaded,
  }) {
    final papers =
        provider.papers.where((paper) => paper['file_id'] == fileId).toList();

    _pageIds = papers.map((paper) => paper['id'].toString()).toList();
    _loadTemplatesForPapers(_pageIds, provider);
    loadDrawingPoints(_pageIds, provider);
    print("paperID : $_pageIds");

    if (onDataLoaded != null) {
      onDataLoaded();
    }
  }

  void _loadTemplatesForPapers(
    List<String> pageIds,
    PaperDBProvider paperProvider,
  ) {
    final Map<String, PaperTemplate> tempTemplates = {};

    for (final pageId in pageIds) {
      final paperData = paperProvider.getPaperDBById(pageId);

      final String templateId = paperData['template_id'] ?? 'plain';

      // Get template directly using templateId
      final PaperTemplate template =
          PaperTemplateFactory.getTemplate(templateId);

      tempTemplates[pageId] = template;
    }

    _paperTemplates = tempTemplates;
  }

  void loadDrawingPoints(List<String> pageIds, PaperDBProvider paperProvider) {
    _pageIds = pageIds;
    _pageDrawingPoints.clear();
    _pageTextAnnotations.clear();
    _pageBubbleAnnotations.clear();
    _undoStack.clear();
    _redoStack.clear();
    for (final pageId in pageIds) {
      final paperData = paperProvider.getPaperDBById(pageId);
      final List<DrawingPoint> pointsForPage = [];
      final List<TextAnnotation> textAnnotationsForPage = [];
      final List<TextAnnotation> BubbleAnnotationsForPage = [];

      // Check if 'drawing_data' is not null and is a list
      if (paperData['drawing_data'] != null || paperData['text_data'] != null) {
        try {
          if (paperData['drawing_data'] != null) {
            final List<dynamic> loadedStrokes = paperData['drawing_data'];

            for (final stroke in loadedStrokes) {
              if (stroke['type'] == 'drawing') {
                final point = DrawingPoint.fromJson(stroke);
                if (point.offsets.isNotEmpty) {
                  pointsForPage.add(point);
                }
              }
            }
          } else {
            final List<dynamic> loadedStrokes = paperData['text_data'];

            for (final stroke in loadedStrokes) {
              print("stroke: $stroke");
              if (stroke['type'] == 'text') {
                final annotation = TextAnnotation.fromJson(stroke);

                if (annotation.isBubble) {
                  BubbleAnnotationsForPage.add(annotation);
                } else {
                  textAnnotationsForPage.add(annotation);
                }
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
      _pageTextAnnotations[pageId] = textAnnotationsForPage;
      _pageBubbleAnnotations[pageId] = BubbleAnnotationsForPage;
    }
    for (String pageId in _pageIds) {
      requestCanvasState(pageId);
    }
  }

  // Drawing operations
  void startDrawing(String pageId, Offset position, Color color, double width) {
    // _saveStateForUndo();
    // _redoStack.clear();
    _currentDrawingPoint = DrawingPoint(
      id: DateTime.now().microsecondsSinceEpoch,
      offsets: [position],
      color: color,
      width: width,
      tool: 'pencil',
    );

    _sendDrawingToServer(pageId, _currentDrawingPoint!, "start");
  }

  void continueDrawing(String pageId, Offset position) {
    if (_currentDrawingPoint == null) return;

    _currentDrawingPoint = _currentDrawingPoint!.copyWith(
      offsets: List.from(_currentDrawingPoint!.offsets)..add(position),
    );

    _sendDrawingToServer(pageId, _currentDrawingPoint!, "continue");
  }

  void endDrawing(String pageId) {
    _sendDrawingToServer(pageId, _currentDrawingPoint, "end");
    // _currentDrawingPoint = null;
  }

  // Erasing operations
  void startErasing(String pageId, Offset position) {
    // _saveStateForUndo();
    // _redoStack.clear();
    // _eraserTool = EraserTool(
    //   eraserWidth: _eraserWidth,
    //   eraserMode: _eraserMode,
    //   pageDrawingPoints: _pageDrawingPoints,
    //   onStateChanged: _onEraserStateChanged,
    //   currentPaperId: pageId,
    // );

    // _eraserTool.handleErasing(position);

    if (_eraserMode == EraserMode.point) {
      _sendPointEraserToServer(pageId, position, "start");
    } else if (_eraserMode == EraserMode.stroke) {
      _sendStrokeEraserToServer(pageId, position, "start");
    }
  }

  void continueErasing(String pageId, Offset position) {
    // _eraserTool.handleErasing(position);

    if (_eraserMode == EraserMode.point) {
      _sendPointEraserToServer(pageId, position, "continue");
    } else if (_eraserMode == EraserMode.stroke) {
      _sendStrokeEraserToServer(pageId, position, "continue");
    }
  }

  void endErasing(String pageId) {
    if (_eraserMode == EraserMode.point) {
      _sendPointEraserToServer(pageId, position!, "end");
    } else if (_eraserMode == EraserMode.stroke) {
      _sendStrokeEraserToServer(pageId, position!, "end");
    }
    // _eraserTool.finishErasing();
  }

  void clickUndo() {
    _socketService!.emit('undo', {
      'roomId': _roomId,
      'fileId': _fileId,
    });
    print("undo socket");
  }

  void clickRedo() {
    _socketService!.emit('redo', {
      'roomId': _roomId,
      'fileId': _fileId,
    });
    print("redo socket");
  }

  void undo() {
    if (_undoStack.isEmpty) return;

    // Save current state to redo stack
    _redoStack.add(_captureCurrentState());

    // Restore previous state
    final previousState = _undoStack.removeLast();

    // Clear current state
    _pageDrawingPoints.clear();
    _pageTextAnnotations.clear();

    // Restore from previous state
    previousState.drawingPoints.forEach((pageId, points) {
      _pageDrawingPoints[pageId] = List<DrawingPoint>.from(points);
    });

    previousState.textAnnotations.forEach((pageId, annotations) {
      _pageTextAnnotations[pageId] = List<TextAnnotation>.from(annotations);
    });

    if (onDataChanged != null) {
      onDataChanged!();
    }
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    // Save current state to undo stack
    _saveStateForUndo();

    // Restore redo state
    final redoState = _redoStack.removeLast();

    // Clear current state
    _pageDrawingPoints.clear();
    _pageTextAnnotations.clear();

    // Restore from redo state
    redoState.drawingPoints.forEach((pageId, points) {
      _pageDrawingPoints[pageId] = List<DrawingPoint>.from(points);
    });

    redoState.textAnnotations.forEach((pageId, annotations) {
      _pageTextAnnotations[pageId] = List<TextAnnotation>.from(annotations);
    });

    if (onDataChanged != null) {
      onDataChanged!();
    }
  }

// 5. Improved state saving for undo
  void _saveStateForUndo() {
    _undoStack.add(_captureCurrentState());
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

  // Update the updateTextAnnotation method to send over socket
  bool updateTextAnnotation(
    String pageId,
    int annotationId, {
    String? text,
    Offset? position,
    Color? color,
    double? fontSize,
    bool? isEditing,
    bool? isSelected,
    bool? isBold,
    bool? isItalic,
    bool? isBubble,
    bool? finishEdit,
  }) {
    bool result = false;
    TextAnnotation? updatedAnnotation;

    // Determine if this is a bubble annotation or regular text
    final workingWithBubbles = isBubble ?? false;

    if (!workingWithBubbles) {
      if (_pageTextAnnotations[pageId] == null) return false;

      final index =
          _pageTextAnnotations[pageId]!.indexWhere((a) => a.id == annotationId);

      if (index == -1) return false;

      final annotation = _pageTextAnnotations[pageId]![index];
      updatedAnnotation = annotation.copyWith(
        text: text ?? annotation.text,
        position: position ?? annotation.position,
        color: color ?? annotation.color,
        fontSize: fontSize ?? annotation.fontSize,
        isEditing: isEditing ?? annotation.isEditing,
        isSelected: isSelected ?? annotation.isSelected,
        isBold: isBold ?? annotation.isBold,
        isItalic: isItalic ?? annotation.isItalic,
      );

      _pageTextAnnotations[pageId]![index] = updatedAnnotation;

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

      result = true;
    } else {
      if (_pageBubbleAnnotations[pageId] == null) return false;

      final index = _pageBubbleAnnotations[pageId]!
          .indexWhere((a) => a.id == annotationId);

      if (index == -1) return false;

      final annotation = _pageBubbleAnnotations[pageId]![index];
      updatedAnnotation = annotation.copyWith(
        text: text ?? annotation.text,
        position: position ?? annotation.position,
        fontSize: fontSize ?? annotation.fontSize,
        isEditing: isEditing ?? annotation.isEditing,
        isSelected: isSelected ?? annotation.isSelected,
        isBold: isBold ?? annotation.isBold,
        isItalic: isItalic ?? annotation.isItalic,
      );

      _pageBubbleAnnotations[pageId]![index] = updatedAnnotation;

      if (isSelected == true) {
        // Deselect all other annotations
        for (int i = 0; i < _pageBubbleAnnotations[pageId]!.length; i++) {
          if (i != index) {
            _pageBubbleAnnotations[pageId]![i] =
                _pageBubbleAnnotations[pageId]![i].copyWith(
              isSelected: false,
              isEditing: false,
            );
          }
        }
        _selectedTextAnnotation = _pageBubbleAnnotations[pageId]![index];
      }

      if (isSelected == false && _selectedTextAnnotation?.id == annotationId) {
        _selectedTextAnnotation = null;
      }

      result = true;
    }

    // Send update to server if we have an updated annotation
    if (result && finishEdit == true) {
      _sendTextAnnotationUpdateToServer(pageId, updatedAnnotation);
    }

    return result;
  }

// Improved version of addTextAnnotation
  int? addTextAnnotation(String pageId, Offset position, Color color,
      double fontSize, bool isBold, bool isItalic, bool isBubble) {
    final int annotationId = DateTime.now().microsecondsSinceEpoch;

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
      isBubble: isBubble,
    );
    _saveStateForUndo();
    _redoStack.clear();

    // Add to local state
    if (isBubble) {
      _pageBubbleAnnotations[pageId] ??= [];
      _pageBubbleAnnotations[pageId]!.add(newAnnotation);
    } else {
      _pageTextAnnotations[pageId] ??= [];
      _pageTextAnnotations[pageId]!.add(newAnnotation);
    }

    _selectedTextAnnotation = newAnnotation;

    return annotationId;
  }

// Improved version of deleteTextAnnotation
  bool deleteTextAnnotation(String pageId, int annotationId, bool isBubble) {
    bool result = false;

    if (isBubble) {
      if (_pageBubbleAnnotations[pageId] == null) return false;

      final index = _pageBubbleAnnotations[pageId]!
          .indexWhere((a) => a.id == annotationId);
      if (index == -1) return false;

      _pageBubbleAnnotations[pageId]!.removeAt(index);

      if (_selectedTextAnnotation?.id == annotationId) {
        _selectedTextAnnotation = null;
      }

      result = true;
    } else {
      if (_pageTextAnnotations[pageId] == null) return false;

      final index =
          _pageTextAnnotations[pageId]!.indexWhere((a) => a.id == annotationId);
      if (index == -1) return false;

      _pageTextAnnotations[pageId]!.removeAt(index);

      if (_selectedTextAnnotation?.id == annotationId) {
        _selectedTextAnnotation = null;
      }

      result = true;
    }

    // Send delete to server if successful
    if (result) {
      _sendTextAnnotationDeleteToServer(pageId, annotationId, isBubble);
    }

    return result;
  }

  // Returns true if any non-empty annotations were deselected
  bool deselectAllTextAnnotations(String pageId) {
    final pageAnnotations = _pageTextAnnotations[pageId];
    final bubbleAnnotations = _pageBubbleAnnotations[pageId];

    if (pageAnnotations == null || bubbleAnnotations == null) return false;

    final combinedAnnotations = [...pageAnnotations, ...bubbleAnnotations];

    // Check if there are any selected or editing annotations with non-empty text
    bool hadMeaningfulEdits = combinedAnnotations
        .any((a) => (a.isSelected || a.isEditing) && a.text.trim().isNotEmpty);

    // Page annotations
    pageAnnotations.removeWhere((a) {
      if (a.text.trim().isEmpty) {
        _sendTextAnnotationDeleteToServer(pageId, a.id, false);
        return true;
      }
      return false;
    });

    // Bubble annotations
    bubbleAnnotations.removeWhere((a) {
      if (a.text.trim().isEmpty) {
        _sendTextAnnotationDeleteToServer(pageId, a.id, true);
        return true;
      }
      return false;
    });

    // Deselect and stop editing all remaining annotations
    for (int i = 0; i < pageAnnotations.length; i++) {
      _sendTextAnnotationUpdateToServer(pageId, pageAnnotations[i]);
    }
    for (int i = 0; i < bubbleAnnotations.length; i++) {
      _sendTextAnnotationUpdateToServer(pageId, bubbleAnnotations[i]);
    }

    _selectedTextAnnotation = null;
    return hadMeaningfulEdits;
  }

  getCurrentUserId() {}

  void disposeListeners() {
    // Clear the callback first to prevent any further UI updates
    onDataChanged = null; // Add this line to clear the callback

    // Remove socket event listeners
    if (_socketService != null) {
      _socketService!.off('canvas_state');
      _socketService!.off('drawing');
      _socketService!.off('eraser');
      _socketService!.off('request_canvas_state');
      _socketService!.off('file_users_update');
    }
  }
}

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

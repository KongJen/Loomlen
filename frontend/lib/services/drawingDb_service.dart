import 'package:flutter/material.dart';
import 'package:frontend/api/socketService.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/providers/paperdb_provider.dart';

/// Service responsible for managing drawing operations and state
class DrawingDBService {
  Function? onDataChanged;
  final Map<String, List<DrawingPoint>> _pageDrawingPoints = {};
  final List<Map<String, List<DrawingPoint>>> _undoStack = [];
  final List<Map<String, List<DrawingPoint>>> _redoStack = [];

  List<String> _pageIds = [];
  Map<String, PaperTemplate> _paperTemplates = {};
  DrawingPoint? _currentDrawingPoint;
  String _roomId = '';
  String _fileId = '';
  late SocketService _socketService;

  // Eraser configuration
  late EraserTool _eraserTool;
  double _eraserWidth = 10.0;
  EraserMode _eraserMode = EraserMode.point;

  List<String> users = [];

  DrawingDBService({
    bool isCollab = false,
    String roomId = '',
    String fileId = '',
    required SocketService socketService,
  }) {
    _socketService = socketService;
    _roomId = roomId;
    _fileId = fileId;
    _eraserTool = EraserTool(
      eraserWidth: _eraserWidth,
      eraserMode: _eraserMode,
      pageDrawingPoints: _pageDrawingPoints,
      undoStack: _undoStack,
      redoStack: _redoStack,
      onStateChanged: _onEraserStateChanged,
      currentPaperId: '',
    );

    _initializeSocketListeners();
    setfile();
  }

  void _initializeSocketListeners() {
    _socketService.on('file_users_update', (data) {
      users = data['users'].cast<String>();
    });

    // Listen for drawing updates from other clients
    _socketService.on('drawing', (data) {
      _handleIncomingDrawing(data['drawing'], data['pageId']);
    });

    // Add listener for eraser events
    _socketService.on('eraser', (data) {
      _handleIncomingEraser(data['eraserAction'], data['pageId']);
    });

    _socketService.on('canvas_state', (data) {
      if (data['canvasState'] != null && data['pageId'] != null) {
        _handleIncomingCanvasState(data['canvasState'], data['pageId']);
      }
    });

    // Add listener for canvas state requests
    _socketService.on('request_canvas_state', (data) {
      String requestingClientId = data['clientId'];
      String pageId = data['pageId'];

      // Only respond if we have data for this page and we're not the requester
      if (_pageDrawingPoints.containsKey(pageId) &&
          _pageDrawingPoints[pageId]!.isNotEmpty &&
          _socketService.socket?.id != requestingClientId) {
        _sendCanvasState(pageId, requestingClientId);
      }
    });
  }

//--------------------------
  void _saveAllDrawingsToDatabase() {
    // Implement your logic to save all drawings to the database
    // This could involve iterating over _pageIds and saving each page's data
    print("Saving all drawings to database...");
    final paperDBProvider = PaperDBProvider();
    for (String pageId in _pageIds) {
      List<DrawingPoint> points = _pageDrawingPoints[pageId] ?? [];
      paperDBProvider.saveDrawingData(pageId, points);
      // Save points to the database for the given pageId
      // Example: paperDBProvider.saveDrawingData(pageId, points);
    }
  }

  void setfile() {
    _socketService.emit('join_file', {
      'roomId': _roomId,
      'fileId': _fileId,
    });
  }

  void leavefile() {
    if (users.length == 1) {
      _saveAllDrawingsToDatabase();
    }
    _socketService.emit('leave_file', {
      'roomId': _roomId,
      'fileId': _fileId,
    });
  }

  void requestCanvasState(String pageId) {
    _socketService.emit('request_canvas_state', {
      'roomId': _roomId,
      'pageId': pageId,
    });
  }

// Add to your DrawingDBService class
  void _sendCanvasState(String pageId, String requestingClientId) {
    List<DrawingPoint> points = _pageDrawingPoints[pageId] ?? [];
    List<Map<String, dynamic>> serializedPoints =
        points.map((point) => point.toJson()).toList();

    Map<String, dynamic> data = {
      "roomId": _roomId,
      "pageId": pageId,
      "clientId": requestingClientId,
      "canvasState": serializedPoints,
    };

    _socketService.emit('canvas_state', data);
  }

  void _handleIncomingCanvasState(List<dynamic> canvasState, String pageId) {
    _pageDrawingPoints[pageId] = [];

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

    if (onDataChanged != null) {
      onDataChanged!();
    }
  }

  void _handleIncomingDrawing(
    Map<String, dynamic> data,
    String pageId,
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

    _pageDrawingPoints[pageId] ??= [];
    _pageDrawingPoints[pageId]!.add(drawingPoint);
    if (onDataChanged != null) {
      onDataChanged!();
    }
  }

  void _handleIncomingEraser(
    Map<String, dynamic> eraserAction,
    String pageId,
  ) {
    if (!_pageDrawingPoints.containsKey(pageId)) {
      _pageDrawingPoints[pageId] = [];
    }

    String type = eraserAction['type'];

    if (type == 'point') {
      // Handle point eraser
      Map<String, dynamic> positionData = eraserAction['position'];
      Offset position =
          Offset(positionData['x'].toDouble(), positionData['y'].toDouble());
      double width = eraserAction['width'].toDouble();

      // Create a temporary EraserTool for point erasing
      EraserTool tempEraserTool = EraserTool(
        eraserWidth: width,
        eraserMode: EraserMode.point,
        pageDrawingPoints: _pageDrawingPoints,
        undoStack: _undoStack,
        redoStack: _redoStack,
        onStateChanged: () {
          if (onDataChanged != null) {
            onDataChanged!();
          }
        },
        currentPaperId: pageId,
      );

      tempEraserTool.handleErasing(position);
    } else if (type == 'stroke') {
      // Handle stroke eraser by deleting the specified strokes
      List<int> deletedIds = List<int>.from(eraserAction['deletedIds']);

      List<DrawingPoint>? pointsForPage = _pageDrawingPoints[pageId];
      if (pointsForPage != null && pointsForPage.isNotEmpty) {
        pointsForPage.removeWhere((point) => deletedIds.contains(point.id));

        if (onDataChanged != null) {
          onDataChanged!();
        }
      }
    }
  }

  void _sendDrawingToServer(String pageId, DrawingPoint drawingPoint) {
    Map<String, dynamic> data = {
      "roomId": _roomId,
      "pageId": pageId,
      "drawing": drawingPoint.toJson(),
    };
    _socketService.emit('drawing', data);
  }

  // Add this method to DrawingDBService to send eraser stroke deletion data
  void _sendStrokeEraserToServer(String pageId, List<int> deletedStrokeIds) {
    Map<String, dynamic> data = {
      "roomId": _roomId,
      "pageId": pageId,
      "eraserAction": {
        "type": "stroke",
        "deletedIds": deletedStrokeIds,
      },
    };
    _socketService.emit('eraser', data);
  }

// Add this method to DrawingDBService to send point eraser data
  void _sendPointEraserToServer(String pageId, Offset position) {
    Map<String, dynamic> data = {
      "roomId": _roomId,
      "pageId": pageId,
      "eraserAction": {
        "type": "point",
        "position": {"x": position.dx, "y": position.dy},
        "width": _eraserWidth,
      },
    };
    _socketService.emit('eraser', data);
  }

  // Public getters
  List<String> getPageIds() => _pageIds;
  Map<String, PaperTemplate> getPaperTemplates() => _paperTemplates;
  Map<String, List<DrawingPoint>> getPageDrawingPoints() => _pageDrawingPoints;
  String getId() => _socketService.socket?.id ?? '';
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
    _undoStack.clear();
    _redoStack.clear();
    for (final pageId in pageIds) {
      final paperData = paperProvider.getPaperDBById(pageId);
      final List<DrawingPoint> pointsForPage = [];

      // Check if 'drawing_data' is not null and is a list
      if (paperData['drawing_data'] != null) {
        try {
          final List<dynamic> loadedStrokes = paperData['drawing_data'];

          for (final stroke in loadedStrokes) {
            if (stroke['type'] == 'drawing') {
              final point = DrawingPoint.fromJson(stroke);
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
    for (String pageId in _pageIds) {
      requestCanvasState(pageId);
    }
  }

  // Drawing operations
  void startDrawing(String pageId, Offset position, Color color, double width) {
    _currentDrawingPoint = DrawingPoint(
      id: DateTime.now().microsecondsSinceEpoch,
      offsets: [position],
      color: color,
      width: width,
      tool: 'pencil',
    );

    _sendDrawingToServer(pageId, _currentDrawingPoint!);
  }

  void continueDrawing(String pageId, Offset position) {
    if (_currentDrawingPoint == null) return;

    _currentDrawingPoint = _currentDrawingPoint!.copyWith(
      offsets: List.from(_currentDrawingPoint!.offsets)..add(position),
    );

    _sendDrawingToServer(pageId, _currentDrawingPoint!);
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

    if (_eraserMode == EraserMode.point) {
      _sendPointEraserToServer(pageId, position);
    } else if (_eraserMode == EraserMode.stroke &&
        _eraserTool.deletedStrokeIds.isNotEmpty) {
      _sendStrokeEraserToServer(pageId, _eraserTool.deletedStrokeIds);
    }
  }

  void continueErasing(String pageId, Offset position) {
    _eraserTool.handleErasing(position);

    if (_eraserMode == EraserMode.point) {
      _sendPointEraserToServer(pageId, position);
    } else if (_eraserMode == EraserMode.stroke &&
        _eraserTool.deletedStrokeIds.isNotEmpty) {
      _sendStrokeEraserToServer(pageId, _eraserTool.deletedStrokeIds);
    }
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

  getCurrentUserId() {}
}

extension StringCapitalizeExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

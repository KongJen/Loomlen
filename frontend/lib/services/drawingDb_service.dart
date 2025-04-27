import 'package:flutter/material.dart';
import 'package:frontend/api/socketService.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

/// Service responsible for managing drawing operations and state
class DrawingDBService {
  Function? onDataChanged;
  final Map<String, List<DrawingPoint>> _pageDrawingPoints = {};
  // final Map<String, List<DrawingPoint>> _pageDrawingPointsSocket = {};
  final List<Map<String, List<DrawingPoint>>> _undoStack = [];
  final List<Map<String, List<DrawingPoint>>> _redoStack = [];

  List<String> _pageIds = [];
  Map<String, PaperTemplate> _paperTemplates = {};
  DrawingPoint? _currentDrawingPoint;
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

    // Add listener for eraser events
    _socketService!.on('eraser', (data) {
      if (data['fileId'] == _fileId) {
        _handleIncomingEraser(
            data['eraserAction'], data['pageId'], data['state']);
      }
    });

    _socketService!.on('canvas_state', (data) {
      if (data['canvasState'] != null && data['fileId'] == _fileId) {
        _handleIncomingCanvasState(data['canvasState'], data['pageId'], data);
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
    List<DrawingPoint> points = _pageDrawingPoints[pageId] ?? [];
    List<Map<String, dynamic>> serializedPoints =
        points.map((point) => point.toJson()).toList();

    // Serialize undo and redo stacks
    List<Map<String, dynamic>> serializedUndoStack = _undoStack.map((state) {
      return {
        for (var entry in state.entries)
          entry.key: entry.value.map((point) => point.toJson()).toList()
      };
    }).toList();

    List<Map<String, dynamic>> serializedRedoStack = _redoStack.map((state) {
      return {
        for (var entry in state.entries)
          entry.key: entry.value.map((point) => point.toJson()).toList()
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
    };

    _socketService!.emit('canvas_state', data);
  }

  void _handleIncomingCanvasState(
      List<dynamic> canvasState, String pageId, Map<String, dynamic> data) {
    if (onDataChanged == null) return;

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

    // 🆕 Handle undoStack and redoStack if they exist
    if (data.containsKey('undoStack') && data['undoStack'] != null) {
      _undoStack.clear();
      for (var state in data['undoStack']) {
        Map<String, List<DrawingPoint>> pageState = {};
        for (var entry in state.entries) {
          pageState[entry.key] = (entry.value as List)
              .map((pointData) => DrawingPoint.fromJson(pointData))
              .toList();
        }
        _undoStack.add(pageState);
      }
    }

    if (data.containsKey('redoStack') && data['redoStack'] != null) {
      _redoStack.clear();
      for (var state in data['redoStack']) {
        Map<String, List<DrawingPoint>> pageState = {};
        for (var entry in state.entries) {
          pageState[entry.key] = (entry.value as List)
              .map((pointData) => DrawingPoint.fromJson(pointData))
              .toList();
        }
        _redoStack.add(pageState);
      }
    }

    if (onDataChanged != null) {
      onDataChanged!();
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
    _redoStack.add(
      _pageDrawingPoints.map(
        (key, value) => MapEntry(key, List<DrawingPoint>.from(value)),
      ),
    );

    // Restore previous state
    final previousState = _undoStack.removeLast();
    _pageDrawingPoints.clear();
    _pageDrawingPoints.addAll(previousState);

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
    _pageDrawingPoints.clear();
    _pageDrawingPoints.addAll(redoState);

    if (onDataChanged != null) {
      onDataChanged!();
    }
  }

// 5. Improved state saving for undo
  void _saveStateForUndo() {
    _undoStack.add(
      _pageDrawingPoints.map(
        (key, value) => MapEntry(key, List<DrawingPoint>.from(value)),
      ),
    );
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

extension StringCapitalizeExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

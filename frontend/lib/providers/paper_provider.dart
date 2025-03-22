import 'package:flutter/foundation.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'package:frontend/items/template_item.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';

class PaperProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final List<Map<String, dynamic>> _papers = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get papers => List.unmodifiable(_papers);

  PaperProvider() {
    _loadPapers();
  }

  Future<void> loadPapers() async {
    await _loadPapers();
  }

  Future<void> _loadPapers() async {
    _papers.clear();
    _papers.addAll(await _storageService.loadData('papers'));
    notifyListeners();
  }

  Future<void> _savePapers() async {
    await _storageService.saveData('papers', _papers);
  }

  /// Add a new paper
  String addPaper(
    PaperTemplate template,
    int pageNumber,
    List<Map<String, dynamic>>? drawingData,
    String? pdfPath,
    double? width,
    double? height,
    String fileId,
  ) {
    final String paperId = _uuid.v4();
    final newPaper = {
      'fileId': fileId,
      'id': paperId,
      'templateId': template.id,
      'drawingData': drawingData ?? [],
      'PageNumber': pageNumber,
      'pdfPath': pdfPath,
      'width': width ?? 595.0,
      'height': height ?? 842.0,
    };

    _papers.add(newPaper);
    _savePapers();
    notifyListeners();
    return paperId;
  }

  String addPaperFromClone(Map<String, dynamic> paperData, String newFileId) {
    final String paperId = _uuid.v4();

    // Create a new paper with the cloned data but new IDs
    final newPaper = {
      'fileId': newFileId,
      'id': paperId,
      'templateId': paperData['templateId'],
      'templateType': paperData['templateType'],
      'drawingData': paperData['drawingData'] ?? [],
      'PageNumber': paperData['PageNumber'],
      'pdfPath': paperData['pdfPath'],
      'width': paperData['width'] ?? 595.0,
      'height': paperData['height'] ?? 842.0,
    };

    _papers.add(newPaper);
    _savePapers();
    notifyListeners();
    return paperId;
  }

  /// Update drawing data
  Future<void> updatePaperDrawingData(
    String paperId,
    List<Map<String, dynamic>> drawingData,
  ) async {
    final index = _papers.indexWhere((paper) => paper['id'] == paperId);
    if (index != -1) {
      _papers[index]['drawingData'] = drawingData;
      _savePapers();
      notifyListeners();
    }
  }

  /// Get paper by ID
  Map<String, dynamic>? getPaperById(String paperId) {
    return _papers.firstWhere(
      (paper) => paper['id'] == paperId,
      orElse: () => {},
    );
  }

  List<DrawingPoint> getDrawingPointsForPage(String pageId) {
    final paperData = _papers.firstWhere(
      (paper) => paper['id'] == pageId,
      orElse: () => {},
    );

    if (paperData['drawingData'] == null) {
      return []; // No drawing data found
    }

    final List<DrawingPoint> drawingPoints = [];

    // Process the drawingData and create DrawingPoint objects
    for (final stroke in paperData['drawingData']) {
      if (stroke['type'] == 'drawing') {
        final point = DrawingPoint.fromJson(stroke['data']);
        if (point.offsets.isNotEmpty) {
          drawingPoints.add(point);
        }
      }
    }

    return drawingPoints;
  }

  /// Delete paper
  Future<void> deletePaper(String paperId) async {
    _papers.removeWhere((paper) => paper['id'] == paperId);
    _savePapers();
    notifyListeners();
  }
}

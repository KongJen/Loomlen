import 'package:flutter/foundation.dart';
import 'package:frontend/api/apiService.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'package:frontend/items/template_item.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';

class PaperDBProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _papers = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get papers => List.unmodifiable(_papers);

  Future<void> loadPapers(String fileId) async {
    try {
      _papers.clear();
      final folderDBData = await _apiService.getPaper(fileId);
      _papers.addAll(folderDBData);
      notifyListeners();
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  void updateFiles(List<Map<String, dynamic>> newPapers) {
    _papers.clear();
    _papers.addAll(newPapers);
    notifyListeners();
  }

  /// Add a new paper
  Future<String> addPaper(
    PaperTemplate template,
    int pageNumber,
    double? width,
    double? height,
    String fileId,
  ) async {
    final String paperId = _uuid.v4();
    await _apiService.addPaper(
        id: paperId,
        fileId: fileId,
        templateId: template.id,
        pageNumber: pageNumber,
        width: width ?? 595.0,
        height: height ?? 842.0);

    notifyListeners();
    return paperId;
  }

  void getPaperDBById(String paperId) {}

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
}

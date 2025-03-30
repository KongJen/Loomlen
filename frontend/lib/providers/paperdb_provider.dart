import 'package:flutter/foundation.dart';
import 'package:frontend/api/apiService.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'package:frontend/items/template_item.dart';
import 'package:uuid/uuid.dart';

class PaperDBProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _papers = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get papers => List.unmodifiable(_papers);

  Future<void> loadPapers(String roomId) async {
    try {
      _papers.clear();
      final paperDBData = await _apiService.getPaper(roomId);
      _papers.addAll(paperDBData);
      notifyListeners();
    } catch (e) {
      print('Error loading papers: $e');
    }
  }

  void updatePapers(List<Map<String, dynamic>> newPapers) {
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
    String roomId,
  ) async {
    final String paperId = _uuid.v4();
    await _apiService.addPaper(
        id: paperId,
        roomId: roomId,
        fileId: fileId,
        templateId: template.id,
        pageNumber: pageNumber,
        width: width ?? 595.0,
        height: height ?? 842.0);

    notifyListeners();
    return paperId;
  }

  Map<String, dynamic> getPaperDBById(String paperId) {
    return _papers.firstWhere(
      (paper) => paper['id'] == paperId,
      orElse: () => {},
    );
  }

  Future<void> updatePaperDrawingData(
    String paperId,
    List<Map<String, dynamic>> drawingData,
  ) async {
    // Send updated drawing data to the backend
    await _apiService.updateDraw(paperId, drawingData);
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

  List<String> getPaperIdsByFileId(String fileId) {
    return _papers
        .where(
            (paper) => paper['file_id'] == fileId) // Filter papers by file_id
        .map((paper) =>
            paper['id'].toString()) // Map filtered papers to their id
        .toList();
  }

  PaperTemplate getPaperTemplate(String templateId) {
    return PaperTemplateFactory.getTemplate(templateId);
  }
}

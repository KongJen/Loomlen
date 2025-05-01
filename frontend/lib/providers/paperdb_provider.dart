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

  void updatePaper(Map<String, dynamic> paperData) {
    print("paperData: $paperData");
    final index = _papers.indexWhere((paper) => paper['id'] == paperData['id']);
    if (index != -1) {
      _papers[index] = paperData;
    } else {
      _papers.add(paperData);
    }
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
    String? image,
  ) async {
    final String paperId = _uuid.v4();
    await _apiService.addPaper(
        id: paperId,
        roomId: roomId,
        fileId: fileId,
        templateId: template.id,
        pageNumber: pageNumber,
        width: width ?? 595.0,
        height: height ?? 842.0,
        image: image ?? '');

    notifyListeners();
    return paperId;
  }

  Map<String, dynamic> getPaperDBById(String paperId) {
    return _papers.firstWhere(
      (paper) => paper['id'] == paperId,
      orElse: () => {},
    );
  }

  List<DrawingPoint> getDrawingPointsForPage(String pageId) {
    final paperData = _papers.cast<Map<String, dynamic>>().firstWhere(
          (paper) => paper['id'] == pageId,
          orElse: () => {},
        );

    final drawingData = paperData['drawing_data'];
    if (drawingData == null || drawingData is! List) {
      return [];
    }

    final List<DrawingPoint> drawingPoints = [];

    for (final stroke in drawingData) {
      if (stroke['type'] == 'drawing') {
        try {
          final point = DrawingPoint.fromJson(stroke); // Use full stroke
          if (point.offsets.isNotEmpty) {
            drawingPoints.add(point);
          }
        } catch (e) {
          debugPrint("Failed to parse stroke: $e");
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

  void saveDrawingData(String pageId, List<DrawingPoint> points) {
    _apiService.updateDraw(pageId, points);
  }
}

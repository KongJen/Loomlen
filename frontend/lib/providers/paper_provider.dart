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

  String insertPaperAt(
    String fileId,
    int insertPosition, // Position to insert (page number - 1)
    PaperTemplate template,
    String? pdfPath,
    double? width,
    double? height,
  ) {
    // Get all papers for this file
    final List<String> paperIds = getPaperIdsByFileId(fileId);

    // Calculate the new page number (position + 1)
    final int newPageNumber = insertPosition + 1;

    // Create the new paper
    final String newPaperId = _uuid.v4();
    final Map<String, dynamic> newPaper = {
      'fileId': fileId,
      'id': newPaperId,
      'templateId': template.id,
      'drawingData': [],
      'PageNumber': newPageNumber,
      'pdfPath': pdfPath,
      'width': width ?? 595.0,
      'height': height ?? 842.0,
    };

    // Add the paper to the papers collection
    _papers.add(newPaper);

    // Update page numbers for all papers that come after the insertion point
    for (int i = 0; i < _papers.length; i++) {
      final paper = _papers[i];
      if (paper['fileId'] == fileId &&
          paper['id'] != newPaperId &&
          (paper['PageNumber'] as int) >= newPageNumber) {
        // Increment the page number for all papers after the insertion point
        _papers[i]['PageNumber'] = (paper['PageNumber'] as int) + 1;
      }
    }

    // Save changes
    _savePapers();
    notifyListeners();

    print("paperIdddddddddddd: $newPaperId");

    return newPaperId;
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

  Future<void> updatePaperRecognizedTexts(
    String paperId,
    List<Map<String, dynamic>> recognizedTexts,
  ) async {
    final index = _papers.indexWhere((paper) => paper['id'] == paperId);
    if (index != -1) {
      _papers[index]['recognizedTexts'] = recognizedTexts;
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

  List<Map<String, dynamic>> getRecognizedTextsForPage(String pageId) {
    final paperData = _papers.firstWhere(
      (paper) => paper['id'] == pageId,
      orElse: () => {},
    );

    if (paperData.isEmpty || paperData['recognizedTexts'] == null) {
      return [];
    }

    return List<Map<String, dynamic>>.from(paperData['recognizedTexts']);
  }

  List<String> getPaperIdsByFileId(String fileId) {
    final filteredPapers =
        _papers.where((paper) => paper['fileId'] == fileId).toList();

    filteredPapers.sort(
      (a, b) => (a['PageNumber'] as int).compareTo(b['PageNumber'] as int),
    );

    return filteredPapers.map((paper) => paper['id'].toString()).toList();
  }

  PaperTemplate getPaperTemplate(String templateId) {
    return PaperTemplateFactory.getTemplate(templateId);
  }

  /// Delete paper
  /// Delete paper and update page numbers of remaining papers in the same file
  Future<void> deletePaper(String paperId) async {
    // Find the paper to delete
    final paperToDelete = _papers.firstWhere(
      (paper) => paper['id'] == paperId,
      orElse: () => {},
    );

    if (paperToDelete.isEmpty) {
      return; // Paper not found
    }

    // Get the fileId and page number of the paper to be deleted
    final String fileId = paperToDelete['fileId'];
    final int deletedPageNumber = paperToDelete['PageNumber'];

    // Remove the paper
    _papers.removeWhere((paper) => paper['id'] == paperId);

    // Update page numbers for all papers that come after the deleted one
    for (int i = 0; i < _papers.length; i++) {
      final paper = _papers[i];
      if (paper['fileId'] == fileId &&
          (paper['PageNumber'] as int) > deletedPageNumber) {
        // Decrement the page number for all papers after the deleted one
        _papers[i]['PageNumber'] = (paper['PageNumber'] as int) - 1;
      }
    }

    _savePapers();
    notifyListeners();
  }

  void swapPaperOrder(String fileId, int fromIndex, int toIndex) {
    // Get all papers for this file
    final paperIds = getPaperIdsByFileId(fileId);

    if (fromIndex < 0 ||
        fromIndex >= paperIds.length ||
        toIndex < 0 ||
        toIndex >= paperIds.length) {
      return; // Invalid indices
    }

    // Get the papers by their IDs in the current order
    final List<Map<String, dynamic>> filePapers = [];
    for (final paperId in paperIds) {
      final paper = getPaperById(paperId);
      if (paper != null && paper.isNotEmpty) {
        filePapers.add(paper);
      }
    }

    // Move the paper in the list
    final movedPaper = filePapers.removeAt(fromIndex);
    filePapers.insert(toIndex, movedPaper);

    // Update page numbers to match the new order
    for (int i = 0; i < filePapers.length; i++) {
      final paperId = filePapers[i]['id'];
      final index = _papers.indexWhere((paper) => paper['id'] == paperId);
      if (index != -1) {
        _papers[index]['PageNumber'] =
            i + 1; // Page numbers typically start from 1
      }
    }

    // Save changes to storage
    _savePapers();
    notifyListeners();
  }
}

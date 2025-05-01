// Create file: lib/services/paper_service.dart

import 'package:frontend/items/template_item.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';

/// Service responsible for paper operations
class PaperService {
  /// Get all papers for a specific file
  List<Map<String, dynamic>> getPapersForFile(
    PaperProvider provider,
    PaperDBProvider dbProvider,
    String fileId,
    bool collab,
  ) {
    if (collab) {
      return dbProvider.papers
          .where((paper) => paper['file_id'] == fileId)
          .toList();
    } else {
      return provider.papers
          .where((paper) => paper['fileId'] == fileId)
          .toList();
    }
  }

  /// Add a new page to the paper
  void addNewPage(
    PaperProvider provider,
    PaperDBProvider dbProvider,
    String fileId,
    PaperTemplate template,
    String roomId,
    bool collab,
  ) {
    final papers = getPapersForFile(provider, dbProvider, fileId, collab);
    int newPageNumber = 1;

    if (collab) {
      if (papers.isNotEmpty) {
        final lastPaper = papers.last;
        newPageNumber = (lastPaper['page_number'] as int? ?? 0) + 1;
      }

      dbProvider.addPaper(
          template, newPageNumber, 595.0, 842.0, fileId, roomId, '');
    } else {
      if (papers.isNotEmpty) {
        final lastPaper = papers.last;
        newPageNumber = (lastPaper['PageNumber'] as int? ?? 0) + 1;
      }

      provider.addPaper(
        template,
        newPageNumber,
        null,
        null,
        595.0, // Default width (A4)
        842.0, // Default height (A4)
        fileId,
      );
    }
  }

  /// Reload all paper data for a file and return updated page IDs
  List<String> reloadPaperData(
    PaperProvider provider,
    PaperDBProvider dbProvider,
    String fileId,
    bool collab,
  ) {
    final papers = getPapersForFile(provider, dbProvider, fileId, collab);
    return papers.map((paper) => paper['id'].toString()).toList();
  }
}

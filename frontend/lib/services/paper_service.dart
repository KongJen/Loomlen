// Create file: lib/services/paper_service.dart

import 'package:flutter/material.dart';
import 'package:frontend/model/template_model.dart';
import 'package:frontend/providers/paper_provider.dart';

/// Service responsible for paper operations
class PaperService {
  /// Get all papers for a specific file
  List<Map<String, dynamic>> getPapersForFile(
    PaperProvider provider,
    String fileId,
  ) {
    return provider.papers.where((paper) => paper['fileId'] == fileId).toList();
  }

  /// Add a new page to the paper
  void addNewPage(
    PaperProvider provider,
    String fileId,
    PaperTemplate template,
  ) {
    final papers = getPapersForFile(provider, fileId);
    int newPageNumber = 1;

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

  /// Reload all paper data for a file and return updated page IDs
  List<String> reloadPaperData(PaperProvider provider, String fileId) {
    final papers = getPapersForFile(provider, fileId);
    return papers.map((paper) => paper['id'].toString()).toList();
  }
}

import 'package:flutter/foundation.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';

class FileProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final List<Map<String, dynamic>> _files = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get files => List.unmodifiable(_files);

  FileProvider() {
    _loadFiles();
  }

  Future<void> loadFiles() async {
    await _loadFiles();
  }

  Future<void> _loadFiles() async {
    _files.clear();
    _files.addAll(await _storageService.loadData('files'));
    notifyListeners();
  }

  Future<void> _saveFiles() async {
    await _storageService.saveData('files', _files);
  }

  String addFile(String name, {String? roomId, String? parentFolderId}) {
    final String fileId = _uuid.v4();
    final newFile = {
      'id': fileId,
      'roomId': roomId,
      'parentFolderId': parentFolderId,
      'name': name,
      'createdDate': DateTime.now().toIso8601String(),
    };

    _files.add(newFile);
    _saveFiles();
    notifyListeners();

    return fileId; // Return the generated fileId
  }

  void renameFile(String fileId, String newName) {
    final file = _files.firstWhere((f) => f['id'] == fileId, orElse: () => {});
    if (file.isNotEmpty) {
      file['name'] = newName;
      _saveFiles();
      notifyListeners();
    }
  }

  Future<void> deleteFile(String fileId, PaperProvider paperProvider) async {
    await paperProvider.loadPapers();

    List<Map<String, dynamic>> papersToDelete =
        paperProvider.papers
            .where((paper) => paper['fileId'] == fileId)
            .toList();

    for (var paper in papersToDelete) {
      await paperProvider.deletePaper(paper['id']);
    }
    _files.removeWhere((file) => file['id'] == fileId);
    await _saveFiles();
    notifyListeners();
  }
}

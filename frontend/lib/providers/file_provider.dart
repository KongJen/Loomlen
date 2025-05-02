import 'package:flutter/foundation.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import 'package:frontend/api/apiService.dart';

class FileProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _files = [];
  final List<Map<String, dynamic>> _sharedFiles = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get files => List.unmodifiable(_files);
  List<Map<String, dynamic>> get sharedFiles => List.unmodifiable(_sharedFiles);

  FileProvider() {
    _loadFiles();
    _loadSharedFiles();
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

  Future<void> _loadSharedFiles() async {
    try {
      _sharedFiles.clear();
      final sharedFilesData = await _apiService.getSharedFiles();
      print("Shared Files Data: $sharedFilesData");
      if (sharedFilesData.isNotEmpty) {
        _sharedFiles.addAll(sharedFilesData);
      }

      notifyListeners();
    } catch (e) {
      print('Error loading shared files: $e');
    }
  }

  Future<void> refreshSharedFiles() async {
    await _loadSharedFiles();
  }

  Map<String, String> addFile(String name,
      {String? roomId, String? parentFolderId}) {
    String baseName = name.trim();
    String uniqueName = baseName;
    int counter = 1;

    // Filter files within the same room and parent folder
    final existingFiles = _files.where((file) =>
        file['roomId'] == roomId && file['parentFolderId'] == parentFolderId);

    // Ensure name is unique in this context
    while (existingFiles.any((file) => file['name'] == uniqueName)) {
      uniqueName = '$baseName ($counter)';
      counter++;
    }

    final String fileId = _uuid.v4();
    final newFile = {
      'id': fileId,
      'roomId': roomId,
      'parentFolderId': parentFolderId,
      'name': uniqueName,
      'createdDate': DateTime.now().toIso8601String(),
      'isShared': false,
    };

    _files.add(newFile);
    _saveFiles();
    notifyListeners();

    return {'id': fileId, 'name': uniqueName};
  }

  void renameFile(String fileId, String newName) {
    final file = _files.firstWhere((f) => f['id'] == fileId, orElse: () => {});
    if (file.isEmpty) return;

    String baseName = newName.trim();
    String uniqueName = baseName;
    int counter = 1;

    final roomId = file['roomId'];
    final parentFolderId = file['parentFolderId'];

    // Filter files within the same room and parent folder, excluding the file being renamed
    final existingFiles = _files.where((f) =>
        f['roomId'] == roomId &&
        f['parentFolderId'] == parentFolderId &&
        f['id'] != fileId);

    // Ensure the new name is unique
    while (existingFiles.any((f) => f['name'] == uniqueName)) {
      uniqueName = '$baseName ($counter)';
      counter++;
    }

    file['name'] = uniqueName;
    _saveFiles();
    notifyListeners();
  }

  Future<void> deleteFile(String fileId, PaperProvider paperProvider) async {
    await paperProvider.loadPapers();

    List<Map<String, dynamic>> papersToDelete = paperProvider.papers
        .where((paper) => paper['fileId'] == fileId)
        .toList();

    for (var paper in papersToDelete) {
      await paperProvider.deletePaper(paper['id']);
    }
    _files.removeWhere((file) => file['id'] == fileId);
    await _saveFiles();
    notifyListeners();
  }

  Future<void> shareFile(
    String fileId,
    List<String> sharedWith,
    String permission,
    PaperProvider paperProvider,
  ) async {
    try {
      final file = _files.firstWhere(
        (f) => f['id'] == fileId,
        orElse: () => {},
      );
      if (file.isEmpty) return;

      // Get all papers for this file
      await paperProvider.loadPapers();
      final papers =
          paperProvider.papers.where((p) => p['fileId'] == fileId).toList();

      // Share the file
      await _apiService.shareFile(
        fileId: fileId,
        sharedWith: sharedWith,
        permission: permission,
        fileContent: [file], // Send the file data
        paperData: papers, // Send the paper data
        name: file['name'],
      );

      // Update the local file to indicate it's shared
      file['isShared'] = true;
      await _saveFiles();

      // Refresh shared files
      await refreshSharedFiles();

      notifyListeners();
    } catch (e) {
      print('Error sharing file: $e');
      rethrow;
    }
  }

  // Clone a shared file
  Future<String> cloneSharedFile(
    String sharedFileId,
    PaperProvider paperProvider,
  ) async {
    try {
      final sharedFileData = await _apiService.cloneSharedFile(sharedFileId);

      // Add the file locally
      final String newFileId = _uuid.v4();
      final newFile = {
        'id': newFileId,
        'name': '${sharedFileData['name']} (Clone)',
        'createdDate': DateTime.now().toIso8601String(),
        'isShared': false,
        'clonedFrom': sharedFileId,
      };

      _files.add(newFile);
      await _saveFiles();

      // Extract paper data
      final List<dynamic> paperData = sharedFileData['paperData'];

      // Add papers for this file
      for (final paper in paperData) {
        final Map<String, dynamic> paperMap = paper;

        // Create a new paper with the cloned file ID
        paperProvider.addPaperFromClone(paperMap, newFileId);
      }

      notifyListeners();
      return newFileId;
    } catch (e) {
      print('Error cloning shared file: $e');
      rethrow;
    }
  }
}
